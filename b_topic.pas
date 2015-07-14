(*
 *  beware ircd, Internet Relay Chat server, b_topic.pas
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

unit b_topic;

interface

uses buser,bcmds,bstuff;

procedure m_topic(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_topic(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses breplies,bchannel,bsend,btime,bconfig,bconsts,bparse,pgtypes;

procedure settopic(sptr:tuser;ch:tchannel;ts:integer;newtopic:bytestring);
var
  from:tuser;
  a,b:integer;
begin
  if ts = 0 then ts := irctime;
  newtopic := copy(newtopic,1,opt.topiclen);


  {too long lines fix}
  a := length(nickuserhost(sptr));
  b := (maxservername-1)+opt.nicklen; {longest server name + space + nicklen + length('123') - length('TOPIC')}
  if a < b then a := b;
  inc(a,10+length(ch.name));
  {:1TOPIC2#channel3:}
  if length(newtopic)+a > 510 then newtopic := copy(newtopic,1,510-a);

  if ch.topic = newtopic then if myconnect(sptr) then if isclient(sptr) then begin
    {no change, send only to sender}
    sendto_one(sptr,cprefix(sptr,MSG_TOPIC)+ch.name+' :'+ch.topic);
    exit;
  end;

  ch.topic := newtopic;
  if not flag_isset(ch.flags,chanflag_local) then begin
    sendto_serversbutone(sptr,sprefix(sptr,TOK_TOPIC)+ch.name+' '+inttostr(ch.ts)+' '+inttostr(ts)+' :'+ch.topic);
  end;

  {$ifndef nodelayed}
  if isclient(sptr) then undelay(getuserchan(sptr,ch));
  {$endif}

  {$ifndef nohis}
  if opt.headinsand and isserver(sptr) then from := me
  else
  {$endif}
  from := sptr;

  ch.topicby := from.name;
  ch.topictime := ts;
  sendto_channel(ch,cprefix(from,MSG_TOPIC)+ch.name+' :'+ch.topic);
end;

procedure m_topic(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  ch:tchannel;
  uc:tuserchan;
begin
  if checkneedmoreparams(sptr,cmdnum,1,parc,parv) then exit;
  ch := findchan(parv[1]);
  if ch = nil then begin
    sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;
  uc := getuserchan(sptr,ch);
  if uc = nil then if flag_isset(ch.modeflag,chanmode_secret) or (parc >= 3) then begin
    sendreply(sptr,ERR_NOTONCHANNEL,ch.name+' '+getrpl0(ERR_NOTONCHANNEL));
    exit;
  end;
  if parc < 3 then begin
    if ch.topic = '' then begin
      sendreply(sptr,RPL_NOTOPIC,ch.name+' '+getrpl0(RPL_NOTOPIC));
    end else begin
      sendreply(sptr,RPL_TOPIC,ch.name+' :'+ch.topic);
      sendreply(sptr,RPL_TOPICWHOTIME,ch.name+' '+ch.topicby+' '+inttostr(ch.topictime));
    end;
    exit;
  end;
  if (flag_isset(ch.modeflag,chanmode_topic) and not
  {$ifdef nohalfop} hasops {$else} hasoporhalfop {$endif} (sptr,ch,uc) )

  {$ifndef nomodeless}or (flag_isset(ch.flags,chanflag_modeless)){$endif} then begin
    sendreply(sptr,ERR_CHANOPRIVSNEEDED,ch.name+' '+getrpl0(ERR_CHANOPRIVSNEEDED));
    exit;
  end;

  settopic(sptr,ch,0,parv[parc-1]);
end;


{
accept the following:

sender T #channel channelts topicts :topic
sender T #channel topicts :topic (asuka style)
sender T #channel :topic

}

procedure ms_topic(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  ch:tchannel;
  chants:integer;
  topicts:integer;
begin
  if parc < 3 then exit;
  ch := findchan(parv[1]);
  if ch = nil then exit;

  {$ifndef nomodeless}
  if flag_isset(ch.flags,chanflag_modeless) then exit;
  {$endif}
  if flag_isset(ch.flags,chanflag_local) then exit;

  if (parc > 3) then topicts := strtointdef(parv[parc-2],0) else topicts := 0;
  if (parc > 4) then chants := strtointdef(parv[parc-3],0) else chants := 0;

  if not ((chants <> 0) and (chants < ch.ts)) then begin
    if (topicts <> 0) and (topicts <= ch.topictime) then exit;
    if (ch.ts <> 0) and (chants > ch.ts) then exit;
  end;

  settopic(sptr,ch,topicts,parv[parc-1]);
end;

end.
