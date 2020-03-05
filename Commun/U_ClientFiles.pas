unit U_ClientFiles;

interface
uses SysUtils, U_Sockets4, dialogs;//, U_UpdaterServRapport;
// Gestion des fichiers du client

var listClientFile_servFileId : cardinal;
type TClientFile = record
  Dir, Name : string; // Dir sans le dernier backslash
  Ver : cardinal; // La version du fichier
  servFileId : cardinal;
  temp_isUsed : boolean; // juste pour la procédure ListClientFiles_updateFileFromDisk
  FileSize : cardinal; // taille du fichier en octets, lu du disque à chaque démérage
end;
type TPClientFile = ^TClientFile;
type TA1ClientFile = array of TClientFile;
var A1ClientFile : TA1ClientFile;
type TPA1ClientFile = ^TA1ClientFile;
//type PTClientFile = ^TClientFile;

var G_EditFileList_filesLocation : string;
var G_EditFileList_saveFileLocation : string;

procedure ListClientFiles(dirPath : string); // dirPath sans le dernier backslash.
procedure ShowClientFiles;
function ListClientFiles_load(fpath : string; pA1OtherClientFile : TPA1ClientFile = nil) : boolean;
procedure ListClientFiles_save(fpath : string; pA1OtherClientFile : TPA1ClientFile = nil);
procedure GameServer_initClientFiles(showFiles : boolean = false);
procedure GameServer_addClientFilesList;
function GameServer_getClientFileFromId(fileId : cardinal) : TPClientFile;//PTClientFile;
function GameServer_getClientFileFromIndex(fileIndex : cardinal) : TPClientFile;
function ListClientFiles_updateFileVer(fDir, fName : string; changerVer : boolean = true; refreshSizeFromDisk : boolean = false) : TPClientFile; // Incrémentation de la version ou ajout d'un fichier
procedure ListClientFiles_updateFromDisk(rootDir : string; updateVersionForAll : boolean = false; refreshSizeFromDisk : boolean = false);
procedure ListClientFiles_updateFromEditorFile(editorFilePath : string; refreshSizeFromDisk : boolean = false); // /!\ faire ListClientFiles_load avant de charger le fichier éditeur !
function ListClientFiles_updateFileVerFromNameOnly(fName : string; newVer : cardinal; refreshSizeFromDisk : boolean = false) : TPClientFile;
function ListClientFiles_find(fDir, fName : string; var index : integer) : TPClientFile;
function UpdateFileSizeFromDisk(fileDir, fileName : string) : boolean; overload; // met à jour la taille du fichier à partir du disque (utile en cas de modification)
function UpdateFileSizeFromDisk(indexInA1ClientFiles : cardinal) : boolean; overload;


procedure ListClientFiles_findEachFileSize; // lire la taille de chaque fichier à partir du disque

procedure ListClientFiles_showNotInEditList;
var G_oldExportFileAge : integer; // pour la mise à jour auto

implementation
uses U_Files, U_NetSys4, U_Arrays, U_ClientFiles_Editor, U_UpdaterServ_updateWoriaExe;

procedure WriteLn(str : string);
begin
  if WriteLnCustom_isDefined then begin
    try
      WriteLnCustom(str);
    except
    end;
  end else begin
    // System.WriteLn(str); enlevé pour ne pas faire buger
  end;
end;

procedure ListClientFiles_add(var A1ClientFile : TA1ClientFile; var sRec : TSearchRec; dir : string);
var len : cardinal;
begin
  len:=length(A1ClientFile);
  SetLength(A1ClientFile, len+1);
  A1ClientFile[len].Name:=sRec.Name;
  A1ClientFile[len].Dir:=dir;
  A1ClientFile[len].Ver:=1;
  A1ClientFile[len].servFileId:=listClientFile_servFileId;
  listClientFile_servFileId:=listClientFile_servFileId+1; // Réinitialisé sur ListClientFiles.
  //WriteLn('Add '+A1ClientFile[len].Dir+'  '+A1ClientFile[len].Name);
