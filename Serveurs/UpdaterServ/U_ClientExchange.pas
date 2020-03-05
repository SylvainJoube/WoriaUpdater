unit U_ClientExchange;

interface

uses U_Arrays, U_Sockets4, U_NetSys4, U_Files, U_StaticBuffer, SysUtils, math, U_ClientFiles, sockets, U_UpdaterServRapport;

type TDownloadClient = record
  Downloading : boolean; // Si le téléchargement est actif
  A1FileName : array of string; // Liste des fichiers à envoyer
  currentFileIndex : cardinal; // L'index du fichier dans lequel je me suis arrété
  currentFilePos : cardinal; // Ma position dans le fichier (position à laquelle je me suis arrété)
end;

// Version serveur updater
const UpdateServerVer = 5; // 4 -> 5 le 2018-11-10
const DownloadSizeMax = 110000; // 110ko max par envoi (le buffer de réception de U_Sockets4 fait 120ko, à ne pas dépasser ici). (avec dépassement possible pour le nom et la taille d'un nouveau fichier)

type TClient = class
  public
    SockE : TSocket;
    Id : cardinal;
    timerDeco : integer;
    serv_doNotDisconnectSock : boolean;
    download : TDownloadClient;
    procedure Download_sendPart;
end;


type downloadAction = (tySend, tyNextFile); // Actionn à effectuer après l'envoi d'une partie de fichier

var DownloadBuffer : array [0..DownloadSizeMax] of byte; // Et non FileBuffer pour éviter une violation d'accès du thread principal.



var A1Client : array of TClient;
procedure ClientLoop;
var serv : TTcpServer;
    clientId : cardinal = 0;
const G_timerDeco = 500*60; // 60 secondes : 1 Loop toutes les 2ms
//VersionServeur

// srv 1 réception de la connexion d'un client
// cli 2 réception de la version serveur des fichiers (envoyé par le serveur)
// cli 3 comparaison aux versions actuelles et envoi de la liste des fichiers à télécharger
// srv-cli : échanges, envoi des parties de fichiers du serveur au client.

procedure DisconnectAllClientsOnShutdown;

implementation
uses U_InitTcpNoDelay;

const MillisecTimeFactor = 100000000/1.157407677; //1.1575;///1.136;

//CheckForDiskUpdate
// En cas de mise à jour de fichiers, je recharge les fichiers du disque, et j'envoie aux client en cours de mise à jour de se réinitialiser

procedure UpdateFiles_sendToClients;
begin

end;

procedure DisconnectAllClientsOnShutdown;
var i, len : cardinal;
begin
  len:=length(A1Client);
  if len=0 then exit;
  mStart(253, 0);
  for i:=0 to len-1 do begin //A1Client[i].SockE.SendAllBuffers
    sendbuffer(A1Client[i].SockE);
    SendAllBuffers;
  end;
  sleep(1200);     
  for i:=0 to len-1 do begin //A1Client[i].SockE.SendAllBuffers
    A1Client[i].SockE.Destroy;
    A1Client[i].Destroy;
  end;
end;


procedure TClient.Download_sendPart;
var f : file;
    fPath: string;
    fsize : cardinal;
    sendSize : cardinal;
    sizeLeft : integer;
    i : cardinal;
    goNext : boolean;
