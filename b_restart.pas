(*
 *  beware ircd, Internet Relay Chat server, b_restart.pas
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

unit b_restart;

interface

uses buser,bcmds,bstuff;

procedure m_restart(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bserver,breplies,bsend,bircdunit,bsock,bconfig,bprivs;

procedure m_restart(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if opt.norestart then begin
    sendreply(sptr,ERR_DISABLED,MSG_RESTART+' '+getrpl0(ERR_DISABLED));
    exit;
  end;
  if not hasprivs(sptr,privs_restart) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;
  triggershutdown('Received restart from '+sptr.name+'!'+sptr.userid+'@'+sptr.host,true);
end;



end.
