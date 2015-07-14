(*
 *  beware ircd, Internet Relay Chat server, b_invite.pas
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

unit b_invite;

interface

uses buser,bcmds,bstuff;

procedure m_invite(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bchannel,bsend,breplies,blinklist,bipcheck,bparse;

procedure m_invite(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  ch:tchannel;
  us:tuser;
  uc:tuserchan;
  p:tinvite;
begin

  if isserver(sptr) then begin
    cptr.error := 'Server '+sptr.name+' invites.';
    cptr.destroy;
    exit;
  end;

  if (parc <= 1) and (isclient(cptr)) then begin
    p := tinvite(cptr.invites);
    while p <> nil do begin
      sendreply(cptr,RPL_INVITELIST,':'+tchannel(p.ch).name);
      p := tinvite(p.next);
    end;
    sendreply(cptr,RPL_ENDOFINVITELIST,getrpl0(RPL_ENDOFINVITELIST));
    exit;
  end;

  if checkneedmoreparams(sptr,cmdnum,2,parc,parv) then exit;

  if isserver(cptr) then if (parv[2,1] = '&') then exit;

  us := findnick(parv[1]);

  if us = nil then begin
    if sptr = cptr then sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;

  if ipcheck_target(sptr,us) > 0 then exit;

  if is_silenced(sptr,us) then exit;

  if not validchanname(parv[2]) then begin
{    sendreply(cptr,ERR_NOSUCHCHANNEL,parv[2]+' '+getrpl0(ERR_NOSUCHCHANNEL));}
    exit;
  end;

  ch := findchan(parv[2]);
  if ch = nil then begin
    {invite to not existing channel can always be done}
    if myconnect(sptr) then
    sendreply(sptr,RPL_INVITING,us.name+' '+parv[2]);

    if myconnect(us) then
    sendto_one(us,cprefix(sptr,MSG_INVITE)+us.name+' '+parv[2])
    else
    sendto_one(us,sprefix(sptr,TOK_INVITE)+us.name+' '+parv[2]);
    exit;
  end;

  if isonchannel(us,ch) then begin
    if sptr = cptr then sendreply(sptr,ERR_USERONCHANNEL,us.name+' '+ch.name+' '+getrpl0(ERR_USERONCHANNEL));
    exit;
  end;

  if not isservice(sptr) then begin
    uc := getuserchan(sptr,ch);
    if uc = nil then begin
      if sptr = cptr then sendreply(sptr,ERR_NOTONCHANNEL,ch.name+' '+getrpl0(ERR_NOTONCHANNEL));
      exit;
    end;
    if not hasops(sptr,ch,uc) then begin
      sendreply(sptr,ERR_CHANOPRIVSNEEDED,ch.name+' '+getrpl0(ERR_CHANOPRIVSNEEDED));
      exit;
    end;
  end;

  {add "invite key" but only if local user}
  if myconnect(us) then begin
    if not isinvited(us,ch) then
    addinvitetochannel(us,ch);
  end;

  if myconnect(sptr) then
  sendreply(sptr,RPL_INVITING,us.name+' '+ch.name);

  if myconnect(us) then
  sendto_one(us,cprefix(sptr,MSG_INVITE)+us.name+' :'+ch.name)
  else if ch.name[1] <> '&' then
  sendto_one(us,sprefix(sptr,TOK_INVITE)+us.name+' :'+ch.name);

end;

end.
