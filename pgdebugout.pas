{pgdebugout.pas}

{debug output code originally for for bserv}

{use this code for whatever you like in programs under whater licence you like
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}
unit pgdebugout;

interface

uses sysutils;
procedure debugout(s:bytestring);

const
  // debug mode bitflags
  DMNone=0;
  DMConsole=1;
  DMFile=2 ;

var
  debugmode : byte;
  debugfile : string;
implementation

procedure debugout(s:bytestring);
var
  t : text;
begin
  if (debugmode and DMConsole)<>0 then begin
    {$ifdef mswindows}
      if isconsole then writeln(s);
    {$else}
      writeln(s);
    {$endif}
  end;
  if (debugmode and DMFile)<>0 then begin
    assign(t,debugfile);
    if fileexists(debugfile) then begin
      append(t);
    end else begin
      rewrite(t);
    end;

    writeln(t,s);
    closefile(t);
  end;
end;

end.
