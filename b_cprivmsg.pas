(*
 *  beware ircd, Internet Relay Chat server, b_cprivmsg.pas
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

unit b_cprivmsg;

interface

uses buser,bcmds,bstuff,pgtypes;

procedure m_cprivmsg(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_cnotice(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses breplies,bsend,bparse,bchannel,bsock,bconfig,blinklist,btime;

procedure whisper(sptr:tuser;target,chan,msg:bytestring;isnotice:boolean);
var
  us:tuser;
  ch:tchannel;
  uc:tuserchan;
  a:integer;
begin
  us := findnick(target);
  if us = nil then begin
    sendreply(sptr,ERR_NOSUCHNICK,target+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;
  ch := findchan(chan);
  if ch = nil then begin
    sendreply(sptr,ERR_NOSUCHCHANNEL,chan+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;
  uc := getuserchan(sptr,ch);
  if uc = nil then begin
    sendreply(sptr,ERR_NOTONCHANNEL,ch.name+' '+getrpl0(ERR_NOTONCHANNEL));
    exit;
  end;
  if not hasopsorvoice(sptr,ch,uc) then begin
    sendreply(sptr,ERR_VOICENEEDED,ch.name+' '+getrpl0(ERR_VOICENEEDED));
    exit;
  end;
  if getuserchan(us,ch) = nil then begin
    sendreply(sptr,ERR_USERNOTINCHANNEL,us.name+' '+ch.name+' '+getrpl0(ERR_USERNOTINCHANNEL));
    exit;
  end;
  if is_silenced(sptr,us) then exit;

  if isnotice then begin
    a := cmdnotice
  end else begin
    a := cmdprivmsg;
  end;
  if cmdnum = cmdcprivmsg then sptr.idletime := irctime;
  sendmsgto_one(sptr,us,a,':'+msg);
end;

procedure m_cprivmsg(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if checkneedmoreparams(cptr,cmdnum,3,parc,parv) then exit;
  whisper(sptr,parv[1],parv[2],parv[parc-1],false);
end;

procedure m_cnotice(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if checkneedmoreparams(cptr,cmdnum,3,parc,parv) then exit;
  whisper(sptr,parv[1],parv[2],parv[parc-1],true);
end;

end.
