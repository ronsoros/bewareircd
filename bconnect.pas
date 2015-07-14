(*
 *  beware ircd, Internet Relay Chat server, bconnect.pas
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

unit bconnect;

interface

uses
  buser,bconfig,bcmds,pgtypes;

procedure connect(sptr:tuser;cl:tconfline;port:bytestring);
procedure timehandler;

implementation

uses
  lsocket,
  bsend,breplies,bsock,bstuff,btime,bserver,bconsts,sysutils;

procedure connect(sptr:tuser;cl:tconfline;port:bytestring);
var
  us:tuser;
  socknum:integer;
  sock:twsocket;
  a,b:integer;
begin
  if not opt.hub then begin
    b := 0;
    for a := 1 to highserverlink do begin
      if serverlinklist[a] <> nil then b := 1;
    end;
    if b <> 0 then begin
      if sptr <> nil then sendreply(sptr,cmdnotice,':*** I am not configured to be hub');
      exit;
    end;
  end;

  b := 0;
  for a := 1 to maxserverlink do begin
    if serverlinklist[a] = nil then b := 1;
  end;
  if b = 0 then begin
    if sptr <> nil then sendreply(sptr,cmdnotice,':*** no more server links possible');
    exit;
  end;

  if pos('.',cl.s3) <> 0 then begin
    if findname(cl.s3) <> nil then begin
      if sptr <> nil then sendreply(sptr,cmdnotice,':*** Server already exists: '+cl.s3);
      exit;
    end;

    {find if initiating connection already exists}
    for a := 0 to highconnection do if connectionlist[a].open then if isinitiated(connectionlist[a].user) then begin
      if strcompup(connectionlist[a].connectto_str,cl.s3) then begin
        if sptr <> nil then sendreply(sptr,cmdnotice,':*** connect attempt already exists: '+cl.s3);
        exit;
      end;
    end;

  end;

  if port = '' then port := inttostr(cl.i4);
  if strtointdef(port,0) = 0 then begin
    port := '4400';
  end;
  socknum := addsocket;
  if socknum = -1 then begin
    if sptr <> nil then sendreply(sptr,cmdnotice,':*** No more connections.');
    exit;
  end;

  us := adduser;
  setflag(us.flags,userflag_nopenalty);

  sock := twsocket.create(nil);
  sock.Tag := socknum;
  us.socknum := socknum;

  connectionlist[us.socknum].open := true;
  connectionlist[us.socknum].user := us;
  connectionlist[us.socknum].sock := sock;

  connectionlist[us.socknum].receivecount := 0;
  connectionlist[us.socknum].pingfreq := 0;
  connectionlist[us.socknum].pingtime := unixtime;
  {
  ping freq, sendq
  }

  sock.addr := cl.s1;
  sock.port := port;
  sock.proto := 'tcp';

  if (opt.mylocaladdr = '') or (opt.mylocaladdr='*')
  then sock.localaddr := ''
  else sock.localaddr := opt.mylocaladdr;

  sock.OnDataAvailable := sc.receivehandler;
  sock.Onsessionclosed := sc.closehandler;
  sock.onsessionconnected := sc.connecthandler;

  us.password := cl.s2;
  connectionlist[socknum].connectto_str := cl.s3;
  if sptr = nil then begin
    connectionlist[socknum].connectby_socknum := 0;
    connectionlist[socknum].connectby_user := nil;
    connectionlist[socknum].connectby_str := 'AutoConn.!*@'+me.name;
  end else begin
    connectionlist[socknum].connectby_socknum := sptr.from.socknum;
    connectionlist[socknum].connectby_user := sptr;
    connectionlist[socknum].connectby_str := nickuserhost(sptr);
  end;

  setflag(us.flags,userflag_initiated);
  if sptr <> nil then begin
    sendreply(sptr,cmdnotice,':*** Connecting to '+cl.s3)
  end else
  locnotice(SNO_TCPCOMMON,'Connection to '+cl.s3+' activated');

  try
    sock.connect;
  except
    on e:exception do begin
      us.error := 'socket error while connecting: '+e.Message;
      us.destroy;
      connectionlist[us.socknum].open := false;
    end;
  end;
end;

procedure timehandler;
var
  p,p2:tconfline;
  a,b,c:integer;
  s:bytestring;
  bool:boolean;
begin
  if tickcount and 3 <> 0 then exit;

  if not opt.hub then begin
    b := 0;
    for a := 1 to highserverlink do if serverlinklist[a] <> nil then inc(b);
    if b >= 1 then exit;
  end;

  p := conflinelist;
  while p <> nil do begin
    if p.c = 'C' then if p.i4 <> 0 then begin
      p2 := getyline(p.i5);
      if p2 = nil then begin
        a := 0;
      end else begin
        a := strtointdef(p2.s3,0);
      end;
      if a > 0 then if tickcount mod ((a+3) and not 3) = 0 then begin

        s := p.s3;
        if pos('.',s) <> 0 then if findname(s) = nil then begin
          if p2.i4 <> 0 then begin
            {count connections in class}
            c := 0;
            for b := 0 to highserverlink do if serverlinklist[b] <> nil then begin
              if connectionlist[tuser(serverlinklist[b].us).socknum].classnum = p.i5 then inc(c);
            end;
            bool := c < p2.i4;
          end else bool := true;
          if bool then connect(nil,p,'');
        end;
      end;
    end;
    p := tconfline(p.next);
  end;
end;

end.
