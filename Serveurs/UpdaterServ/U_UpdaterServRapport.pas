unit U_UpdaterServRapport;

interface
uses SysUtils;

var G_LogFile : TextFile;
procedure WriteLn(str : string);
procedure WriteLn2(str : string); // Sans la date et l'heure
procedure WriteLn3(str : string); // Seulement dans le fichier log
procedure Write(str : string);

implementation

procedure WriteLn(str : string);
begin
  str:=DateTimeToStr(Now)+'   '+str;
  System.Writeln(str);
  System.Writeln(G_LogFile, str);
end;
procedure WriteLn2(str : string);
begin
  System.Writeln(str);
  System.Writeln(G_LogFile, str);
end;
procedure WriteLn3(str : string);
begin
  str:=DateTimeToStr(Now)+'   '+str;
  System.Writeln(G_LogFile, str);
end;
procedure Write(str : string);
begin
  str:=DateTimeToStr(Now)+'   '+str;
  System.Write(str);
  System.Write(G_LogFile, str);
end;


end.
