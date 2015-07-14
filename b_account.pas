(*
 *  beware ircd, Internet Relay Chat server, b_account.pas
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

unit b_account;

interface

uses bstuff,buser,breplies,bcmds;

procedure m_account(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bconfig,bsend;

procedure m_account(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;
begin
  if (parc < 3) or (parv[2] = '') then exit;
  if not isserver(sptr) then exit;
  us := findnumeric(parv[1]);
  if us = nil then exit;
  if not isclient(us) then exit;
  if us.account <> '' then exit;

  if length(parv[2]) > opt.accountlen then begin
    wallops('too long account name: '+parv[0]+' AC '+parv[1]+' '+parv[3]);
    exit;
  end;
  us.account := parv[2];
  sendto_serversbutone(cptr,sprefix(sptr,TOK_ACCOUNT)+us.idstr+' '+parv[2]);
  {$ifndef novhost}
  checkxhost(us);
  {$endif}
end;

end.
