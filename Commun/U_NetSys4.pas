unit U_NetSys4;

// U_NetSys réservé au serveur, la dll core.dll a son propre NetSys.

interface
uses Sockets, U_Sockets4, SysUtils, U_Arrays, math;

//var Buf : TFreeSizeBuffer;
//    BuffPos : integer;
    //BuffSize : integer;


//var NetSys_usedBuffer : TObjectBuffer;


procedure SetUsedBuffer(buffer : TObjectBuffer);
function GetUsedBuffer : TObjectBuffer;
function GetCurrentBufferSize : cardinal; // retourne 0 si aucun buffer actuel
procedure freeBuffer(bufferToUse : TObjectBuffer = nil); overload;
procedure freeBuffer(newBufferSize : cardinal); overload;
function bufferSize : cardinal;
function bufferGet(pos : cardinal) : byte;
procedure bufferPut(data : byte; pos : cardinal);

procedure writeubyte(data : byte);
procedure writebyte(data : shortInt);
procedure writeushort(data : word);
procedure writeshort(data : smallInt);
procedure writeutr(data : cardinal);
procedure writetr(data : integer);
procedure writeuint(data : cardinal);
procedure writeint(data : integer);
procedure writebigint(data : int64);
procedure writeint64(data : int64); // pas un int64 en vérité, va de -10^18 à 10^18
procedure writestring(str : string);
procedure writebool(data : boolean);
function readubyte : byte;
function readbyte : shortInt;
function readushort : word;
function readshort : smallInt;
function readutr : cardinal;
function readtr : integer;
function readuint : cardinal;
function readint : integer;
function readbigint : int64;
function readint64 : int64; // pas un int64 en vérité, va de -10^18 à 10^18
function readstring : string;
function readbool : boolean;
procedure sendBuffer(sockE : TSocket);
function getBufferSize : cardinal;
procedure SendAllBuffers;

//Flow
type TFlowMethod = (tyRead, tyWrite, tyUndefined);
procedure flowubyte(var data : byte; method : TFlowMethod);
procedure flowbyte(var data : shortint; method : TFlowMethod);
procedure flowushort(var data : word; method : TFlowMethod); overload;
procedure flowshort(var data : smallint; method : TFlowMethod); overload;
procedure flowushort(var data : integer; method : TFlowMethod); overload; // avec integer
procedure flowshort(var data : integer; method : TFlowMethod); overload; // avec integer
procedure flowushort(var data : cardinal; method : TFlowMethod); overload; // avec cardinal
procedure flowshort(var data : cardinal; method : TFlowMethod); overload; // avec cardinal

procedure flowtr(var data : cardinal; method : TFlowMethod); overload;
procedure flowtr(var data : integer; method : TFlowMethod); overload;
procedure flowutr(var data : cardinal; method : TFlowMethod); overload;
procedure flowutr(var data : integer; method : TFlowMethod); overload;

procedure flowuint(var data : cardinal; method : TFlowMethod); overload;
procedure flowint(var data : integer; method : TFlowMethod); overload;
procedure flowuint(var data : uint64; method : TFlowMethod); overload;
procedure flowint(var data : uint64; method : TFlowMethod); overload;
procedure flowuint(var data : int64; method : TFlowMethod); overload;
procedure flowint(var data : int64; method : TFlowMethod); overload;

procedure flowint64(var data : int64; method : TFlowMethod); overload;
procedure flowint64(var data : integer; method : TFlowMethod); overload;
procedure flowint64(var data : cardinal; method : TFlowMethod); overload;
procedure flowbool(var data : boolean; method : TFlowMethod);
procedure flowstring(var data : string; method : TFlowMethod);

// Abréviations
procedure mStart(b0, b1 : byte);
function rb : shortInt;
function rub : byte;
function ri : integer;
function rui : cardinal;
function rs : smallint;
function rus : word;
function rstr : string;
procedure wb(data : shortint);
procedure wub(data : byte);
procedure wi(data : integer);
procedure wui(data : cardinal);
procedure ws(data : smallint);
procedure wus(data : word);
procedure wstr(data : string);

