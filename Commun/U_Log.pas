unit U_Log;

interface
var LogPath : string;

procedure SetLogPath(arg_logPath : string);
procedure Log(text : string);


implementation
uses SysUtils;

procedure SetLogPath(arg_logPath : string); begin
  LogPath:=arg_logPath;
end;

procedure Log(text : string);
var f : TextFile;
    time : string;
    //date : TDateTime;
begin
  //date:=Now;
  try
    time:=DateTimeToStr(Now);
    AssignFile(f, LogPath);
    WriteLn(LogPath);
    if not FileExists(LogPath) then ReWrite(f)
    else Append(f);
    WriteLn(f, time+' : '+text);
    CloseFile(f);
  except
  end;
end;

end.
