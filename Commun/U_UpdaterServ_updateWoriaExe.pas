unit U_UpdaterServ_updateWoriaExe;

interface
uses U_NetSys4, U_Sockets4, U_Files;//, U_UpdaterServRapport;


procedure UpdateWoriaExeVersion;
procedure FlowWoriaExeVersion(method : TFlowMethod);

var WriteLnCustom : procedure(str : string) = nil; // A définir impérativement pour afficher quelque chose à l'écran
    WriteLnCustom_isDefined : boolean = false;
    
implementation
uses U_ClientFiles;

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



procedure UpdateWoriaExeVersion;
begin
  WriteLn('UpdateWoriaExeVersion : En cours...');
  ListClientFiles_updateFileVer('ClientFiles', 'Woria.exe', true, true);
  ListClientFiles_updateFileVer('ClientFiles', 'data.win', true, true);
  ListClientFiles_updateFileVer('ClientFiles', 'core.dll', true, true);
  ListClientFiles_updateFileVer('ClientFiles', 'D3DX9_43.dll', true, true);
  ListClientFiles_updateFileVer('ClientFiles', 'options.ini', true, true);
  FlowWoriaExeVersion(tyWrite);
  WriteLn('UpdateWoriaExeVersion : OK !');
end;

procedure FlowWoriaExeVersion_doFile(fName : string; method : TFlowMethod);
var pClientFile : TPClientFile;
    //index : integer;
begin
  // Je trouve le fichier : création si inexistant (et c'est ok avec tyRead aussi)
  {pClientFile:=ListClientFiles_find('ClientFiles', fName, index);
  if (pClientFile=nil) and (method=tyRead) then begin end;}
  pClientFile:=ListClientFiles_updateFileVer('ClientFiles', fName, false);
  flowstring(pClientFile^.Dir, method);
  flowstring(pClientFile^.Name, method);
  flowuint(pClientFile^.Ver, method);
end;

procedure FlowWoriaExeVersion(method : TFlowMethod);
var oldMainBuffer : TObjectBuffer;
begin
   //ExportUpdaterServerFiles.sys
   oldMainBuffer:=G_MainBuffer;
   G_MainBuffer:=nil;
   freebuffer;
   if method=tyRead then if not ReadBufferFromFile('WoriaExeVersion.sys') then begin
     // Echec de la lecture, j'écris à la place (initialisation)
     method:=tyWrite;
   end;
   if method=tyWrite then begin
     FlowWoriaExeVersion_doFile('Woria.exe', tyWrite);
     FlowWoriaExeVersion_doFile('data.win', tyWrite);
     FlowWoriaExeVersion_doFile('core.dll', tyWrite);
     FlowWoriaExeVersion_doFile('D3DX9_43.dll', tyWrite);
     FlowWoriaExeVersion_doFile('options.ini', tyWrite);
   end else begin  
     FlowWoriaExeVersion_doFile('Woria.exe', tyRead);
     FlowWoriaExeVersion_doFile('data.win', tyRead);
     FlowWoriaExeVersion_doFile('core.dll', tyRead);
     FlowWoriaExeVersion_doFile('D3DX9_43.dll', tyRead);
     FlowWoriaExeVersion_doFile('options.ini', tyRead);
   end;
   if method=tyWrite then
    WriteBufferToFile('WoriaExeVersion.sys', false);
   G_MainBuffer.Destroy;
   G_MainBuffer:=oldMainBuffer;
end;

end.
 