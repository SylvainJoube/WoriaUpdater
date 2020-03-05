unit U_Sockets4;

interface
uses Windows, SysUtils, Classes, WinSock, Sockets, math, U_Arrays;

const MillisecTimeFactor = 100000000/1.157407677; //1.1575;///1.136;
const G_ShowSocketLog = false;
const G_SocketMemoryMaxSize = 200000; // 200ko de buffer max
const G_SocketMemoryMaxSendSize = 80000; // 80ko de buffer d'envoi (carte etc.)
const G_SocketMemoryMaxRcvSize = 12000; // 12ko max de réception

type TBuffer = array [0..1023] of byte;
     TFreeSizeBuffer = array of byte;

var Debug_objectBufferId : cardinal;

type TObjectBuffer = class
  public
    NeededSize : cardinal; // Pour la réception  threadée des données (je le remplis jusqu'à avoir atteint ce nombre)
    Buf : TFreeSizeBuffer;
    BuffPos : integer; // Initialisé à 0
    WillBeSent : boolean; // S'il ne va pas être envoyé, alors je peux le supprimer lors du freebuffer.

    //tru : array [0..10000000] of byte; // Débug.
    //Id : cardinal; // Débug.
    constructor Create(enableLog : boolean = false); virtual;
    destructor Destroy; override;
    function IncSize(nb : byte = 1) : cardinal;
    function IncPos(nb : byte = 1) : cardinal;
    function Get(offset : byte = 0) : byte;
    procedure Put(data : byte; pos : cardinal);
    // Utilitaitres de modification du buffer
    procedure SetPos(newBuffPos : cardinal);
    procedure SetSize(newSize : cardinal);
end;

var G_MainBuffer : TObjectBuffer; // Buffer d'envoi principal.


//const Socket_LengthA2Buffer = 1000;
//const Socket_LengthRcvBuffer = 1000000;
// /!\ Plus le buffer de réception est grand, plus la réception prend du temps
const Socket_SendBuffLength = 120000;
var SockSendBuff : array [0..Socket_SendBuffLength-1] of byte;
const Socket_RcvBuffLength = 200; // Le buffer de réception peut très bien être petit
var SockRcvBuff : array [0..Socket_RcvBuffLength-1] of byte;
// Buffer de réception pour le client, seulement (quand il y a peu de répection à faire)
const Socket_RcvBuffLength_onlyClientApp = 120000; // Le buffer de réception peut très bien être petit
var SockRcvBuff_onlyClientApp : array [0..Socket_RcvBuffLength_onlyClientApp-1] of byte;

type tySockAppType = (tyAppServer, tyAppClient, tyAppRaw); // tyAppRaw : application n'étant si un client Woria, ni un serveur Woria
var AppType : tySockAppType = tyAppServer; // par défaut, application serveur
procedure SetAppType(arg_appType : tySockAppType);

type TSnd_messageGroup = class
  public
    Snd_A1Buff : array of TObjectBuffer; // Les buffers de cet objet à envoyer
    Snd_doitEnvoyer : boolean; // Le thread du socket n'y touche pas si ce n'est pas à envoyer.