begin
  // Envoie une partie des fichiers à télécharger
  if not self.download.Downloading then exit;
  FileMode:=fmOpenRead;
  sizeLeft:=DownloadSizeMax; // Taille max du buffer

  // J'utilise un buffer statique. Je ne pense pas qu'il soit nécessaire d'en implémenter un sur le client, il n'a qu'un seul téléchargement à effectuer.
  sb_mStart(4, 3);
  while sizeLeft>0 do begin
    if download.currentFileIndex>=cardinal(length(download.A1FileName)) then begin
      download.Downloading:=false; // fin de l'envoi
      download.currentFileIndex:=0;
      download.currentFilePos:=0;
      break; // Sortie
    end;
    fPath:=download.A1FileName[download.currentFileIndex]; // le nom complet depuis le répertoire current
    if not FileExists(fpath) then begin WriteLn('ERREUR TClient.Download_sendPart : fichier inexistant.'); exit; end; // Ne doit pas arriver
    AssignFile(f, fpath);
    Reset(f, 1); // Il est impossible qu'un autre client essaie d'accéder à ce fichier : il n'y a pas de multithread.
    fsize:=FileSize(f);
    if download.currentFilePos=0 then begin // nouveau fichier
      sb_writestring(fPath); // C'est pas optim de réenvoyer le nom, mais c'est pas grave. (négligeable devant la taille du fichier, <0.1)
      sb_writeuint(fsize);
    end;
    if download.currentFilePos>=fsize then begin // peut égaler fsize, et dans ce cas, je dis au client s'il y a un nouveau fichier ou non
      download.currentFileIndex:=download.currentFileIndex+1;
      download.currentFilePos:=0;
      CloseFile(f);
      goNext:=(sizeLeft>0) and (download.currentFileIndex<cardinal(length(download.A1FileName))); // vrai s'il reste de la place et que je ne suis pas à la fin de l'envoi, faux sinon.
      sb_writebool(goNext);
      //WriteLn('TClient.Download_sendPart fichier suivant, goNext='+booltostr(goNext)+', sizeLeft='+inttostr(sizeLeft));
      continue; // fichier suivant
    end;
    // Taille à envoyer
    sendSize:=min(integer(fsize)-integer(download.currentFilePos), sizeLeft); // sendSize est forcément non nul
    Seek(f, download.currentFilePos);
    //WriteLn('seek @ '+inttostr(download.currentFilePos));
    BlockRead(f, DownloadBuffer, sendSize);
    CloseFile(f);
    download.currentFilePos:=download.currentFilePos+sendSize;
    sizeLeft:=sizeLeft-integer(sendSize); // potentiellement nul
    sb_writeuint(sendSize);
    //WriteLn('TClient.Download_sendPart sendSize='+inttostr(sendSize));
    for i:=0 to sendSize-1 do // Copie du buffer du fichier dans le G_MainBuffer (même si niveau optim, c'est pas topissime)
      sb_writeubyte(DownloadBuffer[i]);
  end;
  //WriteLn('TClient.Download_sendPart Envoi de '+inttostr(DownloadSizeMax-sizeLeft)+' o');
  sb_writebool(download.Downloading); // Comme ça, le client sait s'il doit envoyer une requête pour avoir la suite.
  //WriteLn('TClient.Download_sendPart : demandeSUivant='+booltostr(download.Downloading, true));
  // Envoi
  sb_sendbuffer(socke.GetSocket);
  //WriteLn('TClient.Download_sendPart envoyé.');
end;


// Demande de la liste des fichiers du jeu
procedure Rcv4_1(client : TClient; clientIndex : cardinal);
begin
  mStart(4, 100);
  writeuint(UpdateServerVer);
  GameServer_addClientFilesList;
  //WriteLn('Rcv4_1 : buffSize = ' + inttostr(GetCurrentBufferSize));
  sendbuffer(client.SockE);
end;

// Demande des fichiers du jeu.
// Je pourrais éventuellement faire une création d'arhive threadée, mais c'est inutile, vu que je vais bientôt me passer de l'archive (pour directement accéder aux fichiers)
procedure Rcv4_2(client : TClient; clientIndex : cardinal);
var len, i, fIndex : cardinal;
    pf : TPClientFile;
begin
  len:=readushort;
  //WriteLn('RCV 4->2 len='+inttostr(len));
  if len=0 then exit;
  SetLength(client.download.A1FileName, len);
  client.download.Downloading:=false; // au cas où
  for i:=0 to len-1 do begin
    // je vais faire avec les index pas les Id
    fIndex:=readushort;
    pf:=GameServer_getClientFileFromIndex(fIndex);
    if pf=nil then begin
      WriteLn('Rcv4_2 pf fichier introuvable.');
      exit;
    end;
    client.download.A1FileName[i]:=pf^.Dir+'\'+pf^.Name;
    //WriteLn('Rcv4_2 demande de '+inttostr(fid)+' '+client.download.A1FileName[i]);
  end;
  client.download.currentFileIndex:=0;
  client.download.currentFilePos:=0;
  client.download.Downloading:=true;
  // Envoi du premier paquet
  client.Download_sendPart;
