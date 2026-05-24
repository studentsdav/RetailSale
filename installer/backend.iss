[Setup]
AppName=INVINS
AppId={{8C07A1B8-7BE7-4F73-9A89-42D8F7B9D322}
AppVersion=1.1.33
AppPublisher=INVINS
DefaultDirName={sd}\Retailpos
UsePreviousAppDir=yes
DefaultGroupName=Retailpos
OutputBaseFilename=backend_Installer
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64

[Files]
Source: "D:\inventorynew\RetailSale new\RetailSale\installer\Output\Retailpos_Installer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\inventorynew\RetailSale new\RetailSale\backend\encrypt.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\inventorynew\RetailSale new\RetailSale\installer\app_icon.ico"; DestDir: "{app}\resources"; Flags: ignoreversion
Source: "D:\inventorynew\RetailSale new\RetailSale\installer\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "D:\inventorynew\RetailSale new\RetailSale\installer\postgresql-18.3-2-windows-x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
; Install VC++ silently
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Flags: waituntilterminated runhidden

[Registry]
; ✅ 1. AUTOMATICALLY WIPE THE REGISTRY ON UNINSTALL
; This tells the uninstaller to delete the DbToken and the entire Inventory key
Root: HKLM; Subkey: "SOFTWARE\INVINS\Retailpos"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\INVINS"; Flags: uninsdeletekeyifempty

[UninstallRun]
; REMOVE WINDOWS DEFENDER EXCLUSION ON UNINSTALL
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -Command ""Remove-MpPreference -ExclusionPath '{app}'"""; Flags: runhidden

[UninstallDelete]
; ✅ 3. AUTOMATICALLY DELETE THE HIDDEN FILES AND OLD DATABASE
; This wipes the double-lock backup file
Type: files; Name: "{commonappdata}\INVINS\security.dat"
Type: dirifempty; Name: "{commonappdata}\INVINS"

[Code]
function GenerateJWTSecret(): String;
var
  i: Integer;
  chars: String;
begin
  chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  Result := '';
  for i := 1 to 64 do
    Result := Result + chars[Random(Length(chars)) + 1];
end;

{ 🛡️ SCRAMBLE THE PASSWORD BEFORE SAVING TO REGISTRY }
function ScramblePassword(P: String): String;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(P) do
    { Scrambles the letter and converts it to a Hex code }
    Result := Result + Format('%.2x', [Ord(P[i]) xor 115]); 
end;

{ 🛡️ UNSCRAMBLE THE PASSWORD WHEN THE INSTALLER NEEDS IT }
function UnscramblePassword(H: String): String;
var
  i, Code: Integer;
begin
  Result := '';
  i := 1;
  while i < Length(H) do
  begin
    { Reads the Hex code and turns it back into the letter in memory }
    Code := StrToIntDef('$' + Copy(H, i, 2), 0);
    Result := Result + Chr(Code xor 115);
    i := i + 2;
  end;
end;

{ ✅ GENERATE A SECURE CMD-SAFE PASSWORD FOR THE APP }
function GenerateSecurePassword(): String;
var
  i: Integer;
  chars: String;
begin
  chars := 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  Result := '';
  for i := 1 to 16 do
    Result := Result + chars[Random(Length(chars)) + 1];
end;

procedure CreateConfigFile(DbName, DbUser, DbPassword: String);
var
  ConfigPath: String;
  Content: String;
  JwtSecret: String;
begin
  JwtSecret := GenerateJWTSecret();
  ConfigPath := ExpandConstant('{app}\config.json');

  Content :=
    '{' +
    '"db_host":"127.0.0.1",' +
    '"db_port":5432,' +
    '"db_database":"' + DbName + '",' +
    '"db_user":"' + DbUser + '",' +
    '"db_password":"' + DbPassword + '",' +
    '"JWT_SECRET":"' + JwtSecret + '"' +
    '}';

  SaveStringToFile(ConfigPath, Content, False);
end;

function IsPostgresInstalled(): Boolean;
begin
  Result := DirExists(ExpandConstant('{pf}\PostgreSQL\18'));
end;

procedure InstallPostgres(MasterPassword: String);
var
  ResultCode: Integer;
begin
  Exec(
    ExpandConstant('{tmp}\postgresql-18.3-2-windows-x64.exe'),
    '--mode unattended --superpassword "' + MasterPassword + '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
end;

{ ✅ 100% AUTOMATED, SAFE DATABASE SETUP VIA BATCH SCRIPT WITH LOGGING }
procedure SetupDedicatedDatabase(MasterPassword, DbName, AppUser, AppPassword: String);
var
  ResultCode: Integer;
  PgBin, BatPath, BatContent, LogPath: String;
begin
  { Bulletproof 64-bit path directly to the system drive }
  PgBin := ExpandConstant('{sd}\Program Files\PostgreSQL\18\bin\');
  BatPath := ExpandConstant('{tmp}\setup_db.bat');
  LogPath := ExpandConstant('{app}\db_setup_log.txt');

  { Wait for Postgres service to be fully online }
  Exec('cmd.exe', '/c timeout /t 15', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  { Write a clean Batch script to eliminate Windows quoting bugs & capture logs }
  BatContent := 
    '@echo off' + #13#10 +
    'set "PGPASSWORD=' + MasterPassword + '"' + #13#10 +
    'cd /d "' + PgBin + '"' + #13#10 +
    'echo --- STARTING DATABASE SETUP --- > "' + LogPath + '" 2>&1' + #13#10 +
    
    'echo 1. Creating User... >> "' + LogPath + '" 2>&1' + #13#10 +
    'psql.exe -U postgres -c "CREATE ROLE ' + AppUser + ' WITH LOGIN PASSWORD ''' + AppPassword + ''';" >> "' + LogPath + '" 2>&1' + #13#10 +
    
    'echo 2. Updating Password... >> "' + LogPath + '" 2>&1' + #13#10 +
    'psql.exe -U postgres -c "ALTER ROLE ' + AppUser + ' WITH PASSWORD ''' + AppPassword + ''';" >> "' + LogPath + '" 2>&1' + #13#10 +
    
    'echo 3. Creating Database... >> "' + LogPath + '" 2>&1' + #13#10 +
    'psql.exe -U postgres -tc "SELECT 1 FROM pg_database WHERE datname=''' + DbName + '''" | findstr 1 || createdb.exe -U postgres -O ' + AppUser + ' ' + DbName + ' >> "' + LogPath + '" 2>&1' + #13#10 +
    
    'echo 4. Granting Privileges... >> "' + LogPath + '" 2>&1' + #13#10 +
    'psql.exe -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ' + DbName + ' TO ' + AppUser + ';" >> "' + LogPath + '" 2>&1' + #13#10 +
    
    'echo --- SETUP COMPLETE --- >> "' + LogPath + '" 2>&1' + #13#10 +
    'exit /b 0';

  SaveStringToFile(BatPath, BatContent, False);
  
  { Execute the batch script invisibly }
  Exec(BatPath, '', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  
  { Clean up }
  DeleteFile(BatPath);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  DbName, MasterPassword, AppUser, AppPassword, TokenFile: String;
  FileString: AnsiString;
begin


 { --- ADD WINDOWS DEFENDER EXCLUSION BEFORE EXTRACTING FILES --- }
  if CurStep = ssInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Configuring Security Exclusions...';
    WizardForm.Refresh;
    
    { Create target directory early to ensure the exclusion path exists }
    ForceDirectories(ExpandConstant('{app}'));
    
    { Call PowerShell to add Defender Exclusion }
    Exec('powershell.exe', 
         '-ExecutionPolicy Bypass -WindowStyle Hidden -Command "Add-MpPreference -ExclusionPath ''' + ExpandConstant('{app}') + '''"', 
         '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;


  if CurStep = ssPostInstall then
  
  begin
    { ✅ HARDCODED CONFIGURATION NAMES - SAFE TO HARDCODE }
    DbName := 'POSINVRETAIL';
    AppUser := 'inv_admin_retail';
    
    { --------------------------------------------------------- }
    { 🛡️ THE SECURITY UPGRADE: REGISTRY-BASED MASTER PASSWORD }
    { --------------------------------------------------------- }
    
   { --------------------------------------------------------- }
    { 🛡️ DOUBLE-LOCK SECURE STORAGE (REGISTRY + HIDDEN FILE) }
    { --------------------------------------------------------- }
    
    TokenFile := ExpandConstant('{commonappdata}\INVINS\security.dat');

    { Step 1: Try to read the SCRAMBLED password from the Registry }
    if not RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\INVINS\Retailpos', 'DbToken', MasterPassword) then
    begin
      { Step 2: The Registry key is missing! Let's check the hidden backup file. }
      if LoadStringFromFile(TokenFile, FileString) then
      begin
        { Backup found! Restore the password and quietly fix the Registry }
        MasterPassword := String(FileString);
        RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\INVINS\Retailpos', 'DbToken', MasterPassword);
        MasterPassword := UnscramblePassword(MasterPassword);
      end
      else
      begin
        { Step 3: Both are missing. This is a TRUE fresh install. }
        MasterPassword := GenerateSecurePassword();
        
        { Scramble it once }
        MasterPassword := ScramblePassword(MasterPassword);
        
        { Save it to the Registry }
        RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\INVINS\Retailpos', 'DbToken', MasterPassword);
        
        { Save it to the hidden Backup File }
        ForceDirectories(ExpandConstant('{commonappdata}\INVINS'));
        SaveStringToFile(TokenFile, MasterPassword, False);
        
        { Unscramble it into memory for the installer to use right now }
        MasterPassword := UnscramblePassword(MasterPassword);
      end;
    end
    else
    begin
      { The Registry worked perfectly. Unscramble it into memory. }
      MasterPassword := UnscramblePassword(MasterPassword);
    end;
    
    { The App Password remains random every single time for maximum security }
    AppPassword := GenerateSecurePassword();
    { --------------------------------------------------------- }
    { --- UI UPDATES FOR NON-TECHNICAL USERS --- }
    
    if not IsPostgresInstalled() then
    begin
      WizardForm.StatusLabel.Caption := 'Installing Database Engine (This may take a few minutes)...';
      WizardForm.Refresh; 
      
      InstallPostgres(MasterPassword);
      
      WizardForm.StatusLabel.Caption := 'Starting Database Engine...';
      WizardForm.Refresh;
      Exec('cmd.exe','/c timeout /t 15','',SW_HIDE,ewWaitUntilTerminated,ResultCode);
    end;

    WizardForm.StatusLabel.Caption := 'Configuring Secure Database Environments...';
    WizardForm.Refresh;
    SetupDedicatedDatabase(MasterPassword, DbName, AppUser, AppPassword);

    WizardForm.StatusLabel.Caption := 'Applying Encryption & Security Policies...';
    WizardForm.Refresh;
    CreateConfigFile(DbName, AppUser, AppPassword);

    { Encrypt config.json into sysConfig.enc safely }
    Exec(
      ExpandConstant('{app}\encrypt.exe'),
      '',
      ExpandConstant('{app}'),
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );

    DeleteFile(ExpandConstant('{app}\config.json'));

    WizardForm.StatusLabel.Caption := 'Installing User Interface... Almost done!';
    WizardForm.Refresh;
    Exec(
      ExpandConstant('{app}\Retailpos_Installer.exe'),
      '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="' + ExpandConstant('{app}') + '" /D=' + ExpandConstant('{app}'),
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );
  end;
end;

