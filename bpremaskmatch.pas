(*
 *  beware ircd, Internet Relay Chat server, bpremaskmatch.pas
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


{
this unit helps speeding up maskmatch in code which checks alot of strings
against a single mask.
it isn't as accurate as a real mask match, but uses only about 10% of the cpu.

if premaskmatch does not match, a mask match doesn't match either (and can be skipped)

if premaskmatch does match, a mask match should be done as 
well; it likely matches, but might not.

a /who with a carefully chosen parameter can cause
the server to do like 100,000 maskmatches. with the pre maskmatch code, 
the real maskmatch is only done up to 200 times (one per line of the reply)
}

unit bpremaskmatch;

interface

uses pgtypes;

type
  dvar=array[0..0] of byte;
  pdvar=^dvar;

  tpremask=record
    l1,l2,l3,l4:integer;  {string is used (if false, matches,shortcut)}
    s1,s2,s3,s4:string[255];
    p1,p2,p3,p4:pdvar;
    ltotal:integer;     {length of the 4 strings added (to match, a string must be atleast this)}
  end;
  ppremask=^tpremask;

procedure premaskmake(t:ppremask;s:bytestring);
function premaskmatch(t:ppremask;const s:bytestring):boolean;

{does premaskmatch check, if s is not already uppercased. but premask must be already uppercased}
function premaskmatchup(t:ppremask;const s:bytestring):boolean;


{
s1: string which is at start of mask.
if mask starts with a wildcard, this is not used

s2: first string after s1

..

s3: last string before s4

s4: string which is at end of mask.
if mask ends with a wildcard, this is not used

possible masks

s1*s2*s3*s4
s1*s2*s4
s1*s4
s1
s1*s2*s3*
s1*s2*
*s2*s3*s4
*s2*s4
*s2*s3*
*s2*
}


implementation

uses bstuff;

function findwildfirst(const s:bytestring):integer;
var
  a,b:integer;
begin
  result := 0;
  b := length(s);
  for a := 1 to b do if (s[a] = '*') or (s[a] = '?') then begin
    result := a;
    exit;
  end;
end;

function findwildlast(const s:bytestring):integer;
var
  a,b:integer;
begin
  result := 0;
  b := length(s);
  for a := b downto 1 do if (s[a] = '*') or (s[a] = '?') then begin
    result := a;
    exit;
  end;
end;

procedure premaskmake(t:ppremask;s:bytestring);
label eind;
var
  s2,s3:bytestring;
  a,b:integer;
begin
  t.l1 := 0;
  t.l2 := 0;
  t.l3 := 0;
  t.l4 := 0;
  t.p1 := @t.s1[1];
  t.p2 := @t.s2[1];
  t.p3 := @t.s3[1];
  t.p4 := @t.s4[1];
  b := 0;
  for a := 1 to length(s) do if s[a] = '?' then inc(b);
  t.ltotal := b;

  if s = '' then goto eind;
  a := findwildfirst(s);
  if a = 0 then begin
    {no wildcards: s1 }
    t.s1 := s;
    t.l1 := length(t.s1);
    goto eind;
  end;

  {atleast one wildcard}

  if a = 1 then begin
    {   *xx    }
  end else begin
    {   s1*xx  }
    t.s1 := copy(s,1,a-1);
    t.l1 := length(t.s1)
  end;
  s := copy(s,a+1,500);

  a := findwildlast(s);
  if a = 0 then begin
    if s <> '' then begin
      t.s4 := s;
      t.l4 := length(t.s4);
    end;
    goto eind;
  end else begin
    if copy(s,a+1,500) <> '' then begin
      t.s4 := copy(s,a+1,500);
      t.l4 := length(t.s4);
    end;
  end;
  s := copy(s,1,a-1);

  while findwildfirst(s) = 1 do s := copy(s,2,500);
  while (s <> '') and (findwildlast(s) = length(s)) do s := copy(s,1,length(s)-1);

  a := findwildfirst(s);
  b := findwildlast(s);
  s2 := copy(s,1,a-1);
  s3 := copy(s,b+1,500);
  if (s2 = '') and (s3 <> '') then begin
    t.s2 := s3;
    t.l2 := length(t.s2)
  end else if s3 <> '' then begin
    t.s3 := s3;
    t.l3 := length(t.s3)
  end;

  if s2 <> '' then begin
    t.s2 := s2;
    t.l2 := length(t.s2)
  end;
eind:
  inc(t.ltotal,t.l1+t.l2+t.l3+t.l4);
end;

{p1 is the mask, p2 is the string to check}

function samestring(p1,p2:pdvar;l:integer):boolean;
var
  a:integer;
begin
  result := false;
  for a := l-1 downto 0 do begin
    if p1^[0] <> p2^[0] then exit;
    inc(taddrint(p1));
    inc(taddrint(p2));
  end;
  result := true;
end;

function samestring_ircupper(p1,p2:pdvar;l:integer):boolean;
var
  a:integer;
begin
  result := false;
  for a := l-1 downto 0 do begin
    if p1^[0] <> ircuppertable[p2^[0]] then exit;
    inc(taddrint(p1));
    inc(taddrint(p2));
  end;
  result := true;
end;

function premaskmatch(t:ppremask;const s:bytestring):boolean;
var
  p:pdvar;
  p2,p3:taddrint;
  l:integer;
  b:boolean;
begin
  p := @s[1];
  l := length(s);
  result := false;
  if l < t.ltotal then exit;
  if t.l1 > 0 then if not samestring(t.p1,p,t.l1) then exit;
  if t.l4 > 0 then if not samestring(t.p4,pdvar(taddrint(p)+l-t.l4),t.l4) then exit;


  if t.l2 > 0 then begin
    p3 := taddrint(p)+(l-t.l4-t.l3-t.l2);
    p2 := taddrint(p)+t.l1;
    b := false;
    while p2 <= p3 do begin
      if samestring(t.p2,pdvar(p2),t.l2) then begin
        b := true;
        break;
      end;
      inc(p2);
    end;
    if not b then exit;
  end;

  if t.l3 > 0 then begin
    p3 := taddrint(p)+(l-t.l4-t.l3);
    p2 := taddrint(p)+t.l1+t.l2;
    b := false;
    while p2 <= p3 do begin
      if samestring(t.p3,pdvar(p2),t.l3) then begin
        b := true;
        break;
      end;
      inc(p2);
    end;
    if not b then exit;
  end;


  result := true;
end;


function premaskmatchup(t:ppremask;const s:bytestring):boolean;
var
  p:pdvar;
  p2,p3:taddrint;
  l:integer;
  b:boolean;
begin
  p := @s[1];
  l := length(s);
  result := false;
  if l < t.ltotal then exit;
  if not samestring_ircupper(t.p1,p,t.l1) then exit;
  if not samestring_ircupper(t.p4,pdvar(taddrint(p)+l-t.l4),t.l4) then exit;


  if t.l2 > 0 then begin
    p3 := taddrint(p)+(l-t.l4-t.l3-t.l2);
    p2 := taddrint(p)+t.l1;
    b := false;
    while p2 <= p3 do begin
      if samestring_ircupper(t.p2,pdvar(p2),t.l2) then begin
        b := true;
        break;
      end;
      inc(p2);
    end;
    if not b then exit;
  end;

  if t.l3 > 0 then begin
    p3 := taddrint(p)+(l-t.l4-t.l3);
    p2 := taddrint(p)+t.l1+t.l2;
    b := false;
    while p2 <= p3 do begin
      if samestring_ircupper(t.p3,pdvar(p2),t.l3) then begin
        b := true;
        break;
      end;
      inc(p2);
    end;
    if not b then exit;
  end;


  result := true;
end;


end.
