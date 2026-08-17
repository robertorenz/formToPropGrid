@echo off
rem =====================================================================
rem build.bat - builds PROPGRID.DLL (32-bit, for Clarion) + testhost.exe
rem Requires Visual Studio 2022 (any edition).
rem =====================================================================
setlocal
set VSDEV="%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
if not exist %VSDEV% set VSDEV="%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat"
if not exist %VSDEV% set VSDEV="%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
call %VSDEV% x86 || exit /b 1

cd /d "%~dp0"
if not exist ..\bin mkdir ..\bin

echo --- building PROPGRID.DLL (x86) ---
cl /nologo /W3 /O2 /MT /EHs-c- /GS /LD propgrid.cpp /Fe..\bin\propgrid.dll ^
   /link /DEF:propgrid.def /SUBSYSTEM:WINDOWS user32.lib gdi32.lib || exit /b 1

echo --- building testhost.exe (x86) ---
cl /nologo /W3 /O2 /MT testhost.c /Fe..\bin\testhost.exe ^
   /link /SUBSYSTEM:WINDOWS ..\bin\propgrid.lib user32.lib || exit /b 1

echo --- generating Clarion import library (all Clarion versions) ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-clarion-lib.ps1" || exit /b 1

del *.obj 2>nul
echo Build OK: ..\bin\propgrid.dll  ..\bin\testhost.exe  ..\clarion\propgrid.lib
endlocal
