unit U_ClientFiles_Editor;

interface
uses dialogs, SysUtils, U_Sockets4, U_Files, U_NetSys4, U_Arrays;
// Gestion de la version des fichiers éditeur
// TOUS les fichiers sont dans le même dossier, et ont un nom unique (normal ^^)


type TEditFile = record
  Name : string;
  Ver, Ver_lastExported : cardinal; // Ver est la version du fichier, Ver_lastExported est la dernière version à laquelle le fichier a été exporté
  temp_isUsed : boolean; // juste pour la procédure ListClientFiles_updateFileFromDisk
end;
type TPEditFile = ^TEditFile;
type TA1EditFile = array of TEditFile;
var A1EditFile : TA1EditFile;

// fichiers à ne pas supprimer, mais non présents dans A1EditFle
var A1EditFile_doNotDelete : array of string;


// Fichiers mis dans ClientFiles
type TExportUpdateServerFile = record
  Name : string;
  Ver : cardinal;
end;
type TPExportUpdateServerFile = ^TExportUpdateServerFile;
var A1ExportUpdateServerFile : array of TExportUpdateServerFile;
procedure ExportUpdateServer_clear;
function ExportUpdateServer_find(fName : string; var index : integer) : TPExportUpdateServerFile;
procedure ExportUpdateServer_addFile(fName : string; ver : cardinal);
procedure ExportUpdateServer_deleteFile(fName : string); overload;
procedure ExportUpdateServer_deleteFile(index : cardinal); overload;
procedure ExportUpdateServer_save(servFilePath : string);
function ExportUpdateServer_load(fpath : string) : boolean;  
procedure ExportUpdateServer_deleteUnknownFiles(rootDir : string);


//var G_EditFileList_filesLocation : string;
//var G_EditFileList_saveFileLocation : string;


procedure EditFiles_init(editFilesPath, rootDir : string); // charge le fichier et actualise à partir du disque
function EditFiles_load(fpath : string; showFiles : boolean = false) : boolean;
procedure EditFiles_save(fpath : string);
function EditFiles_find(fileName : string; var fileIndex : integer) : TPEditFile;
procedure EditFiles_delete(fileName : string); overload;
procedure EditFiles_delete(index : cardinal); overload;
function EditFiles_updateFileVer(fName : string; changerVer : boolean = false) : TPEditFile; // Incrémentation de la version ou ajout d'un fichier
procedure EditFiles_updateFromDisk(rootDir : string; updateVersionForAll : boolean = false);
procedure EditFiles_setExportVer(fileName : string); overload;
procedure EditFiles_setExportVer(fileIndex : cardinal); overload;
function EditFiles_doExport(fileName, filePathDest : string) : boolean;
procedure EditFiles_deleteUnknownFiles(rootDir : string); // supprime du dossier rootDir et de ses sous-dossiers les fichiers ne figurant pas dans A1EditFile
procedure EditFiles_doNotDelete_add(fName : string); // fichiers à ne pas supprimer, mais non présents dans A1EditFle
procedure EditFiles_doNotDelete_clear; // remet la taille de la liste A1EditFile_doNotDelete à 0
function EditFiles_doNotDelete_exists(fName : string) : boolean; // retourne true si le fichier existe dans A1EditFile_doNotDelete
procedure ShowEditFiles;
procedure EditFiles_clear; // remet la taille de A1EditFile à 0
function EditFiles_updateFileVer_addFile(fileName : string) : TPEditFile; // seulement appelé depuis EditFiles_updateFileVer

implementation

procedure EditFiles_init(editFilesPath, rootDir : string); // charge le fichier et actualise à partir du disque
begin
  EditFiles_load(editFilesPath, false);
  EditFiles_updateFromDisk(rootDir, false); // aussi fait à l'exportation
  EditFiles_save(editFilesPath);
end;
                            
function EditFiles_find(fileName : string; var fileIndex : integer) : TPEditFile;
var len, i : cardinal;
begin
  Result:=nil;
  fileIndex:=-1;
  len:=length(A1EditFile);
  if len=0 then exit;
  for i:=0 to len-1 do begin
    if A1EditFile[i].Name=fileName then begin
      fileIndex:=i;
      Result:=@A1EditFile[i];
      exit;
    end;
  end;
end;
function EditFiles_load(fpath : string; showFiles : boolean = false) : boolean;
var len, i : cardinal;
    pEditFile : TPEditFile;
    oldMainBuffer : TObjectBuffer;
