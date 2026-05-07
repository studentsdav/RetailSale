[Setup]
AppName=Inventory
AppVersion=1.1.31
AppPublisher=Students dev
DefaultDirName={sd}\Inventory
DefaultGroupName=Inventory
OutputBaseFilename=Inventory_Installer
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
CloseApplications=no
RestartApplications=no


[Types]
Name: "server"; Description: "Main Server (Database & User Interface)"
Name: "client"; Description: "Network Terminal (User Interface Only)"

[Components]
Name: "ui"; Description: "Inventory POS Interface"; Types: server client; Flags: fixed
Name: "backend"; Description: "Local Backend Server Services"; Types: server

[Files]
; UI Files (Installed on both Server and Client)
Source: "D:\inventory\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: ui
Source: "D:\inventory\windows\runner\resources\app_icon.ico"; DestDir: "{app}\resources"; Flags: ignoreversion; Components: ui
Source: "D:\inventory\installer\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; Backend Files (Installed ONLY on the Server)
Source: "D:\inventory\backend\server.exe"; DestDir: "{app}"; Flags: ignoreversion; Components: backend
Source: "D:\inventory\backend\license.key"; DestDir: "{app}"; Flags: ignoreversion; Components: backend
Source: "D:\inventory\backend\sysConfig.enc"; DestDir: "{app}"; Flags: ignoreversion; Components: backend
Source: "D:\inventory\backend\run_hidden.vbs"; DestDir: "{app}"; Flags: ignoreversion; Components: backend

[InstallDelete]
Type: files; Name: "{app}\sync_status.json"
Type: files; Name: "{app}\client.json"

[Icons]
Name: "{group}\inventory"; Filename: "{app}\inventory.exe"; IconFilename: "{app}\resources\app_icon.ico"
Name: "{commondesktop}\inventory"; Filename: "{app}\inventory.exe"; IconFilename: "{app}\resources\app_icon.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Registry]
; Auto-start server on boot (ONLY on the Server)
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "InventoryBackendServer"; ValueData: "wscript.exe ""{app}\run_hidden.vbs"""; Flags: uninsdeletevalue; Components: backend

[Run]
; VC++ Redist is required for both Flutter Windows apps and Node.js
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: NeedsVC

; Firewall and Server start (ONLY on the Server)
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Inventory API Port 3000"" dir=in action=allow protocol=TCP localport=3000"; Flags: runhidden; Components: backend
Filename: "wscript.exe"; Parameters: """{app}\run_hidden.vbs"""; WorkingDir: "{app}"; Flags: nowait; Components: backend

; Launch Flutter UI (On both)
Filename: "{app}\inventory.exe"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent


; 1. Delete the task if it already exists (useful when the user runs an update)
Filename: "schtasks.exe"; Parameters: "/delete /tn ""INVINS_Server"" /f"; Flags: runhidden skipifdoesntexist

; 2. Create the Instant-Boot Task
; /sc onlogon = Runs the exact second the user logs in (No 3-minute delay!)
; /rl highest = Runs with admin rights (Bypasses Windows Defender scanning delays)
Filename: "schtasks.exe"; Parameters: "/create /tn ""INVINS_Server"" /tr ""wscript.exe \""{app}\run_hidden.vbs\"""" /sc onlogon /rl highest /f"; Flags: runhidden

[UninstallRun]
; Remove Firewall rule (ONLY if it was a Server)
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Inventory API Port 3000"""; Flags: runhidden; Components: backend

[Code]
function NeedsVC: Boolean;
var
  VCRuntimeInstalled: Cardinal;
begin
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', VCRuntimeInstalled) then
  begin
    Result := (VCRuntimeInstalled <> 1);
  end
  else
  begin
    Result := True;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec('taskkill.exe', '/F /IM inventory.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill.exe', '/F /IM server.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1000);
  Result := '';
end;
