; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!


[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{C5AE352B-3A5A-45E7-855C-623590FB715E}
AppName=Psyche
AppVersion=0.1
;AppVerName=Psyche 0.1
OutputBaseFilename=Psyche_0.1-win32setup
AppPublisher=Qweex
AppPublisherURL=http://www.qweex.com/
AppSupportURL=http://www.qweex.com/
AppUpdatesURL=http://www.qweex.com/
DefaultDirName={pf}\Psyche
DefaultGroupName=Psyche
AllowNoIcons=yes
LicenseFile=C:\Steampunk\Dev\psyche\LICENSE
OutputDir=C:\Steampunk\Dev\psyche\bin
Compression=lzma
SolidCompression=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "C:\Steampunk\Dev\psyche\bin\psyche.exe"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\Psyche"; Filename: "{app}\main.exe"
Name: "{commondesktop}\Psyche"; Filename: "{app}\main.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\main.exe"; Description: "{cm:LaunchProgram,Psyche}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\README.md"; Description: "View the README file"; Flags: postinstall shellexec skipifsilent unchecked
