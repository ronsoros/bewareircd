(*
 *  beware ircd, Internet Relay Chat server, b_away.pas
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

unit b_away;

interface

uses bstuff,buser,breplies,bcmds,pgtypes;

procedure m_away(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bconfig,bsend;

procedure m_away(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
begin
  if parc < 2 then s := '' else s := parv[parc-1];
  s := copy(s,1,opt.awaylen);
  if sptr.away <> s then begin

    if (sptr.away = '') and (s <> '') then sendto_serversbutone(sptr,sprefix(sptr,TOK_AWAY)+':'+s);
    if (sptr.away <> '') and (s = '') then sendto_serversbutone(sptr,sprefix(sptr,TOK_AWAY));

    sptr.away := s;
    if sptr = cptr then begin
      if sptr.away <> '' then begin
        sendreply(sptr,RPL_NOWAWAY,getrpl0(RPL_NOWAWAY));
      end else begin
        sendreply(sptr,RPL_UNAWAY,getrpl0(RPL_UNAWAY));
      end
    end;
  end;
end;

end.