function buffer_receive(sock : TSocket; var b1, b2 : byte) : boolean;
function buffer_waitFor(sock : TSocket; b1, b2 : byte; maxTime : cardinal = 200) : boolean;

procedure FlowCardinalArray(var A1Card : TCardinalArray; method : TFlowMethod);

implementation

const G_EchecEnvoiNbMax = 120;

procedure SetUsedBuffer(buffer : TObjectBuffer); begin
  G_MainBuffer:=buffer;
end;
function GetUsedBuffer : TObjectBuffer; begin // Juste par mesure de cohérence (Get/Set)
  Result:=G_MainBuffer;
end;
function GetCurrentBufferSize : cardinal; // retourne 0 si aucun buffer actuel
begin
  Result := 0;
  if G_MainBuffer = nil then exit;
  if G_MainBuffer.Buf = nil then exit;
  Result := Length(G_MainBuffer.Buf);
end;


// ## FreeBuffer ##
procedure freeBuffer(bufferToUse : TObjectBuffer = nil); // Commence toujours à 0.
//var i : cardinal;
begin
  //if G_MainBuffer<>nil then G_MainBuffer.Destroy; // Va causer des bugs
  // En théorie, le freebuffer vient après un envoi, donc
  //if G_MainBuffer=nil then

  // Je regarde si le G_MainBuffer est utile ou non. S'il ne l'est pas, je le supprime.

  if G_MainBuffer<>nil then begin
    if (not G_MainBuffer.WillBeSent) and (bufferToUse<>G_MainBuffer) then
      G_MainBuffer.Destroy;
  end;

  if bufferToUse=nil then G_MainBuffer:=TObjectBuffer.Create
  else begin G_MainBuffer:=bufferToUse; G_MainBuffer.NeededSize:=0; SetLength(G_MainBuffer.Buf, 0); G_MainBuffer.BuffPos:=0; end;
                                        // G_MainBuffer.NeededSize:=0; utile ??

  //if G_MainBuffer=nil then G_MainBuffer:=TObjectBuffer.Create; // Création si oubli d'affectation
  //G_MainBuffer.BuffPos:=0;
  //SetLength(G_MainBuffer.Buf, 0);
end;
procedure freeBuffer(newBufferSize : cardinal);
begin
  freebuffer;
  SetLength(G_MainBuffer.Buf, newBufferSize);
end;
// ###### bufWrite ######
// Disponnible : writebyte, writeshort, writeint, writeubyte, writeushort, writeuint, writestring.
procedure writeubyte(data : byte); begin
  G_MainBuffer.Buf[G_MainBuffer.IncSize]:=data;
end;
procedure writebyte(data : shortInt); begin
  G_MainBuffer.Buf[G_MainBuffer.IncSize]:=data+128;
end;
procedure writeushort(data : word);
var len : cardinal;
begin
  len:=G_MainBuffer.IncSize(2);   // NetSys_usedBuffer.Put n'est pas approprié ici.
  G_MainBuffer.Buf[len+1]:=trunc(data/256);
  G_MainBuffer.Buf[len]:=data - G_MainBuffer.Buf[len+1]*256;
end;
procedure writeshort(data : smallInt);
var cdata : word;
begin
  cdata:=data + 32768;
  writeushort(cdata);
end;
procedure writeutr(data : cardinal);
var len : cardinal;
begin
  len:=G_MainBuffer.IncSize(3);   // NetSys_usedBuffer.Put n'est pas approprié ici.
  G_MainBuffer.Buf[len+2]:=trunc(data/(256*256));
  G_MainBuffer.Buf[len+1]:=trunc(data/256) - G_MainBuffer.Buf[len+2]*256;
  G_MainBuffer.Buf[len]:=data - G_MainBuffer.Buf[len+1]*256 - G_MainBuffer.Buf[len+2]*256*256;
end;
procedure writetr(data : integer);
begin
  writeutr(data+8388608);
