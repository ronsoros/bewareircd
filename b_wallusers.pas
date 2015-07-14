(*
 *  beware ircd, Internet Relay Chat server, b_wallusers.pas
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

unit b_wallusers;

interface

uses buser,bcmds,bstuff;

procedure m_wallusers(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,breplies,bsock,bconfig,bparse,pgtypes;

procedure m_wallusers(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
  us:tuser;
  a:integer;
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  sendto_serversbutone(sptr,sprefix(sptr,TOK_WALLUSERS)+':'+parv[parc-1]);

  s := cprefix(sptr,MSG_WALLOPS)+':$ '+parv[parc-1];
  for a := 0 to highconnection do if connectionlist[a].open then begin
    us := connectionlist[a].user;
    if flag_isset(us.modeflag,usermode_wallops) then if isclient(us) then sendto_one(us,s);
  end;
end;

end.
