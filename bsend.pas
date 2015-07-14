(*
 *  beware ircd, Internet Relay Chat server, bsend.pas
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

unit bsend;

interface

uses buser,bchannel,bconsts,blargenum,bstuff,pgtypes;

const
  SNO_OLDSNO=1; {unsorted old messages}
  SNO_SERVKILL=2; {server kills (nick collisions)}
  SNO_OPERKILL=4; {oper kills}
  SNO_HACK2=$8;    {desyncs}
  SNO_HACK3=$10;   {temporary desyncs}
  SNO_UNAUTH=$20;  {unauthorized connections}
  SNO_TCPCOMMON=$40; {common TCP or socket errors}
  SNO_TOOMANY=$80; {too many connections}
  SNO_HACK4=$100;  {Uworld actions on channels}
  SNO_GLINE=$200;  {glines}
  SNO_NETWORK=$400; {net join/break, etc}
  SNO_IPMISMATCH=$800; {IP mismatches}
  SNO_THROTTLE=$1000; {host throttle add/remove notices}
  SNO_OLDREALOP=$2000; {old oper-only messages}
  SNO_CONNEXIT=$4000;  {client connect/exit (ugh)}

  sno_default=SNO_OLDSNO or SNO_NETWORK or SNO_OPERKILL or SNO_GLINE;
  SNO_OPER=(SNO_CONNEXIT or SNO_OLDREALOP);
  SNO_DEFAULTOPER=SNO_DEFAULT or SNO_SERVKILL or SNO_OLDSNO or SNO_HACK2 or SNO_HACK3 or SNO_HACK4 or SNO_UNAUTH or SNO_TCPCOMMON;

{
changes for delayed join:

- sendmsgtochannel, if the user is delayed (based on the userchan parameter)
 then message is only sent to the user itself, not the other users on the channel
(join, part)

- sendto_commonchannels(butone), if the user is delayed (on a given channel),
then that channel is not processed for sending messages to users
(nick change, quit)
}

{send numeric reply to local client}
procedure sendreply(us:tuser;rplnum:integer;const s:bytestring);

procedure sendmsgto_one(source,target:tuser;cmdnum:integer;const s:bytestring);
procedure sendto_one(us:tuser;const s:bytestring);
procedure send_statusnotice(us:tuser;const s:bytestring);
procedure sendmsgto_channel(source:tuser;target:tchannel;cmdnum:integer;const s:bytestring;uc:tuserchan);
procedure sendto_channel(target:tchannel;const s:bytestring);
procedure sendto_commonchannels(source:tuser;const s:bytestring);
procedure sendto_commonchannels_butone(source:tuser;const s:bytestring);
procedure sendto_serversbutone(source:tuser;const s:bytestring);
procedure sendchatto_serversbutone(source:tuser;ch:tchannel;const s:bytestring);
procedure sendchatto_channelbutone(source:tuser;ch:tchannel;const s:bytestring);
procedure sendchatto_serversbutone_flags(source:tuser;ch:tchannel;flags:integer;const s:bytestring);
procedure sendchatto_channelbutone_flags(source:tuser;ch:tchannel;flags:integer;const s:bytestring);
procedure sendto_channelbutone(source:tuser;ch:tchannel;const s:bytestring);
procedure wallops(const s:bytestring);
procedure desynchwallops(const s:bytestring);

{":sender CMD " for server-server protocol}
function sprefix(us:tuser;const cmd:bytestring):bytestring;
function cprefix(us:tuser;const cmd:bytestring):bytestring;

{send server notice}
procedure locnotice(mask:integer; s:bytestring);

procedure needmoreparams(us:tuser;cmdnum:integer);
function checkneedmoreparams(us:tuser;cmdnum,need,parc:integer;parv:pparams):boolean;

procedure sendnosuchserver(sptr:tuser;server:bytestring);

var
  totalsendq:integer=0;
  totalsendqpeak:integer=0;

implementation

uses
  {$ifdef mswindows}winsock,{$endif}lcore,lsocket,
  breplies,bcmds,bircdunit,bsock,blinklist,bserver,b_wallops,b_desynch,bconfig;

function sprefix(us:tuser;const cmd:bytestring):bytestring;
begin
  result := us.idstr+' '+cmd+' ';
end;

function cprefix(us:tuser;const cmd:bytestring):bytestring;
begin
  result := ':'+nickuserhost(us)+' '+cmd+' ';
end;

procedure sendqexceed(num:integer);
begin
  dec(totalsendq,connectionlist[num].sendqsize);
  connectionlist[num].sendqsize := 0;
  connectionlist[num].sock.deletebuffereddata;
  connectionlist[num].sendqexceeded := true;
  setneedsend(num);
end;

procedure totalsendqcheck;
var
  a,b,c:integer;
begin
  while (totalsendq > opt.maxtotalsendq) do begin
    b := -1;
    c := 0;
    for a := 0 to highconnection do if connectionlist[a].open then if isclient(connectionlist[a].user) then begin
      if (connectionlist[a].sendqsize > c) then begin
        b := a;
        c := connectionlist[a].sendqsize;
      end;
    end;
    if b >= 0 then sendqexceed(b);
  end;
end;


procedure sendto_one(us:tuser;const s:bytestring);
const crlf:string[2]=#13#10;
const lf:string[1]=#10;
var
  sock:twsocket;
  i,b:integer;
{$ifdef bdebug}
  ch:tchannel;
{$endif}
begin
  us := us.from;
  {$ifdef bdebug}
  if isserver(us) then begin
    ch := findchan(debugchanprefix+us.name);
    if ch <> nil then sendto_channel(ch,cprefix(me,MSG_PRIVMSG)+ch.name+' :'+debugsendattr+debugstr(s));
  end;
  {$endif}

  {!!! AV location on windows XP, /die command}
  b := us.socknum;
  if connectionlist[b].user <> us then exit; {extra check for send to wrong target}

  if not connectionlist[b].open then exit;
  if (connectionlist[b].sendqexceeded) then exit; {sendQ exceeded}
  if (connectionlist[b].sendqsize > connectionlist[b].maxsendq) then begin
    sendqexceed(b);
    exit;
  end;
  totalsendqcheck;
  if (connectionlist[b].sendqexceeded) then exit; {sendQ exceeded}

  sock := getsock(us);

  sock.putdatainsendbuffer(@s[1],length(s));
  if isserver(us) then begin
    i := length(s)+1;
    sock.putdatainsendbuffer(@lf[1],1);
  end else begin
    i := length(s)+length(crlf);
    sock.putdatainsendbuffer(@crlf[1],length(crlf));
  end;
  if connectionlist[b].sendqsize = 0 then setneedsend(b);

  inc(connectionlist[b].sendqsize,i);
  inc(totalsendq,i);
  if totalsendq > totalsendqpeak then totalsendqpeak := totalsendq;
  if connectionlist[b].sendqsize >= 1460 then if not connectionlist[b].sending then begin
    socksend(b);
  end;
end;

procedure send_statusnotice(us:tuser;const s:bytestring);
var
  l:listenobject;
begin
  if not opt.statusnotices then exit;
  if us.socknum < 0 then exit;
  if flag_isset(us.flags,userflag_initiated) then exit;
  l := connectionlist[us.socknum].listener;
  if l <> nil then if not l.clientaccept then exit;
  sendto_one(us,'NOTICE AUTH :*** '+s);
end;

procedure sendmsgto_one(source,target:tuser;cmdnum:integer;const s:bytestring);
var
  s2:bytestring;
begin
  if s <> '' then s2 := ' ' else s2 := '';
  if target.server = me.server then begin
    sendto_one(target.from,cprefix(source,cmdstr(cmdnum))+target.name+s2+s);
  end else begin
    sendto_one(target.from,sprefix(source,tokstr(cmdnum))+target.idstr+s2+s);
  end;
end;

procedure sendmsgto_channel(source:tuser;target:tchannel;cmdnum:integer;const s:bytestring;uc:tuserchan);
begin
  {$ifndef nodelayed}
  if assigned(uc) then if flag_isset(uc.flags,userchanflag_delayed) then begin
    if source.server = me.server then sendto_one(source,cprefix(source,cmdstr(cmdnum))+s);
    exit;
  end;
  {$endif}
  sendto_channel(target,cprefix(source,cmdstr(cmdnum))+s);
end;

procedure sendto_channel(target:tchannel;const s:bytestring);
var
  p:tplinklist;
begin
  p := target.localuser;
  while p <> nil do begin
    sendto_one(tuser(p.p),s);
    p := tplinklist(p.next);
  end;
end;

procedure sendto_channelbutone(source:tuser;ch:tchannel;const s:bytestring);
var
  p:tplinklist;
begin
  p := ch.localuser;
  while p <> nil do begin
    {clone flood AV location (fixed?)}

    if p.p <> source then sendto_one(tuser(p.p),s);
    p := tplinklist(p.next);
  end;
end;

procedure sendchatto_channelbutone(source:tuser;ch:tchannel;const s:bytestring);
var
  p:tplinklist;
begin
  p := ch.localuser;
  while p <> nil do begin
    if p.p <> source then if not flag_isset(tuser(p.p).modeflag,usermode_deaf) then sendto_one(tuser(p.p),s);
    p := tplinklist(p.next);
  end;
end;

procedure sendchatto_serversbutone(source:tuser;ch:tchannel;const s:bytestring);
var
  a:integer;
begin
  if source <> me then source := tuser(source.from.server.us);

  for a := 1 to highserverlink do begin
    if serverlinklist[a] <> nil then if serverlinklist[a].us <> source
    then if ch.serverlinkcount[a] > 0 then sendto_one(tuser(serverlinklist[a].us),s);
  end;
end;

procedure sendchatto_channelbutone_flags(source:tuser;ch:tchannel;flags:integer;const s:bytestring);
var
  p:tplinklist;
  a:integer;
begin
  p := ch.localuser;
  while p <> nil do begin
    if p.p <> source then begin
      a := getuserchan(p.p,ch).flags;
      if (a and flags <> 0) then if not flag_isset(tuser(p.p).modeflag,usermode_deaf) then sendto_one(p.p,s);
    end;
    p := tplinklist(p.next);
  end;
end;

procedure sendchatto_serversbutone_flags(source:tuser;ch:tchannel;flags:integer;const s:bytestring);
var
  a:integer;
  uc:tuserchan;
  done:array[0..maxserverlink] of boolean;
begin
  if source <> me then source := tuser(source.from.server.us);
  fillchar(done,sizeof(done),0);
  uc := tuserchan(ch.user);
  while uc <> nil do begin
    if (uc.flags and flags <> 0) then if not flag_isset(uc.us.modeflag,usermode_deaf) then begin
      done[uc.us.server.serverlinknum] := true;
    end;
    uc := tuserchan(uc.next2);
  end;

  for a := 1 to highserverlink do begin
    if done[a] then if serverlinklist[a].us <> source
    then sendto_one(tuser(serverlinklist[a].us),s);
  end;
end;

procedure sendto_commonchannels(source:tuser;const s:bytestring);
begin
  if myconnect(source) then sendto_one(source,s);
  sendto_commonchannels_butone(source,s);
end;

procedure sendto_commonchannels_butone(source:tuser;const s:bytestring);
var
  done:pdvar;
  p,p2:tlinklist;
begin
  if source.chancount = 0 then begin
{    if myconnect(source) then sendto_one(source,s);}
    exit;
  end else if source.chancount = 1 then begin
    {$ifndef nodelayed}
    if not flag_isset(tuserchan(source.channel).flags,userchanflag_delayed) then
    {$endif}
    sendto_channelbutone(source,tuserchan(source.channel).ch,s);
    exit;
  end;
  getmem(done,maxconnections);
  fillchar(done^,maxconnections,0);
  p := source.channel;

  {exclude source from receiving the message}
  done[source.from.socknum] := 1;

  while p <> nil do begin

    p2 := tlinklist(tuserchan(p).ch.localuser);

    {$ifndef nodelayed}
    if not flag_isset(tuserchan(p).flags,userchanflag_delayed) then
    {$endif}
    while p2 <> nil do begin
      if done[tuser(tplinklist(p2).p).socknum] = 0 then begin
        sendto_one(tuser(tplinklist(p2).p),s);
        done[tuser(tplinklist(p2).p).socknum] := 1
      end;
      p2 := p2.next;
    end;

    p := tplinklist(p.next);
  end;
  {}
  freemem(done);
end;

procedure sendreply(us:tuser;rplnum:integer;const s:bytestring);
begin
  if me.server = us.server then
  sendto_one(us,cprefix(me,cmdstr(rplnum))+us.name+' '+s)
  else
  sendto_one(us,sprefix(me,tokstr(rplnum))+us.idstr+' '+s)
end;

procedure locnotice(mask:integer;s:bytestring);
var
  a:integer;
  p:tuser;
begin
{  if not serverisrunning then exit;}
  s := cprefix(me,MSG_NOTICE)+'* :*** Notice -- '+s;
  for a := 0 to highconnection do if connectionlist[a].open then if isclient(connectionlist[a].user) then begin
    p := connectionlist[a].user;
    if ((mask and p.snomask) <> 0) then if isclient(p) then sendto_one(p,s);
  end;
end;

procedure needmoreparams;
begin
  if not isserver(us) and myconnect(us) then
  sendreply(us,ERR_NEEDMOREPARAMS,cmdstr(cmdnum)+' '+getrpl0(ERR_NEEDMOREPARAMS));
end;

function checkneedmoreparams(us:tuser;cmdnum,need,parc:integer;parv:pparams):boolean;
begin
  if (parc <= need) or (parv[need] = '') then begin
    result := true;
    needmoreparams(us,cmdnum);
  end else begin
    result := false;
  end;
end;

procedure sendto_serversbutone(source:tuser;const s:bytestring);
var
  a:integer;
begin
  if source <> me then source := tuser(source.from.server.us);
  for a := 1 to highserverlink do begin
    if serverlinklist[a] <> nil then if serverlinklist[a].us <> source
    then sendto_one(tuser(serverlinklist[a].us),s);
  end;
end;

procedure wallops(const s:bytestring);
var
  p:tparams;
begin
  p[0] := me.idstr;
  p[1] := s;
  m_wallops(me,me,2,@p);
end;

procedure desynchwallops(const s:bytestring);
var
  p:tparams;
begin
  p[0] := me.idstr;
  p[1] := s;
  m_desynch(me,me,2,@p);
end;

procedure sendnosuchserver(sptr:tuser;server:bytestring);
begin
  if isserver(sptr.from) then
  sendreply(sptr,ERR_NOSUCHSERVER,'* '+getrpl0(ERR_NOSUCHSERVER))
  else
  sendreply(sptr,ERR_NOSUCHSERVER,server+' '+getrpl0(ERR_NOSUCHSERVER));
end;

end.
