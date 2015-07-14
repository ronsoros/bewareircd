(*
 *  beware ircd, Internet Relay Chat server, bident.pas
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

unit bident;

{ident code in this unit}

interface

uses buser,pgtypes;

procedure identstart(us:tuser);
procedure dnsidentstart(us:tuser);

procedure destroyidentdsock(p:pointer);
procedure timehandler;

implementation

uses
  {$ifdef mswindows}winsock,{$endif}lcore,lsocket,
  bircdunit,bconfig,bstuff,bsend,bwelcome,bsock,bdnscache,bconsts,bdns,sysutils,
  btime,binipstuff;

type
  {"identdclass" - twsocket handlers want a class}
  tic=class
    procedure identconnected(sender:tobject;error:word);
    procedure identreceive(sender:tobject;error:word);
    procedure identclosed(sender:tobject;error:word);
  end;

var
  ic:tic;

procedure destroyidentdsock(p:pointer);
begin
  connectionlist[twsocket(p).tag].identsock := nil;
  with twsocket(p) do begin
    if state <> wsclosed then close;
    release;
  end;
end;

function getremoteport(num:integer):integer;
var
  saddr:tinetsockaddr;
  saddrlen:integer;
begin
  saddrlen := sizeof(saddr);
  connectionlist[num].sock.getpeername(tsockaddrin(saddr),saddrlen);
  result := htons(saddr.port);
end;

procedure tic.identconnected(sender:tobject;error:word);
var
  us:tuser;
  socknum:integer;
begin
  socknum := twsocket(sender).tag;
  if not connectionlist[socknum].open then begin
    {no more connection}
    destroyidentdsock(sender);
    exit;
  end;
  us := connectionlist[socknum].user;
  if error = 0 then begin
    us.away := '';
    twsocket(sender).sendstr(inttostr(getremoteport(us.socknum))+' , '+inttostr(connectionlist[us.socknum].port)+#13#10);
    {ugly, storing the ident info in the user's .away string}
  end else begin
    destroyidentdsock(sender);
  end;
end;

procedure tic.identreceive(sender:tobject;error:word);
function strip(const s:bytestring):bytestring;
var
  a,b,c:integer;
begin
  b := 1;
  for a := 1 to length(s) do if s[a] <> ' ' then begin
    b := a;
    break;
  end;
  c := 1000;
  for a := length(s) downto 1 do if s[a] <> ' ' then begin
    c := a;
    break;
  end;
  result := copy(s,b,c-b+1);
end;

label eind;

var
  s:bytestring;
  a:integer;
  us:tuser;
  parv:tparams;
  parc:integer;
begin
  a := twsocket(sender).tag;
  us := connectionlist[a].user;
  s := twsocket(sender).receivestr;
  if not connectionlist[a].open then goto eind;
  us.away := us.away + s;
  if length(us.away) > 1000 then goto eind;
  a := pos(#13,us.away);
  if a = 0 then exit;
  us.away := copy(us.away,1,a-1);
  parc := strtok(us.away,':',@parv);
  if parc <> 4 then goto eind;
  if (strip(parv[1]) <> 'USERID') {or (strip(parv[2]) <> 'UNIX')} then goto eind;
  us.userid := copy(strip(parv[3]),1,userlen);
  connectionlist[us.socknum].hasident := true;
eind:
  destroyidentdsock(sender);
end;

procedure tic.identclosed(sender:tobject;error:word);
var
  us:tuser;
  socknum:integer;
begin
  socknum := twsocket(sender).tag;
  us := connectionlist[socknum].user;
  if connectionlist[socknum].open then begin
    if us.userid <> '' then begin
      send_statusnotice(us,noticeidentfound);
    end else begin
      send_statusnotice(us,noticeidentfailed);
    end;

    setflag(us.flags,userlog_ident);

    us.away := '';
{    connectionlist[socknum].identsock := nil; - done in destroyidentsock}
    welcome(us);
  end;
  if (connectionlist[socknum].identsock = sender) then destroyidentdsock(sender);
  {}
end;

procedure identstart(us:tuser);
var
  s:twsocket;
begin
  send_statusnotice(us,noticeidentstart);
  connectionlist[us.socknum].identsock := twsocket.create(nil);
  s := connectionlist[us.socknum].identsock;
  s.tag := us.socknum;
  s.addr := ircipbintostr(us.binip);
  s.port := '113';
  s.proto := 'tcp';

  s.localaddr := getsock(us).getxaddr;
  {windows bug workaround}
  if copy(s.addr,1,4) = '127.' then s.localaddr := '127.0.0.1';

  s.onsessionconnected := ic.identconnected;
  s.onsessionclosed := ic.identclosed;
  s.ondataavailable := ic.identreceive;

  try
    s.connect;
  except
    on e:exception do begin
      {no buffer space?... }
      destroyidentdsock(s);
      exit;
    end;
  end;
end;

procedure timehandler;
var
  a,b:integer;
begin
  if unixtime and 3 <> 0 then exit;
  b := unixtime-opt.lookuptimeout;
  for a := 0 to highconnection do if connectionlist[a].open then if isunreg(connectionlist[a].user) then begin
    if (b > connectionlist[a].pingtime) then begin
      if not flag_isset(connectionlist[a].user.flags,userlog_ident) then begin
        if assigned(connectionlist[a].identsock) then destroyidentdsock(connectionlist[a].identsock);
      end;
      if not flag_isset(connectionlist[a].user.flags,userlog_dns) then dnstimeout(a);
    end;
  end;
end;

procedure dnsidentstart(us:tuser);
var
  b:boolean;
begin
  b := false;
  if not opt.dnslookup then begin
    b := true;
    setflag(us.flags,userlog_dns);
  end else dnsstart(us);

  if not opt.identlookup then begin
    b := true;
    setflag(us.flags,userlog_ident);
  end else identstart(us);
  if b then welcome(us);
end;

end.