end;
procedure writeuint(data : cardinal);
var len : cardinal;
begin
  len:=G_MainBuffer.IncSize(4);
  G_MainBuffer.Buf[len+3]:=trunc(data/(256*256*256));
  G_MainBuffer.Buf[len+2]:=trunc(data/(256*256)) - G_MainBuffer.Buf[len+3]*256;
  G_MainBuffer.Buf[len+1]:=trunc(data/(256)) - G_MainBuffer.Buf[len+3]*256*256 - G_MainBuffer.Buf[len+2]*256;
  G_MainBuffer.Buf[len]:=data - G_MainBuffer.Buf[len+3]*256*256*256 - G_MainBuffer.Buf[len+2]*256*256 - G_MainBuffer.Buf[len+1]*256;
end;
procedure writebigint(data : int64); // le vrai int64 va de -9 223 372 036 854 775 808 à 9223372036854775807
var len, i : cardinal;               // celui là va de -1 000 000 000 000 000 000 à 1 000 000 000 000 000 000. 
    b : array [0..7] of byte;
    quotient : byte;
    reste, diviserPar, unsignedBigInt : int64; // Ne marche pas sous Delphi 7 si je mets uint64
begin
  { opérations sur les uint64 mal gérées par Delphi 7 }
  { du coup, j'utilise un int64 pour gérer un nombre moins grand que j'ai appelé BigInt}
  len:=G_MainBuffer.IncSize(8);
  unsignedBigInt:=data+trunc(power(10, 18)); // data+10^18;
  reste:=0;
  for i:=0 to 7 do begin
    diviserPar:=trunc(power(256, 7-i));
    quotient:=trunc(unsignedBigInt/diviserPar)-reste;
    reste:=(reste+quotient)*256;
    b[7-i]:=quotient;
  end;
  { marche aussi :
  reste:=0;
  b[7]:=trunc(data/72057594037927936); reste:=(reste+b[7])*256;
  b[6]:=trunc(data/281474976710656)-reste; reste:=(reste+b[6])*256;
  b[5]:=trunc(data/1099511627776)-reste; reste:=(reste+b[5])*256;
  b[4]:=trunc(data/4294967296)-reste; reste:=(reste+b[4])*256;
  b[3]:=trunc(data/16777216)-reste; reste:=(reste+b[3])*256;
  b[2]:=trunc(data/65536)-reste; reste:=(reste+b[2])*256;
  b[1]:=trunc(data/256)-reste; reste:=(reste+b[1])*256;
  b[0]:=data-reste;}
  {    + G_MainBuffer.Get(7)*72057594037927936
    + G_MainBuffer.Get(6)*281474976710656
    + G_MainBuffer.Get(5)*1099511627776
    + G_MainBuffer.Get(4)*4294967296
    + G_MainBuffer.Get(3)*16777216
    + G_MainBuffer.Get(2)*65536
    + G_MainBuffer.Get(1)*256
    + G_MainBuffer.Get(0);}
  for i:=0 to 7 do begin
    G_MainBuffer.Buf[len+i]:=b[i];
  end;

end;
procedure writeint64(data : int64); begin  // pas un int64 en vérité, va de -10^18 à 10^18
  writebigint(data);
end;
procedure writeint(data : integer);
var cdata : int64;
begin
  cdata:=data;
  cdata:=cdata+2147483648;
  writeuint(cdata);
end;
procedure writestring(str : string); // WriteString
var i : word;
begin
  writeushort(Length(str)); // 2 octets pour la taille du texte
  for i:=1 to Length(str) do
  begin
    writeubyte(ord(str[i])); // J'écris lettre par lettre le texte.
  end;
end;

// ###### BufRead ######
function readubyte : byte;
begin
  if Length(G_MainBuffer.Buf)>G_MainBuffer.BuffPos then begin // Si je peux lire cet octet, je le lis
    result:=G_MainBuffer.Get(0); //NetSys_usedBuffer.Buf[BuffPos];
    G_MainBuffer.IncPos;//NetSys_usedBuffer.BuffPos:=NetSys_usedBuffer.BuffPos+1;
  end else Result:=0;
end;
function readbyte : shortInt; begin
  result:=readubyte-128;