end;
// TYPE TSocket
type TSocket = class
  private
    //A2Buffer : array [0..Socket_LengthA2Buffer-1] of TObjectBuffer; // Buffers prêts pour la lecture.
    //PutNextRcvBufferPos : cardinal; // Pour le thread, position du prochain message. (dans A2Buffer)
    //ReadNextRcvBufferPos : cardinal; // La position du buffer suivant : si c'est nil, c'est qu'il n'y a rien à recevoir.
    // Si je suis à la pos Socket_LengthA1Buffer, c'est que je dois aller à la pos 0. (boucle)
    //Thread : TSocketThread;
    INVALID_SOCKET : boolean; // si, une erreur grave s'est produite dans le socket, je ne peux plus l'utiliser
    ShowSpeed_download, ShowSpeed_upload : int64; // pour la multiplication
    DownloadedTotal, UploadedTotal : int64;
    ShowSpeed_lastTime : int64; // Now*10^8 (ne pas oublier la multiplication par MillisecTimeFactor)  
    ShowSpeed_startTime, ShowSpeed_startDownload, ShowSpeed_startUpload : int64;
    LogFilePath : string;
    LogFile : TextFile;
    EnableLog : boolean;
    // Architecture non threadée
    A1SendBuffer : array of TObjectBuffer; // Buffers à envoyer
    A1ReceivedBuffer : array of TObjectBuffer; // Buffers reçu, prêts à être lus
    ReceivingBuffer : TObjectBuffer;
    ReceivingBuffer_finalSize : cardinal; // Taille finale du buffer
    ReceivingBuffer_currentSize : cardinal; // Position où je suis dans le buffer
    Sock : TTcpClient;
    // Octets restants de la dernière réception, si je n'ai pas pu lire la taille du prochain buffer (4 octets)
    A1OrphanByte : array of byte;
    Memory_maxSize, Memory_maxRcvSize, Memory_maxSendSize : cardinal; // taille maximale occupée par la totalité des buffers
    Memory_enableControl : boolean; // contrôle de la mémoire
    Memory_willBeDestroyed : boolean; // dépassement de la limite de la mémoire, déconnexion et destruction
    CurrentRcvPos : integer; // Utile lors du GetMessage : position dans le buffer de réception. Un nombre n'gatif indique que je dois liste dans A1OrphanByte
    Memory_notYetInBufferSize : integer; // Taille pas encore mise dans un buffer fini
    Memory_lastRcvSize : int64;
    function GetRcvByte : byte;
  public
    //A1SendBuffers : array of TObjectBuffer; // Les buffers à envoyer. PS : voir si ça marche quand-même si j'envoie un buffer en même temps que je reçois les données du socket. Je vais l'envoyer du thread.
    //A2SendBuffer : array [0..Socket_LengthA2Buffer-1] of TSocket_sendBuffer;
    //PutNextSendBufferPos, ReadNextSendBufferPos : cardinal; // PutNextSendBufferPos pour le socket et ReadNextSendBufferPos pour le thread.
    DownloadSpeed, UploadSpeed : cardinal; // vitesse de la connexion (publique)
    NbEnvoiEchec : cardinal;
    StillThere : boolean;
    hasToDestroy_fromSocket : boolean; // Pour savoir qui a demandé l'arrêt du thread et du socket.
    Destroy_calledFromThread : boolean;
    constructor Create(sock : TTcpClient; enableLog : boolean = false); virtual;
    constructor CreateAndConnect(const ip : string; const port : word; useBigBuffer : boolean = false; setNoDelay : boolean = false; isActive : boolean = true); virtual;
    procedure CreateInitialize(sock : TTcpClient; enableLog : boolean = false);
    procedure Stop; // /!\ Utiliser cette procédure pour détruire le socket.
    destructor Destroy; override;
    //procedure ThreadAddMessage(buff : TObjectBuffer); // Un nouveau message est prêt, je l'ajoute à A2Buffer.
    function GetMessage : boolean; // Met le nouveau buffer en buffer principal.
    //function MessageExists : boolean; // Pour la rétro-compatibilité
    function GetSocket : TTcpClient;
    procedure AddSendBuffer(buff : TObjectBuffer);
    procedure SendAllBuffers;
    procedure Free; virtual;
    procedure GetRcvSentSize(var rcvSize, sndSize : cardinal);
    procedure GetRcvSentTotalSize(var rcvSize, sndSize : cardinal);
    procedure GetRcvSentTotalMedian(var moyenneRecu, moyenneEmis : cardinal); 
    procedure GetError(Sender: TObject; SocketError: Integer);
    function GetRcvFinalSize : cardinal;
    function GetRcvCurrentSize : cardinal;
    procedure RenewNetSpeed(resetGlobalMoySpeed : boolean = false);
    procedure WriteLog(text : string);
    procedure Memory_setMaxSize(maxSize : cardinal); // taille maximale occupée par la totalité des buffers
    function Memory_getTotalSizeUsed : cardinal;
    function Memory_getRcvSizeUsed : cardinal;
    function Memory_getSendSizeUsed : cardinal;
    function Memory_isOverloaded : boolean;
    procedure SetNoDelay;
    procedure SetBigBuffer(bufferSize : integer = 20971520);
    function GetRemoteHost : string;
    {StillThere : boolean;
    SendBuffer : array of byte; // Buffer réservé à l'envoi.
    BufferPos : cardinal;
    NbEnvoiEchec : cardinal;
    procedure Receive; // Appelée avec socket.Receive;
    function MessageExists : boolean;
    function GetMessageNumber : integer;
    procedure GetMessage(ObjBuf : TObjectBuffer);
    function GetSocket : TTcpClient;

    function StartAccess : boolean;
    procedure StopAccess;}
end;

type TSocket_server = class
  private
    ServSock : TTcpServer;
  public
    constructor Create(port : word);
    function Initialize(port : word) : boolean;
    function IsActive : boolean;
    function Accept(enableLog : boolean = false) : TSocket; // nil s'il n'y a personne à accepter

end;
//Déclaration de variables communes aux sockets.
//const LargeBufferSize = 20000000;//   ~2Mo
//var CommonLargeBuffer : array [0..LargeBufferSize] of byte; // 2Mo de buffer commun.
//var G_IsServer : boolean;

function GetCurrentMsTime : int64;
// Joue aussi le rôle de U_InitTcpNoDelay
//procedure nodelaySock(sock : TCustomIpClient);
//procedure Sock_setNoDelay(sock : TCustomIpClient);
//procedure modifySockType(sock : TClientSocket);
//procedure Sock_SetBigBuffer(sock : TCustomIpClient; sizeValue : integer = 20971520);

implementation
uses U_Files, U_NetSys4;
//const MillisecTimeFactor = 100000000/1.157407677; //1.1575;///1.136;
//const TimeFactor = 1/1.157407677; //1.1575;///1.136;
//uses U_netSys3;

function GetCurrentMsTime : int64;
begin
  Result:=trunc(now*MillisecTimeFactor);
end;

procedure SetAppType(arg_appType : tySockAppType);
begin
  AppType:=arg_appType;
end;

// Un thread se charge de la destruction des sockets et threads inutilisés.
// Parce qu'il est impossible de détruire un thread depuis sa boucle Execute.
// Ce thread a ds listes dans lesquelles je mets les objets é détruire.
type TDestroySockThread = class (TThread)
  public
    Stop, Stopped : boolean;
    InUse : boolean; // Pour ne pas autoriser l'accès coucourrent.
    A1Sockets : array of TSocket; // Tous les sockets é détruire (Si TSocket.Destroy : alors je n'ajoute que le thread) Préférer TSocket.Stop;
    // Execute est exécuté une fois toutes les 100ms. (pour être sur de ne pas bloquer outrancièrement via InUse)
    procedure Execute; override;
    procedure AddSocket(sock : TSocket);
    procedure GetAccess;
    procedure ReleaseAccess;
end;

var DestroySockThread : TDestroySockThread; // Initialisation dans TSocket.Create (si inexistant)

procedure TDestroySockThread.Execute;
var len, i : cardinal;
begin
  Stop:=false;
  Stopped:=false;
  while not Stop do begin
    // J'essaie d'accéder aux objets à détruire
    GetAccess;
    // Destruction des sockets
    len:=Length(A1Sockets);
    //if len<>0 then WriteLn('Destruction de '+inttostr(len)+' socket(s).');
    if len<>0 then for i:=0 to len-1 do begin
      A1Sockets[i].Destroy_calledFromThread:=true;
      A1Sockets[i].Destroy;
    end;
    SetLength(A1Sockets, 0);
    ReleaseAccess;
    //WriteLn('TDestroySockThread.Execute');
    sleep(100);
  end;
  Stopped:=true;
