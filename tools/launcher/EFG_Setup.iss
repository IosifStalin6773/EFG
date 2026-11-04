; Instalador de EFG Launcher (SetupEFG.exe). Lo compila GitHub Actions (.github/workflows/launcher.yml)
; con Inno Setup 6 sobre dist\EFG_Launcher.exe. Las rutas son relativas a este archivo.

[Setup]
AppName=EFG Launcher
AppVersion=B1
AppPublisher=EFG Project
DefaultDirName={autopf}\EFG Launcher
DefaultGroupName=EFG Launcher
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=SetupEFG
SetupIconFile=efg.ico
UninstallDisplayIcon={app}\EFG_Launcher.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso en el escritorio"; GroupDescription: "Accesos:"

[Files]
Source: "dist\EFG_Launcher.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\EFG Launcher"; Filename: "{app}\EFG_Launcher.exe"
Name: "{group}\Desinstalar EFG Launcher"; Filename: "{uninstallexe}"
Name: "{autodesktop}\EFG Launcher"; Filename: "{app}\EFG_Launcher.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\EFG_Launcher.exe"; Description: "Abrir EFG Launcher"; Flags: nowait postinstall skipifsilent
