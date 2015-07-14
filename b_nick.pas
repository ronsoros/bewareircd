(*
 *  beware ircd, Internet Relay Chat server, b_nick.pas
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

unit b_nick;

interface

uses buser,bcmds,bstuff,b_whowas,pgtypes;

procedure mu_nick(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure mc_nick(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_nick(cptr,sptr:tuser;parc:integer;parv:pparams);

function nickkill(olduser,newuser:tuser;shownewnick:bytestring):boolean;

implementation

uses
  {$ifndef nosethost}b_sethost,{$endif}
  bsend,bconfig,breplies,bwelcome,blinklist,bchannel,btime,bparse,bserver,
  b_kill,bipcheck,bconsts,bsock,bvaliddef,binipstuff;

{
kills one or both users, returns true if the new user is killed
needs fields set:
ts, idstr, name, userid, host, server, from

returns true if the new user is gone
}

function nickkill(olduser,newuser:tuser;shownewnick:bytestring):boolean;
var
  sameuserhost,killold,killnew:boolean;
  s,s2:bytestring;
begin
  result := false;
  sameuserhost := (olduser.userid = newuser.userid) and comparebinip(olduser.binip,newuser.binip);
  killold := true;
  killnew := true;
  if sameuserhost then begin
    if olduser.ts < newuser.ts then killnew := false
    else if olduser.ts > newuser.ts then killold := false
  end else begin
    if olduser.ts > newuser.ts then killnew := false
    else if olduser.ts < newuser.ts then killold := false
  end;

  if (olduser.ts) = (newuser.ts) then
  s := 'Nick collision'
  else if sameuserhost then
  s := 'nick collision from same user@host'
  else
  s := 'older nick overruled';

  {$ifndef nohis}
  if not opt.headinsand then
  {$endif}
    s := tuser(olduser.server.us).name +' <- '+ tuser(newuser.server.us).name+' ('+s+')';

  s2 := 'Nick collision on '+olduser.name+' ('+shownewnick+' '+inttostr(olduser.ts)+' <- '+tuser(newuser.server.us).name+' '+inttostr(newuser.ts);
  if sameuserhost then
  s2 := s2 + ' (Same user@host))'
  else
  s2 := s2 + ' (Different user@host))';

  locnotice(SNO_SERVKILL,s2);

  killnoticeflag := false;

  if olduser = newuser then killnew := false;
  {check to prevent killing the same user twice}

  if killold then begin
    dokill(me,me,olduser,s);
  end;

  if killnew then begin
    dokill(me,me,newuser,s);
    result := true;
  end;

end;

procedure mu_nick(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  l:listenobject;

begin
  l := connectionlist[cptr.socknum].listener;
  if l <> nil then begin
    if not l.clientaccept then begin
      cptr.error := 'Use another port';
      cptr.destroy;
      exit
    end;
  end;

  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  if not flag_isset(cptr.flags,userlog_nick) then begin
    setflag(cptr.flags,userlog_nick);
    if opt.nospoof then begin
      sendto_one(cptr,'PING :'+inttostr(cptr.randomid))
    end else setflag(cptr.flags,userlog_nospoof);
  end;
  cptr.name := copy(parv[1],1,opt.nicklen);
  welcome(cptr);
end;

procedure mc_nick(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
  p:tlinklist;
  a:integer;
begin
  if checkneedmoreparams(sptr,cmdnum,1,parc,parv) then exit;
  parv[1] := copy(parv[1],1,opt.nicklen);
  s := ircupper(parv[1]);

  if parv[1] = sptr.name then exit; {no change}

  if not validnickfromclient(parv[1]) then begin
    sendreply(sptr,ERR_ERRONEUSNICKNAME,parv[1]+' '+getrpl0(ERR_ERRONEUSNICKNAME));
    exit;
  end;

  if not strcompup(s,sptr.name) then if nameinuse(s) then begin
    sendreply(sptr,ERR_NICKNAMEINUSE,parv[1]+' '+getrpl0(ERR_NICKNAMEINUSE));
    exit;
  end;

  {cant change if banned on channels}
  p := sptr.channel;
  while p <> nil do begin
    if not hasopsorvoice(sptr,tuserchan(p).ch,nil) then if isbanned(sptr,tuserchan(p).ch,tuserchan(p)) then begin
      sendreply(sptr,ERR_BANNICKCHANGE,tuserchan(p).ch.name+' '+getrpl0(ERR_BANNICKCHANGE));
      exit;
    end;
    p := p.next;
  end;

  {cant change nick more than rougly once/30 secs}
  if unixtime+(nickdelay) <= sptr.nickpenalty then begin
    a := sptr.nickpenalty - (unixtime+(nickdelay));
    inc(sptr.nickpenalty,2);
    sendreply(sptr,ERR_NICKTOOFAST,parv[1]+' '+getrpl1(ERR_NICKTOOFAST,inttostr(a)));
    exit;
  end;
  if sptr.nickpenalty < unixtime then sptr.nickpenalty := unixtime;
  inc(sptr.nickpenalty,nickdelay);
  if not strcompup(sptr.name,parv[1]) then sptr.ts := irctime;

  sendto_serversbutone(sptr,sprefix(sptr,TOK_NICK)+parv[1]+' '+inttostr(sptr.ts));
  sendto_commonchannels(sptr,cprefix(sptr,MSG_NICK)+':'+parv[1]);
  addwhowas(sptr);
  setname(sptr,parv[1]);
  clearbancacheuser(sptr);
end;

{
SS nick hops TS user host +modes IP SSCCC :fullname
0  1    2    3  4    5    6     -3   -2      -1
                                 7    8      9
}

function decodeb64ip(s:bytestring):tbinip;
var
  a,b:integer;
  before,after:bytestring;
begin
  fillchar(result,sizeof(result),0);
  if (length(s) = 6) then begin
    result.family := AF_INET;
    a := p10strtoint(s);
    result.ip := htonl(a);
    exit;
  end;
  {$ifndef noipv6}
  a := pos('_',s);
  if (a = 0) then begin
    before := s;
    after := '';
  end else begin
    before := copy(s,1,a-1);
    after := copy(s,a+1,9999);
  end;
  b := length(before) div 3;
  for a := 0 to b-1 do begin
    result.ip6.u6_addr16[a] := htons(p10strtoint(copy(before,1+3*a,3)));
  end;
  b := length(after) div 3;
  for a := 0 to b-1 do begin
    result.ip6.u6_addr16[8-b+a] := htons(p10strtoint(copy(after,1+3*a,3)));
  end;
  result.family := AF_INET6;
  {$endif}
end;

procedure ms_nick(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us,us2:tuser;
  s,ipstr:bytestring;
  a:integer;
  ts,p10slotnum:integer;
  idstr:bytestring;
begin
  if (parv[1] = '') or (parc < 2) then begin
    cptr.error := 'Not enough params in NICK';
    cptr.destroy;
    exit;
  end;
  s := ircupper(parv[1]);

  if not (validnick(s)) {or (length(s) > opt.nicklen)} then begin
    cptr.error := 'Invalid nick: '+parv[1];
    cptr.destroy;
    exit;
  end;

  if isclient(sptr) then begin
    a := strtointdef(parv[2],0);
    if not strcompup(sptr.name,parv[1]) then begin
      {real nickchange - not just a chance in case}
      tsfromserver(sptr,a);
      sptr.ts := a;
      us2 := findname(s);
      if (us2 <> nil) and (us2 <> sptr) then begin
        if nickkill(us2,sptr,parv[1]) then exit;
      end;
    end;
    sendto_serversbutone(sptr,sprefix(sptr,TOK_NICK)+parv[1]+' '+inttostr(sptr.ts));
    sendto_commonchannels(sptr,cprefix(sptr,MSG_NICK)+':'+parv[1]);
    addwhowas(sptr);
    setname(sptr,parv[1]);
    clearbancacheuser(sptr);
    exit;
  end;
  if not isserver(sptr) then exit;
  if parc < 9 then begin
    cptr.error := 'Not enough params in NICK';
    cptr.destroy;
    exit; {not enough params}
  end;

  ts := strtointdef(parv[3],0);

  idstr := convertidstrlong(parv[parc-2]);
  if (length(idstr) <> 5) or (p10strtoint(idstr) = -1) then begin
    cptr.error := 'Error in NICK: bogus numeric: '+parv[parc-2];
    cptr.destroy;
    exit;
  end;

  {us.server := sptr.server;
  us.from := sptr.from;}
  {server field must be set before any check;
  if the server gets destroyed, the new user must go as well}

  p10slotnum := p10strtoint(copy(idstr,3,3)) and sptr.server.p10max;

  if p10server[p10strtoint(copy(idstr,1,2))] <> sptr.server then begin
    cptr.error := 'Error in NICK: server numeric and client numeric don''t match: '+sptr.idstr+' '+parv[parc-2];
    cptr.destroy;
    exit;
  end;
  if sptr.server.p10slots[p10slotnum] <> nil then begin
    cptr.error := 'Error in NICK: numeric collision: '+parv[parc-2]+' '+
    tuser(sptr.server.p10slots[p10slotnum]).name+' '+parv[1];
    cptr.destroy;
    exit;
  end;

  {
  - check removed because ircu (gnuworld) sent N messages like this
  if strtointdef(parv[2],0) <> sptr.hops then begin
    cptr.error := 'Error in NICK: bogus hopscount: '+parv[2];
    cptr.destroy;
    exit;
  end;}

  {checks are done here}

  us := adduser;

  us.server := sptr.server;
  us.from := sptr.from;

  us.hops := strtointdef(parv[2],1);
  us.ts := ts;

  us.idstr := convertidstr(idstr);
  us.p10slotnum := p10slotnum;

  us.userid := parv[4];
  us.host := parv[5];

  us.fullname := copy(parv[parc-1],1,maxgcoslength);

  if parv[6,1] = '+' then begin
    {modes}
    for a := 0 to maxusermodetable do if pos(usermodetable[a].c,parv[6]) <> 0 then setflag(us.modeflag,usermodetable[a].flag);
    a := 7;
    {$ifndef no21011}
    if pos('r',parv[6]) <> 0 then begin
      us.account := parv[a];
      inc(a);
    end;
    {$endif}
    {$ifndef nosethost}
    if opt.sethost then if (pos('h',parv[6]) <> 0) then begin
      setflag(us.modeflag,usermode_hhost);
      sethhost(us,parv[a],false);
{      inc(a);}
    end;
    {$endif}

  end;

  ipstr := parv[parc-3];
  us.binip := decodeb64ip(ipstr);

  us2 := findname(s);

  if us2 <> nil then begin
    if nickkill(us2,us,parv[1]) then exit;
  end;

  {from here, the new user is client}
  setflag(us.flags,userflag_isclient);
  setname(us,parv[1]);
  inc(count.globalclients);
  if count.globalclients > count.highestglobalclients then count.highestglobalclients := count.globalclients;
  if flag_isset(us.modeflag,usermode_invisible) then inc(count.invisible);
  if isoper(us) then inc(count.oper);
  inc(us.server.usercount);
  us.server.p10slots[us.p10slotnum] := us;

  ipcheck_remoteclient(us);

  sendto_serversbutone(us,propagateuserstr(us));

  {$ifndef novhost}
  checkxhost(us);
  {$endif}
end;

end.