end;

procedure TDestroySockThread.GetAccess;
begin
  while InUse do
    sleep(1);
  InUse:=true;
end;
procedure TDestroySockThread.ReleaseAccess; // Seulement après GetAccess.
begin
  InUse:=false;
end;
procedure TDestroySockThread.AddSocket(sock : TSocket);
var len : cardinal;
begin
  GetAccess;
  len:=length(A1Sockets);
  SetLength(A1Sockets, len+1);
  A1Sockets[len]:=sock;
  ReleaseAccess;
end;

// TObjectBuffer +
constructor TObjectBuffer.Create;
//var len, i : cardinal;
begin inherited Create;
  BuffPos:=0;
  WillBeSent:=false; // Pas encore à envoyer.
  {Id:=Debug_objectBufferId;
  Debug_objectBufferId:=Debug_objectBufferId+1;
  len:=length(A1CreatedBuffer);
  //WriteLn('BUFFER CREATE ID '+inttostr(Id));
  Write('ALIVE BUFFERS '+inttostr(len));
  if len<>0 then for i:=0 to len-1 do
    Write(' '+inttostr(A1CreatedBuffer[i].Id));
  writeln;
  SetLength(A1CreatedBuffer, len+1);
  A1CreatedBuffer[len]:=self;}
end;
destructor TObjectBuffer.Destroy;
begin
  //ObjectArrayDeleteFromValue(@A1CreatedBuffer, self);
  //WriteLn('BUFFER DESTR. ID '+inttostr(Id));
  inherited;
end;


function TObjectBuffer.IncSize(nb : byte = 1) : cardinal;
var len : cardinal;
begin
  len:=Length(self.Buf);
  SetLength(self.Buf, len+nb);
  result:=len;
end;
function TObjectBuffer.IncPos(nb : byte = 1) : cardinal; begin
  result:=self.BuffPos;
  self.BuffPos:=self.BuffPos+nb;
end;
function TObjectBuffer.Get(offset : byte = 0) : byte; begin
  Result:=self.Buf[self.BuffPos+offset]
end;
procedure TObjectBuffer.Put(data : byte; pos : cardinal); begin
  self.Buf[pos]:=data;
end;
procedure TObjectBuffer.SetPos(newBuffPos : cardinal); begin
  self.BuffPos:=newBuffPos;
end;
procedure TObjectBuffer.SetSize(newSize : cardinal);
begin
  SetLength(self.Buf, newSize);
end;
// TObjectBuffer -

procedure TSocket.CreateInitialize(sock : TTcpClient; enableLog : boolean = false);
begin
  if DestroySockThread=nil then DestroySockThread:=TDestroySockThread.Create(false);
  self.Sock:=sock;
  INVALID_SOCKET:=false;
  sock.OnError:=GetError;
  StillThere:=true;
  ShowSpeed_download:=0; // total téléchargé
  ShowSpeed_upload:=0;   // total émis
  DownloadedTotal:=0;
  UploadedTotal:=0;
  ShowSpeed_lastTime:=trunc(Now*MillisecTimeFactor);
  ShowSpeed_startTime:=GetCurrentMsTime;
  ShowSpeed_startDownload:=0;
  ShowSpeed_startUpload:=0;
  Memory_lastRcvSize:=0;

  if AppType=tyAppServer then begin
    Memory_enableControl:=true;
    Memory_maxSize:=G_SocketMemoryMaxSize;
    Memory_notYetInBufferSize:=0;
    Memory_maxSendSize:=G_SocketMemoryMaxSendSize;
    Memory_maxRcvSize:=G_SocketMemoryMaxRcvSize;
    //WriteLn('TSocket.Create : AppServer !');
  end else Memory_enableControl:=false;


  if enableLog then begin
    self.EnableLog:=true;
    try
      if not directoryExists('C:\Woria_debug\socket\_Log') then ForceDirectories('C:\Woria_debug\socket\_Log');
      self.LogFilePath:='C:\Woria_debug\socket\_Log\Log_Socket'+inttostr(sock.Handle)+'_'+inttostr(trunc(Now*power(10, 8)))+'.txt';
      if fileExists(LogFilePath) then DeleteFile(LogFilePath);
      AssignFile(LogFile, LogFilePath);
      ReWrite(LogFile);
      WriteLn(LogFile, 'Fichier log du socket '+inttostr(sock.Handle)+'.');
    except
    end;
  end;
end;
//TSocket.Create
constructor TSocket.Create(sock : TTcpClient; enableLog : boolean = false);
begin
  inherited Create;
  CreateInitialize(sock, enableLog);
end;
constructor TSocket.CreateAndConnect(const ip : string; const port : word; useBigBuffer : boolean = false; setNoDelay : boolean = false; isActive : boolean = true);
var localClient : TTcpClient;
begin
  inherited Create;
  //WriteLn('TSocket.CreateAndConnect');
  localClient := TTcpClient.Create(nil);
  localClient.RemoteHost := ip;
  localClient.RemotePort := inttostr(port);
  localClient.BlockMode := bmNonBlocking;
  CreateInitialize(localClient);
  if isActive then localClient.Active:=true;
  if useBigBuffer then self.setBigBuffer;//Sock_SetBigBuffer(localClient);
  if setNoDelay then self.setNoDelay;
  //WriteLn('TSocket.CreateAndConnect FINI');
