(*
 *  beware ircd, Internet Relay Chat server, bsignal.pas
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

unit bsignal;

{receive signals like restart, die, rehash}

interface

{$include bircd.inc}

uses
{$ifdef mswindows}
  winsock,
{$endif}
  lsocket,binipstuff,pgtypes;



type
  tsignalclass=class
    {this procedure must be in a class}
    procedure ondataavailable(sender:tobject;error:word);
  end;


procedure signalstart;
procedure signalstop;
procedure sendsignal(const s:bytestring);

var
  signalsock:twsocket;

implementation

uses bsend,bircdunit,bconfig,{$ifndef nowinnt}bwinnt,{$endif}bstuff;

var
  sc:tsignalclass;

procedure tsignalclass.ondataavailable(Sender: TObject; Error: Word);
var
    Buffer : array [0..1023] of char;
    Len    : Integer;
    Src    : tinetsockaddrV;
    SrcLen : Integer;
   s:bytestring;
begin
  SrcLen := SizeOf(Src);
  Len    := twsocket(sender).ReceiveFrom(@Buffer, SizeOf(Buffer), Src, SrcLen);
  setlength(s,len);
  move(buffer[0],s[1],len);

  if Len >= 0 then begin
    if (s = 'stop') or (s = 'die') then begin
      triggershutdown('Received STOP signal',false);
    end else
    if s = 'rehash' then begin
      locnotice(SNO_OLDSNO,'Received REHASH signal, rehashing server config file');
      bconfig.init;
    end else
    if s = 'restart' then begin
      triggershutdown('Received RESTART signal',true);
    end else
    if s = 'writeini' then begin
      writecfg;
    end
  end;
end;

procedure signalstart;
begin
  if signalsock <> nil then exit;
  if strtointdef(opt.signalport,0) = 0 then exit;
  signalsock := twsocket.create(nil);
  signalsock.Proto := 'udp';
  signalsock.addr := '127.0.0.1';
  signalsock.port := opt.signalport;
  try
    signalsock.listen;
    signalsock.ondataavailable := sc.ondataavailable;
  except
    signalstop;
  end;
end;

procedure signalstop;
begin
  if signalsock <> nil then signalsock.destroy;
  signalsock := nil;
end;

procedure sendsignal(const s:bytestring);
var
  sock:twsocket;
begin
  sock := twsocket.create(nil);
  sock.proto := 'udp';
  sock.addr := '127.0.0.1';
  sock.port := opt.signalport;
  sock.connect;
  sock.sendstr(s);
  sock.destroy;
end;

begin
  signalsock := nil;
end.
