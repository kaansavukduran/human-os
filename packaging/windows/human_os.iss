; Inno Setup script for the Human OS Windows installer.
; Built on a Windows host by .github/workflows/windows-exe.yml; never built here.
; The app keeps its data under %LOCALAPPDATA%, outside the install folder, so
; uninstalling does not delete a person's records.
; /DFlavor=encrypted packages a build made with APP_ENV=staging (encrypted
; vault, D-049) as its own app, "Human OS (encrypted)", with its own AppId,
; folder and shortcuts, so it installs beside the development build and
; never replaces it. The flavour only names the installer; the build decides
; the storage.
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef Flavor
  #define Flavor "development"
#endif
#if Flavor == "encrypted"
  #define AppName "Human OS (encrypted)"
  #define AppIdValue "{{C3E2A7D4-5B8F-4E61-A9D0-7F3B2C1E8A94}"
  #define InstallDirName "Human OS encrypted"
  #define OutputName "Human-OS-encrypted-Setup"
#elif Flavor == "development"
  #define AppName "Human OS"
  #define AppIdValue "{{6B1F6E9A-4C1B-4B77-9C0E-1A2B3C4D5E6F}"
  #define InstallDirName "Human OS"
  #define OutputName "Human-OS-Setup"
#else
  #error Flavor must be development or encrypted
#endif

[Setup]
AppId={#AppIdValue}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Human OS
DefaultDirName={autopf}\{#InstallDirName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename={#OutputName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\human_health_os.exe

[Files]
Source: "..\..\human_health_os\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\human_health_os.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\human_health_os.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Run]
Filename: "{app}\human_health_os.exe"; Description: "Open {#AppName}"; Flags: nowait postinstall skipifsilent