end;
//TSocket.Destroy
destructor TSocket.Destroy; // Préférer utiliser Stop que Destroy. (Stop est non bloquant alors que destroy l'est)
var i, len : cardinal;
begin
  try
    // Destruction de ses buffers de récéption et d'envoi
    if ReceivingBuffer<>nil then ReceivingBuffer.Destroy;
    len:=length(A1SendBuffer);
    if len<>0 then for i:=0 to len-1 do A1SendBuffer[i].Destroy;
    SetLength(A1SendBuffer, 0);
    len:=length(A1ReceivedBuffer);
    if len<>0 then for i:=0 to len-1 do A1ReceivedBuffer[i].Destroy;
    SetLength(A1ReceivedBuffer, 0);
    // fermeture et destrcution du socket, s'il existe (nouveau, peut buger)
    try
    if self.Sock<>nil then begin
      try
        self.Sock.Destroy; // prend en charge la fermeture du socket (via TBaseSocket.Close, aussi appelé par TTcpClient.Disconnect)
      except WriteLn('EXCEPTION TSocket.Destroy : sock.Destroy échoué.'); end;
      //if self.sock.Connected then self.sock.Disconnect;
    end;
    except
      if enableLog then WriteLn(LogFile, 'ERREUR : self.Sock<>nil mais erreur à self.sock.Destroy.');
    end;
    if enableLog then CloseFile(LogFile);
  except
     WriteLn('EXCEPTION TSocket.Destroy (erreur inconnue)');
  end;
  inherited Destroy;
end;
//TSocket.WriteLog
procedure TSocket.WriteLog(text : string);
begin
  if not enableLog then exit;
  try WriteLn(LogFile, text);
  except end;
end;

function TSocket.GetRcvByte : byte; // Lit l'octet en position CurrentRcvPos
begin
  if CurrentRcvPos<0 then begin
    Result:=A1OrphanByte[0];
    // Et Je vire cette valeur
    ByteArrayDelete(@A1OrphanByte, 0);
    CurrentRcvPos:=CurrentRcvPos+1;
    exit;
  end;
  // CurrentRcvPos>=0

  if AppType=tyAppServer then // le client reçoit un buffer plus large que le serveur (pour alléger le serveur, par souci de rapidité)
       Result:=SockRcvBuff[CurrentRcvPos]
  else Result:=SockRcvBuff_onlyClientApp[CurrentRcvPos];
  CurrentRcvPos:=CurrentRcvPos+1;
end;

//TSocket.GetMessage
function TSocket.GetMessage : boolean;
var len, i : cardinal;
    receivedSize, sizePut, left : integer;
    A1Left : array of byte;
    A1Size : array [0..3] of byte;
    //tDebugBuff : TObjectBuffer;
    totalRcvSize : cardinal;
    //rcvStr : string;
    //tb : byte;
