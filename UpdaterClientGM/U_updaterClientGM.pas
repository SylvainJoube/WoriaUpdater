unit U_updaterClientGM;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, U_UpdateFiles, U_Arrays, U_Files, U_NetSys4, U_Sockets4, U_StaticBuffer, U_ClientFiles,
  ComCtrls, math, ExtCtrls; {, UITypes, Vcl.Imaging.pngimage}

const UpdateClientVer = 5;
var G_WindowHandle : int64;

var G_updaterState : integer; // dans GestionUodater.Init = -1;
var G_updaterMessage: string;
var G_JeuPretAEtreLance : boolean; // dans GestionUpdater.Init = true;

const G_WaitServerTimeMs = 3000;

const PrivateTest = false;

var UninstallLog_message : string;

const G_privateTestIp = 'updaterf.woria.net';//'dl2.sylvesoft.com';
//const G_privateTestIp = 'localhost';
const G_privateTestPort = 3345;  // couleur $008BBCE9

const G_publicIp = '109.7.239.102';// = sfr.woria.net  //'updaterf.woria.net';//'88.191.184.45';//'192.168.0.21';//'88.191.184.45';////'192.168.0.21';//'updaterf.woria.net';// 'dl2.sylvesoft.com';
const G_publicIp_rescue = 'sfr.woria.net'; // mettre ici l'IP de Free  // probablement 88.191.184.45
const G_publicPort = 3365;//3335;////3365;
const G_publicPort_rescue = 443;   // si le port classique ne r�pond pas

// voir TGestionUpdater.Init pour la gestion des diff�rentes adresses

var InstallationDansProgramFiles : boolean = true;
var EnviroVariable : string;// d�fini dans TGestionUpdater.Init (appel� dans TForm1.Create() pour l'updater en delphi)   = 'APPDATA';
//const EnviroVariable = 'PROGRAMFILES';
const InstallEnviroVariable_programFiles = 'PROGRAMFILES';
const InstallEnviroVariable_appdata = 'APPDATA';

const GameDirName_private = '\Woria_privateAlpha';
const GameDirName_public = '\Woria_alpha';
var GameDirName : widestring = GameDirName_public;


const tryNbMax = 600;

const G_WaitServerTimerMs = 3000; // temps d'attente avant de consid�rer un message perdu

var WaitForWelcomeMessage : boolean = false;
    WaitForWelcomeMessageMsLeft : integer;
    WaitForWelcomeMessage_waitUntilMs : int64;

const StrActionActuelle_defaultMessage = ''; // 'Appuyez sur "Jouer" pour lancer le jeu.';


type TGestionUpdater_netSpeed = record
  InUse : boolean; // pour �viter les violations d'acc�s
  moSpeed, koSpeed, oSpeed : cardinal;
  speedStr : string;
end;
type TGestionUpdater_button = record
  Enabled : boolean;
  Caption : string;
  hasToBeRafreshed : boolean; // pour ne mettre � jour � l'�cran que si n�cessaire (pour �viter le scintillement sur l'application delphi)
end;
type TGestionUpdater_pButton = ^TGestionUpdater_button;
type TGestionUpdater_messages = record // messages affich�s � l'�cran
  StrActionActuelle : TGestionUpdater_button; // communication avec l'utilisateur, "erreur", "attente"...
  StrSpeed : TGestionUpdater_button; // vitesse de t�l�chargement et autres infos
  ButtonPlay : TGestionUpdater_button; // ce qui est affich� sur le bouton "jouer"
  ButtonUninstall : TGestionUpdater_button;
  ButtonInstallMode : TGestionUpdater_button;
end;
type TGestionUpdater_progressBar = record
  Enabled : boolean;
  //Caption : string;
  Percent : cardinal; // 0 - 100%
  hasToBeRafreshed : boolean; // pour ne mettre � jour � l'�cran que si n�cessaire (pour �viter le scintillement sur l'application delphi)
end;
type TGestionUpdater_netAddress = record // une configuration � tester avant d'afficher le message "impossible de se connecter"
  Ip : string; // ip destination
  Port : word; // port destination
  StrToDraw : string; // message � afficher pour dire au joueur de patienter
