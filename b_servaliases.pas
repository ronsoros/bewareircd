
(*
 *  beware ircd, Internet Relay Chat server, b_servaliases.pas
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

unit b_servaliases;

interface

uses bcmds,buser,bstuff,pgtypes;

procedure m_servalias(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure setservicealiases(const s:bytestring);

implementation

uses bconfig,bsend,breplies,bparse;

const
  maxservalias=5;

var
  servaliasnum:array[0..maxservalias] of ^integer;
  servaliastarget:array[0..maxservalias] of string;

procedure m_servalias(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a,b:integer;
  bool:boolean;
  us:tuser;
  servicetarget:bytestring;
  s:bytestring;
begin
  b := -1;
  for a := 0 to maxservalias do if servaliasnum[a]^ = cmdnum then begin
    b := a;
    break;
  end;
  if b < 0 then exit;
  servicetarget := servaliastarget[b];

  if cptr <> sptr then exit;
  a := pos('@',servicetarget);

  {i force nick@server for security}
  if a = 0 then begin
    sendreply(sptr,cmdnotice,':is not available');
    exit;
  end;
  us := findname(copy(servicetarget,1,a-1));
  if us <> nil then begin
    bool := strcompup(copy(servicetarget,a+1,500),tuser(us.server.us).name);
  end else bool := false;
  if not bool then begin
    sendreply(sptr,cmdnotice,':Service is currently not available, try again later.');
    exit;
  end;

  if (parv[1] = '') or (parc < 2) then begin
    sendreply(cptr,ERR_NOTEXTTOSEND,getrpl0(ERR_NOTEXTTOSEND));
    exit;
  end;
  a := 1;
  while (a < length(rawstr)) and (rawstr[a] <> ' ') do inc(a);
  while (a < length(rawstr)) and (rawstr[a] = ' ') do inc(a);

  if isserver(us.from) then
  s := sprefix(sptr,TOK_PRIVMSG)
  else
  s := cprefix(sptr,MSG_PRIVMSG);

  sendto_one(us,s+servicetarget+' :'+copy(rawstr,a,500));
end;

procedure setservicealiases(const s:bytestring);
var
  a,b:integer;
  parc:integer;
  parv:tparams;
begin
  if not assigned(servaliasnum[0]) then begin
    servaliasnum[0] := @cmdalias1;
    servaliasnum[1] := @cmdalias2;
    servaliasnum[2] := @cmdalias3;
    servaliasnum[3] := @cmdalias4;
    servaliasnum[4] := @cmdalias5;
    servaliasnum[5] := @cmdalias6;
  end;
  for a := 0 to maxservalias do with cmdtable[servaliasnum[a]^] do flags := flags or mflg_disabled;
  parc := strtok(s,';',@parv);
  b := (parc shr 1)-1;
  if b > maxservalias then b := maxservalias;
  for a := 0 to b do begin
    if (parv[a shl 1] <> '') and (parv[a shl 1 or 1] <> '') then begin
      with cmdtable[servaliasnum[a]^] do begin
        cmd := ircupper(parv[a shl 1]);
        if copy(cmd,1,1) = '/' then cmd := copy(cmd,2,500);
        flags := flags and not mflg_disabled;
      end;
      servaliastarget[a] := parv[a shl 1 or 1];
    end;
  end;
  bparse.init;
end;

initialization fillchar(servaliasnum,sizeof(servaliasnum),0);

end.
