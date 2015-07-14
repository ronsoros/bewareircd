(*
 *  beware ircd, Internet Relay Chat server, b_help.pas
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

unit b_help;

interface

uses bcmds,buser,bstuff,pgtypes;

procedure m_help(cptr,sptr:tuser;parc:integer;parv:pparams);

var
  helpsorted:boolean=false;

implementation

uses bparse,bsend;

var
  sortlist:array[0..numcmds] of byte;

procedure sort;
var
  a,b,c:integer;
  largest,smallest,current:bytestring;
begin
  smallest := '';
  for a := 0 to numcmds do begin
    largest := #255;
    c := -1;
    for b := 0 to numcmds do begin
      current := cmdtable[b].cmd+inttostr(b);
      if (current > smallest) and (current < largest) then begin
        largest := current;
        c := b;
      end;
    end;
    smallest := largest;
    sortlist[a] := c;
  end;
  helpsorted := true;
end;

procedure m_help(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a:integer;
begin
  if not helpsorted then sort;
  for a := 0 to numcmds do if not flag_isset(cmdtable[sortlist[a]].flags,MFLG_DISABLED) then begin
    sendreply(sptr,cmdnotice,':'+cmdtable[sortlist[a]].cmd);
  end;
end;

end.
