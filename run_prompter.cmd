@echo off
rem Start simple_prompter (plan Step 1). Copies cairo.dll beside the exe when a rebuild removed it.
rem Usage: run_prompter.cmd [script.md] [--capturable]
set "F=%~dp0EIFGENs\simple_prompter_app\F_code"
if not exist "%F%\simple_prompter.exe" (
  echo Build first: ec.sh test -config simple_prompter.ecf -target simple_prompter_app
  pause
  exit /b 1
)
if not exist "%F%\cairo.dll" copy /y "%SIMPLE_EIFFEL%\simple_cairo\cairo.dll" "%F%\" >nul
start "" /d "%F%" "%F%\simple_prompter.exe" %*
