(*
 *  beware ircd, Internet Relay Chat server, b_close.pas
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

unit b_close;

interface

uses buser,bcmds,bstuff,sysutils;

procedure m_close(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses breplies,bsend,btime,bparse,bsock,bserver;

procedure m_close(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a,b:integer;
begin
  b := 0;
  for a := 0 to highconnection do begin
    if connectionlist[a].open then if isunreg(connectionlist[a].user) then begin
      if not isinitiated(connectionlist[a].user) then begin
        inc(b);
        connectionlist[a].user.error := 'closed unknown connections';
        connectionlist[a].user.destroy;
      end;
    end;
  end;
  sendreply(sptr,cmdnotice,':closed '+inttostr(b)+' connections');
end;

end.
