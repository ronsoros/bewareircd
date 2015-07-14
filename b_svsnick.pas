(*
 *  beware ircd, Internet Relay Chat server, b_svsnick.pas
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

unit b_svsnick;

interface

uses buser,bcmds,bstuff;

procedure m_svsnick(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  bconfig,breplies,bsend,btime,b_nick,b_whowas,b_kill,bprivs,bvaliddef,
  bparse;

{
<sender> SVSNICK <target> <newnick>



}


procedure m_svsnick(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us,us2:tuser;
  fromservice:boolean;
begin
  fromservice := flag_isset(sptr.server.flags,servflag_ulined) and isserver(sptr);
  if (opt.svsnick <> 1) and (not fromservice) then begin
    sendreply(sptr,ERR_DISABLED,MSG_SVSNICK+' '+getrpl0(ERR_DISABLED));
    exit;
  end;

  if checkneedmoreparams(cptr,cmdnum,2,parc,parv) then exit;
  us := finduser(parv[1],isserver(cptr));

  if us = nil then begin
    sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;
  if isserver(us) then begin
    sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;

  if not hasprivs(sptr,privs_globalsvsnick) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;

  if not isserver(cptr) then
  parv[2] := copy(parv[2],1,opt.nicklen);

  if parv[2] = us.name then exit; {no change}

  if not validnick(ircupper(parv[2])) then begin
    sendreply(sptr,ERR_ERRONEUSNICKNAME,parv[2]+' '+getrpl0(ERR_ERRONEUSNICKNAME));
    exit;
  end;

  if (not isserver(cptr)) and (nameinuse(parv[2])) and (ircupper(parv[2]) <> ircupper(us.name)) then begin
    sendreply(sptr,ERR_NICKNAMEINUSE,parv[2]+' '+getrpl0(ERR_NICKNAMEINUSE));
    exit;
  end;

  if us.server <> me.server then begin
    sendmsgto_one(sptr,us,cmdsvsnick,parv[2]);
    exit;
  end;

  {target is local}
  us2 := findname(parv[2]);
  if (us2 <> nil) and (us2 <> us) then begin
    {kill the target}
    dokill(me,me,us2,'svsnick collision');
  end;

  if not fromservice then desynchwallops('received SVSNICK from '+nickuserhost(sptr)+': '+us.name+' '+parv[2]);

  sendto_serversbutone(me,sprefix(us,TOK_NICK)+parv[2]+' '+inttostr(irctime));
  sendto_commonchannels(us,cprefix(us,MSG_NICK)+':'+parv[2]);

  addwhowas(sptr);
  setname(us,parv[2]);
  us.ts := irctime;
end;

end.
