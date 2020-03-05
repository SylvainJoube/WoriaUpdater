unit U_InitTcpNoDelay;

interface
uses winsock, sockets, dialogs, sysUtils;

//procedure nodelaySock(sock : TCustomIpClient);

procedure Sock_setNoDelay(sock : TCustomIpClient);
//procedure modifySockType(sock : TClientSocket);
procedure Sock_SetBigBuffer(sock : TCustomIpClient; sizeValue : integer = 20971520);

implementation
const NoDelaySock_enable = true;     

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
    showMessage('Sock_setNoDelay : SOCKET_ERROR : '+inttostr(WSAGetLastError())+' handle='+inttostr(sock.Handle));
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
    showMessage('Sock_SetBigBuffer : SOCKET_ERROR : '+inttostr(WSAGetLastError()));
end;








end.
