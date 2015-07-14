(*
 *  beware ircd, Internet Relay Chat server, b_opmode.pas
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

unit b_opmode;

interface

uses buser,bstuff,bchannel;

procedure m_opmode(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_opmode(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,breplies,bcmds,blinklist,bconfig,bparse,b_mode,bprivs;

procedure m_opmode(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  ch:tchannel;
begin
  if not opt.opmode then begin
    sendreply(sptr,ERR_DISABLED,MSG_OPMODE+' '+getrpl0(ERR_DISABLED));
    exit;
  end;

  {only #channel (modes)}
  if checkneedmoreparams(cptr,cmdnum,2,parc,parv) then exit;

  {channel}
  ch := findchan(parv[1]);
  if ch = nil then begin
    sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;

  {$ifndef nomodeless}
  {no way}
  if flag_isset(ch.flags,chanflag_modeless) then begin
    sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;
  {$endif}

  {if it's a local operator, can only change modes of a &channel}
  if not ((flag_isset(ch.flags,chanflag_local) and isanoper(sptr))
  or hasprivs(sptr,privs_globalmode)) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit
  end;
  locnotice(SNO_HACK4,'HACK(4): '+hacknoticemodestring(parc,parv,MSG_OPMODE));

  setchanmode(ch,cptr,sptr,parc,parv,true);
end;


procedure ms_opmode(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  ch:tchannel;
begin
  {a MODE from a server without 2 parameters doesn't make sense}
  if (parv[2] = '') or (parc < 3) then exit;
  {channel}
  ch := findchan(parv[1]);
  if ch = nil then exit;
  if flag_isset(ch.flags,chanflag_local) then exit;
  {$ifndef nomodeless}
  if flag_isset(ch.flags,chanflag_modeless) then exit;
  {$endif}
  if not (isoper(sptr) or isserver(sptr)) then exit;

  locnotice(SNO_HACK4,'HACK(4): '+hacknoticemodestring(parc,parv,MSG_OPMODE));

  setchanmode(ch,cptr,sptr,parc,parv,true);
end;


end.
