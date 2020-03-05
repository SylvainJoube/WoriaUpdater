unit U_Files;

interface
uses windows, U_NetSys4, U_Sockets4, SysUtils, dialogs;

function WriteBufferToFile(fpath : string; alreadyFullPath : boolean = false) : boolean;
function ReadBufferFromFile(fpath : string) : boolean;
function ForceDirForFile(fpath: string; extraPath : string = '') : string; // En entrée, le chemin relatif
function ForceFullDirForFile(fullFilePath: string) : string; // En entrée, le chemin absolu
function TryForceDir(dirPath : string) : boolean;
function TryCopyFile(srcPath, destPath : widestring) : boolean;
function TryDeleteFile(path : widestring) : boolean;
function GetParentDir(dir : string) : string; 
function TryRenameFile(oldPath, newPath : widestring) : boolean;
function TryDeleteDirectory(dirPath : widestring) : boolean; // /!\ ne supprime pas les fichiers qu'il y a dedans
function GetFileSize(filePath : string) : int64; // retourne la taille, en octets, d'un fichier




var FileBuffer : array [0..20048575] of byte; // 20Mo  0048575
implementation


// Essayer de créer un dossier
function TryForceDir(dirPath : string) : boolean;
var tryNb : cardinal;
begin
  if dirPath='' then begin // dossier actuel, rien à créer.
    Result:=true;
    exit;
  end;
  //ShowMessage('TryForceDir : dirPath='+dirPath);
  Result:=false;
  for tryNb:=0 to 100 do begin
    if DirectoryExists(dirPath) then // C'est ok, le dossier existe déjà
      break;
    if tryNb<>0 then sleep(26); // si ce n'est pas la première itération, j'attends avant de réessayer
    ForceDirectories(dirPath);
  end;
  if not DirectoryExists(dirPath) then // Echec de la création du dossier
    exit;
  Result:=true;
end;

// Ecriture du buffer de U_NetSys2 (Buf) dans le fichier de chemin fpath.
function WriteBufferToFile(fpath : string; alreadyFullPath : boolean = false) : boolean;
var f : file;
    i, len : cardinal;
    dirPath : string;
    success : boolean;
begin
  Result:=false;
  // Copie du buffer de NetSys2 dans le buffer statique FileBuffer.
  len:=Length(G_MainBuffer.Buf);
  if len=0 then exit;

  for i:=0 to len-1 do
    FileBuffer[i]:=G_MainBuffer.Buf[i];

  if fileExists(fpath) then deleteFile(fpath);
  // Création du répertoire s'il n'sst pas déjà créé.
  if alreadyFullPath then dirPath:=ExtractFilePath(fpath)
                     else dirPath:=GetCurrentDir+'\'+ExtractFilePath(fpath); // ExtractFilePath(ParamStr(0)) Le chemin donné en entrée n'est pas le chemin absolu.
  if not TryForceDir(dirPath) then begin
    exit;
  end;

  AssignFile(f, fpath);
  success:=false;
  for i:=0 to 600 do
  try
    Rewrite(f, sizeof(byte));
    success:=true;
    break;
  except
    //ShowMessage('WriteBufferToFile : Impossible d''ouvrir le fichier : fpath='+fpath);
    // Impossible d'ouvrir le fichier
    sleep(4);
  end;
  if success then begin
    BlockWrite(f, FileBuffer, len);
    CloseFile(f);
    Result:=true;
  end;
end;


function ReadBufferFromFile(fpath : string) : boolean;
var f : file;
    i, len : cardinal;
    oldFileMode : byte;
    success : boolean;
