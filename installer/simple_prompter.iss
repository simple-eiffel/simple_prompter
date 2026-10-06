; ============================================================================
;  simple_prompter - Inno Setup script (plan Steps 1-3: the pill follows your voice)
;
;  Ships the finalized Eiffel binary (contract-checked build: a broken promise
;  stops the program and leaves exception_trace.log beside it, which is what
;  a tester wants), cairo.dll (the 2D engine), whisper.cpp 1.8.2 built for CUDA
;  (whisper.dll, ggml*.dll), the Silero voice model, two sample scripts and a
;  README. NOT shipped (too large, or the machine's own): the whisper model
;  (ggml-large-v3-turbo-q5_0.bin, 574 MB - found in {app}\models or
;  D:\prod\simple_speech\models), the CUDA 13 runtime (on PATH from the CUDA
;  toolkit) and ffmpeg (beside the exe, Chocolatey's, or on PATH).
;  Settings live in %APPDATA%\simple_prompter and are left alone on uninstall.
;
;  Build: installer\build_installer.cmd  (builds the app, then this script)
; ============================================================================

#define AppName        "simple_prompter"
#define AppVersion     "0.2.0"
#define AppPublisher   "Larry Rix"
#define AppExeName     "simple_prompter.exe"
#define BuildDir       "..\EIFGENs\simple_prompter_app\F_code"
#define CairoDll       GetEnv("SIMPLE_EIFFEL") + "\simple_cairo\cairo.dll"
#define WhisperBin     GetEnv("SIMPLE_EIFFEL") + "\whisper_cpp_build\build_cuda\bin"
#define SileroModel    GetEnv("SIMPLE_EIFFEL") + "\simple_speech\models\ggml-silero-v6.2.0.bin"

[Setup]
AppId={{5B1E7C3A-2F64-4A8B-9D17-6C0E4F2A8B31}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=.\output
OutputBaseFilename=simple_prompter-{#AppVersion}-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExeName}

; Per-user install: no UAC prompt. The app writes only to %APPDATA%.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; The Eiffel binary is 64-bit.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CairoDll}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#WhisperBin}\whisper.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#WhisperBin}\ggml.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#WhisperBin}\ggml-base.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#WhisperBin}\ggml-cpu.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#WhisperBin}\ggml-cuda.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SileroModel}"; DestDir: "{app}\models"; Flags: ignoreversion
Source: "..\samples\Welcome to simple_prompter.md"; DestDir: "{app}\samples"; Flags: ignoreversion
Source: "..\samples\Voice read test.md"; DestDir: "{app}\samples"; Flags: ignoreversion
Source: "README.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
Name: "{group}\{#AppName}";           Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{group}\Sample scripts";        Filename: "{app}\samples"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";     Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Description: "Start {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; A crash report the program may have left beside itself. Settings in
; %APPDATA%\simple_prompter (speed, pill position, last script) are kept.
Type: files; Name: "{app}\exception_trace.log"