begin
  Result:=false;
  if INVALID_SOCKET then begin
    StillThere:=false;
    exit;
  end;
              
  {if sock=nil then exit;
  if not StillThere then exit;
  receivedSize:=sock.ReceiveBuf(SockRcvBuff_onlyClientApp, Socket_RcvBuffLength_onlyClientApp);
  if receivedSize>0 then begin
    rcvStr:='';
    //WriteLn('receivedSize='+inttostr(receivedSize));
    for i:=0 to receivedSize-1 do begin
      tb:=SockRcvBuff_onlyClientApp[i];
      rcvStr:=rcvStr+chr(tb);
      //if (tb>=32) then rcvStr:=rcvStr+chr(tb)
      //                          else rcvStr:=rcvStr+'_';
    end;
    WriteLn('-------------- RECU --------------');
    WriteLn(rcvStr);  
    WriteLn('--------------      --------------');
    freebuffer;
    writestring(rcvStr);
    WriteBufferToFile('C:\Users\admin\Desktop\Woria Alpha\Champis Laura\sockheader.txt', true);
    Result:=true;
  end;
  exit;}

  try
    if sock=nil then exit;
    if not StillThere then exit;
    // Architecture non threadée
    //A1ReceivedBuffer : array of TObjectBuffer; // Buffers reçu, prêts à être lus
    //A1OrphanBytes : array of byte; // Octets restants de la dernière réception, si je n'ai pas pu lire la taille du prochain buffer (4 octets)
    //ReceivingBuffer : TObjectBuffer;
    // Réception des nouveaux messages
    CurrentRcvPos:=-length(A1OrphanByte);
    //WriteLn('CurrentRcvPos='+inttostr(CurrentRcvPos));
    if AppType=tyAppServer then
         receivedSize:=sock.ReceiveBuf(SockRcvBuff, Socket_RcvBuffLength)
    else receivedSize:=sock.ReceiveBuf(SockRcvBuff_onlyClientApp, Socket_RcvBuffLength_onlyClientApp);


    // Calcul de l'espace non encore mis dans un buffer
    Memory_notYetInBufferSize:=Memory_notYetInBufferSize+(int64(sock.BytesReceived)-Memory_lastRcvSize);
    Memory_lastRcvSize:=sock.BytesReceived;

    //Memory_notYetInBufferSize:=Memory_notYetInBufferSize+newLyReceivedSize;
    //WriteLn('TSocket.GetMessage : Memory_notYetInBufferSize='+inttostr(Memory_notYetInBufferSize));
    if Memory_enableControl then begin
      totalRcvSize:=Memory_getRcvSizeUsed+cardinal(max(0, Memory_notYetInBufferSize));
      //if totalRcvSize>100 then
        //WriteLn('TSocket.GetMessage : totalRcvSize='+inttostr(totalRcvSize));
      if totalRcvSize>=Memory_maxRcvSize then begin
        Memory_willBeDestroyed:=true;
        StillThere:=false;
        //WriteLn('TSocket.GetMessage : dépassement de la limite mémoire. totalRcvSize='+inttostr(totalRcvSize));
        //WriteLn('TSocket.GetMessage : dépassement de la limite mémoire. Memory_getRcvSizeUsed='+inttostr(Memory_getRcvSizeUsed));
        //WriteLn('TSocket.GetMessage : dépassement de la limite mémoire. Memory_notYetInBufferSize='+inttostr(Memory_notYetInBufferSize));
        //Stop;
        exit;
      end;
      if Memory_getSendSizeUsed>=Memory_maxSendSize then begin
        Memory_willBeDestroyed:=true;
        StillThere:=false;
        //WriteLn('TSocket.GetMessage : dépassement de la limite mémoire. Memory_maxSendSize='+inttostr(Memory_maxSendSize));
        exit;
      end;
    end;

    if enableLog then if receivedSize>0 then //débug
      WriteLog('TSocket.GetMessage : receivedSize='+inttostr(receivedSize));

    if receivedSize>0 then begin
      ShowSpeed_download:=ShowSpeed_download+cardinal(receivedSize);
      DownloadedTotal:=DownloadedTotal+cardinal(receivedSize);
    end;
    RenewNetSpeed;
  

    if receivedSize>0 then while CurrentRcvPos<receivedSize do begin // -2<0
      //WriteLn('Iteration CurrentRcvPos<receivedSize');
      // Si le buffer de réception est non nil et a besoin de données. J'attribue dès le départ sa taille au buffer.
      if ReceivingBuffer<>nil then begin
        sizePut:=min(ReceivingBuffer_finalSize-ReceivingBuffer_currentSize, receivedSize-CurrentRcvPos); // Taille restante : receivedSize-CurrentRcvPos
        if enableLog then WriteLog('GetMessage : non nil  sizePut='+inttostr(sizePut));
        // J'ajoute les octets au buffer
        if sizePut<>0 then for i:=0 to sizePut-1 do begin // sizePut<>0 normalement
          //WriteLn('sizePut='+inttostr(sizePut)+' lenBuff='+inttostr(length(ReceivingBuffer.Buf))+' ReceivingBuffer_currentSize='+inttostr(ReceivingBuffer_currentSize));
          ReceivingBuffer.Buf[ReceivingBuffer_currentSize]:=self.GetRcvByte; // Ajout de l'octet
          ReceivingBuffer_currentSize:=ReceivingBuffer_currentSize+1;
        end;
        // Si j'ai fini sa réception, j'ajoute ce buffer à la liste des buffers reçus
        if ReceivingBuffer_finalSize=ReceivingBuffer_currentSize then begin
          len:=length(A1ReceivedBuffer);
          SetLength(A1ReceivedBuffer, len+1);
          A1ReceivedBuffer[len]:=ReceivingBuffer;
          ReceivingBuffer:=nil; // Inutile de réinit les autres variables
          Memory_notYetInBufferSize:=Memory_notYetInBufferSize-integer(ReceivingBuffer_finalSize)-4; // 4 : les 4 octets qui indiquent la taille finale du buffer
        end;
        if receivedSize-CurrentRcvPos=0 then break; // Plus rien à recevoir
      end;

      if ReceivingBuffer=nil then begin // S'il n'y a pas de buffer en cours
        // Si j'ai 4 octets devant moi, je crée un nouveau buffer. Dans le cas contraire, j'ajoute les octets à A1OrphanByte
        left:=receivedSize-CurrentRcvPos;
        if enableLog then WriteLog('GetMessage : nil  left='+inttostr(left));
        if left=0 then break; // Plus rien à recevoir (A1OrphanByte a été précédement mis à jour via GetRcvByte)
        if left<4 then begin
          setlength(A1Left, left);
          for i:=0 to left-1 do A1Left[i]:=GetRcvByte; // Au cas où le tableau A1OrphanByte serait utilisé
          setLength(A1OrphanByte, left);
          for i:=0 to left-1 do A1OrphanByte[i]:=A1Left[i];
          CurrentRcvPos:=CurrentRcvPos+left;
          break; // Plus rien à recevoir
        end;
        // ici left>=4, je peux recevoir la taille du buffer
        for i:=0 to 3 do A1Size[i]:=GetRcvByte; // Pour utiliser les octets dans le bon ordre (je n'ai aucune garantie de l'odre le traîtement des procédures dans une addition)
        ReceivingBuffer_finalSize:=A1Size[0]+A1Size[1]*256+A1Size[2]*65536+A1Size[3]*16777216;
        // CurrentRcvPos:=CurrentRcvPos+4 est implicite à GetRcvByte.
        ReceivingBuffer_currentSize:=0;
        if enableLog then WriteLog('ReceivingBuffer_finalSize='+inttostr(ReceivingBuffer_finalSize));
        ReceivingBuffer:=TObjectBuffer.Create;
        //WriteLog('U_Sockets4 - ReceivingBuffer_finalSize='+inttostr(ReceivingBuffer_finalSize));
        if Memory_enableControl then
        if ReceivingBuffer_finalSize>=Memory_maxSize then begin
          WriteLn('ERREUR TSocket.GetMessage ReceivingBuffer_finalSize>=Memory_maxSize (finalSize='+inttostr(ReceivingBuffer_finalSize)+')');
          self.INVALID_SOCKET:=true;
          exit;
        end;
        SetLength(ReceivingBuffer.Buf, ReceivingBuffer_finalSize); // Si ReceivingBuffer_finalSize pas trop grand
        // Et je vais à l'itération suivante : ReceivingBuffer<>nil
        {WriteLn('receivedSize-CurrentRcvPos='+inttostr(receivedSize-CurrentRcvPos));
        WriteLn('receivedSize='+inttostr(receivedSize));
        WriteLn('CurrentRcvPos='+inttostr(CurrentRcvPos));}
      end;
    end;

    // Message éventuellement prêt :
    len:=length(A1ReceivedBuffer);
    Result:=(len<>0);
    if len=0 then exit;

    // ---debug
    {tDebugBuff:=A1ReceivedBuffer[0];
    if debufFull then begin
      WriteLog('len(A1ReceivedBuffer)='+inttostr(len));
      WriteLog('Premier message b0='+inttostr(tDebugBuff.Buf[0])+' b1='+inttostr(tDebugBuff.Buf[1])+' taille='+inttostr(length(tDebugBuff.Buf)));
      if (tDebugBuff.Buf[0]=3) and (tDebugBuff.Buf[1]=1) then
        WriteLog('   ---b2='+inttostr(tDebugBuff.Buf[2])+' b3='+inttostr(tDebugBuff.Buf[3]));
    end;}
    // debug---
    // même structure des buffers, pourtant l'un passe inaperçu.

    if G_MainBuffer<>nil then if not G_MainBuffer.WillBeSent then G_MainBuffer.Destroy;
    G_MainBuffer:=A1ReceivedBuffer[0];
    ObjectArrayDelete(@A1ReceivedBuffer, 0);
    if enableLog then WriteLog('Message reçu, taille='+inttostr(length(G_MainBuffer.Buf)));
  except
  WriteLn('GRAVE TSocket.GetMessage : EXCEPTION.');
    try
      WriteLn('GRAVE : TSocket.GetMessage EXCEPTION : remoteHost : '+Sock.RemoteHost);
    except
      WriteLn('GRAVE (2) : TSocket.GetMessage EXCEPTION : remoteHost IMPOSSIBLE A LIRE.');
    end;
  end;
