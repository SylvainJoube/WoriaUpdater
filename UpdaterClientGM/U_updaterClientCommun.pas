unit U_updaterClientCommun;

interface
uses
  Windows, Winapi.WinSock, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, System.Win.ScktComp,
  Dialogs, StdCtrls, U_UpdateFiles_xe8, U_Arrays, U_Files_xe8, U_NetSys4_xe8, U_Sockets4_xe8, U_StaticBuffer_xe8, U_ClientFiles_xe8,
  U_InitTcpNoDelay_xe8, ComCtrls, math, ExtCtrls, UITypes, Vcl.Imaging.pngimage;

const UpdateClientVer = 4;

const PrivateTest = false;

const G_privateTestIp = 'dl2.sylvesoft.com';
//const G_privateTestIp = 'localhost';

const G_privateTestPort = 3345;  // couleur $008BBCE9

const G_publicIp = 'dl2.sylvesoft.com';
const G_publicPort = 3335;

var InstallationDansProgramFiles : boolean = true;
var EnviroVariable : string;// défini dans TGestionUpdater.Init (appelé dans TForm1.Create() pour l'updater en delphi)   = 'APPDATA';
//const EnviroVariable = 'PROGRAMFILES';
const InstallEnviroVariable_programFiles = 'PROGRAMFILES';
const InstallEnviroVariable_appdata = 'APPDATA';

const GameDirName_private = '\Woria_privateAlpha';
const GameDirName_public = '\Woria_alpha';
var GameDirName : string = GameDirName_public;


const tryNbMax = 600;

const G_WaitServerTimerMs = 3000; // temps d'attente avant de considérer un message perdu

var WaitForWelcomeMessage : boolean = false;
    WaitForWelcomeMessageMsLeft : integer;



type TGestionUpdater_netSpeed = record
  InUse : boolean; // pour éviter les violations d'accès
  moSpeed, koSpeed, oSpeed : cardinal;
  speedStr : string;
end;
type TGestionUpdater_button = record
  Enabled : boolean;
  Caption : string;
  hasToBeRafreshed : boolean; // pour ne mettre à jour à l'écran que si nécessaire (pour éviter le scintillement sur l'application delphi)
end;
type TGestionUpdater_messages = record // messages affichés à l'écran
  StrActionActuelle : TGestionUpdater_button; // communication avec l'utilisateur, "erreur", "attente"...
  StrSpeed : TGestionUpdater_button; // vitesse de téléchargement et autres infos
  ButtonPlay : TGestionUpdater_button; // ce qui est affiché sur le bouton "jouer"
  ButtonUninstall : TGestionUpdater_button;
  ButtonInstallMode : TGestionUpdater_button;
end;
type TGestionUpdater_progressBar = record
  Enabled : boolean;
  //Caption : string;
  Percent : cardinal; // 0 - 100%
  hasToBeRafreshed : boolean; // pour ne mettre à jour à l'écran que si nécessaire (pour éviter le scintillement sur l'application delphi)
end;
//type TPGestionUpdater_button = ^TGestionUpdater_button;
type TGestionUpdater = class
  private
    cli : TClientSocket;
    client : TSocket;
    client_inUse : boolean; // pour éviter les violations d'accès entre le main et le thread
  public
    Reseau_currentStep : cardinal; // étape de réception (connexion intialie, réception de la version, téléchargement des fichiers du jeu...)
    Reseau_currentStep2_time : int64;


    netSpeed : TGestionUpdater_netSpeed;
    netErrorCode : cardinal;
    IsDownloadingGameFiles : boolean; // vrai si les fichiers du jeu sont en train d'être téléchargés
    WaitForWelcomeMessage : boolean; // indique s'il y a eu une réponse du serveur
    Messages : TGestionUpdater_messages;
    ProgressBar : TGestionUpdater_progressBar;
    // netErrorCode 0 :
    function Main_refreshNetSpeed : boolean; // uniquement appelé par le main (<>thread)
    procedure Connect(ip : string; port  : integer);
    function WaitForMessage : boolean; // retourne true si un message est bien reçu
    function LaunchGame(windowHandle : UIntPtr) : boolean;

    function ReceiveMessage : boolean; // retrourne true si un message a été reçu (il est traité ici)

    procedure UpdateEnviroVariableInstallPath;
    procedure Init;
    constructor Create;
    procedure UpdateButtonCaption(var button : TGestionUpdater_button; caption : string);
    procedure UpdateButtonEnabled(var button : TGestionUpdater_button; enabled : boolean);
    procedure UpdateButton(var button : TGestionUpdater_button; caption : string; enabled : boolean);
    procedure JeuAJour(success : boolean = true);
    procedure UpdateProgressBar(percent : cardinal; enabled : boolean);


