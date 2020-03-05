unit U_Crypt1;

interface
uses windows, SysUtils, U_NetSys4, U_Sockets4, dialogs, ClipBrd, U_FIles, IdGlobal, IdHash, IdHashMessageDigest;

procedure CodeFile(mKey, sKey : cardinal; fpath : string);
procedure DecodeFile(mKey, sKey : cardinal; fpath : string);
procedure Crypt1_setKeys(mKey, sKey : cardinal);
function CodeString(argStr : string) : string;
function DecodeString(argStr : string) : string;

procedure DecodeFileTo(mKey, sKey : cardinal; fSourcePath, fTargetPath : string);
procedure CodeFileTo(mKey, sKey : cardinal; fSourcePath, fTargetPath : string);
procedure CodeBuffer(mKey, sKey : cardinal);
procedure DecodeBuffer(mKey, sKey : cardinal);

//function Hash128(inStr : string) : string;

type TCryptMethod = (tyCrypt_code, tyCrypt_decode);

implementation

var cBuff : array [0..10000000] of byte; // Limité à 10Mo

type TTryOpenFile_mode = (tyOpenRead, tyOpenWrite);
function TryOpenFile(var f : file; openMode : TTryOpenFile_mode) : boolean;
var i : cardinal;
    openSuccess : boolean;
begin
  openSuccess:=false;
  for i:=0 to 800 do
    try
      if openMode=tyOpenRead then Reset(f, 1);
      if openMode=tyOpenWrite then ReWrite(f, 1);
      openSuccess:=true;
      break;
    except sleep(1);// showMessage('U_Crypt1 - TryOpenFile failed');
    end;
  Result:=openSuccess;
end;

// CodeFile
procedure CodeFile(mKey, sKey : cardinal; fpath : string);
var f : file;
    size, pos : cardinal;
begin
  if not FileExists(fPath) then exit;
  FileMode:=fmOpenRead;
  AssignFile(f, fPath);
  if not TryOpenFile(f, tyOpenRead) then exit;
  size:=FileSize(f);
  if size = 0 then begin CloseFile(f); exit; end;
  // Chargement du fichier à crypter en mémoire.
  BlockRead(f, cBuff, size);
  CloseFile(f);
  // Je crypte le buffer
  RandSeed:=sKey;
  for pos:=0 to size-1 do
  begin
    cBuff[pos]:=cBuff[pos] + random(mKey) mod 256;
  end;
  FileMode:=fmOpenWrite;
  if not TryOpenFile(f, tyOpenWrite) then exit;
  BlockWrite(f, cBuff, size);
  CloseFile(f);
end;
// DecodeFile
procedure DecodeFile(mKey, sKey : cardinal; fpath : string);
var f : file;
    size, pos : cardinal;
begin
  if not FileExists(fPath) then exit;
  FileMode:=fmOpenRead;
  AssignFile(f, fPath);
  if not TryOpenFile(f, tyOpenRead) then exit;
  size:=FileSize(f);
  if size = 0 then begin CloseFile(f); exit; end;
  // Chargement du fichier à crypter en mémoire.
  BlockRead(f, cBuff, size);
  CloseFile(f);
  // Je crypte le buffer
  RandSeed:=sKey;
  for pos:=0 to size-1 do
  begin
    cBuff[pos]:=cBuff[pos] - random(mKey) mod 256;
  end;
  FileMode:=fmOpenWrite;
  if not TryOpenFile(f, tyOpenWrite) then exit;
  BlockWrite(f, cBuff, size);
  CloseFile(f);
end;

// CodeBuffer
procedure CodeBuffer(mKey, sKey : cardinal);
var len, i : cardinal;
begin
  if G_MainBuffer=nil then exit;
  len:=length(G_MainBuffer.Buf);
  // Je crypte le buffer
  RandSeed:=sKey;
  if len<>0 then for i:=0 to len-1 do begin
    G_MainBuffer.Buf[i]:=G_MainBuffer.Buf[i] + random(mKey) mod 256;
  end;
end;
// DecodeBuffer
procedure DecodeBuffer(mKey, sKey : cardinal);
var i, len : cardinal;
begin
  if G_MainBuffer=nil then exit;
  len:=length(G_MainBuffer.Buf);
  // Je crypte le buffer
  RandSeed:=sKey;
  if len<>0 then for i:=0 to len-1 do begin
    G_MainBuffer.Buf[i]:=G_MainBuffer.Buf[i] - random(mKey) mod 256;
  end;
end;


const G_NbTry = 600;    
const G_NbTrySleepTime = 2;

function TryCopyFile(srcPath, destPath : widestring) : boolean;
var i : cardinal;
begin
  Result:=false;
  if not FileExists(srcPath) then exit;

  for i:=0 to G_NbTry do begin
    try
      if CopyFileW(PWideChar(srcPath), PWideChar(destPath), false) then begin
      //if ShellCopyFile(srcPath, destPath) then begin
        Result:=true;
        break;
      end;
    except
      //WriteLn('TryCopyFile - ERROR');
    end;
    sleep(G_NbTrySleepTime);
  end;
end;
procedure TryDeleteFile(path : widestring);
var i : cardinal;
begin
  for i:=0 to G_NbTry do begin
    try
      if not FileExists(path) then
        break;
      if DeleteFile(path) then
        break;
    except
      //WriteLn('TryDeleteFile - ERROR');
    end;
    sleep(G_NbTrySleepTime);
  end;
end;

procedure FlowCryptFileTo(mKey, sKey : cardinal; fSourcePath, fTargetPath : string; cryptOrDecrypt : TCryptMethod);
var fSource, fTarget : file;
    size, pos : cardinal;