end;

function TSocket.GetSocket : TTcpClient; begin
  result:=self.Sock;
end;

procedure TSocket.Stop; begin
  DestroySockThread.AddSocket(self);
  //WriteLn('TSocket.Stop');
end;

// Ajout d'un nouveau message à la liste d'envoi des messages.
procedure TSocket.AddSendBuffer(buff : TObjectBuffer);
var len : cardinal;
begin
  buff.WillBeSent:=true;
  len:=length(A1SendBuffer);
  SetLength(A1SendBuffer, len+1);
  A1SendBuffer[len]:=buff;
end;
procedure TSocket.SendAllBuffers;
var i, ii, len, buffSize, cPos, newTotalSize, maxSockBufferSize : cardinal;
    stoppedAtBufferIndex : integer;
    bu : TObjectBuffer;
begin
  try
    if not StillThere then exit;
    if self.Memory_enableControl then
    if Memory_getSendSizeUsed>=Memory_maxSendSize then begin
      Memory_willBeDestroyed:=true;
      StillThere:=false;
      //WriteLn('TSocket.SendAllBuffers : dépassement de la limite mémoire. Memory_maxSendSize='+inttostr(Memory_maxSendSize));
      //Stop;
      exit;
    end;
    maxSockBufferSize:=length(SockSendBuff);
    stoppedAtBufferIndex:=-1;

    // Vérifier à ne pas dépasser la taille d'envoi maximale

    // Je mets tous les buffers dans le buffer commun et j'envoie.
    len:=length(A1SendBuffer);
    //WriteLn('SendAllBuffers A1SendBuffer len='+inttostr(len));
    if len=0 then exit;
    cPos:=0; // Pos dans le buffer principal
    for i:=0 to len-1 do begin
      bu:=A1SendBuffer[i];
      buffSize:=length(bu.Buf);
      newTotalSize:=cPos+buffSize+4;
      if newTotalSize>=maxSockBufferSize then break;
      stoppedAtBufferIndex:=i; // incrémentation à chaque buffer ok
      if buffSize<>0 then begin
        // J'écris la taille du buffer
        SockSendBuff[cPos+3]:=trunc(buffSize/16777216);
        SockSendBuff[cPos+2]:=trunc(buffSize/65536) - SockSendBuff[cPos+3]*256;
        SockSendBuff[cPos+1]:=trunc(buffSize/256) - SockSendBuff[cPos+3]*65536 - SockSendBuff[cPos+2]*256;
        SockSendBuff[cPos+0]:=buffSize - SockSendBuff[cPos+3]*16777216 - SockSendBuff[cPos+2]*65536 - SockSendBuff[cPos+1]*256;
        cPos:=cPos+4;
        // Je mets ses données
        for ii:=0 to buffSize-1 do begin
          SockSendBuff[cPos]:=bu.Buf[ii];
          cPos:=cPos+1;
        end;
      end;
      // juste après, si tout s'est bien passé : bu.Destroy;
    end;

    if cPos<>0 then begin // S'il y a quelque chose à envoyer
      if Sock.SendBuf(SockSendBuff, cPos)<>-1 then begin // Si l'envoi est bon
        len:=length(A1SendBuffer);
        if stoppedAtBufferIndex=integer(len-1) then begin // tous les buffers ont été envoyés (couvre aussi le cas où cPos=0 (n'arrive pas))
          if len<>0 then for i:=0 to len-1 do A1SendBuffer[i].Destroy;
          SetLength(A1SendBuffer, 0);
        end else begin // ce cas est assez rare pour que je fasse un ObjectArrayDelete sans chercher à plus optimiser
          if stoppedAtBufferIndex<>-1 then
          for i:=0 to stoppedAtBufferIndex do begin
            A1SendBuffer[0].Destroy;
            ObjectArrayDelete(@A1SendBuffer, 0);
          end;
        end;
        ShowSpeed_upload:=ShowSpeed_upload+cPos;
        UploadedTotal:=UploadedTotal+cPos;
      end;// else WriteLn('ERREUR TSocket.SendAllBuffers : buffer non envoyé.');
    end;
    //WriteLn('SendAllBuffers cPos='+inttostr(cPos));
    RenewNetSpeed;
  except
    WriteLn('GRAVE : TSocket.SendAllBuffers EXCEPTION.');
    try
      WriteLn('GRAVE : TSocket.SendAllBuffers EXCEPTION : remoteHost : '+Sock.RemoteHost);
    except
      WriteLn('GRAVE (2) : TSocket.SendAllBuffers EXCEPTION : remoteHost IMPOSSIBLE A LIRE.');
    end;
  end;
