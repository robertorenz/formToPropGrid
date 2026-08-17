@echo off
rem =====================================================================
rem build.bat - builds the ClaPropGrid demo.
rem
rem The class is pulled in by PropGridClass's own LINK('PropGrid.clw')
rem attribute, so PropGrid.inc / .clw have to sit on the redirection
rem path.  The simplest place is right here, so they are copied in.
rem
rem Needs Clarion (any of 9..12) - point CLARIONBIN at its bin folder
rem if it is not the default below.
rem =====================================================================
setlocal
if "%CLARIONBIN%"=="" set CLARIONBIN=C:\clarion12\bin
set MSBUILD=C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe

cd /d "%~dp0"
echo --- staging the class and the import lib ---
copy /y ..\..\clarion\PropGrid.inc  . >nul || goto :missing
copy /y ..\..\clarion\PropGrid.clw  . >nul || goto :missing
copy /y ..\..\clarion\propgrid.lib  . >nul || goto :missing

echo --- building PropGridDemo.exe ---
"%MSBUILD%" PropGridDemo.cwproj /p:ClarionBinPath=%CLARIONBIN% /v:minimal || goto :failed

rem  The DLL is staged AFTER the link on purpose: the Clarion build
rem  copies any DLL it finds on the redirection path (accessory\bin)
rem  into the output folder, which would otherwise drop a stale
rem  propgrid.dll on top of the one we just built.
echo --- staging propgrid.dll (after the link, so it wins) ---
copy /y ..\..\bin\propgrid.dll      . >nul || goto :missing

echo.
echo Build OK - run PropGridDemo.exe from this folder.
endlocal & exit /b 0

:missing
echo.
echo Could not find the class / lib / dll.  Build the DLL first:
echo     ..\..\src\build.bat
endlocal & exit /b 1

:failed
echo.
echo Build FAILED.  If it cannot find the Clarion targets, set CLARIONBIN:
echo     set CLARIONBIN=C:\clarion12\bin ^&^& build.bat
endlocal & exit /b 1
