(*
 *  beware ircd, Internet Relay Chat server, bvaliddef.pas
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

unit bvaliddef;

interface

uses bconsts,bstuff,pgtypes;

{check if it's a valid nick, the string must already be uppercased (does not check length!)}
function validnick(const s:bytestring):boolean;

{s must not be uppercased}
function validnickfromclient(const s:bytestring):boolean;

{check if it's a valid servername, the string must already be uppercased (does check length)}
function validservername(const s:bytestring):boolean;

function makevaliduserid(s:bytestring):bytestring;
function validuserid(s:bytestring):boolean;

function validhost(const s:bytestring):boolean;

{check if it's a valid mask (never add invalid masks)}
function validmask(s:bytestring):boolean;

implementation

function validnick(const s:bytestring):boolean;
var
  a:integer;
begin
  result := false;
  if s = '' then exit;
  if length(s) > maxnicklength then exit;
  if not ((s[1] in ['A'..'Z']) or (s[1] = '\') or (s[1] = '[') or (s[1] = ']') or (s[1] = '^') or (s[1] = '`')or (s[1] = '_')) then exit;
  if length(s) > 1 then for a := 2 to length(s) do begin
    if not ((s[a] in ['A'..'Z']) or (s[a] in ['0'..'9']) or (s[a] = '\') or (s[a] = '[') or (s[a] = ']') or (s[a] = '^')
    or (s[a] = '`') or (s[a] = '_') or (s[a] = '-')) then exit
  end;
  result := true
end;

function validnickfromclient(const s:bytestring):boolean;
var
  a:integer;
begin
  result := false;
  if s = '' then exit;
  if length(s) > maxnicklength then exit;
  if not (
  (s[1] in ['A'..'Z']) or (s[1] = '\') or (s[1] = '[') or (s[1] = ']') or (s[1] = '^') or
  (s[1] in ['a'..'z']) or (s[1] = '|') or (s[1] = '{') or (s[1] = '}') or
  (s[1] = '`')or (s[1] = '_')) then exit;
  if length(s) > 1 then for a := 2 to length(s) do begin
    if not ((s[a] in ['A'..'Z']) or (s[a] in ['0'..'9']) or (s[a] = '\') or (s[a] = '[') or (s[a] = ']') or (s[a] = '^')
    or (s[a] in ['a'..'z']) or (s[a] = '|') or (s[a] = '{') or (s[a] = '}')
    or (s[a] = '`') or (s[a] = '_') or (s[a] = '-')) then exit
  end;
  result := true
end;

function validservername(const s:bytestring):boolean;
var
  a:integer;
  c:bytechar;
begin
  result := false;
  if s = '' then exit;
  if length(s) > maxservername then exit;
  if pos('.',s) = 0 then exit;

  for a := 1 to length(s) do begin
    c := s[a];
    if not ((c in ['A'..'Z']) or (c in ['a'..'z']) or (c in ['0'..'9']) or (c = '.') or (c = '-') or (c = '*')) then exit;
  end;
  result := true
end;

function validhost(const s:bytestring):boolean;
var
  a:integer;
  c:bytechar;
begin
  result := false;
  if s = '' then exit;
  if length(s) > hostlen then exit;
  for a := 1 to length(s) do begin
    c := s[a];
    if not ((c in ['A'..'Z']) or (c in ['a'..'z']) or (c in ['0'..'9']) or (c = '.') or (c = '-')) then exit;
  end;
  result := true
end;

function makevaliduserid(s:bytestring):bytestring;
var
  a:integer;
  hasuppercase:boolean;
  hastilde:boolean;
begin
  if s = '' then exit;
  if length(s) > userlen then begin
    s := copy(s,1,userlen);
  end;
  hastilde := false;
  if s[1] = '~' then begin
    s := copy(s,2,userlen-1);
    hastilde := true;
  end;

  if (s <> '') then begin
    if not ((s[1] in ['A'..'Z']) or (s[1] in ['a'..'z']) or (s[1] in ['0'..'9'])) then begin
      s[1] := '_';
    end;
    if not ((s[length(s)] in ['A'..'Z']) or (s[length(s)] in ['a'..'z']) or (s[length(s)] in ['0'..'9'])) then begin
      s[length(s)] := '_';
    end;
  end;

  hasuppercase := false;
  if length(s) > 1 then for a := 2 to length(s) do begin
    if not ((s[a] in ['A'..'Z']) or (s[a] in ['a'..'z']) or (s[a] in ['0'..'9']) or (s[a] = '-') or (s[a] = '_') or (s[a] = '.')) then begin
      s[a] := '_';
    end;
    if s[a] in ['A'..'Z'] then hasuppercase := true;
  end;

  {if any uppercase, first must be uppercase too}
  if hasuppercase then if not (s[1] in ['A'..'Z']) then begin
    for a := 1 to length(s) do begin
      if s[a] in ['A'..'Z'] then s[a] := bytechar(ord(s[a])+32);
    end;
  end;
  if hastilde then s := '~'+s;
  result := s;
end;

function validuserid(s:bytestring):boolean;
var
  a:integer;
  hasuppercase:boolean;
begin
  result := false;
  if s = '' then exit;
  if length(s) > userlen then exit;

  if s[1] = '~' then s := copy(s,2,userlen);

  if not ((s[1] in ['A'..'Z']) or (s[1] in ['a'..'z']) or (s[1] in ['0'..'9'])) then exit;
  if not ((s[length(s)] in ['A'..'Z']) or (s[length(s)] in ['a'..'z']) or (s[length(s)] in ['0'..'9'])) then exit;
  hasuppercase := false;
  if length(s) > 1 then for a := 2 to length(s) do begin
    if not ((s[a] in ['A'..'Z']) or (s[a] in ['a'..'z']) or (s[a] in ['0'..'9']) or (s[a] = '-') or (s[a] = '_') or (s[a] = '.')) then exit;
    if s[a] in ['A'..'Z'] then hasuppercase := true;
  end;

  {if any uppercase, first must be uppercase too}
  if hasuppercase then if not (s[1] in ['A'..'Z']) then exit;


  result := true
end;

function validmask(s:bytestring):boolean;
var
  a:integer;
  c:bytechar;
begin
  result := false;
  if s = '' then exit;
  if length(s) > hostlen then exit;
  for a := 1 to length(s) do begin
    c := s[a];
    if not ((c in ['A'..'Z']) or (c in ['a'..'z']) or (c in ['0'..'9']) or (c = '.') or (c = '-') or (c = '!') or (c = '@') or (c = '*') or (c = '?') or (c = ':')) then exit;
  end;
  result := true
end;

end.
