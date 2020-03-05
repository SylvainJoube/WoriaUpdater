unit U_FonctionGenerales;

interface
uses SysUtils, Windows, ShellApi;

function MoveDir(fromDir, toDir: widestring; copyIfFailed : boolean = false): Boolean;
function CopyDir(fromDir, toDir: widestring): Boolean;
function DelDir(dir : widestring): Boolean;
function ExecuteFile(fPath : widestring) : boolean;
function SearchInString(strSource, subStr : widestring) : boolean;
function ShellCopyFile(fromPath, toPath : widestring) : boolean;

var Dll_CurrentString : string; // pour la dll du client de Woria

implementation

function MoveDir(fromDir, toDir: widestring; copyIfFailed : boolean = false): Boolean;
var
  fos: TSHFileOpStructW;
begin
  Result:=false;
  if not DirectoryExists(fromDir) then exit;

  ZeroMemory(@fos, SizeOf(fos));
  with fos do
  begin
    wFunc  := FO_MOVE;
    fFlags := FOF_FILESONLY;
    pFrom  := PWideChar(fromDir); //  + #0
    pTo    := PWideChar(toDir)
  end;
  Result := (0 = ShFileOperationW(fos));

  if (not Result) and (copyIfFailed) then begin
    Result:=CopyDir(fromDir, toDir);
  end;
end;

function CopyDir(fromDir, toDir: widestring): Boolean;
var
  fos: TSHFileOpStructW;
begin          
  Result:=false;
  if not DirectoryExists(fromDir) then exit;
  
  ZeroMemory(@fos, SizeOf(fos));
  with fos do
  begin
    wFunc  := FO_COPY;
    fFlags := FOF_FILESONLY;
    pFrom  := PWideChar(fromDir); //  + #0
    pTo    := PWideChar(toDir)
  end;
  Result := (0 = ShFileOperationW(fos));
end;

function DelDir(dir: widestring): Boolean;
var
  fos: TSHFileOpStructW;
begin
  Result:=false;       
  if not DirectoryExists(dir) then exit;
  
  ZeroMemory(@fos, SizeOf(fos));
  with fos do
  begin
    wFunc  := FO_DELETE;
    fFlags := FOF_SILENT or FOF_NOCONFIRMATION;
    pFrom  := PWideChar(dir + WideChar(0)); // #0
  end;
  Result := (0 = ShFileOperationW(fos));
end;

function ExecuteFile(fPath : widestring) : boolean;
begin
  Result:=false;
  if not fileExists(fPath) then exit;
  ShellExecuteW(0, 'open', PWideChar(fPath), nil, nil, SW_SHOWNORMAL); // PWideChar
  Result:=true;
end;

function SearchInString(strSource, subStr : WideString) : boolean;
var lenSource, lenSub, repeatNb, offset, iChr : cardinal;
    chSource, chSub : widechar;
    correspond : boolean;
begin
  Result:=false;
  lenSource:=length(strSource);
  lenSub:=length(subStr);
  if lenSource=0 then exit;
  if lenSub=0 then begin Result:=true; exit; end; // Il y a le string nul ('') dans toutes les chaînes de caractères
  if lenSource<lenSub then exit;
  repeatNb:=lenSource-lenSub;
  for offset:=0 to repeatNb do begin // repeatNb>=0 ici
    correspond:=true;
    for iChr:=1 to lenSub do begin
      chSource:=strSource[iChr+offset];
      chSub:=subStr[iChr];
      if chSource<>chSub then begin
        correspond:=false;
        break;
      end;
    end;
    if correspond then begin
      Result:=true;
      exit;
    end;
  end;
end;


function ShellFileOperation(const fromFile, toFile: WideString; Flags: Integer) : integer;
var
  shellinfo: TSHFileOpStructW;
  fromFile_wide, toFile_wide : WideString;
begin
  with shellinfo do
  begin
    //wnd   := Application.Handle;
    fromFile_wide := fromFile;
    toFile_wide := toFile;
    wFunc := Flags;
    pFrom := PWideChar(fromFile_wide);
    pTo   := PWideChar(toFile_wide);
  end;
  Result:=SHFileOperationW(shellinfo);
end;

function ShellCopyFile(fromPath, toPath : WideString) : boolean;
begin

  if ShellFileOperation(fromPath, toPath, FO_COPY)=0 then
    Result:=true
  else
    Result:=false;
end;

end.
