@echo off
rem Start simple_prompter. Copies cairo.dll and the CUDA whisper DLLs beside the exe
rem when a rebuild removed them. Needs the CUDA 13 runtime on PATH for voice following.
rem Usage: run_prompter.cmd [script.md] [--capturable] [--window]
set "F=%~dp0EIFGENs\simple_prompter_app\F_code"
set "W=%SIMPLE_EIFFEL%\whisper_cpp_build\build_cuda\bin"
if not exist "%F%\simple_prompter.exe" (
  echo Build first: ec.sh test -config simple_prompter.ecf -target simple_prompter_app
  pause
  exit /b 1
)
if not exist "%F%\cairo.dll" copy /y "%SIMPLE_EIFFEL%\simple_cairo\cairo.dll" "%F%\" >nul
if not exist "%F%\whisper.dll" copy /y "%W%\*.dll" "%F%\" >nul
start "" /d "%F%" "%F%\simple_prompter.exe" %*
