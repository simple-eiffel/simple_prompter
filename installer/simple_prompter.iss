; ============================================================================
;  simple_prompter - Inno Setup script (plan Step 1: the pill at constant speed)
;
;  Ships the finalized Eiffel binary (contract-checked build: a broken promise
;  stops the program and leaves exception_trace.log beside it, which is what
;  a tester wants), cairo.dll (the 2D engine), two sample scripts and a README.
;  Settings live in %APPDATA%\simple_prompter and are left alone on uninstall.
;
;  Build: installer\build_installer.cmd  (builds the app, then this script)
; ============================================================================

#define AppName        "simple_prompter"
#define AppVersion     "0.1.0"
#define AppPublisher   "Larry Rix"
#define AppExeName     "simple_prompter.exe"
#define BuildDir       "..\EIFGENs\simple_prompter_app\F_code"
#define CairoDll       GetEnv("SIMPLE_EIFFEL") + "\simple_cairo\cairo.dll"

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