begin
  oldMainBuffer:=G_MainBuffer;
  G_MainBuffer:=nil;
  freebuffer;
  Result:=false;
  SetLength(A1EditFile, 0);
  if not ReadBufferFromFile(fpath) then begin
    freebuffer;
    G_MainBuffer.Destroy;
    G_MainBuffer:=oldMainBuffer;
    exit;
  end;
  len:=readuint;
  SetLength(A1EditFile, len);
  if len<>0 then for i:=0 to len-1 do begin
    pEditFile:=@A1EditFile[i];
    pEditFile^.Name:=readstring;
    pEditFile^.Ver:=readuint;
    pEditFile^.Ver_lastExported:=readuint;
  end;
  Result:=true;
  freebuffer;
  G_MainBuffer.Destroy;
  G_MainBuffer:=oldMainBuffer;
end;
procedure EditFiles_save(fpath : string);
var len, i : cardinal;
    oldMainBuff : TObjectBuffer;
    pEditFile : TPEditFile;
begin
  oldMainBuff:=G_MainBuffer;
  G_MainBuffer:=nil;
  freebuffer;
  len:=length(A1EditFile);
  writeuint(len);
  if len<>0 then for i:=0 to len-1 do begin
    pEditFile:=@A1EditFile[i];
    writestring(pEditFile^.Name);
    writeuint(pEditFile^.Ver);
    writeuint(pEditFile^.Ver_lastExported);
  end;
  WriteBufferToFile(fpath, true);
  freebuffer;
  G_MainBuffer.Destroy;
  G_MainBuffer:=oldMainBuff;
end;
//EditFiles_delete
procedure EditFiles_delete(fileName : string);
var index : integer;
begin
  EditFiles_find(fileName, index);
  if index<>-1 then
    EditFiles_delete(index);
end;
procedure EditFiles_delete(index : cardinal);
var i2, len : cardinal;
begin
  // Suppression de la liste A1ClientFile les fichiers qui ne sont plus sur le disque
  len:=length(A1EditFile);
  if index>=len then exit;
  // Suppression du fichier de la liste A1EditFile
  if index<>len-1 then for i2:=index to len-2 do begin
    A1EditFile[i2]:=A1EditFile[i2+1];
  end;
  SetLength(A1EditFile, len-1);
end;
//EditFiles_updateFileVer_addFile
function EditFiles_updateFileVer_addFile(fileName : string) : TPEditFile; // seulement appelé depuis EditFiles_updateFileVer
var len : cardinal;
    pEditFile : TPEditFile;
begin
  len:=length(A1EditFile);
  SetLength(A1EditFile, len+1);
  pEditFile:=@A1EditFile[len];
  pEditFile^.Name:=fileName;
  pEditFile^.Ver:=1;
  pEditFile^.temp_isUsed:=true;
  Result:=pEditFile;
end;
//EditFiles_updateFileVer
function EditFiles_updateFileVer(fName : string; changerVer : boolean = false) : TPEditFile; // Incrémentation de la version ou ajout d'un fichier
var index : integer;
    pEditFile : TPEditFile;
begin
  pEditFile:=EditFiles_find(fName, index);
  if pEditFile=nil then begin
     pEditFile:=EditFiles_updateFileVer_addFile(fName);
  end;
  pEditFile^.temp_isUsed:=true;
  if changerVer then begin
    pEditFile^.Ver:=pEditFile^.Ver+1;
  end;
  Result:=pEditFile;
end;
//EditFiles_updateFromDisk
// rootDir inclut le \ final
procedure EditFiles_updateFromDisk(rootDir : string; updateVersionForAll : boolean = false);
var sRec : TSearchRec;
    i, len : cardinal;
begin
  len:=length(A1EditFile);
  if len<>0 then for i:=0 to len-1 do begin
    A1EditFile[i].temp_isUsed:=false; // sera supprimé si non présent sur le disque
  end;
  // Je trouve les fichiers sur le disque (un seul dossier, et les noms sont uniques à chaque fichier)
  if FindFirst(rootDir+'*.*', faAnyFile, sRec)<>0 then exit;
  repeat
    // Je regarde si le fichier est valide (ou est un dossier)
    if (sRec.Name<>'.') and (sRec.Name<>'..') then
    if true then begin//(sRec.Attr<>faHidden) and (sRec.Attr<>faSysFile) and (sRec.Attr<>faVolumeId) and (sRec.Attr<>faArchive) and (sRec.Attr<>faSymLink) then begin
      if (sRec.Attr and faDirectory)<>faDirectory then begin // Si le fichier est valide, je l'ajoute
        EditFiles_updateFileVer(sRec.Name, false); // temp_isUsed=true si le fichier est déjà présent
      end;
    end;
  until FindNext(sRec)<>0;
  FindClose(sRec);
  // SUppression des fichiers qui ne sont plus sur le disque
  len:=length(A1EditFile);
  i:=0;
  while i<len do begin
    if not A1EditFile[i].temp_isUsed then begin
      EditFiles_delete(i);
      len:=len-1;
    end else
      i:=i+1;
  end;
end;
//ShowEditFiles
procedure ShowEditFiles;
var len, i : cardinal;
    lastDir : string;
begin
  lastDir:='';
  len:=length(A1EditFile);
  if len=0 then exit;
  for i:=0 to len-1 do begin
    WriteLn('  '+A1EditFile[i].Name);
  end;
end;
//EditFiles_setExportVer
procedure EditFiles_setExportVer(fileName : string);
var pEditFile : TPEditFile;
    index : integer;
begin
  pEditFile:=EditFiles_find(fileName, index);
  if pEditFile<>nil then pEditFile^.Ver_lastExported:=pEditFile^.Ver;
end;
procedure EditFiles_setExportVer(fileIndex : cardinal);
var pEditFile : TPEditFile;
    len : cardinal;
begin
  len:=length(A1EditFile);
  if fileIndex>=len then exit;
  pEditFile:=@A1EditFile[fileIndex];
  pEditFile^.Ver_lastExported:=pEditFile^.Ver;
end;
function EditFiles_doExport(fileName, filePathDest : string) : boolean;
var pEditFile : TPEditFile;
    index : integer;
    forceExport : boolean;
begin
  //showMessage('EditFiles_doExport fileName='+fileName+' filePathDest='+filePathDest);
  Result:=true;
  pEditFile:=EditFiles_find(fileName, index);
  if pEditFile=nil then begin // Ajout du fichier, il est nouveal
    pEditFile:=EditFiles_updateFileVer_addFile(fileName);
    //showMessage('EditFiles_doExport : ajout du fichier fileName='+fileName);
    forceExport:=true;
  end else
    forceExport:=false;   
  //showMessage('EditFiles_doExport 1');

  // Ajout à la liste des fichiers du serveur d'update
  ExportUpdateServer_addFile(pEditFile^.Name, pEditFile^.Ver);  
  //showMessage('EditFiles_doExport 2');

  // Si le fichier n'existe pas, je l'ajoute à la liste A1EditFile
  if not forceExport then
  if (pEditFile^.Ver_lastExported=pEditFile^.Ver) then begin
    //showMessage('EditFiles_doExport : verOK, fileName='+fileName+'  filePathDest='+filePathDest);
    if FileExists(filePathDest) then begin // si les versions sont identiques mais que le fichier destination n'existe pas, je copie (retourne true)
      Result:=false; // pas besoin d'exporter
      //showMessage('EditFiles_doExport : ne pas exporter existe='+booltostr(FileExists(filePathDest), true)+', fileName='+fileName+'  filePathDest='+filePathDest);
      exit;
    end;
  end;  
  //Result:=true;
  {if not FileExists(filePathDest) then
    ShowMessage('EditFiles_doExport : exporter (not fileExists) ver : '+inttostr(pEditFile^.Ver_lastExported)+' -> '+inttostr(pEditFile^.Ver))
  else
    ShowMessage('EditFiles_doExport : exporter (fileExists !) ver : '+inttostr(pEditFile^.Ver_lastExported)+' -> '+inttostr(pEditFile^.Ver));
  }
  //ShowMessage('EditFiles_doExport : exporter ver : '+inttostr(pEditFile^.Ver_lastExported)+' -> '+inttostr(pEditFile^.Ver));
  pEditFile^.Ver_lastExported:=pEditFile^.Ver;
  //showMessage('EditFiles_doExport 3');
end;

