program ExportDll;

{$APPTYPE CONSOLE}

uses
  SysUtils, windows, classes;

//const SourcePath = 'C:\Users\Sylvesoft\Desktop\Womos Universe\WandaClientDll\WandaClientDll.dll';
//const TargetPath = 'C:\Users\Sylvesoft\Desktop\Womos Universe\WandaClient.gmx\extensions\CoreDll\WandaClientDll.dll';
const SourcePath = 'UpdaterClientDll.dll';
const TargetPath = 'UpdaterClientGM.gmx\datafiles\UpdaterClientDll.dll';

var msg : string;

type TMainThread = class (TThread)
  public
    Stopped, Stop : boolean;
    steps : cardinal;
    constructor Create; virtual;
    procedure Execute; override;
end;

constructor TMainThread.Create;
begin   // Créé et imédiatement exécuté
  inherited Create(false);
  Stopped:=false;
  Stop:=false;
end;

procedure TMainThread.Execute;
begin
  while not Stop do begin
    if FileAge(SourcePath)<>FileAge(TargetPath) then begin        DeleteFile(TargetPath);
      if CopyFile(PChar(SourcePath), PChar(TargetPath), false) then
        Writeln('Ok copie réussie. '+inttostr(FileAge(SourcePath)))
      else Writeln('ERREUR echec de la copie.');
    end;
    sleep(100);
  end;
  Stopped:=true;
end;

var MainThread : TMainThread;
begin

  MainThread:=TMainThread.Create;

  while true do begin
    readln(Msg);
    //if (Msg='quit') or (Msg='q') then begin

      MainThread.Stop:=true;
      while not MainThread.Stopped do
        sleep(10);
      exit;
    //end;

    {if not FileExists(SourcePath) then Write('ERREUR : Source introuvable.')
    else begin
      WriteLn(inttostr(FileAge(SourcePath)));

      {DeleteFile(TargetPath);
      if CopyFile(PChar(SourcePath), PChar(TargetPath), false) then
        Write('Ok copie réussie.')
      else Write('ERREUR echec de la copie.');
    end;}
  end;


end.
 