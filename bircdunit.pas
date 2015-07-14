(*
 *  beware ircd, Internet Relay Chat server, bircdunit.pas
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

unit bircdunit;

interface

{$include bircd.inc}

uses
  {$ifdef unix}
    {$ifdef VER1_0}
      linux,
    {$else}
      baseunix,unix,unixutil,sockets,
    {$endif}
    lcoreselect,unitfork,
  {$else}
    windows,lcorewsaasyncselect,
  {$endif}
  pgtypes,lcore,lsocket,Classes, bsock;

var
  paramsname:bytestring='';
  paramsport:integer=0;
  paramsnum:integer=0;

  shutdownreason:bytestring;
  shutdownrestarting:boolean;

  foregroundmode:boolean;

procedure triggershutdown(reason:bytestring;restarting:boolean);
procedure initapplication;
procedure RunApplication;
procedure CleanupApplication;

procedure getparams;
procedure startserver;
procedure serverdown(restarting:boolean);
procedure restartserver;
procedure shutdownserver;

procedure conwrite(const s:bytestring);

type
  tmainc=class(tobject)
    procedure ontimer(sender:tobject);
    procedure destroysockmsg(wparam,lparam:integer);
    procedure destroyusermsg(wparam,lparam:integer);
    procedure needsendmsg(wparam,lparam:integer);
  end;

var
  mainc:tmainc;
  maintimer:tltimer;

procedure bircdunit_lcoreinit;

implementation


uses
  {$ifndef nowinnt}bwinnt,{$endif}
  {$ifndef nosignal}bsignal,{$endif}
  buser,bchannel,btime,blinklist,bstuff,bconfig,bserver,bparse,bcmds,
  bsend,b_gline,b_whowas,bconnect,bconsts,bdnscache,bipcheck,b_list,bdns,
  bident,bvaliddef,sysutils;

{$i unixstuff.inc}

var
  conwritten:integer=0;

procedure bircdunit_lcoreinit;
begin
  lcoreinit;
end;

procedure conwrite(const s:bytestring);
var
  t:textfile;
  a:integer;
begin
  (*if false
  {$ifdef mswindows}
  or (not isconsole)
  {$endif}
  {$ifndef nowinnt}
  or runasservice
  {$endif}
  {$ifdef unix}
  or isforked
  {$endif}
  then*)
  begin

    assignfile(t,
    //getprogramdir+dirsep+
    'stdout.txt');
    filemode := 2;
    if (conwritten <> 0) then begin
      {$i-}append(t);{$i+}
      if ioresult <> 0 then exit;
    end else begin
      {$i-}rewrite(t);{$i+}
      if ioresult <> 0 then exit;
    end;

   try //open file

    if (unixtime - conwritten) > 10 then begin
      {$i-}writeln(t,timestring(unixtime));{$i+}
      a := ioresult;

      if (a <> 0) then begin
        if (serverisrunning) then wallops('IO error while writing to log: '+inttostr(a)+','+expandfilename('.')+','+s);
        exit;
      end;
    end;
    if s <> '' then begin
      {$i-}writeln(t,'   ',s);{$i+}
      a := ioresult;
      if (a <> 0) then begin
        if (serverisrunning) then wallops('IO error while writing to log: '+inttostr(a)+','+expandfilename('.')+','+s);
      end;
    end;
   finally
    closefile(t);
   end;
    conwritten := unixtimeint;
    if conwritten = 0 then conwritten := 1;
  end(* else begin
    if s <> '' then writeln(s);
  end;*)
end;

procedure tmainc.destroysockmsg;
var
  num:integer;
begin
  num := wparam;
  if num < nextconnection then nextconnection := num;

  if connectionlist[num].sock = nil then exit;

  {connectionlist[num].sock.destroy;}
  {!!!}connectionlist[num].sock.release;
  fillchar(connectionlist[num],sizeof(connectionlist[num]),0);
end;

procedure tmainc.destroyusermsg;
var
  us:tuser;
begin
  us := connectionlist[wparam].user;
  if assigned(us) then begin
    connectionlist[wparam].user := nil;
    us.destroy; {^fixed? invalid pointer operation location, 200 clones ping flood in channel, one connection on internet}
  end;
end;

procedure tmainc.needsendmsg;
begin
  sendcycle;
end;

procedure triggershutdown(reason:bytestring;restarting:boolean);
begin
  shutdownreason := reason;
  shutdownrestarting := restarting;
  exitmessageloop;
end;

procedure getparams;
var
  a:integer;
begin
  paramsname := '';
  paramsnum := 0;
  paramsport := 0;

  for a := 1 to paramcount do begin
    if paramstr(a) = '-conf' then begin
      conffile := paramstr(a+1);
    end;
    if paramstr(a) = '-ini' then begin
      inifile := paramstr(a+1);
    end;

    if paramstr(a) = '-name' then begin
      paramsname := paramstr(a+1);
      paramsnum := strtointdef(paramstr(a+2),0);
    end;
    if paramstr(a) = '-port' then begin
      paramsport := strtointdef(paramstr(a+1),0);
    end;

    if paramstr(a) = '-foreground' then begin
      foregroundmode := true;
    end;


  end;
end;


procedure startserver;
var
  p:tconfline;
  a,p10max:integer;
begin
  bconfig.init;
  fillchar(statsm,sizeof(statsm),0);
  fillchar(count,sizeof(count),0);
  fillchar(classcount,sizeof(classcount),0);

  bootts := irctime;
  starttime := unixtime;

  {create connection arrays}
  bsock.init;

  {create the local server}
  me := adduser;
  if paramsname <> '' then
  setname(me,paramsname)
  else
  setname(me,opt.servername);
  if not validservername(me.name) or (pos('*',me.name) <> 0) then begin
    {own server name is not valid}
    conwrite('invalid server name in M:line');
    halt;
  end;
  me.fullname := copy(opt.servergcos,1,maxgcoslength);

  {P10 max from maxclients}
  p10max := 4096;
  for a := 1 to 20 do begin
    if 1 shl a >= maxclients then begin
      p10max := (1 shl a)-1;
      break;
    end;
  end;

  if paramsnum <> 0 then
  addserver(me,paramsnum,p10max,nil)
  else
  addserver(me,opt.p10num,p10max,nil);

  setflag(me.server.flags,servflag_burstack);
  {$ifndef noipv6}
  setflag(me.server.flags,servflag_ipv6aware);
  {$endif}
  me.server.parentserver := me.server;
  serverlinklist[0] := me.server;

  if isulined(me.name) then
  setflag(me.server.flags,servflag_ulined);

  if paramsport <> 0 then begin
    p := conflinelist;
    while p <> nil do begin
      if p.c = 'P' then p.c := '#';
      p := tconfline(p.next);
    end;
    p := tconfline.create;
    p.c := 'P';
    p.i4 := paramsport;
    linklistadd(tlinklist(conflinelist),tlinklist(p));
    {port override}
  end;
  if not setlistener then begin
    conwrite('unable to listen on any port.');
    halt; {unable to open any ports, another instance of bircd is probably already running}
  end;
  {$ifndef nosignal}
  signalstart;
  {$endif}

  conwrite('server started successfully');
  serverisrunning := true;
end;


procedure serverdown(restarting:boolean);
var
  us:tuser;
  a:integer;
  sclient:bytestring;
begin
  if not serverisrunning then exit;
  serverisrunning := false;

  {dont receive on any connection}
  for a := 0 to highconnection do if connectionlist[a].open then begin
    connectionlist[a].sock.ondataavailable := nil;
    connectionlist[a].sock.ondatasent := nil;
    connectionlist[a].sock.onsenddata := nil;
  end;

  if restarting then
  sclient := 'Restarting server.'
  else begin
    sclient := 'Server terminating.';

    (*
    -currently no need to write ini on shutdown, because server doesnt change settings while it runs
    {$ifndef noini}
    writecfg; {only write cfg if really stopping, or change to bircd.ini + restart causes overwrite with old config}
    {$endif}
    *)
  end;
  {close ports}
  closealllistener;

  {$ifndef nosignal}
  signalstop;
  {$endif}

  locnotice(sno_oldsno,'shutdown: '+shutdownreason);
  locnotice(sno_oldsno,sclient);
  conwrite('server shutdown: '+shutdownreason);

  {send things}
  for a := 0 to highconnection do if connectionlist[a].open then begin
    us := connectionlist[a].user;
    if isserver(us) then begin
      sendto_one(us,sprefix(me,TOK_ERROR)+':'+shutdownreason);
      setflag(us.server.flags,servflag_nosquit);
    end else if isclient(us) then begin
      {}
    end else begin
      if not flag_isset(us.flags,userflag_initiated) then
        sendto_one(us,MSG_ERROR+' :'+shutdownreason);
    end;
    connectionlist[us.socknum].sock.send(nil,0);
    connectionlist[us.socknum].sock.close; {20040711}
  end;
  sendcycle;

  {destroy connections}
 {do not destroy things, it causes crash on windows XP, let the OS handle it}
(*  for a := 0 to highconnection do if connectionlist[a].open then begin

    us := connectionlist[a].user;
    us.destroy;
  end;

  {exit;}

  me.destroy;
  me := nil;

  freemem(connectionlist);
  connectionlist := nil;

  {ipcheck_destroyall;}
  cleargline;
  clearwhowas;*)
end;

procedure runagain;
var
  s:bytestring;
begin
  s := paramstr(0);
  {$ifdef mswindows}
  winexec(@s[1],0);
  {$else}
  execl(s);
  {$endif}
end;

procedure restartserver;
begin
  {$ifndef nowinnt}
  reportstopping;
  {$endif}
  serverdown(true);

  {$ifdef unix}
  deletepid;
  {$endif}

  runagain;
  {$ifndef nowinnt}
  reportstopped;
  {$endif}
end;

procedure shutdownserver;
begin
  {$ifndef nowinnt}
  reportstopping;
  {$endif}
  serverdown(false);
  {$ifndef nowinnt}
  reportstopped;
  {$endif}

  {$ifdef unix}
  deletepid;
  {$endif}

end;

procedure tmainc.ontimer;
var
  f:float;
begin
  if not serverisrunning then exit;
  f := unixtimefloat;
  if frac(f) < 0.02 then begin
    maintimer.interval := 1030;
  end else if frac(f) < 0.52 then begin
    maintimer.interval := 970;
  end else begin
    maintimer.interval := 100;
    exit;
  end;

  btime.timehandler;
  (*
  {$ifndef mswindows}
  writeln(lcoretestcount);
  lcoretestcount := 0;
  {$endif}
  *)
  inc(tickcount);
  {writeln(unixtime,' ',formatfloat('0.0####',f),' ',maintimer.interval);}

  bsock.timehandler;
  b_gline.timehandler;
  bconnect.timehandler;
  bdnscache.timehandler;
  bipcheck.timehandler;
  bident.timehandler;
end;

procedure CleanupApplication;
begin
  if serverisrunning then begin
    if shutdownrestarting then
    restartserver
    else
    shutdownserver;
  end;
end;

procedure initapplication;
begin
  {call getparams again. in case it runs as NT service, it did not get the first one}
  getparams;

  lcoreinit;
  {$ifdef unix}
  if not checkpid('bircd.pid') then halt;
  {$endif}
  maintimer := tltimer.create(nil);
  maintimer.interval := 970;
  maintimer.ontimer := mainc.ontimer;
  startserver;
  {$ifdef unix}
  writepid;
  {$endif}
end;

procedure runapplication;
begin
  messageloop;
end;

end.