end;

procedure ListClientFiles_recur(dirPath : string; var A1ClientFile : TA1ClientFile); // dirPath sans le dernier backslash.
var sRec : TSearchRec;
begin
  //WriteLn('ListClientFiles : '+dirPath);
  if FindFirst(dirPath+'\*.*', faAnyFile, sRec)<>0 then exit;
  repeat
    // Je regarde si le fichier est valide (ou est un dossier)
    if (sRec.Name<>'.') and (sRec.Name<>'..') then
    if true then begin//(sRec.Attr<>faHidden) and (sRec.Attr<>faSysFile) and (sRec.Attr<>faVolumeId) and (sRec.Attr<>faArchive) and (sRec.Attr<>faSymLink) then begin
      // Si le fichier est valide
      if (sRec.Attr and faDirectory)=faDirectory then ListClientFiles_recur(dirPath+'\'+sRec.Name, A1ClientFile)
                                                 else ListClientFiles_add(A1ClientFile, sRec, dirPath);
    end;
  until FindNext(sRec)<>0;
  FindClose(sRec);
end;

type TLcfDir = record
  DirName : string;
  A1FileId : TCardinalArray;
end;
type PTLcfDir = ^TLcfDir;
type TA1LcfDir = array of TLcfDir;
type PTA1LcfDir = ^TA1LcfDir;

// Ajoute/trouve le dossier et retourne un pointeur vers le dossier
function Lcf_addDir(dirName : string; var A1LcfDir : TA1LcfDir) : PTLcfDir;
var i, len : cardinal;
begin
  // Je recherche le dossier. S'il n'existe pas, je l'ajoute.
  len:=length(A1LcfDir);
  if len<>0 then for i:=0 to len-1 do
  if A1LcfDir[i].DirName=dirName then begin
    Result:=@A1LcfDir[i];
    exit;
  end;
  //WriteLn('ADD '+dirName+' len='+inttostr(len));
  SetLength(A1LcfDir, len+1);
  A1LcfDir[len].DirName:=dirName;
  //SetLength(A1LcfDir[len].A1FileId, 0); // implicite
  Result:=@A1LcfDir[len];
end;

procedure Lcf_addDirFile(dirName : string; var A1LcfDir : TA1LcfDir; fileId : cardinal);
var len : cardinal;
    pDir : PTLcfDir;
begin
  pDir:=Lcf_addDir(dirName, A1LcfDir);
  len:=length(pDir^.A1FileId); // J'ajoute l'id du fichier
  SetLength(pDir^.A1FileId, len+1);
  pDir^.A1FileId[len]:=fileId;
end;

procedure ListClientFiles(dirPath : string); // dirPath sans le dernier backslash.
var rawA1ClientFile : TA1ClientFile;
    len, i, len2, i2, i3 : cardinal;
    A1LcfDir : TA1LcfDir;
begin
  // Je dresse un tableau de tous les dossiers
  ListClientFiles_recur(dirPath, rawA1ClientFile);
  listClientFile_servFileId:=0;
  //WriteLn(length(rawA1ClientFile));
  len:=length(rawA1ClientFile);
  SetLength(A1ClientFile, len);
  SetLength(A1LcfDir, 0);
  if len=0 then exit;
  for i:=0 to len-1 do begin // Tous les fichiers
    //WriteLn('LEN A1LcfDir = '+inttostr(length(A1LcfDir))+' '+rawA1ClientFile[i].Dir);
    Lcf_addDirFile(rawA1ClientFile[i].Dir, A1LcfDir, rawA1ClientFile[i].servFileId);
    {if rawA1ClientFile[i].Dir<>lastDirName then begin
      lastDirName:=rawA1ClientFile[i].Dir;
      Lcf_addDirFile();
    end;}
  end;

  len:=length(A1LcfDir);
  if len=0 then exit; // ne doit jamais arriver
  //WriteLn('Nombre de dossiers : '+inttostr(len));
  i3:=0;
  for i:=0 to len-1 do begin
    len2:=length(A1LcfDir[i].A1FileId);
    //WriteLn('Dossier : '+A1LcfDir[i].DirName+' taille '+inttostr(len2));
    if len2<>0 then for i2:=0 to len2-1 do begin // Len2 ne doit normalement jamais être nul.
      A1ClientFile[i3]:=rawA1ClientFile[A1LcfDir[i].A1FileId[i2]]; // L'id équivant à l'index ici.
      A1ClientFile[i3].servFileId:=i3; // Nouvel Id
      A1ClientFile[i3].Ver:=1;
      i3:=i3+1;
    end;
  end;
  listClientFile_servFileId:=i3;
end;

function ListClientFiles_find(fDir, fName : string; var index : integer) : TPClientFile;
var pClientFile : TPClientFile;
    i, len : integer;
begin
  Result:=nil;
  index:=-1;
  len:=length(A1ClientFile);
  if len<>0 then for i:=0 to len-1 do begin
    pClientFile:=@A1ClientFile[i];
    if (pClientFile^.Dir=fDir) then
    if (pClientFile^.Name=fName) then begin
      Result:=pClientFile;
      exit; // (il y a unicité)
    end;
  end;
end;

// Inctémentation de la version ou ajout d'un fichier
function ListClientFiles_updateFileVer(fDir, fName : string; changerVer : boolean = true; refreshSizeFromDisk : boolean = false) : TPClientFile; // si changerVer, c'est juste une vérification et un ajout si le fichier n'existe pas
var pClientFile : TPClientFile;
    dossierOkFileIndex, realIndex, i, len : integer;
begin
  //WriteLn('ListClientFiles_updateFileVer fName='+fName);
  dossierOkFileIndex:=-1; // cas de l'ajout (fichier encore inexistant)
  len:=length(A1ClientFile);
  if len<>0 then for i:=0 to len-1 do begin
    pClientFile:=@A1ClientFile[i];
    if (pClientFile^.Dir=fDir) then begin
      dossierOkFileIndex:=i+1; // i+1 : ajout après ce fichier, pas avant
      if (pClientFile^.Name=fName) then begin
        if changerVer then pClientFile^.Ver:=pClientFile^.Ver+1; // incrémentation de la version
        pClientFile^.temp_isUsed:=true;
        Result:=pClientFile;
        if refreshSizeFromDisk then
          UpdateFileSizeFromDisk(i);

        //WriteLn('->Trouvé');
        exit; // (il y a unicité)
      end;
    end;
  end;
  // Si j'en suis là, c'est que le fichier n'existe pas encore, je l'ajoute
  // -> je lui trouve un bon index (dans le bon dossier)
  SetLength(A1ClientFile, len+1);

  if dossierOkFileIndex=-1 then begin
    pClientFile:=@A1ClientFile[len];
    //dossierOkFileIndex:=len;
  end else begin // je décale tous les fichiers suivants
    if (len<>1) then for i:=dossierOkFileIndex to len-2 do begin  // len>=1, ne peut égaler 0, je ne décale que si len>=2
      realIndex:=len-1-integer(i-dossierOkFileIndex); // je pars de la fin
      A1ClientFile[realIndex]:=A1ClientFile[realIndex-1];
      //de len-1-dossierOkFileIndex+dossierOkFileIndex=len-1
      //à len-1-len+2+dossierOkFileIndex=-1+2+dossierOkFileIndex=dossierOkFileIndex+1
      // realIndex va de len-1 à dossierOkFileIndex+1 (décroissant)
    end;
    pClientFile:=@A1ClientFile[dossierOkFileIndex];
  end;
  pClientFile^.Dir:=fDir;
  pClientFile^.Name:=fName;
  pClientFile^.Ver:=1;
  pClientFile^.temp_isUsed:=true;
  listClientFile_servFileId:=listClientFile_servFileId+1;
  pClientFile^.servFileId:=listClientFile_servFileId; // pour l'updater (client et serveur)
  //WriteLn('ListClientFiles_updateFileVer : add '+fName+' from '+fDir+' à index='+inttostr(dossierOkFileIndex));
  Result:=pCLientFile;
end;

// Inctémentation de la version ou ajout d'un fichier
function ListClientFiles_updateFileVerFromNameOnly(fName : string; newVer : cardinal; refreshSizeFromDisk : boolean = false) : TPClientFile; // si changerVer, c'est juste une vérification et un ajout si le fichier n'existe pas
// Pas d'ajout de fichier, c'est pour ça qu'il faut vraiment faire ListClientFiles_updateFromDisk avant d'executer ce script
var pClientFile : TPClientFile;
    i, len : integer;
begin
  Result:=nil;
  len:=length(A1ClientFile);
  if len<>0 then for i:=0 to len-1 do begin
    pClientFile:=@A1ClientFile[i];
    if (pClientFile^.Name=fName) then begin
      //WriteLn('ListClientFiles_updateFileVerFromNameOnly : '+fName+' ver '+inttostr(pClientFile^.Ver)+' -> '+inttostr(newVer));
      pClientFile^.Ver:=newVer; // nouvelle version
      Result:=pClientFile;
      exit; // (il y a unicité)
    end;
  end;
  // Des fichiers ne seront pas trouvés, c'est
  WriteLn('ERREUR ListClientFiles_updateFileVerFromNameOnly : non trouvé ('+fName+')');
end;

procedure ListClientFiles_updateFromDisk_recur(dirPath : string; updateVersionForAll : boolean; refreshSizeFromDisk : boolean = false); // dirPath sans le dernier backslash.
var sRec : TSearchRec;
begin
  //WriteLn('ListClientFiles : '+dirPath);
  if FindFirst(dirPath+'\*.*', faAnyFile, sRec)<>0 then exit;
  repeat
    // Je regarde si le fichier est valide (ou est un dossier)
    if (sRec.Name<>'.') and (sRec.Name<>'..') then
    if true then begin//(sRec.Attr<>faHidden) and (sRec.Attr<>faSysFile) and (sRec.Attr<>faVolumeId) and (sRec.Attr<>faArchive) and (sRec.Attr<>faSymLink) then begin
      // Si le fichier est valide
      if (sRec.Attr and faDirectory)=faDirectory then begin
        ListClientFiles_updateFromDisk_recur(dirPath+'\'+sRec.Name, updateVersionForAll); // répertoire
      end else begin
        ListClientFiles_updateFileVer(dirPath, sRec.Name, updateVersionForAll, refreshSizeFromDisk); // fichier à ajouter
      end;
    end;
  until FindNext(sRec)<>0;
  FindClose(sRec);
end;

// Mise à jour de la liste A1ClientFiles à partir du disque (ajout des nouveaux fichiers)
procedure ListClientFiles_updateFromDisk(rootDir : string; updateVersionForAll : boolean = false; refreshSizeFromDisk : boolean = false);
var i, i2, len : cardinal;
    pClientFile : TPClientFile;
begin
  len:=length(A1ClientFile);
  if len<>0 then for i:=0 to len-1 do begin
    A1ClientFile[i].temp_isUsed:=false; // sera supprimé si non présent sur le disque
  end;
  // Mise à jour
  ListClientFiles_updateFromDisk_recur(rootDir, updateVersionForAll, refreshSizeFromDisk);
  // Suppression de la liste A1ClientFile les fichiers qui ne sont plus sur le disque
  i:=0;
  len:=length(A1ClientFile);
  while i<len do begin
    pClientFile:=@A1ClientFile[i];
    if not pClientFile^.temp_isUsed then begin // suppression du fichier
      if (pClientFile^.Name='') or (pClientFile^.Dir='') then begin
        WriteLn('ERROR ListClientFiles_updateFromDisk : delete !empty name! (index='+inttostr(i)+') ('+pClientFile^.Name+') from ('+pClientFile^.Dir+')');
        i:=i+1;
        continue;
      end;
      // SUppression du fichier de la liste A1ClientFile
      if i<>len-1 then for i2:=i to len-2 do begin
        A1ClientFile[i2]:=A1ClientFile[i2+1];
      end;
      len:=len-1; // SetLength à la fin
    end else
      i:=i+1;
  end;
  SetLength(A1ClientFile, len);
end;


// Sauvegarde de A1ClientFile
procedure ListClientFiles_save(fpath : string; pA1OtherClientFile : TPA1ClientFile = nil);
var len, i : cardinal;
    lastDir, dir : string;
    oldMainBuffer : TObjectBuffer;
    pA1ClientFile : TPA1ClientFile;
begin
  if pA1OtherClientFile=nil then pA1ClientFile:=@A1ClientFile
                            else pA1ClientFile:=pA1OtherClientFile; 
  //if pA1ClientFile=@A1ClientFile then ShowMessage('ListClientFiles_save pA1ClientFile=@A1ClientFile ');
  oldMainBuffer:=G_MainBuffer;
  G_MainBuffer:=nil;
  freebuffer;
  len:=length(pA1ClientFile^);
  //ShowMessage('ListClientFiles_save : len='+inttostr(len));
  writeuint(listClientFile_servFileId);                 
  writeuint(len);
  lastDir:='';
  if len<>0 then for i:=0 to len-1 do begin
    dir:=pA1ClientFile^[i].Dir;
    if dir<>lastDir then begin // tri par dossier (effectué vie ListClientFiles)
      writebool(true);
      writestring(dir);
      lastDir:=dir;
    end else writebool(false); // Pas de nouveau dossier (bien plus court que le nom complet du dossier)
    writestring(pA1ClientFile^[i].Name);
    writeuint(pA1ClientFile^[i].Ver);
    writeuint(pA1ClientFile^[i].servFileId);
  end;
  WriteBufferToFile(fpath, true);
  G_MainBuffer.Destroy;
  G_MainBuffer:=oldMainBuffer;
end;
// Chargement de A1ClientFile
function ListClientFiles_load(fpath : string; pA1OtherClientFile : TPA1ClientFile = nil) : boolean;
var len, i : cardinal;
    cDir : string;
    newDir : boolean;
    oldMainBuffer : TObjectBuffer;
    pA1ClientFile : TPA1ClientFile;
begin
  if pA1OtherClientFile=nil then pA1ClientFile:=@A1ClientFile
                            else pA1ClientFile:=pA1OtherClientFile;
  //if pA1ClientFile=@A1ClientFile then ShowMessage('ListClientFiles_load pA1ClientFile=@A1ClientFile ');
  oldMainBuffer:=G_MainBuffer;
  G_MainBuffer:=nil;
  freebuffer;
  //WriteLn('ListClientFiles_load : fpath='+fpath);
  Result:=false;
  SetLength(pA1ClientFile^, 0);
  if not ReadBufferFromFile(fpath) then begin
    freebuffer;
    G_MainBuffer.Destroy;
    G_MainBuffer:=oldMainBuffer;
    exit;
  end;
  //WriteLn('ListClientFiles_load : ReadBufferFromFile ok');
  listClientFile_servFileId:=readuint;
  len:=readuint;        
  SetLength(pA1ClientFile^, len);
  cDir:=''; // pas de dossier encore
  if len<>0 then for i:=0 to len-1 do begin
    newDir:=readbool;
    if newDir then cDir:=readstring; // Je ferai après le tri par dossier
    pA1ClientFile^[i].Dir:=cDir;
    pA1ClientFile^[i].Name:=readstring;
    pA1ClientFile^[i].Ver:=readuint;
    pA1ClientFile^[i].servFileId:=readuint;
    //if (A1ClientFile[i].servFileId=4) or (A1ClientFile[i].servFileId=3) then
    //  A1ClientFile[i].Ver:=A1ClientFile[i].Ver+1;
  end;
  //ListClientFiles_save(A1ClientFile, 'ClientFiles.sys');

  //ShowMessage('ListClientFiles_load : len='+inttostr(len));
  //ShowMessage('ListClientFiles_load : index 52 : name('+pA1ClientFile^[52].Name+') dir('+pA1ClientFile^[52].Dir+') ver('+inttostr(pA1ClientFile^[52].Ver)+')');
  //ShowMessage('ListClientFiles_load : index '+inttostr(len-1)+' : name('+pA1ClientFile^[len-1].Name+') dir('+pA1ClientFile^[len-1].Dir+') ver('+inttostr(pA1ClientFile^[len-1].Ver)+')');

  Result:=true;                                      
  freebuffer;
  G_MainBuffer.Destroy;
  G_MainBuffer:=oldMainBuffer;
end;

// j'envoie au client la liste des fichiers qu'il devrait avoir (dossier + nom fichier + version)
// -> ordonner les fichiers par dossier pour ne pas avoir à systématiquement envoyer le dossier.
// Le client regarde les fichiers qu'il n'a pas, et les demande au serveur (évidemment, il va demander un id de fichier associé à un chemin sur le serveur, et non le nom du fichier, pour des raisons de sécurité)

procedure ShowClientFiles;
var len, i : cardinal;
    lastDir : string;
begin
  lastDir:='';
  len:=length(A1ClientFile);
  if len=0 then exit;
  for i:=0 to len-1 do begin
    if lastDir<>A1ClientFile[i].Dir then begin
      lastDir:=A1ClientFile[i].Dir;
      WriteLn('Dossier '+lastDir);
    end;
    WriteLn('  '+A1ClientFile[i].Name+' -ver'+inttostr(A1ClientFile[i].Ver));
  end;
end;


// Initialisation des fichiers à télécharger par le client
procedure GameServer_initClientFiles(showFiles : boolean = false);  // Obsolète car géré par l'updater uniquement. (en local, pour les tests, le client du jeu copie les fichiers du dossier éditeur)
begin
  //if not ListClientFiles_load('ClientFiles.sys', showFiles) then
    ListClientFiles('ClientFiles');
  //else
  //  ListClientFiles_updateFromDisk('ClientFiles', false);

  // Chargement du fichier des versions éditeur
  ListClientFiles_updateFromEditorFile('ExportUpdaterServerFiles.sys');
  FlowWoriaExeVersion(tyRead);
  // Sauvegarde dans le cas de la création de la liste ET de la mise à jour
  //ListClientFiles_save('ClientFiles.sys');
  WriteLn('GameServer_initClientFiles : nbFichiersTotal='+inttostr(length(A1ClientFile)));
  ListClientFiles_showNotInEditList;
  ListClientFiles_findEachFileSize; // lecture du disque de la taille de chaque fichier
  //ShowClientFiles(A1ClientFile);
end;

procedure GameServer_addClientFilesList;
var i, len : cardinal;    // Comme pour le ListClientFiles_save
    lastDir, dir : string;
begin
  len:=length(A1ClientFile); // A1ClientFile est une variable globale
  writeuint(len);
  lastDir:='';
  if len<>0 then for i:=0 to len-1 do begin
    dir:=A1ClientFile[i].Dir;
    if dir<>lastDir then begin // tri par dossier (effectué via ListClientFiles)
      writebool(true);
      writestring(dir);
      lastDir:=dir;
    end else writebool(false); // Pas de nouveau dossier (bien plus court que le nom complet du dossier)
    writestring(A1ClientFile[i].Name);
    writeushort(A1ClientFile[i].Ver);  // Différence avec le save : ushort et non uint.
    writeuint(A1ClientFile[i].FileSize);
    // index connu ^^ writeushort(i); // Index et non plus Id //A1ClientFile[i].servFileId);
  end;
end;

function GameServer_getClientFileFromId(fileId : cardinal) : TPClientFile;
var len, i : cardinal;      // Id n'est pas identique à index (MAJ 2017)
begin
  Result:=nil;
  len:=length(A1ClientFile);
  // Je tente la correspondance directe
  if len>fileId then
  if A1ClientFile[fileId].servFileId=fileId then begin
    Result:=@A1ClientFile[fileId];
    exit;
  end;
  // Je recherche le fichier dans la liste
  if len<>0 then for i:=0 to len-1 do
  if A1ClientFile[i].servFileId=fileId then begin
    Result:=@A1ClientFile[i];
    exit;
  end;
end;

function GameServer_getClientFileFromIndex(fileIndex : cardinal) : TPClientFile;
var len : cardinal;
begin
  Result:=nil;
  len:=length(A1ClientFile);
  if fileIndex>=len then exit;
  Result:=@A1ClientFile[fileIndex];
end;

procedure ListClientFiles_updateFromEditorFile(editorFilePath : string; refreshSizeFromDisk : boolean = false);
var //pClientFile : TPClientFile;
    //pEditFile : TPEditFile; 
    pUpdateFile : TPExportUpdateServerFile;
    len, i : cardinal;
begin
  // ListClientFiles_updateFileVer
  ExportUpdateServer_load(editorFilePath);
  len:=length(A1ExportUpdateServerFile);
  WriteLn('ListClientFiles_updateFromEditorFile : len='+inttostr(len));
  if len<>0 then for i:=0 to len-1 do begin
    pUpdateFile:=@A1ExportUpdateServerFile[i];
    ListClientFiles_updateFileVerFromNameOnly(pUpdateFile^.Name, pUpdateFile^.Ver, refreshSizeFromDisk);
  end;

end;

// Affichage des fichiers qui ne sont pas dans la liste du serveur, mais qui sont dans A1ClientFile
procedure ListClientFiles_showNotInEditList;
var len, i : cardinal;
    fName : string;
    index : integer;
begin
  len:=length(A1ClientFile);
  if len<>0 then for i:=0 to len-1 do begin
    fName:=A1ClientFile[i].Name;
    ExportUpdateServer_find(fName, index);
    if index=-1 then
    if  (fName<>'Woria.exe') and (fName<>'data.win') and (fName<>'core.dll') and (fName<>'D3DX9_43.dll')
    and (fName<>'options.ini') then
      WriteLn('ListClientFiles_showNotInEditList : '+fName+' non présent.');
  end;
end;

{function GameServer_createDownloadArchive : string; // retourne le chemin de l'archive sur le disque.
var len, i, fId : cardinal;
    A1FileId : TCardinalArray;
begin
  Result:='';
  len:=readushort;
  if len=0 then exit;
  SetLength(A1FileId, len);
  for i:=0 to len-1 do begin
    A1FileId[i]:=readushort;
  end;
  // Encore une fois, ce n'est pas optimisé. Mais je vais bientôt me passer de la constitution de cette archive.
  freebuffer; // Ce buffer ne peut pas dépasser 20Mo. (d'où ses limitations)
  

end;}

// Sur le client :
// je reçois la liste des fichiers
// je dresse la liste de ceux qui me manquent (la liste de leur Id)
// je la demande au serveur
// le serveur crée un fichier temporaire contenant tous les fichiers ajoutés un par un (je pourrai m'affranchir de ça un peu plus tard)
// Le serveur envoie par paquets le fichier (de SizeMax), le client les reçoit et crée son fichier temporaire (pour les premiers tests)
// Plus tard, il créera directement les fichiers.

procedure ListClientFiles_findEachFileSize; // lire la taille de chaque fichier à partir du disque
var lenFiles, iFile : cardinal;
    pClientFile : TPClientFile;
    clientFilePath : WideString;
    fileSize : integer;
begin
  lenFiles := length(A1ClientFile);
  // lire du disque la taille de chaque fichier
  if lenFiles = 0 then exit;
  for iFile := 0 to lenFiles - 1 do begin
    pClientFile := @A1ClientFile[iFile];
    clientFilePath := pClientFile^.Dir + '\' + pClientFile^.Name;
    fileSize := GetFileSize(clientFilePath);
    if fileSize < 0 then fileSize := 0;
    pClientFile^.FileSize := fileSize;
    //U_UpdaterServRapport.WriteLn('ListClientFiles_findEachFileSize : taille = ' + inttostr(trunc(fileSize)) + 'o pour ' + clientFilePath + ' (ind='+inttostr(iFile)+')');
  end;
end;

function UpdateFileSizeFromDisk(fileDir, fileName : string) : boolean; // met à jour la taille du fichier à partir du disque (utile en cas de modification)
var lenFiles, iFile : cardinal;
    pClientFile : TPClientFile;
begin
  lenFiles := length(A1ClientFile);
  Result := false;
  // Je trouve le fichier dans la liste A1ClientFile, je le recherche sur le disque et je mets à jour sa taille s'il est sur le disque.
  if lenFiles = 0 then exit;
  for iFile := 0 to lenFiles - 1 do begin
    pClientFile := @A1ClientFile[iFile];
    if (pClientFile^.Dir = fileDir) and (pClientFile^.Name = fileName) then begin
      Result := UpdateFileSizeFromDisk(iFile);

      {clientFilePath := pClientFile^.Dir + '\' + pClientFile^.Name;
      fileSize := GetFileSize(clientFilePath);
      if fileSize < 0 then fileSize := 0;
      oldFileSize := pClientFile^.FileSize;
      pClientFile^.FileSize := fileSize;
      WriteLn('UpdateFileSizeFromDisk : ' + fileDir + '\' + fileName + ' ' + inttostr(oldFileSize) + ' -> ' + inttostr(fileSize));
      Result := true;}
      exit;
    end;
    //U_UpdaterServRapport.WriteLn('ListClientFiles_findEachFileSize : taille = ' + inttostr(trunc(fileSize)) + 'o pour ' + clientFilePath + ' (ind='+inttostr(iFile)+')');
  end;
  WriteLn('ERREUR UpdateFileSizeFromDisk : fichier non trouvé :  ' + fileDir + '\' + fileName);
end;
function UpdateFileSizeFromDisk(indexInA1ClientFiles : cardinal) : boolean; // met à jour la taille du fichier à partir du disque (utile en cas de modification)
var lenFiles : cardinal;
    pClientFile : TPClientFile;
    clientFilePath : WideString;
    fileSize, oldFileSize : integer;
begin
  lenFiles := length(A1ClientFile);
  Result := false;
  if indexInA1ClientFiles >= lenFiles then exit;
  pClientFile := @A1ClientFile[indexInA1ClientFiles];
  clientFilePath := pClientFile^.Dir + '\' + pClientFile^.Name;
  fileSize := GetFileSize(clientFilePath);
  if fileSize < 0 then fileSize := 0;
  oldFileSize := pClientFile^.FileSize;
  pClientFile^.FileSize := fileSize; // mise à jour de la taille
  WriteLn('UpdateFileSizeFromDisk : ' + pClientFile^.Dir + '\' + pClientFile^.Name + ' ' + inttostr(oldFileSize) + ' -> ' + inttostr(fileSize));
  Result := true;
end;


end.