begin
  freebuffer;
  Result:=false;
  if not fileExists(fpath) then exit;
  oldFileMode:=FileMode; // Sauvegarde de FileMode pour le rétablissement à la fin de la fonction.
  FileMode:=fmOpenRead;
  // Lecture du fichier dans FileBuffer.
  AssignFile(f, fpath);
  success:=false;
  for i:=0 to 120 do
    try
      Reset(f, sizeof(byte));
      success:=true;
      break;
    except sleep(4);
    end;

  if not success then begin
    SetLength(G_MainBuffer.Buf, 0);
    FileMode:=oldFileMode; // Réinitialisation de l'ancien mode de manipulation des fichiers.
    exit;
  end;

  len:=FileSize(f);
  if len<>0 then BlockRead(f, FileBuffer, len);
  CloseFile(f);

  SetLength(G_MainBuffer.Buf, len);
  if len<>0 then
  for i:=0 to len-1 do
    G_MainBuffer.Buf[i]:=FileBuffer[i];

  FileMode:=oldFileMode; // Réinitialisation de l'ancien mode de manipulation des fichiers.
  if len<>0 then
    Result:=true;
end;


//ForceDirForFile
function ForceDirForFile(fpath: string; extraPath : string = '') : string; // retourne le chemin de l'exécutable
var dirPath : string;
begin      //ExtractFilePath(ParamStr(0))
  dirPath:=GetCurrentDir+'\'+extraPath+ExtractFilePath(fpath); // Le chemin donné en entrée n'est pas le chemin absolu.
  if TryForceDir(dirPath) then Result:=GetCurrentDir+'\'+extraPath
                          else Result:='ERROR';
end;
//ForceFullDirForFile
function ForceFullDirForFile(fullFilePath: string) : string;
var dirPath : string;
begin
  dirPath:=ExtractFilePath(fullFilePath);
  if not DirectoryExists(dirPath) then ForceDirectories(dirPath);
  if TryForceDir(dirPath) then Result:=dirPath
                          else Result:='ERROR';
end;

const G_NbTry = 500;
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
function TryDeleteFile(path : widestring) : boolean;
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
  Result:= not FileExists(path);
end;
function TryRenameFile(oldPath, newPath : widestring) : boolean;
var i : cardinal;
begin
  Result := false;
  for i:=0 to G_NbTry do begin
    try
      if FileExists(newPath) then break; // fichier du même nom déjà présent
      if RenameFile(oldPath, newPath) then begin
        Result := true;
        exit;
      end;
    except
      //WriteLn('TryDeleteFile - ERROR');
    end;
    sleep(G_NbTrySleepTime);
  end;
end;

function GetParentDir(dir : string) : string;
begin
  Result:=ExtractFilePath(ExcludeTrailingPathDelimiter(dir));
end;
{oldCurrentDir:=GetCurrentDir; // pour le rétablir
SetCurrentDir('..'); // Dossier parent
EditeurParentDir:=GetCurrentDir;
SetCurrentDir(oldCurrentDir);} // CurrentDir rétabli

// Supprimer un dossier et insister si besoin
function TryDeleteDirectory(dirPath : widestring) : boolean; // /!\ ne supprime pas les fichiers qu'il y a dedans
var iTry : cardinal;
begin
  Result:=true;
  if not directoryExists(dirPath) then exit;
  for iTry:=0 to G_NbTry do begin
    try
      RemoveDir(dirPath);
    except
      sleep(G_NbTrySleepTime);
    end;
    if not directoryExists(dirPath) then
      break;
    sleep(G_NbTrySleepTime);
  end;
  Result:=(not directoryExists(dirPath));
end;

function GetFileSize(filePath : string) : int64;
var fi : file of byte;
    oldFileMode : integer;
begin
  Result := -1;
  try
    if not FileExists(filePath) then exit;
    AssignFile(fi, filePath);
    oldFileMode := FileMode;
    FileMode := fmOpenRead;
    try
      Reset(fi);
      Result := FileSize(fi);
    except
      // Exception dans la lecture du fichier
    end;
    FileMode := oldFileMode; // remise de l'ancien mode d'accès aux fichiers
    CloseFile(fi);
  except
    // exception dans l'assign/close du fichier
  end;
end;

end.