end;
function readushort : word;
begin
  if Length(G_MainBuffer.Buf)>=G_MainBuffer.BuffPos+2 then begin
    //result:=NetSys_usedBuffer.Buf[NetSys_usedBuffer.BuffPos+1] + NetSys_usedBuffer.Buf[NetSys_usedBuffer.BuffPos];
    result:=G_MainBuffer.Get(1)*256 + G_MainBuffer.Get(0);
    G_MainBuffer.IncPos(2);
  end else result:=0;
end;
function readshort : smallInt;
begin
  result:=readushort - 32768;
end;
function readutr : cardinal;
begin
  if Length(G_MainBuffer.Buf)>=G_MainBuffer.BuffPos+3 then begin
    result:=
    G_MainBuffer.Get(2)*65536
    + G_MainBuffer.Get(1)*256
    + G_MainBuffer.Get(0);
    G_MainBuffer.IncPos(3)
  end else result:=0;
end;
function readtr : integer;
begin
  result:=readutr - 8388608;
end;
function readuint : cardinal;
begin
  if Length(G_MainBuffer.Buf)>=G_MainBuffer.BuffPos+4 then begin
    //result:=G_MainBuffer.Get(3)*16777216 + G_MainBuffer.Get(2)*65536 + G_MainBuffer.Get(1)*256 + G_MainBuffer.Get(0);
    result:=
    G_MainBuffer.Get(3)*16777216
    + G_MainBuffer.Get(2)*65536
    + G_MainBuffer.Get(1)*256
    + G_MainBuffer.Get(0);
    //Buf[BuffPos+3]*256*256*256 + Buf[BuffPos+2]*256*256 + Buf[BuffPos+1]*256 + Buf[BuffPos];
    G_MainBuffer.IncPos(4)
  end else result:=0;
end;
function readint : integer;
begin
  result:=readuint - 2147483648;
end;
function readbigint : int64;   // le vrai int64 va de -9 223 372 036 854 775 808 à 9223372036854775807
var i : byte;                  // celui là va de -1*10^18 à 1*10^18. (neuf fois moins que le int64)
begin
  if Length(G_MainBuffer.Buf)>=G_MainBuffer.BuffPos+8 then begin
    Result:=-trunc(power(10, 18)); // -10^18 (signé)
    for i:=0 to 7 do
      Result:=Result+G_MainBuffer.Get(i)*trunc(power(256, i));
    {result:=
    + G_MainBuffer.Get(7)*72057594037927936
    + G_MainBuffer.Get(6)*281474976710656
    + G_MainBuffer.Get(5)*1099511627776
    + G_MainBuffer.Get(4)*4294967296
    + G_MainBuffer.Get(3)*16777216
    + G_MainBuffer.Get(2)*65536
    + G_MainBuffer.Get(1)*256
    + G_MainBuffer.Get(0);}
    G_MainBuffer.IncPos(8);
  end else result:=0;
end;
function readint64 : int64;  // pas un int64 en vérité, va de -10^18 à 10^18
begin
  result:=readbigint;
end;

function readstring : string;
var str : string;
    i : cardinal;
    long : word;
begin
  long:=readushort;
  if long=0 then begin result:=''; exit; end;
  str:='';
  for i:=1 to long do
    str:=str + chr(readubyte);
  result:=str;
end;

// Ecriture d'un booléen : transformation en octet (plus simple).
procedure writebool(data : boolean);
begin
  if data=true then writeubyte(1)
               else writeubyte(0);
end;
function readbool : boolean;
var data : byte;
begin
  data:=readubyte;
  if data=1 then Result:=true
            else Result:=false;
end;



procedure mStart(b0, b1 : byte);
begin
  freebuffer;
  writeubyte(b0);
  writeubyte(b1);
  //WriteLn('mStart '+inttostr(b0)+'->'+inttostr(b1));
end;
// Ecrire
procedure wb(data : shortint); begin
  writebyte(data);
end;
procedure wub(data : byte); begin
  writeubyte(data);
end;
procedure wi(data : integer); begin
  writeint(data);
end;
procedure wui(data : cardinal); begin
  writeuint(data);
