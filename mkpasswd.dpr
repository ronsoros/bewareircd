{$apptype console}


(*
 *  beware IRC services, mkpasswd.pas
 *  Copyright (C) 2002 Bas Steendijk
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

{this code is tested with freepascal 2.4 under linux and delphi 6 under windows 7}

  {$ifndef fpc}
  {$ifdef mswindows}
    {$define winapiversion}
  {$endif}
  {$endif}


program mkpasswd;
uses
  {$ifdef fpc}
    crt,
    {$ifdef unix}
      {$ifdef VER1_0}
        linux,
      {$else}
        baseunix,unix,unixutil,sockets,
      {$endif}
      lcoreselect,unitfork,
    {$endif}
  {$else}

    {$ifdef winapiversion}
      windows,
    {$endif}

  {$endif}
  passcryp;

{$ifdef unix}
  {$i unixstuff.inc}
  procedure write(s:string);
  begin
    fdwrite(1,s[1],length(s));
  end;
  procedure writeln(s:string);
  begin
    write(s+#13#10);
  end;
{$endif}

{$ifdef winapiversion}
var
  hStdin:thandle;

function readkey:string;
var
  buf:INPUT_RECORD;
  numread:cardinal;
begin
  repeat
    if ReadConsoleInput(hstdin,buf,1,numread) then begin
      if (buf.eventtype = KEY_EVENT) then begin
        if buf.Event.KeyEvent.bKeyDown then begin
          result := buf.Event.KeyEvent.AsciiChar;
          exit;
        end;
      end;
    end else begin
      writeln('ReadConsoleInput failed');
      halt;
    end;
  until false;
end;

procedure init;
begin
  hStdin := GetStdHandle(STD_INPUT_HANDLE);
    if (hStdin = INVALID_HANDLE_VALUE) then begin
      writeln('GetStdHandle failed');
      halt;
    end;

    if (not SetConsoleMode(hStdin, ENABLE_WINDOW_INPUT )) then begin
       writeln('SetConsoleMode failed');
      halt;

    end;
end;

{$endif}


var
  s:string;
  c:string;
begin
  {$ifdef winapiversion}
  init;
  {$endif}

  randomize;
  writeln('');
  write('Enter password: ');
  s := '';
  repeat
    c := readkey;
    if (c >= #32) and (c < #128) then s := s + c;

    //backspace
    if (c = #8) then begin
      s := copy(s,1,length(s)-1);
    end;
  until c = #13;
  writeln('');
  writeln('');
  write(passnewcrypt(s));
  readkey;
  writeln('');
end.
