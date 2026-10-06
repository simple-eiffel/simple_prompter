@echo off
rem Build simple_prompter and its installer.
rem   1. finalize the app (contract-checked) with ec.sh
rem   2. compile installer\simple_prompter.iss with Inno Setup 6
rem Output: installer\output\simple_prompter-<version>-Setup.exe
setlocal
set "ROOT=%~dp0.."
set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
pushd "%ROOT%"
bash -c "/d/prod/ec.sh test -config simple_prompter.ecf -target simple_prompter_app -clean" || goto :failed
if not exist "EIFGENs\simple_prompter_app\F_code\simple_prompter.exe" goto :failed
popd
"%ISCC%" "%~dp0simple_prompter.iss" || goto :failed_iscc
echo.
echo Installer ready in %~dp0output
exit /b 0
:failed
popd
echo The app did not build. See the ec.sh output above.
exit /b 1
:failed_iscc
echo Inno Setup could not build the installer.
exit /b 1
