; Installer for the tHAsk Windows app (Inno Setup 6).
; Build with build_installer.ps1 next to this file; it passes AppVersion.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "tHAsk"
#define AppExe "thask.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{67FC4A04-E2B4-4BDC-8C90-149C638BC677}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Schumey
AppPublisherURL=https://github.com/Schumey/tHAsk
VersionInfoVersion={#AppVersion}
; Per-user install, no admin rights needed
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
SetupIconFile=..\runner\resources\app_icon.ico
; Closes a running app before updating (Restart Manager)
CloseApplications=force
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\installer
OutputBaseFilename=thask-setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Beim Anmelden an Windows im Infobereich der Taskleiste starten"; GroupDescription: "Autostart:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; Without the task an update removes an earlier autostart entry
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "{#AppName}"; Flags: deletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExe}"" --minimized"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; Update from within the app (setup started with /SILENT): start the app again afterwards
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent
