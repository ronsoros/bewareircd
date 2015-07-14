(*
 *  beware ircd, Internet Relay Chat server, b_info.pas
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

unit b_info;

interface

uses buser,bstuff,bconfig,bsend,breplies,bserver,bcmds;

procedure m_info(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bprivs,bconsts;

procedure m_info(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  srv:tuser;
begin
  if (parc >= 2) and (parv[1] <> '') then begin
    {$ifndef nohis}
    if opt.headinsand then if not hasprivs(cptr,privs_his) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    {$endif}
    srv := getremoteserver(parv[1],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[1]);
      exit;
    end;
    if srv <> me then begin
      sendmsgto_one(sptr,srv,cmdinfo,'');
      exit;
    end;
  end;

  {if you change the info reply,
  you should atleast keep something in it like
  "based on beware ircd"}

  sendreply(sptr,RPL_INFO,':beware ircd');
  sendreply(sptr,RPL_INFO,':written by Bas Steendijk');
  sendreply(sptr,RPL_INFO,':http://ircd.bircd.org/');
  sendreply(sptr,RPL_INFO,':ircd@bircd.org');
  sendreply(sptr,RPL_INFO,':'+platformstr+' version');

  sendreply(sptr,RPL_ENDOFINFO,getrpl0(RPL_ENDOFINFO));
end;



end.