end;

procedure TSocket.Free;
begin
  if self<>nil then self.Destroy;
  inherited;
end;

procedure TSocket.GetRcvSentSize(var rcvSize, sndSize : cardinal);
begin
  rcvSize:=self.DownloadSpeed;//self.Thread.Log_totalReceivedSize;
  sndSize:=self.UploadSpeed;//self.Thread.Log_totalSentSize;
end;
procedure TSocket.GetRcvSentTotalSize(var rcvSize, sndSize : cardinal);
begin
  rcvSize:=self.ShowSpeed_download;//self.Thread.Log_totalReceivedSize;
  sndSize:=self.ShowSpeed_upload;//self.Thread.Log_totalSentSize;
end;
procedure TSocket.GetRcvSentTotalMedian(var moyenneRecu, moyenneEmis : cardinal);
var diviserTempsMs, totalRecuDepuis, totalEmisDepuis : int64;
begin // Initialisé depuis TSOcket.RenewNetSpeed(true);
  diviserTempsMs:=GetCurrentMsTime-ShowSpeed_startTime;
  if diviserTempsMs<=0 then exit;
  totalRecuDepuis:=DownloadedTotal-ShowSpeed_startDownload;
  totalEmisDepuis:=UploadedTotal-ShowSpeed_startUpload;
  moyenneRecu:=trunc(totalRecuDepuis*1000/diviserTempsMs);
  moyenneEmis:=trunc(totalEmisDepuis*1000/diviserTempsMs);
end;


procedure TSocket.GetError(Sender: TObject; SocketError: Integer);
var error : string;
begin
  if SocketError=10057 then exit; // Socket is not connected.
  if SocketError=10035 then exit; // Resource temporarily unavailable.
  //if SocketError=10054 then exit; // Connection reset by peer.

  if (SocketError>=10041) and (SocketError<=10054) then StillThere:=false;
  if SocketError=10058 then StillThere:=false;
  if SocketError=10060 then StillThere:=false; // "Asynchronous socket error" impossible de joindre l'hôte à cette ip + port

  error:='Erreur inconnue.';
  case SocketError of
    10035 : error:='Resource temporarily unavailable.';
    10040 : error:='Message too long.';
    10041 : error:='Protocol wrong type for socket.';
    10042 : error:='Bad protocol option.';
    10043 : error:='Protocol not supported.';
    10044 : error:='Socket type not supported.';
    10045 : error:='Operation not supported.';
    10046 : error:='Protocol family not supported.';
    10047 : error:='Address family not supported by protocol family.';
    10048 : error:='Address already in use.';
    10049 : error:='Cannot assign requested address.';
    10050 : error:='Network is down.';
    10051 : error:='Network is unreachable.';
    10052 : error:='Network dropped connection on reset.';
    10053 : error:='Software caused connection abort.';
    10054 : error:='Connection reset by peer.';
    10055 : error:='No buffer space available.';
    10058 : error:='Cannot send after socket shutdown.';
    10060 : error:='Connection Time-out error.';
  end;

  if G_ShowSocketLog then
    WriteLn('ERROR_SOCK '+inttostr(SocketError)+' '+error);
end;


function TSocket.GetRcvFinalSize : cardinal; begin
  Result:=ReceivingBuffer_finalSize; // Taille finale du buffer
end;
function TSocket.GetRcvCurrentSize : cardinal; begin
  Result:=ReceivingBuffer_currentSize; // Position où je suis dans le buffer
end;

procedure TSocket.RenewNetSpeed(resetGlobalMoySpeed : boolean = false);
var newTime, deltaTime, timeMax : int64;
begin
  // Actualisation de la vitesse seconde par seconde
  newTime:=trunc(Now*MillisecTimeFactor);
  deltaTime:=newTime-ShowSpeed_lastTime;
  timeMax:=1000;
  if deltaTime>timeMax then begin
    DownloadSpeed:=trunc(ShowSpeed_download*(1000/deltaTime)); // (Nb d'octets) / (temps pris). Avec temps pris en secondes (=ms/1000, donc 1/t = 1000/ms)
    UploadSpeed:=trunc(ShowSpeed_upload*(1000/deltaTime));
    ShowSpeed_download:=0;
    ShowSpeed_upload:=0;
    ShowSpeed_lastTime:=newTime;
  end;
  // Actualisation de la vitesse moyenne depuis la création du socket
  if resetGlobalMoySpeed then begin
    ShowSpeed_startTime:=GetCurrentMsTime;
    ShowSpeed_startDownload:=DownloadedTotal;
    ShowSpeed_startUpload:=UploadedTotal;
  end;
end;

procedure TSocket.Memory_setMaxSize(maxSize : cardinal); // taille maximale occupée par la totalité des buffers
begin
  Memory_maxSize:=maxSize;
end;
function TSocket.Memory_getRcvSizeUsed : cardinal;
var lenBuff, iBuff : cardinal;
    objBuff : TObjectBuffer;
begin
  Result:=0;
  lenBuff:=length(A1ReceivedBuffer);
  if lenBuff<>0 then for iBuff:=0 to lenBuff-1 do begin
    objBuff:=A1ReceivedBuffer[iBuff];
    Result:=Result+cardinal(length(objBuff.Buf));
  end;
end;
function TSocket.Memory_getSendSizeUsed : cardinal;
var lenBuff, iBuff : cardinal;
    objBuff : TObjectBuffer;
begin
  Result:=0;
  lenBuff:=length(A1SendBuffer);
  if lenBuff<>0 then for iBuff:=0 to lenBuff-1 do begin
    objBuff:=A1SendBuffer[iBuff];
    Result:=Result+cardinal(length(objBuff.Buf));
  end;
