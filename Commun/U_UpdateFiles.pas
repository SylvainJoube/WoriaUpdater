unit U_UpdateFiles;
// mise � jour des fichiers du client
// (obsol�te, fait via l'updater)

interface
uses U_Sockets4, U_Files;  //dialogs

function Update_receiveFileList(sock : TSocket; dossierServeur : string; fromUpdater : boolean = false) : boolean; // suite � un 4->1
function Update_receivePart(sock : TSocket; dossierServeur : string; fromUpdater : boolean = false) : boolean; // suite � un 4->3. Je fais confiance au serveur


var G_Updade_neededNb, G_Updade_currentNb : cardinal;
    NeededFiles_totalSize : cardinal; // taille totale des fichiers dont l'updater � besoin pour �tre � jour
    NeededFiles_receivedSizeTotal : cardinal; // nombre d'octets re�us au total

implementation
uses SysUtils, U_NetSys4, U_Arrays, dialogs, U_ClientFiles;

var A1DistantFile : TA1ClientFile; // Utile pour la r�ception des fichiers de la port du serveur : il n'enverra que l'id (et non dir+nom+ver)
var A1LocalFile : TA1ClientFile;

procedure SendErrorMessage(str : string; sock : TSocket);
var oldBuffer : TObjectBuffer;
begin
  oldBuffer:=G_MainBuffer;
  G_MainBuffer:=nil; // Pour ne pas perturber le buffer principal
  mStart(5, 1);
  writestring(str);
  sendbuffer(sock);
  sendAllBuffers;
  G_MainBuffer:=oldBuffer;
end;

// Retourne vrai si le fichier est pr�sent dans la liste de la sauvegarde (et sur le disque), et que sa version est bonne
function Update_fileIsLocal(var distantFile : TClientFile; dossierServeur : string; fromUpdater : boolean = false) : boolean;
var i, len, fileIndex : integer;
    basePath, fpath : string;
