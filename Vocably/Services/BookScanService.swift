import Foundation
import Vision
import UIKit
import VocablyDomain

// Photograph-a-vocab-book OCR (HANDOFF §11 node 5J-0, extended). Recognises text WITH
// bounding boxes, then reconstructs the page layout: rows by vertical position, columns by
// horizontal position → pairs each term with its translation(s). Parenthetical notes become
// the example/description. Pure Vision + heuristics; no network.
struct BookScanService {

    /// Extract vocabulary pairs from a photo of a vocabulary list.
    func extractVocabulary(from image: UIImage) async -> [CardDraft] {
        guard let cg = image.cgImage else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["es", "en", "de", "fr", "it"]

            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            try? handler.perform([request])

            // (text, boundingBox) — box is normalised, origin bottom-left.
            let lines: [(text: String, box: CGRect)] = (request.results ?? []).compactMap { obs in
                guard let s = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces),
                      !s.isEmpty else { return nil }
                return (s, obs.boundingBox)
            }
            return Self.reconstruct(lines)
        }.value
    }

    /// Turn positioned text fragments into term/translation drafts.
    static func reconstruct(_ lines: [(text: String, box: CGRect)]) -> [CardDraft] {
        guard !lines.isEmpty else { return [] }

        // Group into rows: walk top→bottom (origin bottom-left, so larger midY first).
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }
        let rowTolerance = max(0.012, (lines.map { $0.box.height }.reduce(0, +) / Double(lines.count)) * 0.6)

        var rows: [[(text: String, box: CGRect)]] = []
        for item in sorted {
            if let refY = rows.last?.first?.box.midY, abs(refY - item.box.midY) < rowTolerance {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }

        var drafts: [CardDraft] = []
        for row in rows {
            let cells = row.sorted { $0.box.minX < $1.box.minX }
            var term = ""
            var rhs = ""

            if cells.count >= 2 {
                // Two columns detected: leftmost = term, the rest = translation column.
                term = cells[0].text
                rhs = cells[1...].map { $0.text }.joined(separator: " ")
            } else if let only = cells.first {
                // Single fragment: split on a separator or a wide internal gap.
                (term, rhs) = splitSingle(only.text)
            }

            term = term.trimmingCharacters(in: .whitespaces)
            rhs = rhs.trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty, !rhs.isEmpty, !isHeader(term, rhs) else { continue }

            // Pull a parenthetical note out of the translation → example/description.
            var translation = rhs
            var note: String?
            if let r = rhs.range(of: #"\(([^)]*)\)"#, options: .regularExpression) {
                note = String(rhs[r]).trimmingCharacters(in: CharacterSet(charactersIn: "() "))
                translation = rhs.replacingCharacters(in: r, with: "").trimmingCharacters(in: .whitespaces)
            }
            // Normalise "a, b /c" multiple translations into ", "-separated.
            translation = translation
                .replacingOccurrences(of: " /", with: ", ")
                .replacingOccurrences(of: "/", with: ", ")
                .replacingOccurrences(of: " ,", with: ",")

            drafts.append(CardDraft(term: term, translation: translation, example: note))
        }
        return drafts
    }

    /// Split a single recognised line into term/translation on a separator or big gap.
    private static func splitSingle(_ s: String) -> (String, String) {
        for sep in [" — ", " – ", " - ", " = ", "\t", "  ", " : ", ": "] {
            if let r = s.range(of: sep) {
                return (String(s[s.startIndex..<r.lowerBound]), String(s[r.upperBound...]))
            }
        }
        return (s, "")
    }

    /// Heuristic: drop obvious header/title rows (e.g. "Spanish English", "Unit 3").
    private static func isHeader(_ term: String, _ rhs: String) -> Bool {
        let langWords: Set<String> = ["spanish", "english", "german", "french", "italian",
                                      "español", "inglés", "deutsch", "vocabulario", "vocabulary", "unidad", "unit"]
        return langWords.contains(term.lowercased()) || langWords.contains(rhs.lowercased())
    }
}