end;
type TPGestionUpdater_netAddress = ^TGestionUpdater_netAddress;
//type TPGestionUpdater_button = ^TGestionUpdater_button;
type TGestionUpdater = class
  private
    //cli : TClientSocket;
    client : TSocket;
    client_inUse : boolean; // pour �viter les violations d'acc�s entre le main et le thread
  public
    Reseau_currentStep : cardinal; // �tape de r�ception (connexion intialie, r�ception de la version, t�l�chargement des fichiers du jeu...)
    Reseau_currentStep2_time : int64;


    netSpeed : TGestionUpdater_netSpeed;
    netErrorCode : cardinal;
    IsDownloadingGameFiles : boolean; // vrai si les fichiers du jeu sont en train d'�tre t�l�charg�s
    WaitForWelcomeMessage : boolean; // indique s'il y a eu une r�ponse du serveur
    Messages : TGestionUpdater_messages;
    ProgressBar : TGestionUpdater_progressBar;

    A1NetAddressToTry : array of TGestionUpdater_netAddress; // Liste de toutes les configurations � essayer avant de dire qu'il est impossible de se connecter
    NetAddress_currentTryIndex : cardinal; // = 0, je commence par la premi�re configuration possible


    // netErrorCode 0 :
    function Main_refreshNetSpeed : boolean; // uniquement appel� par le main (<>thread)
    procedure Connect(ip : string; port  : integer; addrNameGraphic : string = '');
    function WaitForMessage : boolean; // retourne true si un message est bien re�u
    function LaunchGame(windowHandle : int64) : boolean; // UIntPtr = NativeUInt = unsigned int = Cardinal

    function ReceiveMessage : boolean; // retrourne true si un message a �t� re�u (il est trait� ici)

    procedure UpdateEnviroVariableInstallPath;
    procedure Init;
    constructor Create;
    procedure UpdateButtonCaption(var button : TGestionUpdater_button; caption : string);
    procedure UpdateButtonEnabled(var button : TGestionUpdater_button; enabled : boolean);
    procedure UpdateButton(var button : TGestionUpdater_button; caption : string; enabled : boolean);
    procedure JeuAJour(success : boolean = true);
    procedure UpdateProgressBar(percent : cardinal; enabled : boolean);
    procedure AddAdressToTry(ip : string; port : word; putFirst : boolean = false; afficherMessageStr : string = ''); // ajout d'une adresse � essayer
    function GetNextAdressToTry(var outIP : string; var outPort : word; var outAddrGraphicName : string) : boolean; // false s'il n'y en a plus
    function HasNextAdressToTry : boolean; // true s'il reste une adresse � essayer, false sinon
    procedure SetUnableToReachServer;
    

end;

var GestionUpdater : TGestionUpdater;

type TUninstallThread = class (TThread)
  public
    Finished, HasToStop : boolean;
    UsingFileCount_nb, UsingFileCount_maxNb : boolean;
    CurrentFileNb, MaxFileNb : cardinal;
    UsingFileDescriptionName : boolean;
    CurrentFileName : string;

    //CurrentFileName_external : string; // mis � jour uniquement par un thread externe (le principal)
    //CurrentFileNb_external, MaxFileNb_external : cardinal; // ^ idem ^

    UninstallDir : widestring;

    constructor Create; virtual;//(uninstallDirPath : widestring); virtual;
    procedure Execute; override;
    procedure UninstallDir_recur(dirPath : widestring);
    //procedure UpdateInfoFromMainThread; // s'il peut, met � jour les informations graphiques (CurrentFileName etc.)
end;

var Uninstall_currentFileCount : cardinal;
var Uninstall_isUnistalling : boolean = false;
var UninstallThread : TUninstallThread;


var IsDownloading : boolean = false;
    gameDir : string;

function GetTimeMs : int64;

var Dll_CurrentString: string;
function dGetCurrentString(arg_valueIndex : double) : double; cdecl;
function dSetCurrentString(arg_index, arg_chr : double) : double; cdecl;


implementation
uses ShellApi;

function GetTimeMs : int64;
begin
  Result:=trunc(SysUtils.Now*MillisecTimeFactor);
end;


//var Dll_CurrentString : string;  dans U_FonctionGenerales

function dGetCurrentString(arg_valueIndex : double) : double; cdecl;
begin
  if arg_valueIndex=0 then begin // L'indexation des caract�res du string commence � 1.
    Result:=Length(Dll_CurrentString);
    exit;
  end;
  Result:=ord(Dll_CurrentString[trunc(arg_valueIndex)]);
end;
exports dGetCurrentString;