//EditFiles_deleteUnknownFiles
// Supprime tous les fichiers du répertoire 'rootDir' et de ses sous-répetroires, s'ils ne figurent pas dans la liste A1EditFile
// rootDir inclut le \ final
procedure EditFiles_deleteUnknownFiles(rootDir : string);
var sRec : TSearchRec;
    pEditFile : TPEditFile;
    index : integer;
begin
  //ShowMessage('EditFiles_deleteUnknownFiles : dossier='+rootdir);
  // Je trouve les fichiers sur le disque
  if FindFirst(rootDir+'*.*', faAnyFile, sRec)<>0 then exit;
  repeat
    // Je regarde si le fichier est valide (ou est un dossier)
    if (sRec.Name<>'.') and (sRec.Name<>'..') then
    if true then begin//(sRec.Attr<>faHidden) and (sRec.Attr<>faSysFile) and (sRec.Attr<>faVolumeId) and (sRec.Attr<>faArchive) and (sRec.Attr<>faSymLink) then begin
      if (sRec.Attr and faDirectory)<>faDirectory then begin // Si le fichier est valide, je l'ajoute
        //EditFiles_updateFileVer(sRec.Name, false); // temp_isUsed=true si le fichier est déjà présent
        pEditFile:=EditFiles_find(sRec.Name, index);
        if pEditFile=nil then begin // fichier non présent
          if (not EditFiles_doNotDelete_exists(sRec.Name)) then begin // et pas à garder sans pourtant n'être présent dans A1EditFile
            TryDeleteFile(rootDir+sRec.Name);
            //ShowMessage('EditFiles_deleteUnknownFiles : pEditFile=nil; delete sRec.Name='+sRec.Name);
          end;
        end;
      end else EditFiles_deleteUnknownFiles(rootDir+sRec.Name+'\');
    end;
  until FindNext(sRec)<>0;
  FindClose(sRec);
end;

procedure EditFiles_doNotDelete_add(fName : string); // fichiers à ne pas supprimer, mais non présents dans A1EditFle
var len : cardinal;
begin
  len:=length(A1EditFile_doNotDelete);
  SetLength(A1EditFile_doNotDelete, len+1);
  A1EditFile_doNotDelete[len]:=fName;
end;
procedure EditFiles_doNotDelete_clear; // remet la taille de la liste A1EditFile_doNotDelete à 0  
begin                       
  SetLength(A1EditFile_doNotDelete, 0);
end;
function EditFiles_doNotDelete_exists(fName : string) : boolean; // retourne true si le fichier existe dans A1EditFile_doNotDelete
var len, i : cardinal;
begin
  Result:=false;
  len:=length(A1EditFile_doNotDelete);
  if len<>0 then for i:=0 to len-1 do begin
    if A1EditFile_doNotDelete[i]=fName then begin
      Result:=true;  // est dans la liste
      exit;
    end;
  end;
end;

procedure EditFiles_clear;
begin
  SetLength(A1EditFile, 0);
end;


procedure ExportUpdateServer_clear;
begin
  SetLength(A1ExportUpdateServerFile, 0);
end;
procedure ExportUpdateServer_addFile(fName : string; ver : cardinal);
var len : cardinal; // Je vérifie que le fichier n'existe bien pas, par sécurité, mâma si clear est fait avant l'exportation
    pUpdateFile : TPExportUpdateServerFile;
    index : integer;
begin
  {len:=length(A1ExportUpdateServerFile);
  if len<>0 then for i:=0 to len-1 do begin // je vérifie quand-même par sécurité
    pUpdateFile:=@A1ExportUpdateServerFile[i];
    if pUpdateFile^.Name=fName then begin
      pUpdateFile^.Ver:=ver;
      exit;
    end;
  end;}
  pUpdateFile:=ExportUpdateServer_find(fName, index);
  if pUpdateFile<>nil then begin
    pUpdateFile^.Ver:=ver;
    exit;
  end;
  len:=length(A1ExportUpdateServerFile);
  SetLength(A1ExportUpdateServerFile, len+1);
  pUpdateFile:=@A1ExportUpdateServerFile[len];
  pUpdateFile^.Name:=fName;
  pUpdateFile^.Ver:=ver;
end;
procedure ExportUpdateServer_deleteFile(index : cardinal);
var i2, len : cardinal;
begin
  len:=length(A1ExportUpdateServerFile);
  if index>=len then exit;
  // Suppression du fichier de la liste A1ExportUpdateServerFile
  if index<>len-1 then for i2:=index to len-2 do begin
    A1ExportUpdateServerFile[i2]:=A1ExportUpdateServerFile[i2+1];
  end;
  SetLength(A1ExportUpdateServerFile, len-1);
end;
procedure ExportUpdateServer_deleteFile(fName : string);
var index : integer;
begin
  ExportUpdateServer_find(fName, index);
  //showMessage('ExportUpdateServer_deleteFile : fName='+fName+' index='+inttostr(index));
  if index<>-1 then
    ExportUpdateServer_deleteFile(index);
end;
function ExportUpdateServer_find(fName : string; var index : integer) : TPExportUpdateServerFile;
var len, i : cardinal; // Je vérifie que le fichier n'existe bien pas, par sécurité, mâma si clear est fait avant l'exportation
    pUpdateFile : TPExportUpdateServerFile;
begin
  Result:=nil;
  index:=-1;
  len:=length(A1ExportUpdateServerFile);
  if len<>0 then for i:=0 to len-1 do begin // je vérifie quand-même par sécurité
    pUpdateFile:=@A1ExportUpdateServerFile[i];
    if pUpdateFile^.Name=fName then begin
      Result:=pUpdateFile;
      index:=i;
      exit;
    end;
  end;
end;
procedure ExportUpdateServer_save(servFilePath : string);   
var len, i : cardinal;
    oldMainBuff : TObjectBuffer;
    pUpdateFile : TPExportUpdateServerFile;
begin
  oldMainBuff:=G_MainBuffer;
  G_MainBuffer:=nil;
  freebuffer;
  len:=length(A1ExportUpdateServerFile);
  writeuint(len);
  if len<>0 then for i:=0 to len-1 do begin
    pUpdateFile:=@A1ExportUpdateServerFile[i];
    writestring(pUpdateFile^.Name);
    writeuint(pUpdateFile^.Ver);
  end;
  WriteBufferToFile(servFilePath, true);
  freebuffer; G_MainBuffer.Destroy;
  G_MainBuffer:=oldMainBuff;
end;
function ExportUpdateServer_load(fpath : string) : boolean;
var len, i : cardinal;
    pUpdateFile : TPExportUpdateServerFile;
begin
  Result:=false;
  SetLength(A1ExportUpdateServerFile, 0);
  if not ReadBufferFromFile(fpath) then exit;
  len:=readuint;
  SetLength(A1ExportUpdateServerFile, len);
  if len<>0 then for i:=0 to len-1 do begin
    pUpdateFile:=@A1ExportUpdateServerFile[i];
    pUpdateFile^.Name:=readstring;
    pUpdateFile^.Ver:=readuint;
  end;
  Result:=true;
end;

procedure ExportUpdateServer_deleteUnknownFiles(rootDir : string);
var sRec : TSearchRec;
    pUpdateFile : TPExportUpdateServerFile;
    index : integer;
begin
  //ShowMessage('EditFiles_deleteUnknownFiles : dossier='+rootdir);
  // Je trouve les fichiers sur le disque
  if FindFirst(rootDir+'*.*', faAnyFile, sRec)<>0 then exit;
  repeat
    // Je regarde si le fichier est valide (ou est un dossier)
    if (sRec.Name<>'.') and (sRec.Name<>'..') then
    if true then begin//(sRec.Attr<>faHidden) and (sRec.Attr<>faSysFile) and (sRec.Attr<>faVolumeId) and (sRec.Attr<>faArchive) and (sRec.Attr<>faSymLink) then begin
      if (sRec.Attr and faDirectory)<>faDirectory then begin // Si le fichier est valide, je l'ajoute
        //EditFiles_updateFileVer(sRec.Name, false); // temp_isUsed=true si le fichier est déjà présent
        pUpdateFile:=ExportUpdateServer_find(sRec.Name, index);
        if pUpdateFile=nil then begin // fichier non présent
         // if (not EditFiles_doNotDelete_exists(sRec.Name)) then begin // et pas à garder sans pourtant n'être présent dans A1EditFile
            TryDeleteFile(rootDir+sRec.Name);
            //ShowMessage('EditFiles_deleteUnknownFiles : pEditFile=nil; delete sRec.Name='+sRec.Name);
          //end;
        end;
      end else ExportUpdateServer_deleteUnknownFiles(rootDir+sRec.Name+'\');
    end;
  until FindNext(sRec)<>0;
  FindClose(sRec);
end;

end.
