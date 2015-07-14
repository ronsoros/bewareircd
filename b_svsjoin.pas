(*
 *  beware ircd, Internet Relay Chat server, b_svsjoin.pas
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

unit b_svsjoin;

interface


uses buser,bstuff,pgtypes;

procedure m_svsjoin(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,bcmds,bchannel,breplies,b_join,bprivs,bconfig,bparse;

{
SVSjoin, cause someone else to join

SVSjoin target #channel :TS
}

procedure m_svsjoin(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;
  ch:tchannel;
  params:tparams;
  s,s2:bytestring;
  a:integer;
  fromservice:boolean;
begin
  fromservice := isulinedserver(sptr);
  if (opt.svsjoin <> 1) and (not fromservice) then begin
    sendreply(sptr,ERR_DISABLED,MSG_SVSJOIN+' '+getrpl0(ERR_DISABLED));
    exit;
  end;

  if checkneedmoreparams(sptr,cmdnum,2,parc,parv) then exit;

  {check: must be global oper}
  if not hasprivs(sptr,privs_globalsvsjoin) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;

  us := finduser(parv[1],isserver(cptr));
  if (us = nil) then begin
    sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;
  if isserver(us) then begin
    sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;

  a := 1;
  s2 := '';
  repeat
    strtok2(parv[2],',',a,s);
    if s = '' then break;
    if not validchanname(s) then begin
      sendreply(sptr,ERR_NOSUCHCHANNEL,s+' '+getrpl0(ERR_NOSUCHCHANNEL));
      continue;
    end;
    {check: for local channel, message can't come from or go to server link}
    if (s[1] = '&') then if (us.server <> me.server) or (sptr.server <> me.server) then begin
      sendreply(sptr,ERR_NOSUCHCHANNEL,s+' '+getrpl0(ERR_NOSUCHCHANNEL));
      continue;
    end;
    ch := findchan(s);
    if ch <> nil then if isonchannel(us,ch) then begin
      sendreply(sptr,ERR_USERONCHANNEL,us.name+' '+ch.name+' '+getrpl0(ERR_USERONCHANNEL));
      continue;
    end;

    {ok, add it}
    if s2 <> '' then s2 := s2 + ',';
    s2 := s2 + s;
  until false;

  {no channels}
  if s2 = '' then exit;

  if (us.server = me.server) then begin
    if not fromservice then desynchwallops('received SVSJOIN from '+nickuserhost(sptr)+': '+us.name+' '+copy(s2,1,300));

    {if assigned(ch) then addinvitetochannel(us,ch);}
    params[0] := us.idstr;
    params[1] := s2;
    params[2] := '';
    forcedjoin := true;
    m_join(us,us,2,@params);
    forcedjoin := false;
  end else begin
    sendmsgto_one(sptr,us,cmdsvsjoin,s2);
  end;
end;

end.
