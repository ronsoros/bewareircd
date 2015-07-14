(*
 *  beware ircd, Internet Relay Chat server, b_error.pas
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

unit b_error;

interface

uses
  buser,bcmds,bstuff,bsend,pgtypes;

procedure m_error(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

procedure m_error(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a,b,c:integer;
  s:bytestring;
begin
  if cptr.error = '' then begin
    s := parv[parc-1];
    a := pos('(',s);
    if (a <> 0) then if (pos('CLOSING LINK',ircupper(s)) = 1) then begin
      {find last ] before first (}
      b := 0;
      for c := 1 to a do if s[c] = ']' then b := c;
      if b > 0 then begin
        s := copy(s,b+2,length(s));
      end;
    end;
    cptr.error := 'Received ERROR: '+s;
  end;
  cptr.destroy;
end;

end.
