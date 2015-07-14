(*
 *  beware ircd, Internet Relay Chat server, buser.pas
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

unit buser;

interface

{$include bircd.inc}

uses
  blinklist,bcmds,bstuff,blargenum,bipcheck,bconsts,unitbanmask,binipstuff,pgtypes;

type
  tusermodetable=record
    c:bytechar;           {mode char}
    flag:integer;         {mode flag}
    local:boolean;
    disabled:boolean;
    auto:boolean;
    num:^integer;
  end;

const
  usermode_invisible= $1;
  usermode_oper=      $2;
  usermode_wallops=   $4;
  usermode_notices=   $8;
  usermode_service=  $10;
  usermode_deaf=     $20;
  usermode_debug=    $40;
  usermode_locop=    $80;
  usermode_xhost=    $100;
  usermode_hhost=    $200;
  usermode_reggedonly=$400;

  maxusermodetable=7
  {$ifndef novhost} +1 {$endif}
  {$ifndef noqnet} +1 {$endif}
  ;

  fakeipstr='127.0.0.1';

var
  usermodetable_reggedonly:integer;

const
  {
  this table is used in sending/receiving N messages
  }
  usermodetable:array[0..maxusermodetable] of tusermodetable=(
  (c:'i';flag:usermode_invisible),
  (c:'o';flag:usermode_oper),
  (c:'O';flag:usermode_locop;local:true),
  (c:'w';flag:usermode_wallops;auto:true),
  (c:'s';flag:usermode_notices),
  (c:'k';flag:usermode_service),
  (c:'d';flag:usermode_deaf),
  {$ifndef noqnet}
  (c:'R';flag:usermode_reggedonly;auto:true;num:@usermodetable_reggedonly),
  {$endif}
  {$ifndef novhost}
  (c:'x';flag:usermode_xhost),
  {$endif}
  (c:'g';flag:usermode_debug)
  );

  {
  each stage of the registration sets a flag;
  a combination of flags causes the connection to become server or client
  }
  userlog_nick=       $1;
  userlog_user=       $2;
  userlog_ident=      $4;
  userlog_dns=        $8;
  userlog_nospoof=   $10;
  userlog_server=    $20;
  userlog_regclient= userlog_nick or userlog_user or userlog_nospoof or userlog_dns or userlog_ident;
  userlog_ikline=    $40;

  userflag_globalkill=     $100; {don't send QUIT or similar to other servers}
  userflag_myuser=         $400;
  userflag_isserver=       $800;
  userflag_isclient=      $1000;
  userflag_destroying=    $2000;
  userflag_noerror=       $8000; {don't send an error when destroying this user}
  userflag_pongneeded=   $10000; {a ping has been sent, now pong is required to prevent timeout}
  userflag_initiated=    $20000; {this connection is done by connecting (as opposed to accepted)}
  userflag_parse=        $40000; {only parse received data if this flag is set}
  userflag_dnsreverse=   $80000; {reverse dns is done (need forward dns)}
  userflag_closed=      $100000;
  userflag_whomarked=   $200000; {marked by /WHO - matched. also used by /names to mark seen user in channel}
  userflag_parsing=     $400000; {parcerecvq is being done, prevent recursed call}
  userflag_hasvhost=    $800000; {has virtual host}
  userflag_nameset=    $1000000; {has name in name hashtable}
  userflag_nopenalty=  $2000000; {no penalty on this connection (server links)}
  userflag_whomarkshow=$4000000; {marked by /WHO - showed}
            {maximum  $80000000;}


{00110408
userlog_dns
userflag_myuser
userflag_pongneeded
userflag_closed}

  userlog_initiateserver= userlog_dns or userlog_ident or userflag_initiated;

  servflag_ulined=           $1; {server is U:lined}
  servflag_joining=          $2; {server doesnt have netburst completed (is J10)}
  servflag_destroying=       $4; {server is marked for being destroyed, ignore incoming SQUIT for this server}
  servflag_nosquit=          $8; {don't send a SQUIT when destroying this server}
  servflag_destroying_root= $10; {set for the first server in markdestroyingserver.
  prevent the same server from being destroyed twice (crash) when a farther server
  gets destroyed first, and then a nearer server}
  servflag_burstack=        $20;
  servflag_hub=             $40; {+h}
  servflag_services=        $80; {+s}
  servflag_ghost=          $100; {introduced a ghost}
  servflag_ipv6aware=      $200; {+6}

type
  pointerarray=array[0..0] of pointer;
  ppointerarray=^pointerarray;
  tserver=class(tlinklist)
    us:tlinklist;           {the user-object for this server}
    p10num:integer;         {numeric, 0..4095}
    p10slots:ppointerarray;
    p10max:integer;         {should be 2^n-1}
    parentserver:tserver;   {one server closer}
    usercount:integer;      {number of clients on server}
    linktime:integer;
    lag:integer;            {the lag number in /MAP}
    flags:integer;
    serverlinknum:integer;  {entry in server-link array}
    protoversion:integer;   {P##, other than 10 is accepted for remote servers, i assume the directly linked server properly uses P10}
    destructor destroy; override;
  end;
  tsilence=class(tlinklist)
    s:bytestring;
    bm:tbanmask
  end;

{
i made the string vars of a user have static length (string[nn]) because
i noticed a kind of n^2 slowdown if there are thousands of clones (local clients) -
which may be caused by delphi keeping some list of all allocated dynamic strings.
this may speed up, at the cost of using more ram. removing the [length] will not break anything

later clone tests revealed that 90% of cpu is used by the windows kernel, during the test.
on 2000 pro.
does this happen on all windows versions? do the short/static strings give any speedup?
}


  tuser=class(tthing)

    userid:string{$ifdef shortstrings}[userlen]{$endif};    {userid (supplied by identd or user command, identd overriding user command)}
    idstr:string{$ifdef shortstrings}[SSCCClen]{$endif};     {p10 numeric string SS for server or SSCCC for client}
    p10slotnum:integer;                                      {entry in the server's P10 users array}

    host:string{$ifdef shortstrings}[hostlen]{$endif};      {the actual host}

    {$ifndef novhost}
    vhost:string{$ifdef shortstrings}[hostlen]{$endif};     {virtual host (if set). use showhost function to get "current visible"}
    {$endif}
    {$ifndef nosethost}
    vuserid:string{$ifdef shortstrings}[userlen]{$endif};
    {$endif}

    binip:tbinip;    {dword ip}
    fullname:string[maxgcoslength];
    modeflag:integer; {any boolean user modes}
    snomask:integer;  {server notice mask (must be set to zero if the user is -s)}

    server:tserver;   {The Tserver this user is on. if this user isserver, it's his own server (not the parent)}
    hops:integer;     {hopcount}

    socknum:integer;  {index in connection-array}

    chancount:integer;  {on n channels}
    channel:tlinklist;

    away:bytestring;      {/away string}
    error:bytestring;     {error string, to be set prior to destroying user}
    password:bytestring;  {set by /pass}

    flags:integer;    {other, internal, boolean vars, not modes}
    signontime:integer;{online since, in /whois reply}
    ts:integer;       {nick last changed, used for nick collision}
    idletime:integer; {last time received PRIVMSG}

    from:tuser;       {the user/server which is directly connected to me and this user is behind. - from=self if local connection}

    recvq:bytestring;            {receive buffer; should not become length >1024 for a client}
    recvofs:integer;         {offset in buffer to parse next command from}
    penaltytime:integer;     {used for the "roughy 1 command/2 secs"}
    nickpenalty:integer;     {used for "rougly 1 nickchange/30 secs"}
    randomid:integer;        {random number used for nospoof ping}
    listinprogress:tlinklist; {Tlistinprogress - user is downloading a /LIST}
    invites:tlinklist2;
    silence:tsilence; {silence list}

    ipcheck:tipcheck;        {pointer to ipcheck structure}
    killer:tuser;            {who closed the connection}
    {$ifndef no21011}
    account:bytestring;          {services login name}
    {$endif}
    destructor destroy; override;
  end;

var
  globaluserlist:tlinklist;
  me:tuser;      {the local server}
  susermodesupported:bytestring;

  count:record
    globalclients:integer;
    localclients:integer;
    unknown:integer;
    oper:integer;
    invisible:integer;
    globalservers:integer;
    localservers:integer;
    connections:integer;
    channels:integer;

    highestconnections:integer;
    highestlocalclients:integer;
    highestglobalclients:integer;
    recvc,sendc:largenum;
  end;


function adduser:tuser;
{procedure removeuser(us:tuser);}

function isunreg(us:tuser):boolean;
function isclient(us:tuser):boolean;
function isserver(us:tuser):boolean;
function myconnect(us:tuser):boolean;
function isoper(us:tuser):boolean;
function isanoper(us:tuser):boolean;
function islocop(us:tuser):boolean;
function isservice(us:tuser):boolean;
function isprivileged(us:tuser):boolean;
function ispenalized(us:tuser):boolean;
function isunknown(us:tuser):boolean;
function isinitiated(us:tuser):boolean;
function isp10(us:tuser):boolean;
function isulinedserver(us:tuser):boolean;

function nickuserhost(us:tuser):bytestring;
function showuserid(us:tuser):bytestring;
function showhost(us:tuser):bytestring;

{checks if a name is occupied; also does jupes}
function nameinuse(const s:bytestring):boolean;
procedure setname(us:tuser;const s:bytestring);

{user1 can see user2 (for whois etc commands)}
function canseeuser(us1,us2:tuser):boolean;

{a string of all this user's modes. note that if there are any modes set, the string is prefixed with a space}
function usermodestr(us:tuser;global:boolean):bytestring;
function usermodestrdiff(prev,newstr:integer;toservers:boolean):bytestring;

function findnick(const s:bytestring):tuser;
function findname(const s:bytestring):tuser;
function finduser(const s:bytestring;numeric:boolean):tuser;
function findnumeric(const s:bytestring):tuser;
function convertidstr(const s:bytestring):bytestring;
function convertidstrlong(const s:bytestring):bytestring;

procedure setusermode(us,cptr,sptr:tuser;parc:integer;parv:pparams);

function usermodesupported:bytestring;

function is_silenced(sptr,target:tuser):boolean;

{$ifndef novhost}
function setvhost(us:tuser;const newuserid,newhost,quitreason:bytestring):boolean;
procedure checkxhost(us:tuser);
function cryptedvhost(us:tuser):bytestring;
function makexhost(us:tuser):bytestring;
{$endif}

function propagateuserstr(us:tuser):bytestring;
function propagateserverstr(p:tserver):bytestring;

procedure updatehighestconnections;

type
  tbanmask_user=record
    bm:tbanmask;
    vhost1:bytestring;
    vhost2:bytestring;
  end;

procedure banmaskmatch_user_init(var bmu:tbanmask_user;us:tuser);
function banmaskmatch_user(const bmu:tbanmask_user;us:tuser;const bm:tbanmask;const mask:bytestring):boolean;

{convert to valid *!*@* mask}
function cookmask(const s:bytestring):bytestring;

implementation

uses
  {$ifndef nosethost}b_sethost,{$endif}
  bserver,bparse,bsock,bchannel,bsend,bsearchtree,b_list,bconfig,breplies,
  b_whowas,bircdunit,passcryp,lcorernd,bident,bmodebuf,btime;

var
  usertree:thashtable;


function cookmask(const s:bytestring):bytestring;
var
  nick,userid,host:bytestring;
  possep1,possep2:integer;
begin
  (*- $Rrealname
  if copy(s,1,1) = '$' then begin
    result := s;
    exit;
  end;*)

  possep1 := pos('!',s);
  possep2 := pos('@',s);
  nick := '*';
  userid := '*';
  host := '*';
  if (possep1 = 0) and (possep2 = 0) then begin
    if ((pos('.',s) = 0) and (pos('/',s) = 0) and (pos(':',s) = 0)) then begin
      {only nick}
      nick := s;
    end else begin
      {only host}
      host := s;
    end;
  end else if (possep2 <> 0) and (possep1 = 0) then begin
    {user@host}
    userid := copy(s,1,possep2-1);
    host := copy(s,possep2+1,9999);

  end else if (possep2 = 0) and (possep1 <> 0) then begin
    {nick!user}
    nick := copy(s,1,possep1-1);
    userid := copy(s,possep1+1,9999);
  end else begin
    {nick!user@host}
    nick := copy(s,1,possep1-1);
    userid := copy(s,possep1+1,possep2-possep1-1);
    host := copy(s,possep2+1,9999);
  end;
  if length(nick) > opt.nicklen then nick := copy(nick,1,opt.nicklen);
  if length(userid) > userlen then begin
    userid := '*'+copy(userid,length(userid)-userlen+2,userlen-1);
  end;
  if length(host) > hostlen then begin
    host := '*'+copy(host,length(host)-hostlen+2,hostlen-1);
  end;


  result := nick + '!' + userid + '@' + host;

end;


function usermodesupported:bytestring;
var
  a:integer;
  s:bytestring;
begin
  if susermodesupported <> '' then begin
    result := susermodesupported;
    exit;
  end;
  s := '';
  for a := 0 to maxusermodetable do begin
    if not (usermodetable[a].disabled or usermodetable[a].local) then s := s + usermodetable[a].c;
  end;

  {alphabetically sort s into result, aAbB....}
  result := '';
  for a := 1 to 26 do begin
    if pos(chr(a+96),s) <> 0 then result := result + chr(a+96);
    if pos(chr(a+64),s) <> 0 then result := result + chr(a+64);
  end;
  susermodesupported := result;
end;

procedure setname(us:tuser;const s:bytestring);
begin
  if flag_isset(us.flags,userflag_nameset) then deltree(@usertree,ircupper(us.name));
  us.name := s;
  if us.name <> '' then begin
    addtree(@usertree,ircupper(us.name),us);
    setflag(us.flags,userflag_nameset)
  end else
  clearflag(us.flags,userflag_nameset);
end;

function nameinuse;
var
  sl:tstringlinklist;
begin
  result := findname(s) <> nil;
  if not result then begin
    sl := jupenicklist;
    while sl <> nil do begin
      if strcompup(sl.s,s) then begin
        result := true;
        exit
      end;
      sl := tstringlinklist(sl.next);
    end;
  end;
end;

function adduser:tuser;
begin
  result := tuser.create;
  result.name := '';
  result.randomid := randomdword and $7fffffff;
  linklistadd(globaluserlist,tlinklist(result));
end;

function isclient;
begin
  result := flag_isset(us.flags,userflag_isclient);
end;

function isserver;
begin
  result := flag_isset(us.flags,userflag_isserver);
end;

function isunreg;
begin
  result := not (isserver(us) or isclient(us));
end;

function myconnect;
begin
  result := flag_isset(us.flags,userflag_myuser);
end;

function isoper;
begin
  result := flag_isset(us.modeflag,usermode_oper);
end;

function isanoper;
begin
  result := flag_isset(us.modeflag,usermode_oper) or flag_isset(us.modeflag,usermode_locop);
end;

function islocop;
begin
  result := flag_isset(us.modeflag,usermode_locop);
end;

function isservice;
begin
  result := flag_isset(us.modeflag,usermode_service);
end;

function isprivileged;
begin
  result := flag_isset(us.modeflag,usermode_oper) or flag_isset(us.modeflag,usermode_locop) or flag_isset(us.flags,userflag_isserver);
end;

function ispenalized;
begin
  result := not flag_isset(us.flags,userflag_nopenalty);
end;

function isunknown;
begin
  result := isunreg(us) and not flag_isset(us.flags,userflag_initiated);
end;

function isinitiated;
begin
  result := flag_isset(us.flags,userflag_initiated);
end;

function isp10;
begin
  result := isserver(us.from) or flag_isset(us.from.flags,userlog_initiateserver);
end;

function isulinedserver(us:tuser):boolean;
begin
  result := false;
  if not isserver(us) then exit;
  result := flag_isset(us.server.flags,servflag_ulined);
end;

destructor tuser.destroy;
var
  s,s2:bytestring;
  p,p2:tlinklist;
  a:integer;
begin
  if flag_isset(self.flags,userflag_destroying) then exit;
  setflag(self.flags,userflag_destroying);
  if myconnect(self) then begin
    if not flag_isset(self.flags,userflag_closed) then begin
      {if not closing by force, and sendq is smaller than nn, put ERROR and send.}

      setflag(self.flags,userflag_closed);
      if connectionlist[self.socknum].open then begin
        if (connectionlist[self.socknum].sendqsize < 1460) and (not connectionlist[self.socknum].sendqexceeded) then begin
          {if too big sendQ, don't send}
          if not flag_isset(self.flags,userflag_noerror) and (self.error <> '') then begin
            if not assigned(killer) then killer := me;
            if isclient(self) then
            s := MSG_ERROR+' :Closing Link: '+self.name+'['+self.userid+'@'+self.host+'] by '+killer.name+' ('+self.error+')'#13#10
            else if isserver(self) then
            s := sprefix(me,TOK_SQUIT)+me.name+' 0 :'+self.error+#13#10
            else if isp10(self) then
            s := sprefix(me,TOK_ERROR)+':Closing Link: '+self.name+' by '+killer.name+' ('+self.error+')'#13#10
            else
            s := MSG_ERROR+' :Closing Link: '+self.name+'['+self.host+'] by '+killer.name+' ('+self.error+')'#13#10
          end else s := '';
          inc(connectionlist[self.socknum].sendqsize,length(s));
          inc(totalsendq,length(s));
          getsock(self).sendstr(s);
        end;
        connectionlist[self.socknum].open := false;
        connectionlist[self.socknum].sock.ondataavailable := nil;
        getsock(self).close;
      end;
    end;
    dec(totalsendq,connectionlist[self.socknum].sendqsize);
    connectionlist[self.socknum].sendqsize := 0;

    if assigned(connectionlist[socknum].identsock) then begin
      destroyidentdsock(connectionlist[socknum].identsock);
    end;
    {$ifndef nodnsquery}
    if assigned(connectionlist[socknum].dnsq) then begin
      connectionlist[socknum].dnsq.tag := 0;
      connectionlist[socknum].dnsq.destroy;
      connectionlist[socknum].dnsq := nil;
    end;
    {$endif}
    if flag_isset(self.flags,userflag_isserver) then
    dec(count.localservers)
    else if flag_isset(self.flags,userflag_isclient) then begin
      if serverisrunning then locnotice(SNO_CONNEXIT,'Client exiting: '+self.name+' ('+self.userid+'@'+self.host+') ['+self.error+'] ['+ircipbintostr(self.binip)+']');
      dec(count.localclients)
    end else dec(count.unknown);
    dec(count.connections);
    a := connectionlist[self.socknum].classnum;
    if (a > 0) and (a <= maxclass) then dec(classcount[a]);
    if connectionlist[self.socknum].listener <> nil then
    dec(connectionlist[self.socknum].listener.count);
    destroysock(self.socknum);
    clearneedsend(self.socknum);
  end;

  if flag_isset(self.flags,userflag_initiated) then if not isserver(self) then begin
    if connectionlist[self.socknum].connectby_user <> nil then begin
      if connectionlist[connectionlist[self.socknum].connectby_socknum].open then begin
        sendreply(connectionlist[connectionlist[self.socknum].connectby_socknum].user,cmdnotice,':*** Connection failed: '+self.error);
      end;
    end else begin
      locnotice(SNO_TCPCOMMON,'Connection to '+connectionlist[self.socknum].connectto_str+' failed: '+self.error);
    end;
    if connectionlist[self.socknum].open then begin
      connectionlist[self.socknum].open := false;
      getsock(self).close;
    end;
    if self.socknum >= 0 then destroysock(self.socknum);
  end;

  if isclient(self) then begin
    {send quit to common}
    {remove from channels}
    addwhowas(self);

    if serverisrunning then begin
      if not flag_isset(self.flags,userflag_globalkill) then
      sendto_serversbutone(self,sprefix(self,TOK_QUIT)+':'+self.error);

      sendto_commonchannels_butone(self,cprefix(self,MSG_QUIT)+':'+self.error);
    end;
    while self.channel <> nil do begin
      deluserfromchannel(self,tuserchan(self.channel).ch,tuserchan(self.channel));
    end;
    while self.invites <> nil do begin
      delinvitefromchannel(self,tchannel(tinvite(self.invites).ch),tinvite(self.invites));
    end;
    if flag_isset(self.modeflag,usermode_invisible) then dec(count.invisible);
    if isoper(self) then dec(count.oper);
    dec(count.globalclients);

    {remove from P10 list}
    self.server.p10slots[self.p10slotnum] := nil;

    dec(self.server.usercount);

  end else if isserver(self) then begin
    {
    send:
    no quits

    no squits. each server on the net must be able to do the destroying
    of the tree behind a given server

    }

    s2 := self.error;

    if not flag_isset(self.server.flags,servflag_destroying) then begin
      if serverisrunning then begin
        if myconnect(self) then
        locnotice(SNO_NETWORK,'Link with '+self.name+' cancelled: '+self.error+#15);

        locnotice(SNO_NETWORK,'Net break: '+tuser(self.server.parentserver.us).name+' '+self.name+' ('+self.error+#15')');
      end;

      {netsplit quit reason for clients
      (as this changes this server's "error" field, things which need the original reason,
      such as logging, before here     --beware}
      {$ifndef nohis}
      if opt.headinsand then
      self.error := '*.net *.split'
      else
      {$endif}
      self.error := tuser(self.server.parentserver.us).name+' '+self.name
    end;

    markdestroyingserver(self.server);
    p := globalserverlist;
    while p <> nil do begin
      p2 := p.next;
      if tserver(p).parentserver = self.server then if (tserver(p) <> self.server) then begin
        if not flag_isset(tserver(p).flags,servflag_destroying_root) then begin
          setflag(tserver(p).flags,servflag_nosquit);
          tuser(tserver(p).us).error := self.error;
          tuser(tserver(p).us).destroy;
        end;
      end;
      p := p2;
    end;
    if not flag_isset(self.server.flags,servflag_nosquit) then sendto_serversbutone(self,sprefix(tuser(self.server.parentserver.us),TOK_SQUIT)+self.name+' '+inttostr(self.server.linktime)+' :'+s2);

    self.server.destroy;
    {dec count.servers done in tserver.destroy}
  end;

  ipcheck_disconnect(self.ipcheck);

  if self.listinprogress <> nil then begin
    tlistinprogress(self.listinprogress).destroy;
    self.listinprogress := nil;
  end;

  while self.silence <> nil do begin
    p := tlinklist(self.silence);
    linklistdel(tlinklist(self.silence),p);
    tstringlinklist(p).destroy;
  end;

  setname(self,''); {remove name}
  linklistdel(globaluserlist,self);
  prev := nil;
  next := nil;
  inherited destroy;
end;


destructor tserver.destroy;
begin
  destroyserver(self);
  prev := nil;
  next := nil;
  inherited destroy;
end;

function nickuserhost;
begin
  if isclient(us) then result := us.name+'!'+showuserid(us)+'@'+showhost(us)
  else result := us.name
end;

function showuserid(us:tuser):bytestring;
begin
  {$ifndef nosethost}
  if us.vuserid <> '' then
  result := us.vuserid
  else
  {$endif}
  result := us.userid;
end;

function showhost(us:tuser):bytestring;
begin
  {$ifndef novhost}
  if us.vhost <> '' then
  result := us.vhost
  else
  {$endif}
  result := us.host;
end;


function canseeuser(us1,us2:tuser):boolean;
var
  p1,p2:tlinklist;
begin
  if not flag_isset(us2.modeflag,usermode_invisible) then begin
    result := true;
    exit
  end else result := false;
  if us1 = us2 then begin
    result := true;
    exit;
  end;
  p1 := us1.channel;
  while p1 <> nil do begin
    p2 := us2.channel;
    while p2 <> nil do begin
      if tuserchan(p1).ch = tuserchan(p2).ch then begin
        result := true;
        exit
      end;
      p2 := p2.next;
    end;
    p1 := p1.next;
  end;
end;

function usermodestr(us:tuser;global:boolean):bytestring;
var
  a:integer;
begin
  if us.modeflag = 0 then begin
    result := '';
    exit;
  end;
  result := ' +';
  for a := 0 to maxusermodetable do if not (usermodetable[a].local and global) then begin
    if us.modeflag and usermodetable[a].flag <> 0 then result := result + usermodetable[a].c;
  end;
end;

function usermodestrdiff(prev,newstr:integer;toservers:boolean):bytestring;
var
  a,b:integer;
begin
  result := '';
  if newstr = prev then exit;
  b := 0;
  for a := 0 to maxusermodetable do begin
    if (newstr and usermodetable[a].flag = 0) and (prev and usermodetable[a].flag <> 0) and (not (toservers and usermodetable[a].local)) then begin
      if b = 0 then begin
        b := 1;
        result := result + '-';
      end;
      result := result + usermodetable[a].c;
    end;
  end;
  b := 0;
  for a := 0 to maxusermodetable do begin
    if (newstr and usermodetable[a].flag <> 0) and (prev and usermodetable[a].flag = 0) and (not (toservers and usermodetable[a].local)) then begin
      if b = 0 then begin
        b := 1;
        result := result + '+';
      end;
      result := result + usermodetable[a].c;
    end;
  end;
end;

function convertidstr(const s:bytestring):bytestring;
begin
  if opt.shortnumerics then begin
    case length(s) of
      5: begin
        if (s[1] = 'A') and (s[3] = 'A') then
        result := s[2]+s[4]+s[5]
        else
        result := s;
      end;
      2: begin
        if s[1] = 'A' then
        result := s[2]
        else
        result := s;
      end;
      1,3: result := s;
      4: begin
        if s[2] = 'A' then
        result := s[1]+s[3]+s[4]
        else
        result := 'A'+s;
      end;
    end;
  end else begin
    case length(s) of
      2,5: result := s;
      3: result := 'A'+s[1]+'A'+s[2]+s[3];
      1,4: result := 'A'+s;
    end;
  end;
end;

function convertidstrlong(const s:bytestring):bytestring;
begin
  case length(s) of
    2,5: result := s;
    3: result := 'A'+s[1]+'A'+s[2]+s[3];
    1,4: result := 'A'+s;
  end;
end;

function findnumeric(const s:bytestring):tuser;
var
  p:pointer;
  SSnum:integer;
  CCCnum:integer;
begin
  result := nil;
  case length(s) of
    1:begin
      {S}
      ssnum := p10strtoint(copy(s,1,1));
      cccnum := -2;
    end;
    2:begin
      {SS}
      ssnum := p10strtoint(copy(s,1,2));
      cccnum := -2;
    end;
    3:begin
      {SCC}
      ssnum := p10strtoint(copy(s,1,1));
      cccnum := p10strtoint(copy(s,2,2));
    end;
    4:begin
      {SCCC (universal only)}
      ssnum := p10strtoint(copy(s,1,1));
      cccnum := p10strtoint(copy(s,2,3));
    end;
    5:begin
      {SSCCC}
      ssnum := p10strtoint(copy(s,1,2));
      cccnum := p10strtoint(copy(s,3,3));
    end;
    else begin
      ssnum := -1;
      cccnum := -1;
    end;
  end;
  if ssnum < 0 then exit;
  if cccnum = -2 then begin
    {is server}
    p := p10server[ssnum];
    if p <> nil then result := tuser(tserver(p).us);
  end else begin
    if cccnum < 0 then exit;
    p := p10server[ssnum];
    if p = nil then exit;
    p := tserver(p).p10slots[cccnum and tserver(p).p10max];
    if p <> nil then if tuser(p).idstr = convertidstr(s) then result := p;
  end;
end;

function findname(const s:bytestring):tuser;
begin
  result := findtree(@usertree,ircupper(s));
end;

function findnick(const s:bytestring):tuser;
begin
  result := findname(s);
  if result <> nil then if not isclient(result) then result := nil;
end;

function finduser(const s:bytestring;numeric:boolean):tuser;
begin
  if numeric then result := findnumeric(s)
  else result := findname(s);
end;

function is_silenced(sptr,target:tuser):boolean;
var
  p:tsilence;
  bmu:tbanmask_user;
begin
  result := false;
  p := target.silence;
  if p = nil then exit;
  if not isclient(sptr) then exit;
  if isservice(sptr) then exit;
  banmaskmatch_user_init(bmu,sptr);

  while p <> nil do begin
    if banmaskmatch_user(bmu,sptr,p.bm,p.s) then begin
      result := true;
      if not myconnect(sptr) then sendto_one(sptr.from,sprefix(target,TOK_SILENCE)+sptr.idstr+' :'+p.s);
      exit;
    end;
    p := tsilence(p.next);
  end;
end;


{$ifndef novhost}

{
code to make hidden host like "hidden-12345.domain.com", as on old unrealircd and beware0.7,
uncomment if you want it

function Maskchecksum(s:string):integer;
var
  i,j,k:integer;
begin
  j := 0;
  for i := 0 to length(s)-1 do begin
    if i < 16 then k := (i+1)*(i+1) else k := i*(i-15);
    inc(j,ord(s[i+1])*k);
  end;
  result := (j+1000) mod $ffff;
end;


function make_virthost(curr:string):string;
const
  HASHVAL_TOTAL = 30011;
  HASHVAL_PARTIAL = 211;
var
  hash_total,a,b:integer;
  parv:array[0..20] of string;
  parc:integer;
begin
  hash_total := maskchecksum(curr) mod hashval_total;
  parc := 0;
  a := 1;
  repeat
    if curr[a] = '.' then inc(parc) else parv[parc] := parv[parc] + curr[a];
    inc(a);
  until a > length(curr);
  if curr[length(curr)] in ['0'..'9'] then begin
    b := (maskchecksum(parv[0])+maskchecksum(parv[1])+maskchecksum(parv[2])) mod hashval_partial;
    if dt.maskipstring then result := parv[0]+'.'+parv[1]+'.'+inttostr(b)+'.'+dt.maskstring+'-'+inttostr(hash_total)
    else result := parv[0]+'.'+parv[1]+'.'+inttostr(b)+'.'+inttostr(hash_total);
    exit
  end;
  if (length(parv[parc]) = 2) and (parc >= 2) and ((parv[parc-1] = 'co') or (parv[parc-1] = 'com') or (parv[parc-1] = 'or') or (parv[parc-1] = 'org')) then begin
    result := dt.maskstring+'-'+inttostr(hash_total)+'.'+parv[parc-2]+'.'+parv[parc-1]+'.'+parv[parc];
  end else begin
    result := dt.maskstring+'-'+inttostr(hash_total)+'.'+parv[parc-1]+'.'+parv[parc];
  end
end;


}


function setvhost(us:tuser;const newuserid,newhost,quitreason:bytestring):boolean;
var
  a:integer;
  uc:tuserchan;
  olduserid:bytestring;
  s1,s2:bytestring;
begin
  result := false;

  {no change}
  if (us.vhost = newhost)
  {$ifndef nosethost}and (us.vuserid = newuserid){$endif}
  then exit;

  result := true;

  sendto_commonchannels_butone(us,cprefix(us,MSG_QUIT)+':'+quitreason);

  olduserid := showuserid(us);

  if (newuserid <> '') or (newhost <> '') then begin
    setflag(us.flags,userflag_hasvhost);
  end else clearflag(us.flags,userflag_hasvhost);

  {$ifndef nosethost}
  us.vuserid := newuserid;
  {$endif}
  us.vhost := newhost;

  uc := tuserchan(us.channel);
  while uc <> nil do begin
    {$ifndef nodelayed}
    if not flag_isset(uc.flags,userchanflag_delayed) then
    {$endif}
    begin
      sendto_channelbutone(us,uc.ch,cprefix(us,MSG_JOIN)+uc.ch.name);
      s1 := '';
      s2 := '';
      for a := 0 to maxuserchanmodetable do if flag_isset(uc.flags,userchanmodetable[a].flag) then begin
        s1 := s1 + userchanmodetable[a].c; s2 := s2 + ' '+us.name;
      end;
      if s1 <> '' then sendto_channelbutone(us,uc.ch,cprefix(me,MSG_MODE)+uc.ch.name+' +'+s1+s2);
    end;
    uc := tuserchan(uc.next)
  end;

  if olduserid <> showuserid(us) then s1 := showuserid(us)+'@' else s1 := '';
  s1 := s1 + showhost(us);

  if myconnect(us) then sendreply(us,RPL_HOSTHIDDEN,s1+' '+getrpl0(RPL_HOSTHIDDEN));

  clearbancacheuser(us);
end;

{
the procedure which creates the crypted host must be globally available, with this procedure name
because it is used (isbanned)
}
function cryptedvhost(us:tuser):bytestring;
var
  a:integer;
  s:bytestring;
begin
  {this code is really simple but does the job.
  i did look at irc-hispano's virtual hosts but they use real encryption (this is MD5)
  feel free to replace it with something better or to completely remove it}

  {dotted ip notation}
  s := passcryptinternal(ircipbintostr(us.binip)+opt.vhostcryptstr,0);
  for a := 1 to length(s) do begin
    if (s[a] = '[') or (s[a] = ']') then s[a] := '0';
  end;
  result := copy(s,4,6)+'.'+copy(s,10,6)+'.virtual';
end;

function makexhost(us:tuser):bytestring;
begin
  case opt.vhoststyle of
    0:result := '';
    1:if us.account <> '' then result := us.account+opt.vhostaccountstr else result := '';
    2:result := cryptedvhost(us);
    3:result := opt.vhostaccountstr;
  end;
end;

procedure checkxhost(us:tuser);
var
  s:bytestring;
begin
  if (opt.vhoststyle = 0) then exit;

  clearbancacheuser(us);

  {user has h-host which overrules x host}
  if flag_isset(us.modeflag,usermode_hhost) then exit;


  if flag_isset(us.flags,userflag_hasvhost) and not flag_isset(us.modeflag,usermode_xhost) then begin
    {user unsetting mode +x}
    setvhost(us,'','','Host change');
    exit;
  end;

  {here, the user's virtual host can be set, based on conditions.
  call checkvhost whenever one of those conditions change
  for example: user sets mode +x, user's ACCOUNT name changes, etc
  }
  if not flag_isset(us.modeflag,usermode_xhost) then exit;
  if flag_isset(us.flags,userflag_hasvhost) then exit;

  s := makexhost(us);
  if s <> '' then setvhost(us,'',s,opt.vhostquitreason);
end;
{$endif}

procedure setusermode(us,cptr,sptr:tuser;parc:integer;parv:pparams);
var
  cc:integer;
  a,setclear,lastsetclear:integer;
  s:bytestring;
  bool:boolean;
  byserver:boolean;
  uc:tuserchan;
  chardone:boolean;
  prevflags:integer;

procedure setmodechar(k:bytechar;flag:integer;setclear:integer);
begin
  if setclear = 2 then begin
    if not byserver then if us.modeflag and flag <> 0 then exit; {no change}
{    if lastsetclear <> setclear then outs := outs + '+';
    outs := outs + k;}
    lastsetclear := setclear;
    us.modeflag := us.modeflag or flag;
  end else begin
    if not byserver then if us.modeflag and flag = 0 then exit; {no change}
{    if lastsetclear <> setclear then outs := outs + '-';
    outs := outs + k;}
    lastsetclear := setclear;
    us.modeflag := us.modeflag and not flag;
  end;
end;

begin
  byserver := isserver(cptr);
  s := parv[2];
  setclear := 2;
  lastsetclear := 0;

  if us = nil then begin
    sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;

  if (sptr <> us) then begin
    if not (opt.usermodehacking and isulinedserver(sptr)) then begin
      sendreply(sptr,ERR_USERSDONTMATCH,getrpl0(ERR_USERSDONTMATCH));
      exit;
    end;
  end;

  if not byserver then if (parv[2] = '') or (parc < 3) then begin
    sendreply(sptr,RPL_UMODEIS,usermodestr(us,false));
    if flag_isset(sptr.modeflag,usermode_notices) then
    if ((not isanoper(sptr)) and (sptr.snomask <> sno_default)) or (isanoper(sptr) and (sptr.snomask <> opt.snodefaultoper)) then sendreply(us,RPL_SNOMASK,inttostr(us.snomask)+' '+getrpl1(RPL_SNOMASK,'0x'+inttohex(us.snomask,1)));
    exit;
  end;

  prevflags := us.modeflag;
  for cc := 1 to length(s) do begin
    chardone := false;
    case s[cc] of
      '-':setclear := 1;
      '+':setclear := 2;
      else begin
        bool := true;
        if bool then begin
          case s[cc] of
            'd':begin
              chardone := true;
              if setclear = 2 then begin
                if not flag_isset(us.modeflag,usermode_deaf) then begin
                  uc := tuserchan(us.channel);
                  while uc <> nil do begin
                    serverlinkcountchange(uc.ch,us.server.serverlinknum,-1);
                    uc := tuserchan(uc.next);
                  end;
                end;
              end else begin
                if flag_isset(us.modeflag,usermode_deaf) then begin
                  uc := tuserchan(us.channel);
                  while uc <> nil do begin
                    serverlinkcountchange(uc.ch,us.server.serverlinknum,1);
                    uc := tuserchan(uc.next);
                  end;
                end;
              end;
              setmodechar('d',usermode_deaf,setclear);
            end;
            'i':begin
              chardone := true;
              if setclear = 2 then begin
                if not flag_isset(us.modeflag,usermode_invisible) then inc(count.invisible)
              end else begin
                if flag_isset(us.modeflag,usermode_invisible) then dec(count.invisible)
              end;
              setmodechar('i',usermode_invisible,setclear);
            end;
            's':begin
              chardone := true;
              if setclear = 2 then begin
                if (parc < 4) or (parv[3] = '') then begin
                  if isanoper(us) then a := opt.snodefaultoper else a := sno_default
                end else begin
                  if parv[3,1] = '+' then
                    a := us.snomask or strtointdef(copy(parv[3],2,10),0)
                  else if parv[3,1] = '-' then
                    a := us.snomask and not strtointdef(copy(parv[3],2,10),0)
                  else
                    a := strtointdef(copy(parv[3],1,10),0);
                end;
              end else begin
                if (parc < 4) or (parv[3] = '') then a := 0 else begin
                  if parv[3,1] = '+' then
                    a := us.snomask and not strtointdef(copy(parv[3],2,10),0)
                  else if parv[3,1] = '-' then
                    a := us.snomask or strtointdef(copy(parv[3],2,10),0)
                  else
                    a := us.snomask and not strtointdef(copy(parv[3],1,10),0)
                end;
              end;
              if not isanoper(sptr) then a := a and not sno_oper;
              if (us.snomask = 0) and (a <> 0) then begin
                if byserver or isanoper(sptr) or not ({$ifndef nohis}opt.headinsand or{$endif} opt.secretnotices)
                then setmodechar('s',usermode_notices,2) else a := 0;
              end else if (us.snomask <> 0) and (a = 0) then begin
                setmodechar('s',usermode_notices,1)
              end else begin
                if myconnect(us) then if us.snomask <> a then sendreply(us,RPL_SNOMASK,inttostr(a)+' '+getrpl1(RPL_SNOMASK,'0x'+inttohex(a,1)));
              end;
              us.snomask := a;
            end;
            'g':begin
              chardone := true;
              if (setclear = 1) or byserver or isanoper(sptr) or not ({$ifndef nohis}opt.headinsand or {$endif}opt.secretnotices)
              then setmodechar('g',usermode_debug,setclear);
            end;
            'o':begin
              chardone := true;
              if setclear = 2 then begin
                if byserver then begin
                  if not isoper(us) then inc(count.oper);
                  setmodechar('o',usermode_oper,setclear);
                end
              end else begin
                if isoper(us) then dec(count.oper);
                setmodechar('o',usermode_oper,setclear);
              end;
            end;
            'O':begin
              chardone := true;
              if setclear = 2 then begin
                {}
              end else begin
                if not byserver then begin
                  setmodechar('O',usermode_locop,setclear);
                end;
              end;
            end;
            'k':begin
              chardone := true;
              if byserver or (isoper(sptr) and opt.opermodek) then begin
                if not byserver then if setclear=2 then if not isservice(sptr) then desynchwallops('oper '+sptr.name+' ('+sptr.userid+'@'+sptr.host+') sets mode +k');
                setmodechar('k',usermode_service,setclear);
              end;
            end;
            {$ifndef novhost}
            'x':begin
              if opt.vhoststyle > 0 then begin
                chardone := true;
                if setclear = 2 then begin
                  if not flag_isset(us.modeflag,usermode_xhost) then begin
                    setmodechar('x',usermode_xhost,setclear);
                    checkxhost(us);
                  end;
                end else begin
                  if isserver(cptr) then begin
                    {don't allow mode -x but i do allow it for users on other servers}
                    if flag_isset(us.modeflag,usermode_xhost) then begin
                      setmodechar('x',usermode_xhost,setclear);
                      checkxhost(us);
                    end;
                  end;
                end;
              end;
            end;
            {$endif}
            {$ifndef nosethost}
            'h':if opt.sethost then begin
              chardone := true;
              if setclear = 2 then begin
                dosethost(us,parv[3],parv[4],parc+2,false,sptr);
              end else begin
                if flag_isset(us.modeflag,usermode_hhost) then doclearhost(us);
                us.modeflag := us.modeflag and not usermode_hhost;
              end;
            end;
            {$endif}
          else
            for a := 0 to maxusermodetable do if s[cc] = usermodetable[a].c then if usermodetable[a].auto then if not usermodetable[a].disabled then begin
              chardone := true;
              setmodechar(usermodetable[a].c,usermodetable[a].flag,setclear);
            end;
          end;
          if not chardone then
            if myconnect(sptr) then sendreply(sptr,ERR_UMODEUNKNOWNFLAG,getrpl0(ERR_UMODEUNKNOWNFLAG));
        end;
      end
    end;
  end;

  if prevflags <> us.modeflag then begin
    s := usermodestrdiff(prevflags,us.modeflag,true);
    if s <> '' then sendto_serversbutone(sptr,sprefix(sptr,TOK_MODE)+us.name+' :'+s);
    if myconnect(us) then begin
      s := usermodestrdiff(prevflags,us.modeflag,false);
      if s <> '' then begin
        if opt.headinsand then if isserver(sptr) then sptr := me;
        sendto_one(us,cprefix(sptr,MSG_MODE)+us.name+' :'+s);
      end;
    end;
  end;
end;


function encodeb64ip(ip:tbinip;supportsv6:boolean):bytestring;
const
  addrlen=8;
var
  a,b,c,runbegin,runlength:integer;
begin
  {$ifndef noipv6}
  if ip.family = AF_INET6 then begin
    if not supportsv6 then begin
      result := 'AAAAAA';
      exit;
    end;
    {find longest run of zeroes}
    runbegin := 0;
    runlength := 0;
    for a := 0 to addrlen-1 do begin
      if ip.ip6.u6_addr16[a] = 0 then begin
        c := 0;
        for b := a to addrlen-1 do if ip.ip6.u6_addr16[b] = 0 then begin
          inc(c);
        end else break;
        if (c > runlength) then begin
          runlength := c;
          runbegin := a;
        end;
      end;
    end;
    result := '';
    for a := 0 to runbegin-1 do begin
      result := result + p10inttostr(htons(ip.ip6.u6_addr16[a]),3);
    end;
    if (runlength > 0) then result := result + '_';
    for a := runbegin+runlength to 7 do begin
      result := result + p10inttostr(htons(ip.ip6.u6_addr16[a]),3);
    end;
  end else
  {$endif}
  begin
    result := p10inttostr(htonl(ip.ip),6);
  end;
end;


function propagateuserstr(us:tuser):bytestring;
var
  s,s2:bytestring;
begin
  s := usermodestr(us,true);
  s2 := '';
  {$ifndef no21011}
  if us.account <> '' then begin
    if s = '' then s := ' +';
    s := s + 'r';
    s2 := s2 + ' '+us.account;
  end;
  {$endif}
  {$ifndef nosethost}
  if flag_isset(us.modeflag,usermode_hhost) then begin
    {i need to add the 'h' char because its "local only" flagged in the table}
    if s = '' then s := ' +';
    s := s + 'h';
    s2 := s2 + ' '+showuserid(us)+'@'+showhost(us);
  end;
  {$endif}

  result := sprefix(tuser(us.server.us),TOK_NICK)+us.name+' '+inttostr(us.hops+1)+' '+
  inttostr(us.ts)+' '+us.userid+' '+us.host+s+s2+' ';

  result := result + encodeb64ip(us.binip,flag_isset(us.server.flags,servflag_ipv6aware));
  result := result + ' '+us.idstr+' :'+us.fullname;
end;

function propagateserverstr(p:tserver):bytestring;
begin
  result := sprefix(tuser(p.parentserver.us),TOK_SERVER)+tuser(p.us).name+' '+
  inttostr(tuser(p.us).hops+1)+' '+inttostr(bootts)+' '+inttostr(p.linktime);
  if flag_isset(p.flags,servflag_joining) then result := result + ' J' else result := result + ' P';
  result := result + inttostr(p.protoversion div 10)+ inttostr(p.protoversion mod 10)+' '+
  convertidstr(p10inttostr(p.p10num,2)+p10inttostr(p.p10max,CCClen))+' +';
  if flag_isset(p.flags,servflag_hub) then result := result + 'h';
  if flag_isset(p.flags,servflag_services) then result := result + 's';
  if flag_isset(p.flags,servflag_ipv6aware) then result := result + '6';
  result := result + ' :'+tuser(p.us).fullname;
end;

procedure banmaskmatch_user_init(var bmu:tbanmask_user;us:tuser);
var
  nickstr:bytestring;
begin
  nickstr := us.name+'!'; {or empty}
  banmaskmake_oneuser(@bmu.bm,nickstr+us.userid,us.host,us.binip);
  {$ifndef nosethost}
  if flag_isset(us.modeflag,usermode_hhost) then begin
    bmu.vhost1 := nickstr+showuserid(us)+'@'+us.vhost;
    bmu.vhost2 := makexhost(us);
    if bmu.vhost2 <> '' then bmu.vhost2 := nickstr+us.userid+'@'+bmu.vhost2;
  end else
  {$endif}
  begin
    {$ifndef novhost}
    if opt.vhoststyle <> 0 then begin
      if flag_isset(us.flags,userflag_hasvhost) then bmu.vhost1 := us.vhost
      else bmu.vhost1 := makexhost(us);
      if bmu.vhost1 <> '' then bmu.vhost1 := nickstr+us.userid+'@'+bmu.vhost1;
    end else
    {$endif}
    bmu.vhost1 := '';
    bmu.vhost2 := '';
  end;
end;

function banmaskmatch_user(const bmu:tbanmask_user;us:tuser;const bm:tbanmask;const mask:bytestring):boolean;
begin
  (*- $Rrealname
  if copy(mask,1,2) = '$R' then begin
    {realname match}
    result := maskmatchup(copy(mask,3,500),us.fullname);
  end else*)
  begin
    result := banmaskmatch(@bm,@bmu.bm);
    {$ifndef novhost}
    if not result then if bmu.vhost1 <> '' then begin
      result := maskmatchup(mask,bmu.vhost1);
      {$ifndef nosethost}
      if not result then if bmu.vhost2 <> '' then begin
        result := maskmatchup(mask,bmu.vhost2);
      end;
      {$endif}
    end;
    {$endif}
  end;
end;

procedure updatehighestconnections;
var
  a:integer;
begin
  a := count.localclients+count.localservers;
  if a > count.highestconnections then begin
    count.highestconnections := a;
    if a mod 10 = 0 then begin
      locnotice(SNO_OLDSNO,'Maximum connections: '+inttostr(a)+' ('+inttostr(count.highestlocalclients)+' clients)');
    end;
  end;
end;

procedure init;
var
  a:integer;
begin
  globaluserlist := nil;

  for a := 0 to maxusermodetable do if usermodetable[a].num <> nil then
  usermodetable[a].num^ := a;
end;

initialization init;

end.