end;
procedure ws(data : smallint); begin
  writeshort(data);
end;
procedure wus(data : word); begin
  writeushort(data);
end;
procedure wstr(data : string); begin
  writestring(data);
end;
// Lire
function rb : shortInt; begin
  Result:=readbyte;
end;
function rub : byte; begin
  Result:=readubyte;
end;
function ri : integer; begin
  Result:=readint;
end;
function rui : cardinal; begin
  Result:=readuint;
end; 
function rs : smallint; begin
  Result:=readshort;
end;
function rus : word; begin
  Result:=readushort;
end;
function rstr : string; begin
  Result:=readstring;
end;

// Flow
procedure flowubyte(var data : byte; method : TFlowMethod); begin
  if method=tyRead then data:=readubyte
                   else writeubyte(data);
end;
procedure flowbyte(var data : shortint; method : TFlowMethod); begin
  if method=tyRead then data:=readbyte
                   else writebyte(data);
end;
procedure flowushort(var data : word; method : TFlowMethod); begin
  if method=tyRead then data:=readushort
                   else writeushort(data);
end;
procedure flowushort(var data : integer; method : TFlowMethod); begin // type integer
  if method=tyRead then data:=readushort
                   else writeushort(data);
end;
procedure flowushort(var data : cardinal; method : TFlowMethod); begin // type cardinal
  if method=tyRead then data:=readushort
                   else writeushort(data);
end;
procedure flowshort(var data : smallint; method : TFlowMethod); begin
  if method=tyRead then data:=readshort
                   else writeshort(data);
end;
procedure flowshort(var data : integer; method : TFlowMethod); begin // type integer
  if method=tyRead then data:=readshort
                   else writeshort(data);
end;
procedure flowshort(var data : cardinal; method : TFlowMethod); begin // type cardinal
  if method=tyRead then data:=readshort
                   else writeshort(data);
end;
procedure flowtr(var data : cardinal; method : TFlowMethod); begin
  if method=tyRead then data:=readtr
                   else writetr(data);
end;
procedure flowtr(var data : integer; method : TFlowMethod); begin
  if method=tyRead then data:=readtr
                   else writetr(data);
end;
procedure flowutr(var data : cardinal; method : TFlowMethod); begin
  if method=tyRead then data:=readutr
                   else writeutr(data);
end;
procedure flowutr(var data : integer; method : TFlowMethod); begin
  if method=tyRead then data:=readutr
                   else writeutr(data);
end;
procedure flowuint(var data : cardinal; method : TFlowMethod); begin
  if method=tyRead then data:=readuint
                   else writeuint(data);
end;
procedure flowint(var data : integer; method : TFlowMethod); begin
  if method=tyRead then data:=readint
                   else writeint(data);
end;
procedure flowuint(var data : uint64; method : TFlowMethod); begin
  if method=tyRead then data:=readuint
                   else writeuint(data);
end;
procedure flowuint(var data : int64; method : TFlowMethod); begin
  if method=tyRead then data:=readuint
                   else writeuint(data);
end;
procedure flowint(var data : int64; method : TFlowMethod); begin
  if method=tyRead then data:=readint
                   else writeint(data);
end;
procedure flowint(var data : uint64; method : TFlowMethod); begin
  if method=tyRead then data:=readint
                   else writeint(data);
end;
procedure flowint64(var data : int64; method : TFlowMethod); begin
  if method=tyRead then data:=readbigint
                   else writebigint(data);
end;
procedure flowint64(var data : integer; method : TFlowMethod); begin
  if method=tyRead then data:=readbigint
                   else writebigint(data);
end;
procedure flowint64(var data : cardinal; method : TFlowMethod); begin
  if method=tyRead then data:=readbigint
                   else writebigint(data);
end;
procedure flowbool(var data : boolean; method : TFlowMethod); begin
  if method=tyRead then data:=readbool
                   else writebool(data);
end;
procedure flowstring(var data : string; method : TFlowMethod); begin
  if method=tyRead then data:=readstring
                   else writestring(data);
end;


var A1Sock_sendBuffer : array of TSocket;