begin
  if not fromUpdater then
       basePath:=ExtractFilePath(ParamStr(0))+dossierServeur
  else basePath:=dossierServeur;
  Result:=false;
  //ShowClientFiles(A1LocalFile);
  //WriteLn('Update_fileIsLocal : v�rif de '+distantFile.Name+' (dans '+distantFile.Dir+')');
  fileIndex:=-1;
  i:=0;
  while i<length(A1LocalFile) do begin  // len=0 -> aucun fichier en local
    if  (A1LocalFile[i].Dir=distantFile.Dir)
    and (A1LocalFile[i].Name=distantFile.Name) then begin // fichier trouv�, je v�rifie sa version et son existence sur le disque
      fileIndex:=i; // Le fichier existe dans la liste A1LocalFile
      if  (A1LocalFile[i].Ver=distantFile.Ver) // Si la version est mauvaise ou qu'il n'est pas pr�sent sur le disque, je l'enl�verai de A1LocalFile.
      and FileExists(basePath+A1LocalFile[i].Dir+'\'+A1LocalFile[i].Name) then begin // ok disque
          Result:=true;
          exit;
          //ShowMessage('OK '+A1LocalFile[i].Name+' i='+inttostr(i));
      end else begin
          //ShowMessage('Doit MAJ '+A1LocalFile[i].Name+' i='+inttostr(i)+' verDistant='+inttostr(distantFile.Ver)
          //            +' verLocal='+inttostr(A1LocalFile[i].Ver)+' existeSurDisque='+booltostr(FileExists(basePath+A1LocalFile[i].Dir+'\'+A1LocalFile[i].Name), true));
      end;
      //ShowMessage('Doit MAJ '+A1LocalFile[i].Name+' i='+inttostr(i));
      break;
    end;
    i:=i+1;
  end;
  //WriteLn('Result='+booltostr(Result, true)+' fileIndex='+inttostr(fileIndex));
  //if not Result then begin
  //  ShowMessage('Doit MAJ '+distantFile.Name);
  //end;

  if (not Result) and (fileIndex<>-1) then begin  // Si le fichier n'est pas bon (ou inexistant sur le disque), je l'enl�ve de la liste et je sauvegarde la liste sur le disque
    len:=length(A1LocalFile);                     // Si fileIndex=-1, je n'ai rien � faire car le fichier n'est pas dans la liste A1LocalFile.
    fpath:=basePath+A1LocalFile[fileIndex].Dir+'\'+A1LocalFile[fileIndex].Name;
    if FileExists(fPath) then DeleteFile(fPath);

    ///WriteLn('ListClientFiles_save : '+A1LocalFile[i].Name+' supprim�. ver '+inttostr(A1LocalFile[i].Ver));
    //WriteLn('Suppression '+A1LocalFile[fileIndex].Name);
    //ShowClientFiles(A1LocalFile);
    if fileIndex<=len-2 then
      for i:=fileIndex to len-2 do begin
        //WriteLn(A1LocalFile[i].Name+'-> '+A1LocalFile[i+1].Name);
        A1LocalFile[i]:=A1LocalFile[i+1];
      end;
    SetLength(A1LocalFile, len-1);
    ListClientFiles_save(basePath+'LocalFiles.sys', @A1LocalFile);
    //WriteLn('Supprim� ok');
    //ShowClientFIles(A1LocalFile);
    //ShowMessage('Update_fileIsLocal : ');
  end;
end;

type TNeededFileDebugInfo = record
  size : cardinal;
  name : string;
  dir : string;

end;

var currentFileName : string;
    currentFilePos, currentFileSize : cardinal; // Position dans le fichier actuel.
    A1NeededFileIndex : TCardinalArray;
    A1NeededFileVer : TCardinalArray;
    A1NeededFileDebugInfo : array of TNeededFileDebugInfo;
    // d�clar� dans l'interface de cette unit� NeededFiles_totalSize : cardinal;

function Update_receiveFileList(sock : TSocket; dossierServeur : string; fromUpdater : boolean = false) : boolean; // suite � un 4->1. Retourne faux s'il n'y a rien � faire.
var len, i : integer;
    cDir : string;
    newDir : boolean;
    basePath : string;
    //besoin1, besoin2, len1 : cardinal;
begin
  Result:=true;
  NeededFiles_totalSize := 0;
  if not fromUpdater then                              //ExtractFilePath(ParamStr(0))
       basePath:=GetCurrentDir+'\'+dossierServeur
  else basePath:=dossierServeur;
  SetLength(A1NeededFileIndex, 0); // r�initialisation, au cas o� un ancien t�l�chargement aurait �t� abandonn�
  //showMessage(basePath);
  len:=readuint;
  //ShowMessage('Fichiers : '+inttostr(len)+' dossierServeur='+dossierServeur);
  SetLength(A1DistantFile, len);
  cDir:=''; // pas de dossier encore
  if len<>0 then for i:=0 to len-1 do begin
    newDir:=readbool;
    if newDir then cDir:=readstring; // Je ferai apr�s le tri par dossier
    A1DistantFile[i].Dir:=cDir;
    A1DistantFile[i].Name:=readstring;
    A1DistantFile[i].Ver:=readushort;
    A1DistantFile[i].FileSize:=readuint;
    //showmessage('Update_receiveFileList i=' + inttostr(i) + ' size=' + inttostr(A1DistantFile[i].FileSize) + ' A1DistantFile[i].Name=' + A1DistantFile[i].Name);
    //A1DistantFile[i].servFileId:=readushort; // cet Id est relatif � la session serveur actuelle (et non absolu, c'est Dir/Name/Ver qui sont importants). Id sert � la communication client-serveur
  end;
  ListClientFiles_load(basePath+'LocalFiles.sys', @A1LocalFile); // Les fichiers pr�sents
  // � la fin de la r�cepton des fichiers, je sauvegarderai LocalFiles.sys
  // Je fais l'inventaire des diff�rences.
  // (c'est long et non optim, mais c'est un d�but) : pour chaque fichier de A1DistantFile, je v�rifie qu'il existe en local et que la version est bonne. Sinon, je l'ajoute dans la liste des fichiers dont j'ai besoin.
  //showmessage('len A1LocalFile='+inttostr(length(A1LocalFile)));
  i:=0;
  while i<length(A1DistantFile) do begin
    if not Update_fileIsLocal(A1DistantFile[i], dossierServeur, fromUpdater) then begin // fichier non pr�sent (pas sur le disque ou pas la bonne version), ajout � la liste des t�l�chargements n�cessaires
      len:=length(A1NeededFileIndex);
      SetLength(A1NeededFileIndex, len+1);
      SetLength(A1NeededFileVer, len+1);
      SetLength(A1NeededFileDebugInfo, len+1);
      A1NeededFileIndex[len]:=i;//A1DistantFile[i].servFileId;
      A1NeededFileVer[len]:=A1DistantFile[i].Ver;
      A1NeededFileDebugInfo[len].size:=A1DistantFile[i].FileSize;
      A1NeededFileDebugInfo[len].name:=A1DistantFile[i].Name;
      A1NeededFileDebugInfo[len].dir:=A1DistantFile[i].Dir;
      NeededFiles_totalSize := NeededFiles_totalSize + A1DistantFile[i].FileSize;
      //if A1DistantFile[i].FileSize = 0 then
      //  showMessage('ERROR : Update_receiveFileList : A1DistantFile[i].FileSize = 0');

      //showMessage('besoin de '+inttostr(i)+' '+A1DistantFile[i].Name); //A1DistantFile[i].servFileId -> i
    end;
    i:=i+1;
  end;

  // J'envoie au serveur la liste des Id des fichiers dont j'ai besoin
  len:=length(A1NeededFileIndex);
  G_Updade_neededNb:=len;
  //ShowMessage('Update_receiveFileList : G_Updade_neededNb = ' + inttostr(G_Updade_neededNb));
  G_Updade_currentNb:=0;
  if len=0 then begin
    Result:=false;
    exit;
  end;
  mStart(4, 2);
  //ShowMessage('Besoin de : '+inttostr(len) + ' NeededFiles_totalSize = ' + inttostr(NeededFiles_totalSize));
  writeushort(len); // len<>0 en th�orie
  if len<>0 then for i:=0 to len-1 do
    writeushort(A1NeededFileIndex[i]); // Je pense qu'il y aura moins de 65000 fichiers, sinon, il faudra que je communique d'une autre mani�re (paquet trop gros pour �tre envoy�)
  sendbuffer(sock);
  sendAllBuffers;
  currentFileName:='';
  currentFilePos:=0;
  currentFileSize:=0;
  //showMessage('A1NeededFileId[21]='+inttostr(A1NeededFileId[21]));
  //showMessage('nbFichiers='+inttostr(length(A1NeededFileId)));
end;

type TUpdateCurrentFile = record
  Dir, Name : string;
  Ver : cardinal;
end;

var UpdateCurrentFile : TUpdateCurrentFile;


procedure WriteText(str : string; sock : TSocket = nil); // si sock<>nil, j'envoie au serveur le message (d'erreur/info)
begin
  // Ecrire le stexte � l'�cran
  ShowMessage(str);
  if sock<>nil then
    SendErrorMessage(str, sock);
end;

function Update_receivePart(sock : TSocket; dossierServeur : string; fromUpdater : boolean = false) : boolean; // suite � un 4->3. Je fais confiance au serveur
var rcvSize, i : cardinal;         // retrourne false si c'est termin�, true s'il faut continuer.
    f : file;
    goNext, askAgain : boolean;
    baseDir : string;
    basePath : string;
    success : boolean;
    len : integer;
    debug_tailleAtendue, iDebug_file, lenDebug_file : cardinal;
begin
  goNext:=true;
  // non exact, fait plus bas : NeededFiles_receivedSizeTotal := NeededFiles_receivedSizeTotal + GetCurrentBufferSize - 2; // moins les deux octets indiquant la nature du message (b1, b2)
  //SendErrorMessage('Update_receivePart test errorMessage', sock);

  while goNext do begin
    if currentFileName='' then begin
      currentFileName:=readstring; // nouveau fichier
      currentFileSize:=readuint;
      currentFilePos:=0;
      UpdateCurrentFile.Name:=ExtractFileName(currentFileName);
      UpdateCurrentFile.Dir:=ExtractFileDir(currentFileName);
      UpdateCurrentFile.Ver:=A1NeededFileVer[G_Updade_currentNb];
      lenDebug_file := G_Updade_currentNb;
      debug_tailleAtendue := 0;
      if lenDebug_file <> 0 then for iDebug_file := 0 to lenDebug_file - 1 do begin
        debug_tailleAtendue := debug_tailleAtendue + A1NeededFileDebugInfo[iDebug_file].size;
      end;
      {ShowMessage('Update_receivePart : lenDebug_file = ' + inttostr(lenDebug_file) + '  debug_tailleAtendue = ' + inttostr(debug_tailleAtendue) + '  ' + inttostr(NeededFiles_receivedSizeTotal) + ' = NeededFiles_receivedSizeTotal'
       + chr(10) + 'nom attendu = ' + A1NeededFileDebugInfo[iDebug_file].name + '  ' + currentFileName + ' = nom re�u'
      );}




      {WriteLn('Update_receivePart : name='+UpdateCurrentFile.Name);
      WriteLn('Update_receivePart : dir='+UpdateCurrentFile.Dir);
      WriteLn('Update_receivePart : ver='+inttostr(UpdateCurrentFile.Ver));}
      //UpdateCurrentFile.Dir:=A1NeededFileId[G_Updade_currentNb].Dir;
      G_Updade_currentNb:=G_Updade_currentNb+1;
      //ShowMessage('Fichier '+currentFileName);
    end;
    rcvSize:=readuint; // paquet pour le fichier en cours
    NeededFiles_receivedSizeTotal := rcvSize + NeededFiles_receivedSizeTotal; // incr�ment du nombre total d'octets re�us
    //showMessage('Size='+inttostr(rcvSize));
    // rcvSize peut �tre nul en cas exceptionnel.
    for i:=0 to rcvSize-1 do
      FileBuffer[i]:=readubyte;
    //showMessage('Nom '+currentFileName);
    if not fromUpdater then
      baseDir:=ForceDirForFile(currentFileName, dossierServeur)
    else begin
      ForceFullDirForFile(dossierServeur+currentFileName);
      baseDir:=dossierServeur;
    end;
    if baseDir='ERROR' then begin
      WriteText('Impossible de cr�er le dossier '+dossierServeur+'.', sock);
      Result:=false;
      //showMessage('Update_receivePart : BUG 1');
      exit;
    end;

    FileMode:=fmOpenReadWrite;           // dossierServeur inclut le '\'
    //showmessage(baseDir);
    //showMessage('Fullname '+baseDir+currentFileName);

    if FileExists(baseDir+currentFileName) and (currentFilePos=0) then DeleteFile(baseDir+currentFileName); // ancien fichier
                       //fromUpdater
    AssignFile(f, baseDir+currentFileName);
    //WriteLn('dossierServeur='+dossierServeur+' currentFileName='+currentFileName);

    i:=0;
    success:=false;
    while (i<1000) and not success do begin try
      if not FileExists(baseDir+currentFileName) then ReWrite(f, 1)
                                                 else Reset(f, 1);
      success:=true;
      except success:=false; sleep(3); end; // WriteText('ERROR Update_receivePart open failed.');
      if not success then sleep(12);
    end;
    if success=false then begin
      WriteText('Update_receivePart echec de l''ouverture du fichier '+currentFileName, sock);
      Result:=false;
      //showMessage('Update_receivePart : BUG 2');
      exit;
    end;

    //if currentFilePos <> cardinal(fileSize(f)) then begin  d�bug temporaire
    //  ShowMessage('ERREUR Update_receivePart :  currentFilePos = ' + inttostr(currentFilePos) + '  ' + inttostr(fileSize(f)) + ' = fileSize(f)');
    //end;

    //showMessage('Seek to '+inttostr(currentFilePos));
    if currentFilePos>cardinal(fileSize(f)) then begin
      WriteText('Update_receivePart seek (demand� '+inttostr(currentFilePos)+') trop grand (tailleR�elle '+inttostr(fileSize(f))+')', sock);
      CloseFile(f);
      Result:=false;
      //showMessage('Update_receivePart : TROP GRAND 3');
      exit;
    end;
    seek(f, currentFilePos); // �a doit �tre bon
    BlockWrite(f, FileBuffer, rcvSize);
    currentFilePos:=currentFilePos+rcvSize;
    try
      CloseFile(f);
    except
      WriteText('Update_receivePart impossible de fermer un fichier : '+currentFileName+' dans '+baseDir, sock);
    end;
    if currentFileSize=currentFilePos then begin // fichier re�u.
      len:=length(A1LocalFile); // il n'�tait pas pr�sent dans cette liste car je l'en ai enlev� lors de la v�rification des fichiers locaux (omparaison avec la liste serveur).
      SetLength(A1LocalFile, len+1);  // Sauvegarde de ce fichiers, il a bien �t� re�u.
      A1LocalFile[len].Dir:=UpdateCurrentFile.Dir;
      A1LocalFile[len].Name:=UpdateCurrentFile.Name;
      A1LocalFile[len].Ver:=UpdateCurrentFile.Ver;
      ListClientFiles_save(dossierServeur+'LocalFiles.sys', @A1LocalFile); // Mise � jour de la liste des fichiers t�l�charg�s
      goNext:=readbool; // /!\ ListClientFiles_save fait un freebuffer, mais pas grave, il utilise son propre buffer
      //showMessage(UpdateCurrentFile.Name+' dans '+UpdateCurrentFile.Dir+' size='+inttostr(currentFileSize)+' OK. goNext='+booltostr(goNext, true));
      currentFileName:='';
      //if not goNext then showMessage('not goNext');
    end else goNext:=false; // Je n'ai pas fini de recevoir ce fichier
  end;
  askAgain:=readbool;
  Result:=askAgain;
  //showMessage('Update_receivePart : ASKAGAIN='+booltostr(Result, true));
  if askAgain then begin mStart(4, 3); sendbuffer(sock); sendAllBuffers; end else begin
    // Si le t�l�chargement est termin�, je sauvegarde la nouvelle liste.
    if not fromUpdater then basePath:=GetCurrentDir+'\'+dossierServeur
                       else basePath:=dossierServeur;
    ListClientFiles_save(basePath+'LocalFiles.sys', @A1LocalFile); // Les fichiers pr�sents
    //showMessage('Update_receivePart: ListClientFiles_save '+basePath+'LocalFiles.sys');
    A1LocalFile:=A1DistantFile;
    SetLength(A1NeededFileIndex, 0);
    SetLength(A1NeededFileVer, 0);
  end;
end;

end.
