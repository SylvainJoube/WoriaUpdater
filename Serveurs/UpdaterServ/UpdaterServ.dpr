program UpdaterServ;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  math,
  classes,
  sockets,
  U_Arrays in '..\..\Commun\U_Arrays.pas',
  U_ClientFiles in '..\..\Commun\U_ClientFiles.pas',
  U_Crypt1 in '..\..\Commun\U_Crypt1.pas',
  U_Files in '..\..\Commun\U_Files.pas',
  U_NetSys4 in '..\..\Commun\U_NetSys4.pas',
  U_Sockets4 in '..\..\Commun\U_Sockets4.pas',
  U_StaticBuffer in '..\..\Commun\U_StaticBuffer.pas',
  U_ClientExchange in 'U_ClientExchange.pas',
  U_UpdaterServRapport in 'U_UpdaterServRapport.pas',
  U_ClientFiles_Editor in '..\..\Commun\U_ClientFIles_Editor.pas',
  U_UpdaterServ_updateWoriaExe in '..\..\Commun\U_UpdaterServ_updateWoriaExe.pas',
  U_InitTcpNoDelay in '..\..\Commun\U_InitTcpNoDelay.pas';

// Constantes
const PrivateTestVer = false;
const G_ServPort = 3365;//3335;
const G_PrivateTestPort = 3345;
const MillisecTimeFactor = 100000000/1.157407677; //1.1575;///1.136;




//TMainThread
type TMainThread = class (TThread)
  private
    fini : boolean;
    doitTerminer : boolean;
  public
    constructor Create; virtual;
    procedure Execute; override;
    procedure Terminer;
    function EstTermine : boolean;
end;
//Create
constructor TMainThread.Create;
begin
  inherited Create(false);
  fini:=false;
  doitTerminer:=false;
end;
//Execute
procedure TMainThread.Execute;
//var t1, t2 : int64;
begin
  while not doitTerminer do begin
    //t1:=trunc(now*MillisecTimeFactor);
    try ClientLoop; except WriteLn('GRAVE TMainThread.Execute : exception @ClientLoop'); end;
    try SendAllBuffers; except WriteLn('GRAVE TMainThread.Execute : exception @SendAllBuffers'); end;
    //t2:=trunc(now*MillisecTimeFactor);
    //WriteLn('T='+inttostr((t2-t1)));
    //WriteLn('NbCLients='+inttostr(length(A1CLient)));
    
    sleep(1);
  end;
  fini:=true;
end;
//Terminer
procedure TMainThread.Terminer;
begin
  doitTerminer:=true;
end;
//EstTermine
function TMainThread.EstTermine : boolean;
begin
  Result:=fini;
end;


var MainThread : TMainThread;
    consoleInput : string;
    iMainThread : cardinal;

begin
  WriteLnCustom := WriteLn; // Sortie des logs
  WriteLnCustom_isDefined := true;

  if PrivateTestVer then
    AssignFile(G_LogFile, 'ServUpdaterLog_private_v'+inttostr(UpdateServerVer)+'.txt')
  else
    AssignFile(G_LogFile, 'ServUpdaterLog_v'+inttostr(UpdateServerVer)+'.txt');
  ReWrite(G_LogFile);

  WriteLn('Liste des fichiers dans ClientFiles...');
  GameServer_initClientFiles(false);       
  WriteLn('Liste des fichiers dans ClientFiles OK !');
  if PrivateTestVer then
    WriteLn('Serveur de test (updater) - PrivateTestVer port '+inttostr(G_PrivateTestPort));

  WriteLn('Démarrage du socket');
  serv:=TTcpServer.Create(nil);
  serv.BlockMode:=bmNonBlocking;
  // Port classique si c'est le serveur de jeu non lié au serveur central
  if PrivateTestVer then serv.LocalPort:=AnsiString(inttostr(G_PrivateTestPort))
                    else serv.LocalPort:=AnsiString(inttostr(G_ServPort));
  serv.Active:=true;    
  WriteLn('Port ' + serv.LocalPort);
  if not serv.Listening then begin
    WriteLn('ERREUR : port déjà utilisé, impossible de lancer le serveur.');   
    try
      serv.Close;
      serv.Destroy;
    except end;
    CloseFile(G_LogFile);
  end;


  MainThread:=TMainThread.Create;
  consoleInput:='';
  WriteLn('Saisissez une commande :');

  // Commandes 
  while consoleInput<>'q' do begin
    readln(consoleInput);
    if consoleInput='q' then begin DisconnectAllClientsOnShutdown; break; end;
    if consoleInput='quit' then  begin DisconnectAllClientsOnShutdown; break; end;
    if consoleInput='l' then ShowClientFiles;
    if (consoleInput='up') or (consoleInput='update') then UpdateWoriaExeVersion;
  end;

  MainThread.Terminer;
  for iMainThread:=0 to 100 do begin
    if MainThread.EstTermine then break;
    sleep(10);
  end;
  serv.Close;
  serv.Destroy;

  WriteLn('Terminé (iMainThread='+inttostr(iMainThread)+')');
  CloseFile(G_LogFile);
  readln;
end.