end;

var GestionUpdater : TGestionUpdater;

type UninstallThread = class (TThread)
  public
    Finished, HasToStop : boolean;
    UsingFileCount_nb, UsingFileCount_maxNb : boolean;
    CurrentFileNb, MaxFileNb : cardinal;
    UsingFileDescriptionName : boolean;
    CurrentFileName : string;

    //CurrentFileName_external : string; // mis à jour uniquement par un thread externe (le principal)
    //CurrentFileNb_external, MaxFileNb_external : cardinal; // ^ idem ^

    UninstallDir : widestring;

    constructor Create(uninstallDirPath : widestring); virtual;
    procedure Execute; override;
    procedure UninstallDir_recur(dirPath : widestring);
    //procedure UpdateInfoFromMainThread; // s'il peut, met à jour les informations graphiques (CurrentFileName etc.)
end;


var IsDownloading : boolean = false;
    gameDir : string;

function GetTimeMs : int64;

implementation
uses ShellApi;

function GetTimeMs : int64;
begin
  Result:=trunc(SysUtils.Now*MillisecTimeFactor);
end;

procedure UninstallFull_dir(dirPath : string);
var sRec : TSearchRec;
    name : string;
begin
  //ShowMessage(booltostr(directoryExists(dirPath), true)+' - '+dirPath);
  if FindFirst(dirPath+'\*', faAnyFile, sRec)<>0 then exit;
  //ShowMessage(dirPath+'\*');
  repeat
    name:=sRec.Name;
    if name='.' then continue;
    if name='..' then continue;
    if (sRec.Attr and faDirectory)=faDirectory then begin // ici, and est une opération sur l'écriture binaire des nombres. Exemple : 1001101 and 1100100 = 1000100.
      UninstallFull_dir(dirPath+'\'+name); // Suppression de tous les fichiers de ce répertoire
    end else

      Form1.LActionActuelle.Caption:='Supression de '+name;
      Form1.LActionActuelle.Refresh;
      Form1.LPanelActionActuelle.Refresh;
      TryDeleteFile(dirPath+'\'+name);
      //if not TryDeleteFile(dirPath+'\'+name) then ShowMessage('Impossible de supprimer '+name+'.');
  until FindNext(sRec)<>0;
  FindClose(sRec);
  Form1.LActionActuelle.Caption:='Supression...';
  Form1.LActionActuelle.Refresh;
  Form1.LPanelActionActuelle.Refresh;
  TryDeleteDirectory(dirPath);
  //if not TryDeleteDirectory(dirPath) then ShowMessage('Impossible de supprimer le dossier '+dirPath+'.');
end;

procedure UninstallFull;
var dirPath : string;
begin
  with Form1 do begin
    LActionActuelle.Caption:='Désinstallation...';
    Form1.LPanelActionActuelle.Refresh;
    //if not PrivateTest then
    dirPath:=GetEnvironmentVariable(EnviroVariable)+GameDirName;//'\Woria_alpha'
    //else
    //  dirPath:=GetEnvironmentVariable(EnviroVariable)+'\Woria_privateAlpha';
    UninstallFull_dir(dirPath);
    LActionActuelle.Caption:='Désinstallation terminée.';
    Form1.LPanelActionActuelle.Refresh;
  end;
end;

procedure TForm1.BUninstallClick(Sender: TObject);
var button : integer;
begin
  button:=MessageDlg('Voulez-vous vraiment désinstaller le jeu et tout ses composants ? :''(', mtCustom, [mbYes, mbCancel], 0);
  if button=6 then begin
    UninstallFull;
    ProgressBar.Position:=0;
  end;
end;

constructor UninstallThread.Create;//(uninstallDirPath : widestring);
begin
  inherited Create(true);
  Finished:=false;
  HasToStop:=false;
  UsingFileDescriptionName:=false;
  UsingFileCount_nb:=false;
  UsingFileCount_maxNb:=false;
  CurrentFileNb:=0;
  MaxFileNb:=0;
  CurrentFileName:='';
  UninstallDir:=GetEnvironmentVariable(EnviroVariable)+GameDirName;
  Suspended:=false;
end;

procedure UninstallThread.Execute;
begin

  Finished:=true;
end;

procedure UninstallThread.UninstallDir_recur(dirPath : widestring);
var sRec : TSearchRec;
    name : string;
begin
  //ShowMessage(booltostr(directoryExists(dirPath), true)+' - '+dirPath);
  if FindFirst(dirPath+'\*', faAnyFile, sRec)<>0 then exit;
  //ShowMessage(dirPath+'\*');
  repeat
    if self.HasToStop then break;
    name:=sRec.Name;
    if name='.' then continue;
    if name='..' then continue;
    if (sRec.Attr and faDirectory)=faDirectory then begin // ici, and est une opération sur l'écriture binaire des nombres. Exemple : 1001101 and 1100100 = 1000100.
      UninstallDir_recur(dirPath+'\'+name); // Suppression de tous les fichiers de ce répertoire
    end else
      if not UsingFileDescriptionName then begin
        UsingFileDescriptionName:=true;
        CurrentFileName:=name;
        UsingFileDescriptionName:=false;
      end;
      //Form1.LActionActuelle.Caption:='Supression de '+name;
      //Form1.LActionActuelle.Refresh;
      //Form1.LPanelActionActuelle.Refresh;
      TryDeleteFile(dirPath+'\'+name);
      //if not TryDeleteFile(dirPath+'\'+name) then ShowMessage('Impossible de supprimer '+name+'.');
  until FindNext(sRec)<>0;
  FindClose(sRec);
  if not UsingFileDescriptionName then begin
    UsingFileDescriptionName:=true;
    CurrentFileName:=dirPath;
    UsingFileDescriptionName:=false;
  end;
  //Form1.LActionActuelle.Caption:='Supression...';
  //Form1.LActionActuelle.Refresh;
  //Form1.LPanelActionActuelle.Refresh;
  TryDeleteDirectory(dirPath);
end;

{
procedure UninstallThread.UpdateInfoFromMainThread; // s'il peut, met à jour les informations graphiques (CurrentFileName etc.)
begin
  if not UsingFileCount_nb then CurrentFileNb_external:=CurrentFileNb;
  if not UsingFileCount_maxNb then MaxFileNb_external:=MaxFileNb;
  if not UsingFileDescriptionName then CurrentFileName_external:=CurrentFileName;
end;
}

var cli : TClientSocket;
    client : TSocket;

procedure TGestionUpdater.Init;
begin
  UpdateEnviroVariableInstallPath;
  SetAppType(tyAppClient); // grand buffer
  if PrivateTest then GameDirName:=GameDirName_private
                 else GameDirName:=GameDirName_public;
  Reseau_currentStep:=0;
end;

constructor TGestionUpdater.Create;
begin
  inherited Create;
  Init;
end;

function TGestionUpdater.Main_refreshNetSpeed : boolean;
var speedStr : string;
    rcvSpeed, sndSpeed, inUseCount : cardinal;
    accessGranted : boolean;
begin
  Result:=false;
  accessGranted:=false;
  for inUseCount:=1 to 5 do begin
    if client_inUse then
      sleep(1)
    else begin
      accessGranted:=true;
      break;
    end;
  end;

  if not accessGranted then exit; // impossible d'accéder au client, il est utilisé par le thread

  client_inUse:=true;
  client.GetRcvSentSize(rcvSpeed, sndSpeed);
  client_inUse:=false;

  netSpeed.moSpeed:=trunc(rcvSpeed/1048576);
  netSpeed.koSpeed:=trunc(rcvSpeed/1024)-netSpeed.moSpeed*1024;
  netSpeed.oSpeed:=integer(rcvSpeed)-netSpeed.moSpeed*1048576-netSpeed.koSpeed*1024;
  if rcvSpeed<1000 then netSpeed.speedStr:=inttostr(rcvSpeed)+' O/s (très lent)';
  if (rcvSpeed>=1000) and (rcvSpeed<1000000) then netSpeed.speedStr:=inttostr(netSpeed.koSpeed)+'.'+inttostr(trunc(netSpeed.oSpeed/10))+' Ko/s';
  if rcvSpeed>=1000000 then netSpeed.speedStr:=inttostr(netSpeed.moSpeed)+'.'+inttostr(trunc(netSpeed.koSpeed/10))+' Mo/s';
  UpdateButtonCaption(Messages.StrSpeed, netSpeed.speedStr);
  Result:=true;
end;


// Connect : connexion au serveur (initialisation de la partie réseau de la dll)
procedure TGestionUpdater.Connect(ip : string; port  : integer);
begin            //System.Win.ScktComp
  // pas besoin de gérer client_inUse, le thread n'est pas encore créé à cette étape (dll et updater delphi identiques)
  //localSock:=Winapi.WinSock.TSocket.Create;
  cli:=TClientSocket.Create(nil);
  //cli.:=BmNonBlocking;
  //cli.LocalHost:=AnsiString(ip);
  cli.Host:=ip;
  cli.Port:=port;
  cli.ClientType:=ctNonBlocking;
  client:=TSocket.Create(cli.Socket, true);
  cli.Active:=true;
  Sock_SetBigBuffer(cli);
  UpdateButtonCaption(Messages.ButtonPlay, 'Vérification...');
  //UpdateButtonCaption(Messages.StrActionActuelle, 'Connexion...');
  UpdateButtonCaption(Messages.StrActionActuelle, 'Attente du message de bienvenue...');

  WaitForWelcomeMessage:=true;
  WaitForWelcomeMessageMsLeft:=2000;
  //Sock_setNoDelay(cli);
  //.Active:=true;
  //noDelaySock(cli);
end;

function TGestionUpdater.WaitForMessage : boolean; // (obsolète car bloquant) retourne true si un message est bien reçu
var i : cardinal;
begin
  Result:=false;
  for i:=0 to 2000 do begin
    if client.GetMessage then begin
      Result:=true;
      break;
    end;
    sleep(1);
  end;
end;

function TGestionUpdater.LaunchGame(windowHandle : UIntPtr) : boolean;
var resOpen : cardinal;
    exePath, messageStr : string;
    success : boolean;
begin
  UpdateButtonCaption(Messages.StrActionActuelle, 'Ouverture du jeu...');
  exePath:=gameDir+'ClientFiles\Woria.exe';
  resOpen:=ShellExecute(windowHandle, 'open', PWideChar(exePath), PWideChar('executeDepuisUpdater5533'), nil, SW_SHOWNORMAL);
  success:=true;
  if resOpen=2 then
    success:=false; // 'ERREUR : impossible de lancer le jeu. (Woria.exe ne s''exécute pas)';
  if success then
    messageStr:='Appuyez sur "Jouer" pour lancer le jeu.'
  else
    messageStr:='ERREUR : impossible de lancer le jeu. (Woria.exe ne s''exécute pas)';
  UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
end;

procedure TGestionUpdater.UpdateEnviroVariableInstallPath;
begin
  if InstallationDansProgramFiles then
    EnviroVariable:=InstallEnviroVariable_programFiles
  else
    EnviroVariable:=InstallEnviroVariable_appData;
  if InstallationDansProgramFiles then Messages.ButtonInstallMode.Caption:='Installation normale (nécessite droits administrateur)'
                                  else Messages.ButtonInstallMode.Caption:='Installation locale (peut ne pas marcher en fonction de votre nom de session)';
  Messages.ButtonInstallMode.hasToBeRafreshed:=true;
end;

// Reseau_currentStep 0 : aucune demande au serveur en cours
// Reseau_currentStep 1 : première connexion, tentative de joindre le serveur
// Reseau_currentStep 2 : attente de la réception de la liste des fichiers
// Reseau_currentStep 0 :
// Reseau_currentStep 0 :

function TGestionUpdater.ReceiveMessage : boolean; // retrourne true si un message a été reçu (il est traité ici)
var b1, b2 : byte;
    bRes : boolean;
    UpdateServerVer : cardinal;
    tryNb : cardinal;
    messageStr : string;
    newState : boolean;
    nbFinal, nbCurrent : integer;
begin

  //if Reseau_currentStep=0 then exit; // rien à recevoir (des messages ont peut-être été perdus, je fais quand-même un client.GetMessage)

  if Reseau_currentStep=1 then begin
    WaitForWelcomeMessageMsLeft:=WaitForWelcomeMessageMsLeft-1;
    if WaitForWelcomeMessageMsLeft<=0 then begin
      UpdateButtonCaption(Messages.StrActionActuelle, 'ERREUR : impossible de joindre le serveur.');
      UpdateButton(Messages.ButtonPlay, 'Réessayer', true);
      IsDownloading:=false;
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      WaitForWelcomeMessage:=false;
      Reseau_currentStep:=0;
      exit;
    end;
  end;

  if Reseau_currentStep=2 then begin
    if GetTimeMs-Reseau_currentStep2_time>=G_WaitServerTimeMs then begin
      Reseau_currentStep:=0;
      UpdateButtonCaption(Messages.StrActionActuelle, 'ERREUR : impossible de joindre le serveur (2).');
      IsDownloading:=false;
      UpdateButton(Messages.ButtonPlay, 'Réessayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
    end;
  end;



  if not client.GetMessage then exit;
  b1:=readubyte;
  b2:=readubyte;
  {showMessage('20->8 envoyé');
  sleep(200);
  mStart(20, 8);
  sendbuffer(client);
  SendAllBuffers;
  sleep(20000);}

  if (Reseau_currentStep=1) and (not ((b1=1) and (b2=1))) then begin
    messageStr:='! ERREUR : mauvais message reçu du serveur.'+chr(10)+'Téléchargez le dernier updater de woria.net';
    UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
    IsDownloading:=false;
    UpdateButton(Messages.ButtonPlay, 'Réessayer', true);
    UpdateButtonEnabled(Messages.ButtonUninstall, true);
    exit;
  end;


  //Reseau_currentStep = 1
  if Reseau_currentStep=1 then begin

    if (b1=1) and (b2=1) then begin // Reseau_currentStep = 1
      UpdateButtonCaption(Messages.StrActionActuelle, 'Connexion ok, demande de la liste des fichiers.');
      mStart(4, 1);
      sendbuffer(client);
      SendAllBuffers;
      UpdateButtonCaption(Messages.StrActionActuelle, 'Attente de la réception de la liste des fichiers...');
      Reseau_currentStep:=2;
      Reseau_currentStep2_time:=GetTimeMs;
      IsDownloading:=true;
      WaitForWelcomeMessage:=false;
      exit;
    end;
  end;

  //Reseau_currentStep = 2
  if Reseau_currentStep=2 then begin

    if not ((b1=4) and (b2=100)) then begin // Reseau_currentStep = 2
      messageStr:='Updater non à jour. Téléchargez le dernier updater de woria.net (mauvais message reçu, b1='+inttostr(b1)+' b2='+inttostr(b2)+')';
      ShowMessage(messageStr);
      UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
      UpdateButtonCaption(Messages.StrSpeed, '');
      UpdateButton(Messages.ButtonPlay, 'Réessayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      IsDownloading:=false;
      Reseau_currentStep:=0;
      exit;
    end;

    UpdateServerVer:=readuint;
    if UpdateServerVer<>UpdateClientVer then begin
      messageStr:='Updater non à jour. Téléchargez le dernier updater de woria.net (vLocal '+inttostr(UpdateClientVer)+'; vDist '+inttostr(UpdateServerVer)+')';
      ShowMessage(messageStr);
      UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
      UpdateButtonCaption(Messages.StrSpeed, '');
      UpdateButton(Messages.ButtonPlay, 'Réessayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      IsDownloading:=false;
      Reseau_currentStep:=0;
      exit;
    end;

    Reseau_currentStep:=3;
    UpdateButtonCaption(Messages.StrActionActuelle, 'Création du dossier du jeu...');
    //if not PrivateTest then
    gameDir:=GetEnvironmentVariable(EnviroVariable)+GameDirName+'\';
    //else
    //  gameDir:=GetEnvironmentVariable(EnviroVariable)+'\Woria_privateAlpha\';
    // Création du dossier du jeu
    for tryNb:=0 to tryNbMax-1 do begin
      if DirectoryExists(gameDir) then // Si le dossier du jeu existe, c'est ok.
        break;
      if tryNb<>0 then sleep(12);
      ForceDirectories(gameDir);
    end;
    if not DirectoryExists(gameDir) then begin // bug : impossible de créer le dossier du jeu.
      ShowMessage('Echec de l''installation : impossible de créer le dossier du jeu.'+chr(10)+'-> Exécutez ce programme en administrateur+'+chr(10)+'-> Désactivez votre antivirus');
      UpdateButtonCaption(Messages.StrActionActuelle, '! Impossible de créer le dossier du jeu.');
      UpdateButtonCaption(Messages.StrSpeed, '');
      UpdateButton(Messages.ButtonPlay, 'Réessayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      IsDownloading:=false;
      Reseau_currentStep:=0;
      exit;
    end;

    Reseau_currentStep:=4;
    UpdateButtonCaption(Messages.StrActionActuelle, 'Téléchargement des fichiers...');

    bRes:=Update_receiveFileList(client, gameDir, true);
    IsDownloading:=bRes;

    UpdateButtonEnabled(Messages.ButtonPlay, not IsDownloading);
    if IsDownloading then UpdateButtonCaption(Messages.ButtonPlay, 'Mise à jour...');

    if not IsDownloading then begin
      //client.GetSocket.Disconnect;
      JeuAJour;
      LaunchGame;
      Reseau_currentStep:=0;
    end else begin
      UpdateProgressBar(0, true);
      Reseau_currentStep:=5;
      //ImgLogoClair.Width:=0;
    end;

    //WriteLn('bRes='+booltostr(bRes, true));
    // ---

  end;

  //Reseau_currentStep = 5
  if Reseau_currentStep=5 then begin // téléchargement des fichiers du jeu

    { Fait plus haut dans ce script
    if WaitForWelcomeMessage and (not IsDownloading) then begin
      if IsDownloading then showMessage('TForm1.TimerRcvTimer : IsDownloading.');
      WaitForWelcomeMessage_listen;
      if not IsDownloading then exit;
    end;
    }


    if not IsDownloading then begin
      Reseau_currentStep:=0;
      exit;
    end;
    //RefreshSpeed;
    Main_refreshNetSpeed;

    while true {client.GetMessage} do begin
      //RefreshSpeed;

      if (b1=253) then begin
        ShowMessage('L''updater est en maintenance, veuillez réessayer plus tard. Désolé ><''');
        IsDownloading:=false;
        JeuAJour(false);
        Reseau_currentStep:=0;
        exit;
      end;

      //showMessage('Update_receivePart '+inttostr(b1)+' '+inttostr(b2));
      //WriteLn('Update_receivePart '+inttostr(b1)+' '+inttostr(b2));
      if ((b1=4) and (b2=3)) then begin
        newState:=Update_receivePart(client, gameDir, true);
        nbFinal:=max(1, G_Updade_neededNb);//max(1, client.GetRcvFinalSize);
        nbCurrent:=G_Updade_currentNb;//client.GetRcvCurrentSize;
        UpdateButtonCaption(Messages.StrActionActuelle, 'Téléchargement du fichier '+inttostr(nbCurrent)+' sur '+inttostr(nbFinal)+'...');
        UpdateProgressBar(trunc((nbCurrent-1)/nbFinal*100), true);
        IsDownloading:=newState;
        if not IsDownloading then begin // suite juste après la fin de la boucle while
          break;
        end;
      end;

      if not client.GetMessage then break;
      b1:=readubyte;  // pour l'itération suivante
      b2:=readubyte;
    end;

    if IsDownloading then exit;
    JeuAJour;
    //GameStart;
    //LaunchGame;
  end; // fin Reseau_currentStep = 5

end;


procedure TGestionUpdater.UpdateButtonCaption(var button : TGestionUpdater_button; caption : string);
begin
  button.Caption:=caption;
  button.hasToBeRafreshed:=true;
end;
procedure TGestionUpdater.UpdateButtonEnabled(var button : TGestionUpdater_button; enabled : boolean);
begin
  button.Enabled:=enabled;
  button.hasToBeRafreshed:=true;
end;
procedure TGestionUpdater.UpdateButton(var button : TGestionUpdater_button; caption : string; enabled : boolean);
begin
  button.Caption:=caption;
  button.Enabled:=enabled;
  button.hasToBeRafreshed:=true;
end;

procedure TGestionUpdater.UpdateProgressBar(percent : cardinal; enabled : boolean);
begin
  ProgressBar.Percent:=percent;
  ProgressBar.Enabled:=enabled;
end;

procedure TGestionUpdater.JeuAJour(success : boolean = true);
var progressBarPercent : cardinal;
    messageStr : string;
    progressBarEnable : boolean;
begin
  UpdateButton(Messages.ButtonPlay, 'Jouer', true);
  UpdateButtonCaption(Messages.StrSpeed, '');

  if success then begin
    progressBarPercent:=100;
    messageStr:='Appuyez sur "Jouer" pour lancer le jeu.';
    progressBarEnable:=true;
  end else begin
    progressBarPercent:=0;
    messageStr:='Échec de la mise à jour.';
    progressBarEnable:=false;
  end;

  UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
  UpdateProgressBar(progressBarPercent, progressBarEnable);
  UpdateButtonEnabled(Messages.ButtonUninstall, true);
end;



end.