begin
  if not FileExists(fSourcePath) then exit;
  FileMode:=fmOpenRead;
  AssignFile(fSource, fSourcePath);
  //ShowMessage('DecodeFileTo : try open fSource...');
  if not TryOpenFile(fSource, tyOpenRead) then exit;   
  //ShowMessage('DecodeFileTo : try open fSource OK !');
  size:=FileSize(fSource);
  if size = 0 then begin CloseFile(fSource); exit; end;
  // Chargement du fichier à crypter en mémoire.
  BlockRead(fSource, cBuff, size);
  CloseFile(fSource);
  // Je crypte le buffer
  RandSeed:=sKey;
  if cryptOrDecrypt=tyCrypt_decode then for pos:=0 to size-1 do begin
    cBuff[pos]:=cBuff[pos] - random(mKey) mod 256;
  end;
  if cryptOrDecrypt=tyCrypt_code then for pos:=0 to size-1 do begin
    cBuff[pos]:=cBuff[pos] + random(mKey) mod 256;
  end;
  FileMode:=fmOpenWrite;
  if FileExists(fTargetPath) then
    TryDeleteFile(fTargetPath);
  AssignFile(fTarget, fTargetPath);
  //ShowMessage('DecodeFileTo : try open fTarget...');
  if not TryOpenFile(fTarget, tyOpenWrite) then exit;
  BlockWrite(fTarget, cBuff, size);
  CloseFile(fTarget);
  //ShowMessage('DecodeFileTo : try open fTarget OK !');
end;


procedure DecodeFileTo(mKey, sKey : cardinal; fSourcePath, fTargetPath : string);
begin
  FlowCryptFileTo(mKey, sKey, fSourcePath, fTargetPath, tyCrypt_decode);

{var fSource, fTarget : file;
    size, pos : cardinal;
begin
  //ShowMessage('DecodeFileTo : fSourcePath='+fSourcePath);
  //ShowMessage('DecodeFileTo : fTargetPath='+fTargetPath);
  //Clipboard.AsText:=fSourcePath;
  //ShowMessage('DecodeFileTo : (fSourcePath) existe='+booltostr(FileExists(fSourcePath), true));
  if not FileExists(fSourcePath) then exit;
  FileMode:=fmOpenRead;
  AssignFile(fSource, fSourcePath);
  //ShowMessage('DecodeFileTo : try open fSource...');
  if not TryOpenFile(fSource, tyOpenRead) then exit;   
  //ShowMessage('DecodeFileTo : try open fSource OK !');
  size:=FileSize(fSource);
  if size = 0 then begin CloseFile(fSource); exit; end;
  // Chargement du fichier à crypter en mémoire.
  BlockRead(fSource, cBuff, size);
  CloseFile(fSource);
  // Je crypte le buffer
  RandSeed:=sKey;
  for pos:=0 to size-1 do
  begin
    cBuff[pos]:=cBuff[pos] - random(mKey) mod 256;
  end;
  FileMode:=fmOpenWrite;
  if FileExists(fTargetPath) then
    TryDeleteFile(fTargetPath);
  AssignFile(fTarget, fTargetPath);
  //ShowMessage('DecodeFileTo : try open fTarget...');
  if not TryOpenFile(fTarget, tyOpenWrite) then exit;
  BlockWrite(fTarget, cBuff, size);
  CloseFile(fTarget);}
  //ShowMessage('DecodeFileTo : try open fTarget OK !');
end;




procedure CodeFileTo(mKey, sKey : cardinal; fSourcePath, fTargetPath : string);
begin
  FlowCryptFileTo(mKey, sKey, fSourcePath, fTargetPath, tyCrypt_code);
end;











var ModKey, SeedKey : cardinal;
//Crypt1_setKeys
procedure Crypt1_setKeys(mKey, sKey : cardinal);
begin
  ModKey:=mKey;
  SeedKey:=sKey;
end;
// CodeString. Attention, la chaine de caractère peut contenir des carctères illisibles, il faut impérativement la décrypter avant de l'utiliser en tant que texte.
// Prendre le résultat comme un tableau d'octets transformés via chr(), plutôt que comme une chaine de caractères.
function CodeString(argStr : string) : string;
var str : string;
    i : cardinal;
    nb, nbCode : byte;
begin
  SetLength(str, Length(argStr));
  if Length(argStr)=0 then begin Result:=''; exit; end;
  RandSeed:=SeedKey;
  for i:=1 to Length(argStr) do
  begin
    nb:=ord(argStr[i]);
    nbCode:= nb + random(ModKey) mod 256;
    str[i]:=chr(nbCode);
  end;
  Result:=str;
end;
//DecodeString
function DecodeString(argStr : string) : string;
var str : string;
    i : cardinal;
    nb, nbCode : byte;
begin
  SetLength(str, Length(argStr));
  if Length(argStr)=0 then begin Result:=''; exit; end;
  RandSeed:=SeedKey;
  for i:=1 to Length(argStr) do
  begin
    nbCode:=ord(argStr[i]);
    nb:= nbCode - random(ModKey) mod 256;
    str[i]:=chr(nb);
  end;
  Result:=str;
end;


{function Hash128(inStr : string) : string;
var h : TIdHashMessageDigest5;
    v : TIdHash128;
    text4 : T4x4LongWordRecord;
    hashText : string;
begin
  h:=TIdHashMessageDigest5.Create;
  v:=TIdHash128.Create;
  text4:=h.HashValue(inStr);
  hashText:=v.AsHex(text4);
  Result:=hashText;
  h.Free;
  v.Free;
  //WriteLn('CryptString2 : in = '+inStr);
  //WriteLn('CryptString2 : out = '+hashText);

end;}

{with TIdHashMessageDigest5.Create do
try
    Result := TIdHash128.AsHex(HashValue('Hello, world'));
finally
    Free;
end;}


end.