end;
function TSocket.Memory_getTotalSizeUsed : cardinal;
begin
  Result:=Memory_getRcvSizeUsed+Memory_getSendSizeUsed;
{var lenBuff, iBuff : cardinal;
    objBuff : TObjectBuffer;
begin
  Result:=0;
  lenBuff:=length(A1ReceivedBuffer);
  if lenBuff<>0 then for iBuff:=0 to lenBuff-1 do begin
    objBuff:=A1ReceivedBuffer[iBuff];
    Result:=Result+cardinal(length(objBuff.Buf));
  end;
  lenBuff:=length(A1SendBuffer);
  if lenBuff<>0 then for iBuff:=0 to lenBuff-1 do begin
    objBuff:=A1SendBuffer[iBuff];
    Result:=Result+cardinal(length(objBuff.Buf));
  end;}
end;
function TSocket.Memory_isOverloaded : boolean; // taille maximale occupée par la totalité des buffers
begin
  Result:=Memory_willBeDestroyed;
end;



{const NoDelaySock_enable = true;
procedure nodelaySock(sock : TCustomIpClient);
var opt : byte;
begin
  opt:=1;
  if NoDelaySock_enable then setsockopt(sock.Handle, IPPROTO_TCP, TCP_NODELAY, PAnsiChar(@opt),sizeof(opt));// TCP_NODELAY
end;


procedure Sock_setNoDelay(sock : TCustomIpClient);
var opt, iDebug : integer;
    success : boolean;
begin
  if not NoDelaySock_enable then exit;
  opt:=1;
  //  showMessage('Sock_setNoDelay : handle='+inttostr(sock.Handle));

  success:=false;
  for iDebug:=0 to 30 do begin
    if setsockopt(sock.Handle, IPPROTO_TCP, TCP_NODELAY, @opt, sizeof(opt)) <> SOCKET_ERROR then begin
      success:=true;
      break;
    end;
    sleep(60);
  end;
  if not success then
    WriteLn('Sock_setNoDelay : SOCKET_ERROR : '+inttostr(WSAGetLastError())+' handle='+inttostr(sock.Handle));
end;

procedure Sock_SetBigBuffer(sock : TCustomIpClient; sizeValue : integer = 20971520);
var OptVal: integer;
    len, i : cardinal;
    success : boolean;
begin
  OptVal := sizeValue;//1024*1024*20; // 20mo de buffer
  len:=4;
  success:=false;
  for i:=1 to len do begin
    if setsockopt(sock.Handle, SOL_SOCKET, SO_RCVBUF, @OptVal, SizeOf(OptVal)) <> SOCKET_ERROR then begin
      success:=true;
      break;
    end;
    OptVal:=trunc(OptVal/2);
  end;
  if not success then
    WriteLn('Sock_SetBigBuffer : SOCKET_ERROR : '+inttostr(WSAGetLastError()));
end;}


procedure TSocket.setNoDelay;
var opt, iDebug : integer;
    success : boolean;
begin
  //if not NoDelaySock_enable then exit;
  opt:=1;
  //  showMessage('Sock_setNoDelay : handle='+inttostr(sock.Handle));
  success:=false;
  for iDebug:=0 to 30 do begin
    if setsockopt(sock.Handle, IPPROTO_TCP, TCP_NODELAY, @opt, sizeof(opt)) <> SOCKET_ERROR then begin
      success:=true;
      break;
    end;
    sleep(60);
  end;
  if not success then
    WriteLog('Sock_setNoDelay : SOCKET_ERROR : '+inttostr(WSAGetLastError())+' handle='+inttostr(sock.Handle));
end;

procedure TSocket.setBigBuffer(bufferSize : integer = 20971520);
var OptVal: integer;
    len, i : cardinal;
    success : boolean;
begin
  OptVal := bufferSize;//1024*1024*20; // 20mo de buffer
  len:=4;
  success:=false;
  for i:=1 to len do begin
    if setsockopt(sock.Handle, SOL_SOCKET, SO_RCVBUF, @OptVal, SizeOf(OptVal)) <> SOCKET_ERROR then begin
      success:=true;
      break;
    end;
    OptVal:=trunc(OptVal/2);
  end;
  if not success then
    WriteLog('Sock_SetBigBuffer : SOCKET_ERROR : '+inttostr(WSAGetLastError()));
end;

function TSocket.GetRemoteHost : string;
begin
  Result := '';
  if self.Sock = nil then exit;
  if self.INVALID_SOCKET then exit;
  if not self.StillThere then exit;
  try
    Result := Sock.RemoteHost;
  except
    WriteLog('EXCEPTION TSocket.GetRemoteHost : Sock.RemoteHost inaccessible.');
  end;
end;




constructor TSocket_server.Create(port : word);
begin
  inherited Create;
  ServSock := nil;

end;
function TSocket_server.Initialize(port : word) : boolean; 
begin
  ServSock := TTcpServer.Create(nil);
  ServSock.BlockMode := bmNonBlocking;
  // Port classique si c'est le serveur de jeu non lié au serveur central
  ServSock.LocalPort := inttostr(port); // AnsiString();
  ServSock.Active := true;
  if not ServSock.Listening then begin
    Result := false;
    exit;
  end;
  Result := true;
end;
function TSocket_server.IsActive : boolean;
begin
  Result := false;
  if ServSock = nil then exit;
  if not ServSock.Active then exit; // <- probablement ligne inutile
  if not ServSock.Listening then exit;
  Result := true;
end;

function TSocket_server.Accept(enableLog : boolean = false) : TSocket;
var newClient : TTcpClient;
    newClientSockE : TSocket;
begin
  Result := nil;
  if ServSock = nil then exit;
  if ServSock.Listening = false then exit;
  
  newClient := TTcpClient.Create(nil);
  if ServSock.Accept(TCustomIpClient(newClient)) then begin
    newClientSockE := TSocket.Create(newClient, enableLog);
    Result := newClientSockE;
  end else
    newClient.Destroy;
end;




end.

