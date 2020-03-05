library UpdaterClientDll;

//{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
//{$WEAKLINKRTTI ON}

uses
  SysUtils, // System.
  Classes,  // System.
  //vcl.Graphics,
  //vcl.Forms,
  dialogs,
  ShellApi,
  U_updaterClientGM,
  U_ClientFiles in '..\Commun\U_ClientFiles.pas',
  U_Crypt1 in '..\Commun\U_Crypt1.pas',
  U_Files in '..\Commun\U_Files.pas',
  // pas besoin, intégré à U_Sockets4   U_InitTcpNoDelay in '..\Commun\U_InitTcpNoDelay.pas',
  U_NetSys4 in '..\Commun\U_NetSys4.pas',
  U_Sockets4 in '..\Commun\U_Sockets4.pas',
  U_StaticBuffer in '..\Commun\U_StaticBuffer.pas',
  U_UpdateFiles in '..\Commun\U_UpdateFiles.pas',
  U_Arrays in '..\Commun\U_Arrays.pas',
  U_UpdaterServ_updateWoriaExe in '..\Commun\U_UpdaterServ_updateWoriaExe.pas',
  U_ClientFIles_Editor in '..\Commun\U_ClientFiles_Editor.pas';

{$R *.res}




function dPlay(arg_windowHandle : double) : double; cdecl; // appuyer sur le bouton "jouer"
var connectToIp, tryAgain_addrName : string;
    connectToPort : word;
    hasAddress : boolean;
begin
  if GestionUpdater=nil then begin
    GestionUpdater:=TGestionUpdater.Create;
  end;

  G_WindowHandle:=trunc(arg_windowHandle);
  G_JeuPretAEtreLance:=false;
  Result := 0; // résusltat par défaut
  if Uninstall_isUnistalling then exit;
  if not ((G_updaterState=-2) or (G_updaterState=-1) or (G_updaterState=0)) then exit; // l'updater est occupé

  connectToIp:='';
  connectToPort:=0;
  tryAgain_addrName:='';

  if not PrivateTest then begin // GestionUpdater.Connect(G_publicIp, G_publicPort)   //dl2.sylvesoft.com localhost

    // si j'ai une nouvelle adresse à essayer pour joindre le serveur, je l'essaie
    // tryAgain_addrName et connectToPort sont des variables modifiées par la fonction GestionUpdater.GetNextAdressToTry
    hasAddress := GestionUpdater.GetNextAdressToTry(connectToIp, connectToPort, tryAgain_addrName);

    if hasAddress then begin // GestionUpdater.Connect va échouer dans ce cas
      Result := 10;
    end else begin
      Result := 9; // Valeurs de retour utilisées dans dStep (et GestionUpdater.ReceiveMessage;)
    end;
    //connectToIp := G_publicIp;
    //connectToPort := G_publicPort;
  end else begin //GestionUpdater.Connect(G_privateTestIp, G_privateTestPort);
    connectToIp := G_privateTestIp;
    connectToPort := G_privateTestPort;
  end;
  //ShowMessage('dPlay : connect à ip = ' + connectToIp + ' @port = ' + inttostr(connectToPort));
  GestionUpdater.Connect(connectToIp, connectToPort, tryAgain_addrName);

  (* fait dans GestionUpdater.Connect :
  G_updaterState:=1; // 'Attente du message de bienvenue...';
  WaitForWelcomeMessage:=true;
  //WaitForWelcomeMessageMsLeft:=2000;
  WaitForWelcomeMessage_waitUntilMs:=GetTimeMs+2000;
  *)

end;
exports dPlay;

function dStep : double; cdecl; // rertrourne un nombre : l'état dans lequel l'updater est (-1 )
begin
  if GestionUpdater=nil then begin
    GestionUpdater:=TGestionUpdater.Create;
  end;
  Result:=G_updaterState;
  if Uninstall_isUnistalling then exit;
  //if G_updaterState=1 then begin // en attente de connexion
  if G_updaterState>0 then begin
    GestionUpdater.ReceiveMessage;
  end;
  Result:=G_updaterState;
end;
exports dStep;

function dGetUpdaterButton(buttonId, variableType : double) : double; cdecl;
var pButton : TGestionUpdater_pButton;
begin
  pButton:=nil;
  Result:=-1;
  case trunc(buttonId) of
    1 : pButton:=@GestionUpdater.Messages.StrActionActuelle; // communication avec l'utilisateur, "erreur", "attente"...
    2 : pButton:=@GestionUpdater.Messages.StrSpeed; // vitesse de téléchargement et autres infos
    3 : pButton:=@GestionUpdater.Messages.ButtonPlay; // ce qui est affiché sur le bouton "jouer"
    4 : pButton:=@GestionUpdater.Messages.ButtonUninstall;
    5 : pButton:=@GestionUpdater.Messages.ButtonInstallMode;
  end;
  if pButton=nil then exit;

  if variableType=1 then begin
    if pButton^.Enabled then
      Result:=1
    else
      Result:=0;
  end;

  if variableType=2 then
    Dll_CurrentString:=pButton^.Caption;

  if variableType=3 then begin
    if pButton^.hasToBeRafreshed then
      Result:=1
    else
      Result:=0;
  end;