// ###### SendBuffer ######
procedure sendBuffer(sockE : TSocket);
var i : integer;
    dataSize, len : cardinal;
    newMainBuff : TObjectBuffer;
begin
  //if not Assigned(sockE) then exit;
  dataSize:=Length(G_MainBuffer.Buf);
  //WriteLn('sendBuffer dataSize='+inttostr(dataSize));
  //WriteLn(dataSize);
  if dataSize=0 then exit; // Le buffer doit être non vide
  // Tous les messages sont envoyés d'un même buffer.
  // J'ajoute les octets au buffer d'envoi du socket.
  sockE.AddSendBuffer(G_MainBuffer);
  newMainBuff:=TObjectBuffer.Create;
  newMainBuff.Buf:=G_MainBuffer.Buf; // Copie du buffer (pour les envois multiples par ex)
  G_MainBuffer:=newMainBuff;
  // /!\ dire que je sendBuffer ne veut pas dire que je ne veux pas envoyer ce buffer à un autre socket !
  //G_MainBuffer:=nil;//TObjectBuffer.Create; // Je lui cède le buffer
  len:=Length(A1Sock_sendBuffer);
  if len<>0 then for i:=0 to len-1 do if A1Sock_sendBuffer[i]=SockE then exit; // Je cherche le socket dans les sockets à envoyer  // S'il est déjà là, il sera bien envoyé.
  // J'ajoute le socket dans la liste des sockets qui devront être envoyés.
  SetLength(A1Sock_sendBuffer, len+1);
  A1Sock_sendBuffer[len]:=SockE;
end;

function getBufferSize : cardinal;
begin
  if G_MainBuffer=nil then begin
    Result:=0;
    exit;
  end;
  Result:=Length(G_MainBuffer.Buf);
end;

// SendAllBuffers;
procedure SendAllBuffers;
var i : cardinal;
begin //try
      // Un buffer de taille dynamique peut être envoyé, mais sa taille doit être bien inféreure à celle d'un buffer statique.
      // Je communique donc un buffer statique à la dll de Windows.
      // J'envoie les données (je transmet les données à la dll Windows).
  if length(A1Sock_sendBuffer)=0 then exit;
  // Les sockets qui ont quelque chose à envoyer.
  for i:=0 to Length(A1Sock_sendBuffer)-1 do
    A1Sock_sendBuffer[i].SendAllBuffers; // Dit au thread via une variable du Socket qu'il peut envoyer les données.;
  SetLength(A1Sock_sendBuffer, 0);
end;

function bufferSize : cardinal;
begin
  Result:=length(G_MainBuffer.Buf);
end;
function bufferGet(pos : cardinal) : byte; begin
  Result:=G_MainBuffer.Buf[pos]; // Je supose que le G_MainBuffer existe et que la position est valide (une vérification coûterait du temps)
end; 
procedure bufferPut(data : byte; pos : cardinal); begin
  G_MainBuffer.Put(data, pos);
end;

function buffer_receive(sock : TSocket; var b1, b2 : byte) : boolean;
begin
  result:=false;
  freebuffer;
  if not sock.GetMessage then exit;
  b1:=readubyte;
  b2:=readubyte;
  Result:=true;
end;

function buffer_waitFor(sock : TSocket; b1, b2 : byte; maxTime : cardinal = 200) : boolean; // timer de 2 secondes
var r1, r2 : byte;
    i : cardinal;
begin
  Result:=false;
  for i:=0 to maxTime do begin
    if buffer_receive(sock, r1, r2) then
    if (r1=b1) and (r2=b2) then begin
      Result:=true;
      exit;
    end;
    sleep(10);
  end;
end;


procedure FlowCardinalArray(var A1Card : TCardinalArray; method : TFlowMethod);
var len, i : cardinal;
begin
  if method=tyRead then begin
    len:=readuint;
    SetLength(A1Card, len);
  end else begin
    len:=length(A1Card);
    writeuint(len);
  end;
  if len<>0 then for i:=0 to len-1 do
    flowuint(A1Card[i], method);
end;


end.
