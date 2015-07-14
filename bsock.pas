(*
 *  beware ircd, Internet Relay Chat server, bsock.pas
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

unit bsock;

{
local connections are an array and thus has a maximum
but this makes it safe to check if a socket still exists
}

{$ifdef noipv6}
'compiling without ipv6 support will exclude code that is necessary for handling users with IPv6 addresses on the network'
'this makes it problematic to support ipv6 on the network, even for other servers, or to transition to ipv6 later on. don''t do this'
{$endif}

interface

{$include bircd.inc}

uses
  dnsasync,
  {$ifdef mswindows}winsock,{$endif}lcore,lsocket,
  classes,buser,bconfig,bcmds,blargenum,bipcheck,bconsts,blinklist,binipstuff,
  unitbanmask,pgtypes;


const
  maxlistener=31;
  penaltytimeconst=8;
  floodreason = 'Excess Flood';

type
  TInetSockAddr = packed Record
    family:Word;
    port  :Word;
    addr  :Cardinal;
    pad   :array [1..8] of byte;
  end;

  tsc=class
    procedure SessionAvailableHandler(sender:tobject;error:word);
    procedure receiveHandler(sender:tobject;error:word);
    procedure closeHandler(sender:tobject;error:word);
    procedure connectHandler(sender:tobject;error:word);
    procedure senddatahandler(sender:tobject;bytessent:integer);
    procedure datasenthandler(sender:tobject;error:word);
  end;

  listenobject=class(tobject)
    sock:twsocket;
  public
    serveraccept:boolean;
    clientaccept:boolean;
    hidden:boolean;
    acceptmask:bytestring;

    ipmask:tbanmask;

    localaddr:bytestring;
    port:integer;
    count:integer;
  end;

  {
  i do not use "long" strings here to prevent leaks,
  they are not freed properly if they are not in a class
  }
  tconnection=record
    sock:twsocket;

    user:tuser;
    open:boolean;
    hasident:boolean;
    sending:boolean;
    sendqexceeded:boolean;
    identsock:twsocket; {socket used for identd lookup, must be destroyed when done}
    sendqsize:integer;
    receivecount:integer;
    connectby_socknum:integer;
    connectby_user:tuser;
    connectby_str:string[63]; {static string here atm. connection array is failsafe}
    connectto_str:string[31]; {static string here atm. connection array is failsafe}
    pingtime:integer; {last time something received from this user (for ping timeout)}
    lastreceived:integer;
    penaltyreceivecount:integer;
    {Y:line stuff for this connection}
    classnum:integer;
    pingfreq:integer;      {pingpong frequency}
    maxsendq:integer;        {max sendQ size}
    listener:listenobject;     {pointer to listener for this socket (if accepted)}
    port:integer;
    needsenditem:tplinklist; {item in list of connections which need sending}
    {$ifndef nodnsquery}
    dnsq:tdnsasync;     {dnsquery object, used for dns lookup in this user}
    {$endif}
  end;
  type tconnectionlist=array[0..0] of tconnection;

var
  listenlist:array[0..maxlistener] of listenobject;
  sc:tsc;
  maxconnections,maxclients:integer;
  highconnection:integer;
  nextconnection:integer;

  connectionlist:^tconnectionlist;

  needsendlist:tplinklist;
  globalneedsend:boolean;

{
starts a listener, returns true if ok
if an error did happen, any creating is undone
}
function addlistener(owner:tcomponent;cl:tconfline):boolean;
procedure closelistener(num:integer);
procedure closealllistener;
function setlistener:boolean;

{if a new connection exists because of acception or outgoing connection}
procedure newconnection(us:tuser;outgoing:boolean);

{call once per second}
procedure timehandler;

{call once during startserver, but after config.init}
procedure init;

{get number of empty connection entry}
function addsocket:integer;

{process what's in this user's recvq}
procedure parserecvq(us:tuser);

function getsock(us:tuser):twsocket;

function makelocaladdr(const s:bytestring):bytestring;

procedure destroysock(num:integer);

procedure sendcycle;
procedure socksend(a:integer);

procedure setneedsend(num:integer);
procedure clearneedsend(num:integer);
function isneedsend(num:integer):boolean;

function ircipbintostr(const ip:tbinip):bytestring;

implementation

uses
  bircdunit,bstuff,btime,bparse,bident,bsend,b_list,bserver,sysutils,breplies,
  b_gline;

function ircipbintostr(const ip:tbinip):bytestring;
begin
  result := ipbintostr(ip);
  if result <> '' then if result[1] = ':' then result := '0'+result;
end;

procedure setneedsend(num:integer);
var
  p:tplinklist;
begin
  if not globalneedsend then begin
    addtask(mainc.needsendmsg,nil,0,0);
    globalneedsend := true;
  end;

  if connectionlist[num].needsenditem <> nil then exit;
  p := tplinklist.create;
  p.p := pointer(num);
  connectionlist[num].needsenditem := p;
  linklistadd(tlinklist(needsendlist),tlinklist(p));
end;

procedure clearneedsend(num:integer);
var
  p:tplinklist;
begin
  p := connectionlist[num].needsenditem;
  if p = nil then exit;
  linklistdel(tlinklist(needsendlist),tlinklist(p));
  p.destroy;
  connectionlist[num].needsenditem := nil;
end;

function isneedsend(num:integer):boolean;
begin
  result := connectionlist[num].needsenditem <> nil;
end;

function sockreason(error:integer):bytestring;
begin
    case error of
      0:result := 'Read error: EOF from client';
      24:result := 'too many open files';
      10022:result := 'Invalid argument';
      32,
      10032:result := 'Broken pipe';
      10050:result := 'Read error: Network is down';
      10051:result := 'Read error: Network is unreachable';
      {
      10053:result := 'Software caused connection abort';
      windows 2000, as i tested, often returns 10053, hiding the real error code.
      i do this because it looks better (more ircd like)
      }
      54,
      104,
      10053,
      10054:result := 'Read error: Connection reset by peer';
      110,
      10060:result := 'Connection timed out';
      111,
      10061:result := 'Connection refused';
      10064:result := 'Read error: Host is down';
      113,
      10065:result := 'Read error: No route to host';
      {(Read error: 60 (Operation timed out))}
    else
      result := 'socket error '+inttostr(error);
    end;
end;

function makelocaladdr(const s:bytestring):bytestring;
begin
  if (s= '') or (s = '*') then result := '' else result := s;

//  {$ifdef mswindows}
//  if result = '' then result := '0.0.0.0';
//  {$endif}

end;

procedure setlistenerproperties(l:listenobject;acceptmask,flags:bytestring);
var
  b1,b2:boolean;
  s:bytestring;
begin
  if acceptmask = '' then s := '*' else s := acceptmask;
  l.acceptmask := s;
  b1 := pos('C',flags) <> 0;
  b2 := pos('S',flags) <> 0;
  l.clientaccept := b1 or not (b1 or b2);
  l.serveraccept := b2 or not (b1 or b2);
  l.hidden := pos('H',flags) <> 0;

  banmaskmake(@l.ipmask,acceptmask);
end;

function addlistener(owner:tcomponent;cl:tconfline):boolean;
var
  a,b:integer;
  s:bytestring;
begin
  result := false;
  b := -1;
  for a := 0 to maxlistener do if listenlist[a] = nil then begin
    b := a;
    break;
  end;
  if b = -1 then begin
    exit;
  end;
  listenlist[b] := listenobject.create;
  listenlist[b].sock := twsocket.create(nil);
  listenlist[b].sock.tag := taddrint(listenlist[b]);

  with listenlist[b] do begin
    try
      sock.Proto := 'tcp';
      sock.port := inttostr(cl.i4);
      s := makelocaladdr(cl.s2);
      sock.addr := s;
      listenlist[b].localaddr := sock.addr;
      sock.OnSessionAvailable := sc.SessionAvailableHandler;
      sock.listen;
      result := true;

      setlistenerproperties(listenlist[b],cl.s1,cl.s3);
      listenlist[b].port := cl.i4;
    except
      on e:exception do begin
        if serverisrunning then begin
          locnotice(SNO_OLDSNO,'Listen failed, '+sock.addr+' '+sock.port+', '+e.message);
        end else begin
          conwrite('Listen failed, '+sock.addr+' '+sock.port+', '+e.message);
        end;
        sock.destroy;
        listenlist[b].destroy;
        listenlist[b] := nil;
        exit
      end;
    end;
  end;
end;

function setlistener:boolean;
var
  p:tconfline;
  bool:boolean;
  a:integer;
begin

  {scan for each listener is its still in the P:lines, if not, close}
  for a := 0 to maxlistener do if listenlist[a] <> nil then begin
    bool := false;
    p := conflinelist;
    while p <> nil do begin
      if p.c = 'P' then begin
        if (makelocaladdr(p.s2) = listenlist[a].localaddr) and (p.i4 = listenlist[a].port) then begin
          bool := true;
        end;
      end;
      p := tconfline(p.next);
    end;
    if not bool then closelistener(a);
  end;

  {scan for each P:line if it has a listener; if not, add it}
  p := conflinelist;
  while p <> nil do begin
    if p.c = 'P' then begin
      bool := false;
      for a := 0 to maxlistener do if listenlist[a] <> nil then begin
        if (makelocaladdr(p.s2) = listenlist[a].localaddr) and (p.i4 = listenlist[a].port) then begin
          bool := true;
        end;
      end;
      if not bool then addlistener(nil,p);
    end;
    p := tconfline(p.next);
  end;
  result := false;
  for a := 0 to maxlistener do if listenlist[a] <> nil then result := true;


  {for each listener, find a P:line (there must be one) and set properties which don't require a port open.close}
  for a := 0 to maxlistener do if listenlist[a] <> nil then begin
    p := conflinelist;
    while p <> nil do begin
      if p.c = 'P' then begin
        if (makelocaladdr(p.s2) = listenlist[a].localaddr) and (p.i4 = listenlist[a].port) then begin
          setlistenerproperties(listenlist[a],p.s1,p.s3);
          break;
        end;
      end;
      p := tconfline(p.next);
    end;
  end;

end;

procedure closelistener(num:integer);
var
  a:integer;
  us:tuser;
begin
  if not assigned(listenlist[num]) then exit;
  if serverisrunning then begin
    for a := 0 to highconnection do if connectionlist[a].open then begin
      us := connectionlist[a].user;
      if connectionlist[a].listener = listenlist[num] then begin
        us.error := 'Listen port is closed';
        us.destroy;
      end;
    end;
  end;
  listenlist[num].sock.close;
  listenlist[num].sock.destroy;
  listenlist[num].destroy;
  listenlist[num] := nil;
end;

procedure closealllistener;
var
  a:integer;
begin
  for a := 0 to maxlistener do closelistener(a);
end;

procedure newconnection(us:tuser;outgoing:boolean);
var
  s:bytestring;
begin
  connectionlist[us.socknum].sock.OnSendData := sc.senddatahandler;
  setflag(us.flags,userflag_myuser);
  inc(count.unknown);
  inc(count.connections);

  connectionlist[us.socknum].pingfreq := maxlongint;
  {this is set to require one to complete the registering in a timeout window}
  setflag(us.flags,userflag_pongneeded);

  connectionlist[us.socknum].maxsendq := 100000;

  us.host := ircipbintostr(us.binip);

  connectionlist[us.socknum].pingtime := unixtime;
  connectionlist[us.socknum].lastreceived := irctime;

  {the K/G-line check for the case of CIDR G-lines}
  if glinebinmatch(us,s) then begin
    //sendreply(us,ERR_YOUREBANNEDCREEP,':*** '+s+'.');

    //special case, because the user has no name set
    sendto_one(us,cprefix(me,cmdstr(ERR_YOUREBANNEDCREEP))+'*'+' '+':*** '+s+'.');
    us.error := 'K-lined';
    us.destroy;
    exit;
  end;

  {start identd}
  dnsidentstart(us);
end;

procedure parserecvq(us:tuser);
label eind;
var
  a,b,c,d,socknum:integer;
  goed:boolean;
  server:boolean;
  s:bytestring;
begin
  if flag_isset(us.flags,userflag_parsing) then exit;
  socknum := us.socknum;
goed := false;
  a := us.recvofs;
  if a < 1 then a := 1;
  b := length(us.recvq);
  if b = 0 then exit;

  setflag(us.flags,userflag_parsing);

  d := 0;
  server := isserver(us);
  repeat
    c := a;
    while (a < b) and (us.recvq[a] <> #13) and (us.recvq[a] <> #10) do inc(a);
    if (a <= b) then if (us.recvq[a] <> #13) and (us.recvq[a] <> #10) then inc(a);
    if a <= b then begin

      s := pansichar(copy(us.recvq,c,a-c));
      {s := copy(us.recvq,c,a-c);} {- copy without null termination}
      d := a;
      us.recvofs := d;
      if s <> '' then begin
        if server then begin
          parsecommand(us,s,true);
          if not connectionlist[socknum].open then exit;
        end else begin
          if us.penaltytime < unixtime then us.penaltytime := unixtime;
          parsecommand(us,s,true);
          if not connectionlist[socknum].open then exit;
          if ispenalized(us) then if us.penaltytime > unixtime+penaltytimeconst then begin
            goed := true;
          end;
        end;
        b := length(us.recvq);
      end;
    end else goed := true;
    inc(a);
  until goed;

  if d > 0 then delete(us.recvq,1,d);
  us.recvofs := 1;
eind:
  clearflag(us.flags,userflag_parsing);
end;

procedure tsc.receiveHandler(sender:tobject;error:word);
const bufsize=4096;
var
  i:integer;
  us:tuser;
  sock:twsocket;
  socknum:integer;
{  s:bytestring;
  buf:array[0..bufsize-1] of byte; }
begin
{  conwrite('receive begin');}
  socknum := tcomponent(sender).tag;
  if socknum < 0 then begin
    twsocket(sender).receivestr;
    exit;
  end;
  {AV crash location socknum = 195948557 (fixed? by disabling handler after unsetting "open")

  workaround 1: disabling on-handlers when destroying sock does it?
  workaround 2:
  - 0 <= tag <= highconnection.
  - connectionlist[tag].open
  - connectionlist[tag].sock = sender

  }
  if not connectionlist[socknum].open then begin
    twsocket(sender).receivestr;
    exit;
  end;
  us := connectionlist[socknum].user;
  sock := connectionlist[us.socknum].sock;

  i := length(us.recvq);
  us.recvq := us.recvq + sock.receivestr;
  i := length(us.recvq)-i;

  {i := sock.receive(@buf,bufsize);
  setlength(s,i);
  move(buf[0],s[1],i);
  us.recvq := us.recvq + s;}

  addlargenum(count.recvc,i);

  if isunreg(us) then begin
    if not isinitiated(us) then begin

      inc(connectionlist[us.socknum].receivecount,i);
      if connectionlist[us.socknum].receivecount >= 1024 then begin
        us.error := floodreason;
        us.destroy;
        exit;
      end;
    end;

  end else if isclient(us) then begin
    inc(connectionlist[socknum].penaltyreceivecount,i);
    if (length(us.recvq) > opt.floodbufsize) then if not (isoper(us) and opt.opernoflood) then begin
      us.error := floodreason;
      us.destroy;
      exit;
    end;
  end;

  if flag_isset(us.flags,userflag_parse) then begin
    if ispenalized(us) then begin
      if us.penaltytime >= unixtime+penaltytimeconst then exit;
      parserecvq(us);
      if connectionlist[socknum].penaltyreceivecount > opt.floodbufsize then begin
        if opt.opernoflood and isoper(us) then exit;
        us.error := floodreason;
        us.destroy;
        exit;
      end;
    end else begin
      parserecvq(us);
    end;
  end;
{  conwrite('receive end');}
end;


procedure tsc.closeHandler(sender:tobject;error:word);
var
  us:tuser;
  sock:twsocket;
begin
  sock := twsocket(sender);
  if sock.tag < 0 then exit;
  if not connectionlist[sock.tag].open then exit;
  connectionlist[sock.tag].open := false;
  sock.ondataavailable := nil;
  us := connectionlist[sock.tag].user;
  if not assigned(us) then exit;
  if not flag_isset(us.flags,userflag_closed) then begin
    if us.error = '' then begin
      us.error := sockreason(error);
      if error = 0 then begin
        if isserver(us) then us.error := 'Server '+us.name+' closed the connection' {looks better for a server than "EOF from client"}
        else if isunreg(us) then us.error := us.name+' closed the connection';
      end;
    end;
    setflag(us.flags,userflag_closed);
    sock.close;
    {sock.destroy;
    sock := nil;}
    {us.destroy;}
    {destroysock(sock.tag);}
    addtask(mainc.destroyusermsg,nil,sock.tag,0);
  end;
end;

procedure destroysock(num:integer);
begin
  {if num < nextconnection then nextconnection := num;
  connectionlist[num].sock.destroy;
  fillchar(connectionlist[num],sizeof(connectionlist[num]),0);}
  addtask(mainc.destroysockmsg,nil,num,0);
end;

procedure tsc.SessionAvailableHandler(sender:tobject;error:word);
var
  sock:twsocket;
  handle:integer;
  us:tuser;
  a:integer;
  ip:tbinip;

  ipc:tipcheck;
  listener:listenobject;
  bm:tbanmask;
begin
{  conwrite('accept begin');}
  us := nil;
  try

  try
    handle := twsocket(sender).accept;
  except
    on e:exception do begin
      wallops('accept raised exception: '+e.message);
      conwrite('exception in accept1 '+e.message);
      exit;
    end;
  end;
  sock := twsocket.create(nil);
  sock.dup(handle);
  sock.OnDataAvailable := sc.receivehandler;

  {$ifdef mswindows}
  ipstrtobin(sock.getpeeraddr,ip);
  {$else}
  sock.getpeeraddrbin(ip);
  {$endif}

  ipc := ipcheck_connect(ip);
  if ipc = nil then begin
    sock.sendstr(MSG_ERROR+' :Your host is trying to (re)connect too fast -- throttled'#13#10);
    sock.destroy;
    exit;
  end;

  listener := pointer(twsocket(sender).tag);

  if listener.ipmask.cidr <> 255 then begin
    banmaskmake_oneuser(@bm,'','',ip);
    if not banmaskmatch(@listener.ipmask,@bm) then begin
      sock.sendstr(MSG_ERROR+' :You can''t connect to this port'#13#10);
      sock.destroy;
      exit;
    end;
  end;

  (*
  if ((ip and listener.ipmask) <> listener.ip) then begin
    ipcheck_disconnect(ipc);
    sock.sendstr(MSG_ERROR+' :You can''t connect to this port'#13#10);
    sock.destroy;
    exit;
  end;
  *)
  {assign localuser}
  a := addsocket;
  sock.tag := a;
  if a = -1 then begin
    {no free connections}
    ipcheck_disconnect(ipc);
    sock.sendstr(MSG_ERROR+' :No more connections'#13#10);
    sock.destroy;
    exit;
  end;

  sock.Onsessionclosed := sc.closehandler;
{  sock.ondatasent := sc.datasenthandler;}

  us := adduser;
  us.server := me.server;
  us.from := us;
  us.ipcheck := ipc;
  us.binip := ip;

  inc(listener.count);

  connectionlist[a].sock := sock;
  connectionlist[a].listener := listener;
  connectionlist[a].port := listener.port;
  with connectionlist[a] do begin
    user := us;
    open := true;
  end;
  us.socknum := a;

  newconnection(us,false);

  except
    on e:exception do begin
      if assigned(us) then us.destroy;
      conwrite('exception in accept2 '+e.message);
      wallops('exception in onsessionavailable: "'+e.message+'". Please file a bug report with the developers.');
    end;
  end;
{  conwrite('accept end');}
end;

procedure tsc.connectHandler(sender:tobject;error:word);
var
  socknum:integer;
  sock:twsocket;
  us:tuser;

begin
  socknum := twsocket(sender).tag;
  if socknum < 0 then exit;
  us := connectionlist[socknum].user;

  sock := twsocket(sender);

  if error = 0 then begin
    connectionlist[socknum].port := strtointdef(twsocket(sender).getxport,0);
    us.name := '';
    us.server := me.server;
    us.from := us;
    us := connectionlist[socknum].user;

    {$ifdef mswindows}
    ipstrtobin(sock.getpeeraddr,us.binip);
    {$else}
    sock.getpeeraddrbin(us.binip);
    {$endif}

    {become "unregistered connection"}

{    sendto_one(us,'PASS :'+us.password);
    us.password := '';
    sendto_one(us,'SERVER '+me.name+' 1 '+inttostr(bootts)+' '+inttostr(irctime)+' J10 '+me.idstr+p10inttostr(me.server.p10max,CCClen)+' :'+me.fullname);}

    {- PASS and SERVER sent later, after the dns/ident are completed, in bwelcome unit}

    newconnection(us,true);
  end else begin
    us.error := sockreason(error);
    connectionlist[socknum].open := false;
    connectionlist[socknum].user.destroy;
  end;
end;


procedure timehandler;
var
  a,b,c:integer;
  us:tuser;
begin
  c := (tickcount and 7);

  {every second, i ping of 1/8th of the connections, so they aren't all at the same time
  smaller peaks on the system monitor instead of one big one.
  }

  {poll pingpong}
  for a := 0 to highconnection do if a and 7 = c then if connectionlist[a].open then if connectionlist[a].pingfreq <> 0 then begin
    us := connectionlist[a].user;
    if isunreg(us) then begin
      {kill after 40 decs w/no warning}
      if connectionlist[us.socknum].pingtime < unixtime-unregtimeout then begin
        us.error := 'Ping Timeout';
        us.destroy;
      end;
    end else begin
      if connectionlist[us.socknum].pingtime < unixtime-connectionlist[us.socknum].pingfreq then begin
        if flag_isset(us.flags,userflag_pongneeded) then begin
          if isserver(us) then locnotice(SNO_NETWORK,'No response from '+us.name+', closing link');
          us.error := 'Ping Timeout';
          us.destroy;
        end else begin
          setflag(us.flags,userflag_pongneeded);
          connectionlist[us.socknum].pingtime := unixtime;
          if isserver(us) then begin
            sendto_one(us,sprefix(me,TOK_PING)+':'+me.name)
          end else
          sendto_one(us,'PING :'+me.name);
        end
      end;
    end;
  end;


  if tickcount and 1 = 0 then begin
   { processmessages;}
    b := 0;
    for a := 0 to highconnection do if connectionlist[a].sock <> nil then b := a;
    highconnection := b;

    {penalty, 1 command per 2 seconds}
    for a := 0 to highconnection do if connectionlist[a].open then begin
      us := connectionlist[a].user;
      if us.recvq <> '' then
      {sc.receivehandler(connectionlist[a].sock,0);}
      if flag_isset(us.flags,userflag_parse) then parserecvq(us);
    end;
  end;
end;

function addsocket:integer;
var
  a:integer;
begin
  result := -1;
  for a := nextconnection to maxconnections-1 do begin
    if connectionlist[a].user = nil then begin
      if a > highconnection then highconnection := a;
      nextconnection := a+1;
      result := a;
      exit;
    end
  end;
end;

function getsock;
begin
  result := connectionlist[us.socknum].sock;
end;

procedure init;
begin
  highconnection := 0;
  nextconnection := 0;
  maxclients := opt.maxclients;

  {limit on numerics for this server}
  if maxclients > CCCmask+1 then maxclients := CCCmask+1;

  {sanity check}
  if maxclients > 16384 then maxclients := 16384;
  if maxclients < 10 then maxclients := 10;

  maxconnections := maxclients+24;

  getmem(connectionlist,sizeof(tconnection)*maxconnections);
  fillchar(connectionlist^,sizeof(tconnection)*maxconnections,0);
end;

procedure tsc.senddatahandler(sender:tobject;bytessent:integer);
var
  a:integer;
begin
  a := twsocket(sender).tag;
  if not connectionlist[a].open then exit;
  dec(connectionlist[a].sendqsize,bytessent);
  dec(totalsendq,bytessent);
  if connectionlist[a].sendqsize <= 0 then connectionlist[a].sending := false;
  addlargenum(count.sendc,bytessent);
end;

procedure tsc.datasenthandler(sender:tobject;error:word);
var
  a:integer;
begin
  a := twsocket(sender).tag;
  if not connectionlist[a].open then exit;
  if connectionlist[a].user.listinprogress <> nil then listinprogresshandler(connectionlist[a].user);
end;

procedure socksend(a:integer);
begin
  if connectionlist[a].sendqexceeded then begin
    connectionlist[a].user.error := 'Max SendQ exceeded';
    addtask(mainc.destroyusermsg,nil,a,integer(connectionlist[a].user));
    exit;
  end;
  clearneedsend(a);
  try
    if connectionlist[a].sendqsize > 0 then begin
{      conwrite('before send');}
      connectionlist[a].sending := true;
      connectionlist[a].sock.Send(nil,0);
{      conwrite('after send');}
    end;
  except
    on E: Exception do begin
      conwrite('exception in send: '+e.message);
      locnotice(SNO_OLDSNO,'sending to connection '+inttostr(a)+' raised exception: ['+E.Message+'] ['+inttostr(E.HelpContext)+']');
    end;
  end;
end;

procedure sendcycle;
var
  a,b:integer;
  p,p2:tplinklist;
begin
  globalneedsend := false;

  {first send server links}
  for b := 1 to highserverlink do if serverlinklist[b] <> nil then begin
    a := tuser(serverlinklist[b].us).socknum;
    if connectionlist[a].open then socksend(a);
  end;

  {then send all non-server connections}
  p := needsendlist;
  while p <> nil do begin
    a := integer(p.p);
    p2 := tplinklist(p.next);
    if connectionlist[a].open then if not isserver(connectionlist[a].user) then socksend(a);
    p := p2;
  end;

  (*
  for a := 0 to highconnection do begin
    if connectionlist[a].open then begin
      socksend(a);
    end
  end;
  *)
end;

begin
  needsendlist := nil;
  fillchar(listenlist,sizeof(listenlist),0);
end.