end;

// Envoi d'un nouveat paquet
procedure Rcv4_3(client : TClient; clientIndex : cardinal);
begin
  client.Download_sendPart;
end;

procedure Rcv5_1(client : TClient; clientIndex : cardinal);
var errorMsg : string;
begin
  errorMsg:=readstring;
  WriteLn('Erreur client '+inttostr(client.Id)+' : '+errorMsg);
end;


function AddClient(sock : TTcpClient; decoTimer : cardinal) : TClient;
var len : cardinal;
begin
  //noDelaySock(sock);
  //Sock_SetBigBuffer(sock);
  Result:=TClient.Create;
  len:=length(A1Client);
  SetLength(A1Client, len+1);
  A1Client[len]:=Result;
  Result.SockE:=TSocket.Create(sock, true);
  Result.Id:=clientId;
  Result.timerDeco:=decoTimer;
  Result.serv_doNotDisconnectSock:=false;
  clientId:=clientId+1;
end;
procedure clientDisconnect(index : cardinal; freeSock : boolean);
var client : TClient;
begin
  client:=A1Client[index];
  if freeSock then client.SockE.Stop;
  ObjectArrayDelete(@A1Client, index);
  client.Destroy;
  // Le client.Destroy n'affecte pas le thread et le socket (ils continuent de tourner et sont arrêtés via le TSocketThread)
end;



procedure ClientLoop;
var i : cardinal;
    sockE : TSocket;
    client : TClient;
    b1, b2 : byte;
    disconnect : boolean;
    sock : TTcpClient;
    //t1 : int64; test vitesse réception (réinitialisation du buffer de réception)
begin
  // ###### Nouveau client connecté ######
  try
    sock:=TTcpClient.Create(nil);
    if serv.Accept(TCustomIpClient(sock)) then begin
      client:=AddClient(sock, G_timerDeco);
      WriteLn('Nouveau client : ' + IntToStr(client.Id)+' '+string(client.SockE.GetSocket.RemoteHost));
      //sleep(1);
      mStart(1, 1);
      //writeubyte(VersionServeur);
      sendbuffer(client.SockE);
    end else sock.Free;
  except WriteLn('GRAVE ClientLoop : acceptation de client : exception.'); end;

  // ###### Gestion des clients ######
  //t1:=trunc(now*MillisecTimeFactor);
  i:=0;
  while i<cardinal(length(A1Client)) do begin
    try
      client:=A1Client[i];
      try
        client.timerDeco:=client.timerDeco-1;
        if (client.timerDeco<=0) or (not client.sockE.StillThere) then begin
          clientDisconnect(i, true);
          //WriteLn('Deco cli : '+inttostr(i));
          continue;
        end;

        disconnect:=false; // déconnecter depuis un message reçu (entrée en jeu par ex)
        sockE:=client.SockE;
        sock:=socke.GetSocket;


        if socke.GetMessage then begin // Un message a été reçu
          client.timerDeco:=G_timerDeco;
          b1:=readubyte;
          b2:=readubyte;
          //WriteLn('RCV cli : '+inttostr(b1)+'->'+inttostr(b2));
          if (b1=4) and (b2=1) then Rcv4_1(client, i);   // Demande de la liste des fichiers
          if (b1=4) and (b2=2) then Rcv4_2(client, i);   // Envoi des fichiers nécessaires
          if (b1=4) and (b2=3) then Rcv4_3(client, i);   // Demande d'envoi d'un paquet
          if (b1=5) and (b2=1) then Rcv5_1(client, i);   // Message d'erreur
        end;
        if not disconnect then i:=i+1;
      except
        WriteLn('GRAVE ClientLoop : client['+inttostr(i)+'] : exception, suppressuin manuelle du client sans détruire le socket.');
        ObjectArrayDelete(@A1Client, i);
      end;
    except WriteLn('GRAVE ClientLoop : client['+inttostr(i)+'] : exception.'); end;
    //WriteLn('Tc'+inttostr(client.Id)+'='+inttostr((trunc(now*MillisecTimeFactor)-t1)));
  end;
  //WriteLn('Tt='+inttostr((trunc(now*MillisecTimeFactor)-t1)));
end;









end.
