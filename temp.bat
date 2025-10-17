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

:: create temp work dir
set "TMP=%TEMP%\sfxbundle_%RANDOM%_%RANDOM%"
mkdir "%TMP%" || (echo Failed to create temp dir & exit /b 6)

:: copy files into temp
copy /Y "%APP%"  "%TMP%\" >nul
copy /Y "%BAT%"  "%TMP%\" >nul

:: create 7z archive containing the two files
echo Creating 7z archive...
"%ZIPEXE%" a -t7z "%TMP%\bundle.7z" "%TMP%\*" >nul
if errorlevel 1 (
  echo 7z archive creation failed
  rd /s /q "%TMP%" >nul 2>&1
  exit /b 7
)

:: create SFX config
(
  echo ;!@Install@!UTF-8!
  echo Title="%~n3 bundle"
  echo BeginPrompt="This package will extract files and run %~nx4. Continue?"
  echo RunProgram="%~nx4"
  echo ;!@InstallEnd@!
) > "%TMP%\config.txt"

:: assemble final EXE: SFX stub + config + archive
echo Building final SFX executable...
copy /b "%SFX%" + "%TMP%\config.txt" + "%TMP%\bundle.7z" "%OUT%" >nul
if not exist "%OUT%" (
  echo Failed to create "%OUT%".
  rd /s /q "%TMP%" >nul 2>&1
  exit /b 8
)

echo Bundle created: "%OUT%"