function dSetCurrentString(arg_index, arg_chr : double) : double; cdecl;
begin
  Result:=1;
  if arg_index=0 then begin // L'indexation des caract�res du string commence � 1.
    SetLength(Dll_CurrentString, trunc(arg_chr));
    exit;
  end;
  Dll_CurrentString[trunc(arg_index)]:=chr(trunc(arg_chr));
end;
exports dSetCurrentString;


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
    if (sRec.Attr and faDirectory)=faDirectory then begin // ici, and est une op�ration sur l'�criture binaire des nombres. Exemple : 1001101 and 1100100 = 1000100.
      UninstallFull_dir(dirPath+'\'+name); // Suppression de tous les fichiers de ce r�pertoire
    end else

      UninstallLog_message:='Supression de '+name;
      TryDeleteFile(dirPath+'\'+name);
      //if not TryDeleteFile(dirPath+'\'+name) then ShowMessage('Impossible de supprimer '+name+'.');
  until FindNext(sRec)<>0;
  FindClose(sRec);
  UninstallLog_message:='Supression...';
  TryDeleteDirectory(dirPath);
  //if not TryDeleteDirectory(dirPath) then ShowMessage('Impossible de supprimer le dossier '+dirPath+'.');
end;

procedure UninstallFull;
var dirPath : string;
begin
  if G_updaterState<>0 then exit;
  G_updaterState:=-10;

  // -> Faire la d�sinstallation avec un thread.
  UninstallLog_message:='D�sinstallation...';
  //if not PrivateTest then
  dirPath:=GetEnvironmentVariable(EnviroVariable)+GameDirName;//'\Woria_alpha'
  //else
  //  dirPath:=GetEnvironmentVariable(EnviroVariable)+'\Woria_privateAlpha';
  UninstallFull_dir(dirPath);
  UninstallLog_message:='D�sinstallation termin�e.';
  G_updaterState:=0;
end;

{procedure TForm1.BUninstallClick(Sender: TObject);
var button : integer;
begin
  button:=MessageDlg('Voulez-vous vraiment d�sinstaller le jeu et tout ses composants ? :''(', mtCustom, [mbYes, mbCancel], 0);
  if button=6 then begin
    UninstallFull;
    ProgressBar.Position:=0;
  end;
end;}


constructor TUninstallThread.Create;//(uninstallDirPath : widestring);
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
  Uninstall_currentFileCount:=0;
  Uninstall_isUnistalling:=true;
  Resume; // Delphi 7
  //Start; // Delphi XE4+  nouvelle version de : Resume;
  //sleep(2000);
  Suspended:=false;
end;

procedure TUninstallThread.Execute;
begin
  try
    //UninstallDir_recur(UninstallDir);
  except
  end;
  Uninstall_isUnistalling:=false;
  Finished:=true;
end;

procedure TUninstallThread.UninstallDir_recur(dirPath : widestring);
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
    if (sRec.Attr and faDirectory)=faDirectory then begin // ici, and est une op�ration sur l'�criture binaire des nombres. Exemple : 1001101 and 1100100 = 1000100.
      UninstallDir_recur(dirPath+'\'+name); // Suppression de tous les fichiers de ce r�pertoire
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
      Uninstall_currentFileCount:=Uninstall_currentFileCount+1;
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
procedure UninstallThread.UpdateInfoFromMainThread; // s'il peut, met � jour les informations graphiques (CurrentFileName etc.)
begin
  if not UsingFileCount_nb then CurrentFileNb_external:=CurrentFileNb;
  if not UsingFileCount_maxNb then MaxFileNb_external:=MaxFileNb;
  if not UsingFileDescriptionName then CurrentFileName_external:=CurrentFileName;
end;
}

//var cli : TClientSocket;
//    client : TSocket;

procedure TGestionUpdater.Init;
var messageStr : string;
    //randResult : integer;
begin
  client:=nil;
  NetAddress_currentTryIndex := 0;
  G_updaterState:=-1;
  G_JeuPretAEtreLance:=true;

  UpdateEnviroVariableInstallPath;
  SetAppType(tyAppClient); // grand buffer
  if PrivateTest then GameDirName:=GameDirName_private
                 else GameDirName:=GameDirName_public;
  Reseau_currentStep:=0;
  //Randomize;
  //randResult := random(4);
  //messageStr:='';
  //messageStr:='Appuyez sur "Jouer" pour lancer le jeu.';
  messageStr:=StrActionActuelle_defaultMessage;//'On joue ? :D';
  UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
  // Ajout des diff�rentes adresse � tester :
  self.AddAdressToTry(G_publicIp, G_publicPort, false, 'serveur principal (port par d�faut)');
  self.AddAdressToTry(G_publicIp, G_publicPort_rescue, false, 'serveur principal (port alternatif)');
  self.AddAdressToTry(G_publicIp_rescue, G_publicPort, false, 'serveur de secours (port par d�faut)');
  self.AddAdressToTry(G_publicIp_rescue, G_publicPort_rescue, false, 'serveur de secours (port alternatif)');

end;

constructor TGestionUpdater.Create;
begin
  inherited Create;
  Init;
end;

function TGestionUpdater.Main_refreshNetSpeed : boolean;
var //speedStr : string;
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

  if not accessGranted then exit; // impossible d'acc�der au client, il est utilis� par le thread

  client_inUse:=true;
  client.GetRcvSentSize(rcvSpeed, sndSpeed);
  client_inUse:=false;

  netSpeed.moSpeed:=trunc(rcvSpeed/1048576);
  netSpeed.koSpeed:=trunc(rcvSpeed/1024)-netSpeed.moSpeed*1024;
  netSpeed.oSpeed:=integer(rcvSpeed)-integer(netSpeed.moSpeed)*1048576-integer(netSpeed.koSpeed)*1024;
  if rcvSpeed<1000 then netSpeed.speedStr:=inttostr(rcvSpeed)+' O/s (tr�s lent)';
  if (rcvSpeed>=1000) and (rcvSpeed<1000000) then netSpeed.speedStr:=inttostr(netSpeed.koSpeed)+'.'+inttostr(trunc(netSpeed.oSpeed/10))+' Ko/s';
  if rcvSpeed>=1000000 then netSpeed.speedStr:=inttostr(netSpeed.moSpeed)+'.'+inttostr(trunc(netSpeed.koSpeed/10))+' Mo/s';
  UpdateButtonCaption(Messages.StrSpeed, netSpeed.speedStr);
  Result:=true;
end;


// Connect : connexion au serveur (initialisation de la partie r�seau de la dll)
procedure TGestionUpdater.Connect(ip : string; port  : integer; addrNameGraphic : string = '');
var strPortInfo, strInfo : string;
begin            //System.Win.ScktComp
  // pas besoin de g�rer client_inUse, le thread n'est pas encore cr�� � cette �tape (dll et updater delphi identiques)
  //localSock:=Winapi.WinSock.TSocket.Create;
  if client<>nil then begin
    client.Destroy;
  end;
  client := TSocket.CreateAndConnect(ip, port, true);
  //ShowMessage('Connexion � ip ='+ip+' port = '+inttostr(port)+' addrNameGraphic = ' + addrNameGraphic);
  {cli:=TClientSocket.Create(nil);
  cli.Host:=ip;
  cli.Port:=port;
  cli.ClientType:=ctNonBlocking;
  client:=TSocket.Create(cli.Socket, true);
  cli.Active:=true;
  Sock_SetBigBuffer(cli);}

  UpdateButtonCaption(Messages.ButtonPlay, 'V�rification...');
  //UpdateButtonCaption(Messages.StrActionActuelle, 'Connexion...');

  strPortInfo := ''; // info relative au port utilis�
  //if (port = G_publicPort) then strPortInfo := ' (port par d�faut)';
  //if (port = G_publicPort_rescue) then strPortInfo := ' (port alternatif)';
  if (port = G_privateTestPort) then strPortInfo := ' (port version de test)';

  strInfo := 'Connexion';
  if addrNameGraphic = '' then begin
    strInfo := strInfo + '...';
  end else begin
    strInfo := strInfo +' � ' + addrNameGraphic + '...';
  end;
  strInfo := strInfo + strPortInfo; // 'Attente du message de bienvenue...' + strPortInfo

  UpdateButtonCaption(Messages.StrActionActuelle, strInfo);

  WaitForWelcomeMessage:=true;
  WaitForWelcomeMessageMsLeft:=2000;
  Reseau_currentStep:=1; // ?

  G_updaterState:=1; // 'Attente du message de bienvenue...';
  WaitForWelcomeMessage:=true;
  //WaitForWelcomeMessageMsLeft:=2000;
  WaitForWelcomeMessage_waitUntilMs:=GetTimeMs+2000;
  //Sock_setNoDelay(cli);
  //noDelaySock(cli);
end;

function TGestionUpdater.WaitForMessage : boolean; // (obsol�te car bloquant) retourne true si un message est bien re�u
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

function TGestionUpdater.LaunchGame(windowHandle : int64) : boolean;
var resOpen : cardinal;
    exePath, messageStr, applicationArgumentPassword : WideString;
    success : boolean;
    //wideExePath : WideString;
begin
  UpdateButtonCaption(Messages.StrActionActuelle, 'Ouverture du jeu...');
  exePath:=gameDir+'ClientFiles\Woria.exe';
  //wideExePath:=exePath;
  applicationArgumentPassword := 'executeDepuisUpdater5533';
  resOpen:=ShellExecuteW(windowHandle, 'open', PWideChar(exePath), PWideChar(applicationArgumentPassword), nil, SW_SHOWNORMAL);
  success:=true;
  if resOpen=2 then
    success:=false; // 'ERREUR : impossible de lancer le jeu. (Woria.exe ne s''ex�cute pas)';
  if success then
    messageStr:=StrActionActuelle_defaultMessage//'Appuyez sur "Jouer" pour lancer le jeu.'
  else
    messageStr:='ERREUR : impossible de lancer le jeu. (Woria.exe ne s''ex�cute pas)';
  UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
  Result := success; // visiblement non utilis�
end;

procedure TGestionUpdater.UpdateEnviroVariableInstallPath;
begin
  if InstallationDansProgramFiles then
    EnviroVariable:=InstallEnviroVariable_programFiles
  else
    EnviroVariable:=InstallEnviroVariable_appData;
  if InstallationDansProgramFiles then Messages.ButtonInstallMode.Caption:='Installation normale (n�cessite droits administrateur)'
                                  else Messages.ButtonInstallMode.Caption:='Installation locale (peut ne pas marcher en fonction de votre nom de session)';
  Messages.ButtonInstallMode.hasToBeRafreshed:=true;
end;

// Reseau_currentStep 0 : aucune demande au serveur en cours
// Reseau_currentStep 1 : premi�re connexion, tentative de joindre le serveur
// Reseau_currentStep 2 : attente de la r�ception de la liste des fichiers
// Reseau_currentStep 0 :
// Reseau_currentStep 0 :

function TGestionUpdater.ReceiveMessage : boolean; // retrourne true si un message a �t� re�u (il est trait� ici)
var b1, b2 : byte;
    bRes : boolean;
    UpdateServerVer : cardinal;
    tryNb : cardinal;
    messageStr : string;
    newState : boolean;
    nbFinal, nbCurrent : integer;
    tryAgain_ip : string;
    tryAgain_port : word;
    tryAgain_addrName : string;
    progressionActuelle : double;
    tailleATelechargerRestante : integer;
    tailleATelechargerRestante_str: string;
    //currentDownSize_mo, currentDownSize_ko, currentDownSize_o : cardinal;
    //currentNeededSize_mo, currentNeededSize_ko, currentNeededSize_o : cardinal;
begin

  Result := false; // valeur par d�faut
  //if Reseau_currentStep=0 then exit; // rien � recevoir (des messages ont peut-�tre �t� perdus, je fais quand-m�me un client.GetMessage)

  if Reseau_currentStep=1 then begin
    //WaitForWelcomeMessageMsLeft:=WaitForWelcomeMessageMsLeft-1;
    if WaitForWelcomeMessage_waitUntilMs < GetTimeMs then begin

      //if (port = G_publicPort) then strPortInfo := ' (port par d�faut)';
      //if (port = G_publicPort_rescue) then strPortInfo := ' (port alternatif)';
      //if (port = G_privateTestPort) then strPortInfo := ' (port version de test)';

      if self.HasNextAdressToTry then begin
        self.GetNextAdressToTry(tryAgain_ip, tryAgain_port, tryAgain_addrName);
        self.Connect(tryAgain_ip, tryAgain_port, tryAgain_addrName); // nouvelle tentative de connexion
        //showMessage('TGestionUpdater.ReceiveMessage : novelle tentative de connexion vers : ip=' + tryAgain_ip + ' port=' + inttostr(tryAgain_port));
      end else
        self.SetUnableToReachServer;
      {
      UpdateButtonCaption(Messages.StrActionActuelle, 'ERREUR : impossible de joindre le serveur.');
      UpdateButton(Messages.ButtonPlay, 'R�essayer', true);
      IsDownloading:=false;
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      G_updaterMessage:='ERREUR : impossible de joindre le serveur.';
      WaitForWelcomeMessage:=false;
      Reseau_currentStep:=0;
      G_updaterState:=-2; // impossible de se connecter au serveur
      }
      exit;
    end;
  end;

  if Reseau_currentStep=2 then begin
    if GetTimeMs-Reseau_currentStep2_time>=G_WaitServerTimeMs then begin
      Reseau_currentStep:=0;
      UpdateButtonCaption(Messages.StrActionActuelle, 'ERREUR : impossible de joindre le serveur (2).');
      IsDownloading:=false;
      G_updaterState:=-2; // impossible de se connecter au serveur
      G_updaterMessage:='ERREUR : impossible de joindre le serveur (2).';
      UpdateButton(Messages.ButtonPlay, 'R�essayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
    end;
  end;



  if not client.GetMessage then exit;
  NetAddress_currentTryIndex := 0; // r�initialisation de l'index, comme une connexion a bien �t� �tablie (je pourrais aussi utiliser NetAddress_currentTryIndex := max(0, integer(NetAddress_currentTryIndex) - 1)
  b1:=readubyte;
  b2:=readubyte;
  {showMessage('20->8 envoy�');
  sleep(200);
  mStart(20, 8);
  sendbuffer(client);
  SendAllBuffers;
  sleep(20000);}

  if (Reseau_currentStep=1) and (not ((b1=1) and (b2=1))) then begin
    messageStr:='! ERREUR : mauvais message re�u du serveur.'+chr(10)+'T�l�chargez le dernier updater de woria.net';
    //UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
    G_updaterMessage:=messageStr;
    IsDownloading:=false;
    G_updaterState:=-3; // mauvaise version de l'updater
    UpdateButton(Messages.ButtonPlay, 'R�essayer', true);
    UpdateButtonEnabled(Messages.ButtonUninstall, true);
    exit;
  end;


  //Reseau_currentStep = 1
  if Reseau_currentStep=1 then begin

    if (b1=1) and (b2=1) then begin // Reseau_currentStep = 1
      //UpdateButtonCaption(Messages.StrActionActuelle, 'Connexion ok, demande de la liste des fichiers.');
      G_updaterMessage:='Connexion ok, demande de la liste des fichiers...';
      mStart(4, 1);
      sendbuffer(client);
      SendAllBuffers;
      G_updaterState:=2; // attente de la r�ception de la liste de fichiers
      UpdateButtonCaption(Messages.StrActionActuelle, 'Attente de la r�ception de la liste des fichiers...');
      G_updaterMessage:='Attente de la r�ception de la liste des fichiers...';
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
      messageStr:='Updater non � jour. T�l�chargez le dernier updater de woria.net (mauvais message re�u, b1='+inttostr(b1)+' b2='+inttostr(b2)+')';
      ShowMessage(messageStr);
      G_updaterMessage:=messageStr;
      G_updaterState:=-3; // mauvaise version de l'updater
      UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
      UpdateButtonCaption(Messages.StrSpeed, '');
      UpdateButton(Messages.ButtonPlay, 'R�essayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      IsDownloading:=false;
      Reseau_currentStep:=0;
      exit;
    end;

    UpdateServerVer:=readuint;
    if UpdateServerVer<>UpdateClientVer then begin
      messageStr:='Updater non � jour. T�l�chargez le dernier updater de woria.net (vLocal '+inttostr(UpdateClientVer)+'; vDist '+inttostr(UpdateServerVer)+')';
      G_updaterState:=-3; // mauvaise version de l'updater
      //ShowMessage(messageStr);
      G_updaterMessage:=messageStr;
      UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
      UpdateButtonCaption(Messages.StrSpeed, '');
      UpdateButton(Messages.ButtonPlay, 'R�essayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      IsDownloading:=false;
      Reseau_currentStep:=0;
      exit;
    end;

    Reseau_currentStep:=3;
    //UpdateButtonCaption(Messages.StrActionActuelle, 'Cr�ation du dossier du jeu...');
    G_updaterMessage:='Cr�ation du dossier du jeu...';
    //if not PrivateTest then
    gameDir:=GetEnvironmentVariable(EnviroVariable)+GameDirName+'\';
    //else
    //  gameDir:=GetEnvironmentVariable(EnviroVariable)+'\Woria_privateAlpha\';
    // Cr�ation du dossier du jeu
    for tryNb:=0 to tryNbMax-1 do begin
      if DirectoryExists(gameDir) then // Si le dossier du jeu existe, c'est ok.
        break;
      if tryNb<>0 then sleep(12);
      ForceDirectories(gameDir);
    end;
    if not DirectoryExists(gameDir) then begin // bug : impossible de cr�er le dossier du jeu.
      messageStr:='Echec de l''installation : impossible de cr�er le dossier du jeu.'+chr(10)+'-> Ex�cutez ce programme en administrateur+'+chr(10)+'-> D�sactivez votre antivirus';
      ShowMessage(messageStr);
      G_updaterMessage:=messageStr;
      G_updaterState:=0;
      UpdateButtonCaption(Messages.StrActionActuelle, '! Impossible de cr�er le dossier du jeu.');
      UpdateButtonCaption(Messages.StrSpeed, '');
      UpdateButton(Messages.ButtonPlay, 'R�essayer', true);
      UpdateButtonEnabled(Messages.ButtonUninstall, true);
      IsDownloading:=false;
      Reseau_currentStep:=0;
      exit;
    end;

    Reseau_currentStep:=4;
    //UpdateButtonCaption(Messages.StrActionActuelle, 'T�l�chargement des fichiers...');
    G_updaterMessage:='T�l�chargement des fichiers...';
    UpdateButtonCaption(Messages.StrActionActuelle, 'T�l�chargement des fichiers...');

    bRes:=Update_receiveFileList(client, gameDir, true);
    NeededFiles_receivedSizeTotal := 0; // r�initialisation du nombre total d'octets t�l�charg�s
    IsDownloading:=bRes;

    //UpdateButtonEnabled(Messages.ButtonPlay, not IsDownloading);
    if IsDownloading then G_updaterMessage:='Mise � jour...'; //UpdateButtonCaption(Messages.ButtonPlay, 'Mise � jour...');

    if not IsDownloading then begin
      //client.GetSocket.Disconnect;
      JeuAJour;
      LaunchGame(G_WindowHandle);
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
  if Reseau_currentStep=5 then begin // t�l�chargement des fichiers du jeu

    { Fait plus haut dans ce script
    if WaitForWelcomeMessage and (not IsDownloading) then begin
      if IsDownloading then showMessage('TForm1.TimerRcvTimer : IsDownloading.');
      WaitForWelcomeMessage_listen;
      if not IsDownloading then exit;
    end;
    }
    G_updaterState:=3;

    if not IsDownloading then begin
      Reseau_currentStep:=0;
      exit;
    end;
    //RefreshSpeed;
    Main_refreshNetSpeed;

    while true {client.GetMessage} do begin
      //RefreshSpeed;

      if (b1=253) then begin
        //ShowMessage('L''updater est en maintenance, veuillez r�essayer plus tard. D�sol� ><''');
        G_updaterMessage:='L''updater est en maintenance, veuillez r�essayer plus tard. D�sol� ><''';
        UpdateButtonCaption(Messages.StrActionActuelle, 'L''updater est en maintenance, veuillez r�essayer plus tard. D�sol� ><''');
        G_updaterState:=0;
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

        tailleATelechargerRestante := NeededFiles_totalSize - NeededFiles_receivedSizeTotal;
        //tailleATelechargerRestante_str := 'total=' + inttostr(NeededFiles_totalSize) + ' rcv=' + inttostr(NeededFiles_receivedSizeTotal);

        tailleATelechargerRestante := abs(tailleATelechargerRestante);
        tailleATelechargerRestante_str := inttostr(tailleATelechargerRestante) + 'o';
        if tailleATelechargerRestante < 1024 then
          tailleATelechargerRestante_str := inttostr(tailleATelechargerRestante) + 'o';
        if (tailleATelechargerRestante >= 1024) and (tailleATelechargerRestante < 1024*1024) then
          tailleATelechargerRestante_str := inttostr(trunc(tailleATelechargerRestante / 1024)) + 'ko';
        if (tailleATelechargerRestante >= 1024*1024) and (tailleATelechargerRestante < 1024*1024*1024) then
          tailleATelechargerRestante_str := inttostr(trunc(tailleATelechargerRestante / (1024*1024))) + 'mo';
        if (tailleATelechargerRestante >= 1024*1024*1024) then
          tailleATelechargerRestante_str := inttostr(trunc(tailleATelechargerRestante / (1024*1024*1024))) + 'go';


        // Affichage du nombre de fichiers
        UpdateButtonCaption(Messages.StrActionActuelle, 'Fichier '+inttostr(nbCurrent)+' sur '+inttostr(nbFinal)+' (reste ' + tailleATelechargerRestante_str + ')...');

        //UpdateButtonCaption(Messages.StrActionActuelle, 'Total  '+inttostr(trunc(NeededFiles_totalSize/(1024*1024)))+'  Rcved = '+inttostr(trunc(NeededFiles_receivedSizeTotal/(1024*1024))));



        if NeededFiles_totalSize <> 0 then
          progressionActuelle := NeededFiles_receivedSizeTotal / NeededFiles_totalSize
        else
          progressionActuelle := 0;

        UpdateProgressBar(trunc(progressionActuelle * 100), true); // (nbCurrent-1)/nbFinal*

        // NeededFiles_totalSize

        IsDownloading:=newState;
        if not IsDownloading then begin // suite juste apr�s la fin de la boucle while
          break;
        end;
      end;

      if not client.GetMessage then break;
      b1:=readubyte;  // pour l'it�ration suivante
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
  G_updaterState:=0;

  if success then begin
    progressBarPercent:=100;
    messageStr:=StrActionActuelle_defaultMessage; //'Appuyez sur "Jouer" pour lancer le jeu.';
    progressBarEnable:=true;
    G_JeuPretAEtreLance:=true;
  end else begin
    progressBarPercent:=0;
    messageStr:='�chec de la mise � jour.';
    progressBarEnable:=false;
    G_JeuPretAEtreLance:=false;
  end;

  UpdateButtonCaption(Messages.StrActionActuelle, messageStr);
  UpdateProgressBar(progressBarPercent, progressBarEnable);
  UpdateButtonEnabled(Messages.ButtonUninstall, true);
end;


procedure TGestionUpdater.AddAdressToTry(ip : string; port : word; putFirst : boolean = false; afficherMessageStr : string = ''); // ajout d'une adresse � essayer
var oldLen, newLen, i : cardinal;
begin
  oldLen := length(A1NetAddressToTry);
  newLen := oldLen + 1;
  SetLength(A1NetAddressToTry, newLen);
  if putFirst then begin
    if newLen <> 0 then // v�rif inutile
    for i := oldLen downto 1 do begin
      A1NetAddressToTry[i] := A1NetAddressToTry[i - 1];
    end;
    A1NetAddressToTry[0].Ip := ip; // record et non classe
    A1NetAddressToTry[0].Port := port;
    A1NetAddressToTry[0].StrToDraw := afficherMessageStr;
  end else begin
    A1NetAddressToTry[oldLen].Ip := ip; // record et non classe
    A1NetAddressToTry[oldLen].Port := port;
    A1NetAddressToTry[oldLen].StrToDraw := afficherMessageStr;
  end;

end;

function TGestionUpdater.GetNextAdressToTry(var outIP : string; var outPort : word; var outAddrGraphicName : string) : boolean; // false s'il n'y en a plus
begin
  Result := false;
  if not HasNextAdressToTry then exit;
  Result := true; // encore une adresse � essayer
  outIP := A1NetAddressToTry[NetAddress_currentTryIndex].Ip;
  outPort := A1NetAddressToTry[NetAddress_currentTryIndex].Port;
  outAddrGraphicName := A1NetAddressToTry[NetAddress_currentTryIndex].StrToDraw;
  NetAddress_currentTryIndex := NetAddress_currentTryIndex + 1;

end;

procedure TGestionUpdater.SetUnableToReachServer;
begin
  UpdateButtonCaption(Messages.StrActionActuelle, 'ERREUR : impossible de joindre le serveur.');
  UpdateButton(Messages.ButtonPlay, 'R�essayer', true);
  IsDownloading:=false;
  UpdateButtonEnabled(Messages.ButtonUninstall, true);
  G_updaterMessage:='ERREUR : impossible de joindre le serveur.';
  WaitForWelcomeMessage:=false;
  Reseau_currentStep:=0;
  G_updaterState:=-2; // impossible de se connecter au serveur
end;

function TGestionUpdater.HasNextAdressToTry : boolean; // true s'il reste une adresse � essayer, false sinon
begin
  if integer(NetAddress_currentTryIndex) >= length(A1NetAddressToTry) then begin // plus aucune adresse � essayer
    Result := false;
    exit;
  end;
  Result := true;
end;




end.
