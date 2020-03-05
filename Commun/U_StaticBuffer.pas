unit U_StaticBuffer;

interface
uses sockets, sysUtils;

var StaticBuffer : array [0..40000000] of byte; // 40Mo
    StaticBufferPos : cardinal;

procedure sb_mStart(b1, b2 : byte);
procedure sb_writeubyte(data : byte);
procedure sb_writebyte(data : shortInt);
procedure sb_writebool(data : boolean);
procedure sb_writeuint(data : cardinal; pos : integer = -1);
procedure sb_writeint(data : cardinal);
procedure sb_writeushort(data : word);
procedure sb_writeshort(data : smallInt);
procedure sb_writestring(str : string);

procedure sb_sendbuffer(sock : TTcpClient);

implementation

procedure sb_mStart(b1, b2 : byte);
begin
  // les 4 premiers octets sont pour la taille du message
  StaticBuffer[4]:=b1;
  StaticBuffer[5]:=b2;
  StaticBufferPos:=6;
end;
procedure sb_writeubyte(data : byte); begin
  StaticBuffer[StaticBufferPos]:=data;
  StaticBufferPos:=StaticBufferPos+1;
end;
procedure sb_writebyte(data : shortInt);
var cdata : byte;
begin
  cdata:=data+128;
  sb_writeubyte(cdata);
end;
procedure sb_writebool(data : boolean); begin
  if data then sb_writeubyte(1) else sb_writeubyte(0);
end;
procedure sb_writeuint(data : cardinal; pos : integer = -1);
var i : cardinal;
begin
  if pos=-1 then i:=StaticBufferPos else i:=pos; // cas du placement initial de la taille du message par ex
  StaticBuffer[i+3]:=trunc(data/(256*256*256));
  StaticBuffer[i+2]:=trunc(data/(256*256)) - StaticBuffer[i+3]*256;
  StaticBuffer[i+1]:=trunc(data/(256)) - StaticBuffer[i+3]*256*256 - StaticBuffer[i+2]*256;
  StaticBuffer[i]:=data - StaticBuffer[i+3]*256*256*256 - StaticBuffer[i+2]*256*256 - StaticBuffer[i+1]*256;
  if pos=-1 then StaticBufferPos:=StaticBufferPos+4;
end;
procedure sb_writeint(data : cardinal);
var cdata : integer;
begin
  cdata:=data+2147483648;
  sb_writeuint(cdata);
end;
procedure sb_writeushort(data : word);
var i : cardinal;
begin
  i:=StaticBufferPos;
  StaticBuffer[i+1]:=trunc(data/256);
  StaticBuffer[i]:=data - StaticBuffer[i+1]*256;
  StaticBufferPos:=StaticBufferPos+2;
end;
procedure sb_writeshort(data : smallInt);
var cdata : word;
begin
  cdata:=data + 32768;
  sb_writeushort(cdata);
end;
procedure sb_writestring(str : string); // WriteString
var i : word;
begin
  sb_writeushort(Length(str)); // 2 octets pour la taille du texte
  for i:=1 to Length(str) do
  begin
    sb_writeubyte(ord(str[i])); // J'écris lettre par lettre le texte.
  end;
end;

procedure sb_sendbuffer(sock : TTcpClient);
var res : integer;
    i : cardinal;
begin
  sb_writeuint(StaticBufferPos-4, 0); // Taille du message (moins les 4 premiers octets indiquant sa taille !)
  res:=sock.SendBuf(StaticBuffer, StaticBufferPos);
  //writeln('sb_sendbuffer : '+inttostr(res));
  if res=-1 then for i:=0 to 1000 do begin
    res:=sock.SendBuf(StaticBuffer, StaticBufferPos);
    //writeln('sb_sendbuffer RETRY : '+inttostr(res));
    if res<>-1 then break;
    sleep(1);
  end;
  //for i:=0 to 8 do write(inttostr(StaticBuffer[i])+' ');
  //writeln;
end;

end.
