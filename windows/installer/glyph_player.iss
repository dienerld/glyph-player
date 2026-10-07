; Inno Setup script for the Windows installer.
; Build:  iscc /DAppVersion=0.1.0 windows\installer\glyph_player.iss
; Needs `flutter build windows --release` first. Output: build\installer\
#ifndef AppVersion
  #error Pass the version: iscc /DAppVersion=X.Y.Z glyph_player.iss
#endif

[Setup]
AppId={{6F0B7C52-3D1A-4E8B-9A57-2C4D8E1F0A93}
AppName=Glyph Player
AppVersion={#AppVersion}
AppPublisher=Glyph
DefaultDirName={autopf}\Glyph Player
DefaultGroupName=Glyph Player
UninstallDisplayIcon={app}\glyph_player.exe
SetupIconFile=..\runner\resources\app_icon.ico
OutputDir=..\..\build\installer
OutputBaseFilename=glyph-player-{#AppVersion}-windows-x64-setup
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Program Files for all users by default; the dialog offers a per-user install
; (under %LocalAppData%\Programs) for people without admin rights.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\Glyph Player"; Filename: "{app}\glyph_player.exe"
Name: "{autodesktop}\Glyph Player"; Filename: "{app}\glyph_player.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\glyph_player.exe"; Description: "{cm:LaunchProgram,Glyph Player}"; Flags: nowait postinstall skipifsilent
