@echo off
REM Local dev helper: run Swift against the VocablyCore package on this machine.
REM Usage (from repo root):  cmd.exe /c sw.bat <swift-args>   e.g.  cmd.exe /c sw.bat test
set "SWIFT_ROOT=C:\Users\duwef\AppData\Local\Programs\Swift"
set "PATH=%SWIFT_ROOT%\Toolchains\6.3.2+Asserts\usr\bin;%SWIFT_ROOT%\Runtimes\6.3.2\usr\bin;%PATH%"
set "SDKROOT=%SWIFT_ROOT%\Platforms\6.3.2\Windows.platform\Developer\SDKs\Windows.sdk"
cd /d "%~dp0Packages\VocablyCore"
swift %*
