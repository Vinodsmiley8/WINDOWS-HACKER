@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ---------------------------------------------------------
:: Usage:
::   make_sfx_bundle_and_search.bat "C:\Program Files\7-Zip\7z.exe" ^
::                                  "C:\Program Files\7-Zip\7z.sfx" ^
::                                  "C:\path\to\yourapp.exe" ^
::                                  "C:\path\to\yourscript.bat" ^
::                                  "C:\path\to\output-bundle.exe"
:: ---------------------------------------------------------

if "%~5"=="" (
  echo Usage: %~nx0 "path\to\7z.exe" "path\to\7z.sfx" "app.exe" "script.bat" "output.exe"
  echo.
  echo Example:
  echo   %~nx0 "C:\Program Files\7-Zip\7z.exe" "C:\Program Files\7-Zip\7z.sfx" app.exe install.bat bundle.exe
  exit /b 1
)

set "ZIPEXE=%~1"
set "SFX=%~2"
set "APP=%~3"
set "BAT=%~4"
set "OUT=%~5"

:: short names (safe for use inside blocks)
set "APPNAME=%~nx3"
set "BATNAME=%~nx4"

:: check files
if not exist "%ZIPEXE%" (
  echo ERROR: 7z.exe not found at "%ZIPEXE%"
  exit /b 2
)
if not exist "%SFX%" (
  echo ERROR: SFX stub not found at "%SFX%"
  exit /b 3
)
if not exist "%APP%" (
  echo ERROR: app file not found: "%APP%"
  exit /b 4
)
if not exist "%BAT%" (
  echo ERROR: bat file not found: "%BAT%"
  exit /b 5
)

:: prepare temp work dir
set "TMP=%TEMP%\sfxbundle_%RANDOM%_%RANDOM%"
mkdir "%TMP%" 2>nul || (
  echo Failed to create temp dir "%TMP%"
  exit /b 6
)

:: ensure cleanup on error/exit by jumping to :cleanup
set "ERRORLEVEL_TMP=0"

:: copy files into temp (use just the filenames so archive is clean)
copy /Y "%APP%"  "%TMP%\%APPNAME%" >nul 2>&1 || (
  echo Failed copying "%APP%" to temp.
  set "ERRORLEVEL_TMP=7"
  goto :cleanup
)
copy /Y "%BAT%"  "%TMP%\%BATNAME%" >nul 2>&1 || (
  echo Failed copying "%BAT%" to temp.
  set "ERRORLEVEL_TMP=8"
  goto :cleanup
)

:: create 7z archive containing only the two files (avoid bundling the archive itself)
echo Creating 7z archive...
pushd "%TMP%" >nul 2>&1 || (
  echo Failed to pushd "%TMP%"
  set "ERRORLEVEL_TMP=9"
  goto :cleanup
)

"%ZIPEXE%" a -t7z "%TMP%\bundle.7z" "%APPNAME%" "%BATNAME%" >nul 2>&1
if errorlevel 1 (
  echo 7z archive creation failed.
  popd >nul 2>&1
  set "ERRORLEVEL_TMP=10"
  goto :cleanup
)
popd >nul 2>&1

:: create SFX config (use delayed expansion variables so expansion happens at runtime)
(
  echo ;!@Install@!UTF-8!
  echo Title="!APPNAME! bundle"
  echo BeginPrompt="This package will extract files and run !BATNAME!. Continue?"
  echo RunProgram="!BATNAME!"
  echo ;!@InstallEnd@!
) > "%TMP%\config.txt"

:: if output exists, attempt to remove (or overwrite)
if exist "%OUT%" (
  echo Warning: "%OUT%" already exists — will be overwritten.
  del /F /Q "%OUT%" 2>nul
)

:: assemble final EXE: SFX stub + config + archive
echo Building final SFX executable...
copy /b "%SFX%" + "%TMP%\config.txt" + "%TMP%\bundle.7z" "%OUT%" >nul 2>&1
if not exist "%OUT%" (
  echo Failed to create "%OUT%".
  set "ERRORLEVEL_TMP=11"
  goto :cleanup
)

echo Bundle created: "%OUT%"

:cleanup
:: remove temp dir (if exists)
if exist "%TMP%" (
  rd /s /q "%TMP%" >nul 2>&1
)

if defined ERRORLEVEL_TMP (
  if not "%ERRORLEVEL_TMP%"=="0" (
    exit /b %ERRORLEVEL_TMP%
  )
)

endlocal & exit /b 0