end;
exports dGetUpdaterButton;

function dGetUpdaterNetSpeed(variableType : double) : double; cdecl;
begin
  Result:=0; // pour évier le warning
  if variableType=1 then begin
    if GestionUpdater.netSpeed.InUse then
      Result:=1
    else
      Result:=0;
  end;

  if variableType=2 then
    Result:=GestionUpdater.netSpeed.moSpeed;
  if variableType=3 then
    Result:=GestionUpdater.netSpeed.koSpeed;
  if variableType=4 then
    Result:=GestionUpdater.netSpeed.oSpeed;

end;
exports dGetUpdaterNetSpeed;

function dGetProgressBarVariable(variableIndex : double) : double; cdecl;
begin
  Result:=-1;
  case trunc(variableIndex) of
    1 : Result:=GestionUpdater.ProgressBar.Percent;
    2 : Result:=G_Updade_currentNb;
    3 : Result:=G_Updade_neededNb;

  end;

end;
exports dGetProgressBarVariable;

function dNePasSupprimerPourExporter : double; cdecl;
begin
  Result:=1;
end;
exports dNePasSupprimerPourExporter;

function dGet_jeuPretAEtreLance : double; cdecl;
begin
  if G_JeuPretAEtreLance then
    Result:=1
  else
    Result:=0;
end;
exports dGet_jeuPretAEtreLance;

function dChangeInstallMode : double; cdecl;
begin
  Result:=0; // pour éviter le warning
  InstallationDansProgramFiles:=not InstallationDansProgramFiles;
  GestionUpdater.UpdateEnviroVariableInstallPath;
end;
exports dChangeInstallMode;

function dUninstallFull(arg_windowHandle : double) : double; cdecl;
var ShOp: TSHFileOpStructW;
begin
  G_updaterState:=0;
  if GestionUpdater<>nil then GestionUpdater.Destroy;
  GestionUpdater:=TGestionUpdater.Create;

  G_WindowHandle:=trunc(arg_windowHandle);
  ShOp.Wnd := G_WindowHandle;
  ShOp.wFunc := FO_DELETE;
  ShOp.pFrom := PWideChar(GetEnvironmentVariable(EnviroVariable)+GameDirName+chr(0));
  ShOp.pTo := nil;
  ShOp.fFlags := 0;//FOF_NO_UI;
  SHFileOperationW(ShOp);

  Result:=1;



  // Code commenté : supprimer moi-même les dossier via un thread qui supprime tout, récursivement
  // (les dossiers ne peuvent être supprimés que s'ils sont vides)
  // Ce code est commenté parce que j'ai trouvé beaucoup plus simple : recourir au shell de Windows (utilisé plus haut)

  //InstallationDansProgramFiles:=not InstallationDansProgramFiles;
  //GestionUpdater.UpdateEnviroVariableInstallPath;
  {if arg_valueIndex=-1 then begin
    Result:=40;//Uninstall_currentFileCount;
    exit;
  end;

  if arg_valueIndex=0 then begin
    if Uninstall_isUnistalling then // savoir si la désinstallation est en cours ou non
      Result:=1
    else
      Result:=0;
    exit;
  end;

  if arg_valueIndex=1 then begin // désinstaller
    if Uninstall_isUnistalling then exit; // déjà en cours de désinstallation
    G_updaterState:=103;
    Uninstall_isUnistalling:=true;
    UninstallThread:=TUninstallThread.Create;
  end;

  if arg_valueIndex=2 then begin // annuler la désinstallation (si résultat 0 : échec de l'annulation (thread ne répond pas), si résultat 1 : annulé et destruction du thread)
    if not Uninstall_isUnistalling then exit;
    if UninstallThread=nil then exit;
    UninstallThread.HasToStop:=true;
    Result:=0;
    for i:=0 to 3000 do begin
      if UninstallThread.Finished then begin
        Result:=1;
        //UninstallThread.Destroy;
        UninstallThread:=nil;
        Uninstall_isUnistalling:=false;
        G_updaterState:=0;
        break;
      end;
      sleep(1);
    end;
  end;}


end;
exports dUninstallFull;


var dAddRescueAddress_addrGraphicName : string;
// Ajouter via GM une adresse de connexion alternative à essayer (pour ne pas avoir à mettre à jour la dll juste pour ajouter une adresse possible de connexion)
function dAddRescueAddress(arg_addrPort, arg_putFirst : double) : double; cdecl; // -> passer l'IP via dSetCurrentString
begin
  Result := 1;
  if GestionUpdater=nil then begin
    GestionUpdater:=TGestionUpdater.Create;
  end;
  if arg_addrPort = -1 then begin
    dAddRescueAddress_addrGraphicName := Dll_CurrentString;
    exit;
  end;
  GestionUpdater.AddAdressToTry(Dll_CurrentString, trunc(arg_addrPort), (arg_putFirst = 1), dAddRescueAddress_addrGraphicName);
end;
exports dAddRescueAddress;

begin


end.
