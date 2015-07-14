(*
 *  beware ircd, Internet Relay Chat server, bstuff.pas
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

unit bstuff;

{
misc functions "library"

good idea to not use back units in interface,
and to avoid using back units in implementation
}

interface

uses pgtypes;

const
  mparams=30;

type
  bstuffstring=bytestring;
  bstuffchar=bytechar;
  tparams=array[0..mparams] of bytestring;
  pparams=^tparams;


  dvar=array[0..0] of byte;
  pdvar=^dvar;

{these string related functions may be useful for something other than IRC so the string type is different so it could be widestring easily}
function maskmatch(s1,s2:bstuffstring):boolean;
function strtok(const s:bstuffstring;separate:bstuffchar;params:pparams):integer;

{get next token from string}
procedure strtok2(const s:bstuffstring;separate:bstuffchar;var index:integer;var result:bstuffstring);



{IRC uppercase}
function ircupper(const s:bytestring):bytestring;
function strcompup(const s1,s2:bytestring):boolean;
function maskmatchup(s1,s2:bytestring):boolean;

function flag_isset(a,b:integer):boolean;

procedure setflag(var a:integer;b:integer);
procedure clearflag(var a:integer;b:integer);

function p10inttostr(i,chars:integer):bytestring;
function p10strtoint(const s:bytestring):integer;



{inttostr without sysutils}
function inttostr(i:integer):bytestring;
function strtointdef(const s:bytestring;i:integer):integer;
function inttohex(i,n:integer):bytestring;

function debugstr(const s:bytestring):bytestring; {replace all strange characters to hex code}

{chdir to dir of executable}
procedure getpath;


(*
translate table for IRC uppercase

char  ascii

[  91
\  92
]  93
^  94

{  123
|  124
}  125
~  126
*)

const
  ircuppertable:array[0..255] of byte=(
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
  16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,
  32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,
  48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,
  64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,
  80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,
  96,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,
  80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,127,
  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
  192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
  208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
  );

implementation


{this function allows and returns empty parameters as well}
function strtok(const s:bstuffstring;separate:bstuffchar;params:pparams):integer;
var
  a,c,d:integer;
begin
  a := 1;
  c := length(s);
  result := 0;
  while (a <= c) do begin
    if result > mparams then break;
    d := a;
    while (s[a] <> separate) and (a <= c) do inc(a);
    params[result] := copy(s,d,a-d);
    inc(result);
    {while (s[a] = ' ') and <- no empty, include this}
    if (a <= c) then inc(a)
  end;
end;

procedure strtok2(const s:bstuffstring;separate:bstuffchar;var index:integer;var result:bstuffstring);
var
  bool:boolean;
  a,b:integer;
begin
  a := length(s);
  bool := false;
  repeat
    if index <= a then begin
      if s[index] = separate then inc(index) else bool := true;
    end else begin
      bool := true;
    end;
  until bool;
  b := index;
  bool := false;
  repeat
    if index <= a then begin
      if s[index] <> separate then inc(index) else bool := true;
    end else begin
      bool := true;
    end;
  until bool;
  result := copy(s,b,index-b);
end;


{
check if s2 matches s1, s1 may contain * ? wildcards, s2 may not
this is case sensitive, the caller should do uppercase (can be faster this way)
}
function maskmatch(s1,s2:bstuffstring):boolean;
var
  a,b,c,d,ls1,ls2,count:integer;
  s3:bstuffstring;
  bool,bool2:boolean;
begin
  if s2 = s1 then begin
    result := true;
    exit
  end;
  bool := true;
  s1 := #1 + s1 + #1;
  s2 := #1 + s2 + #1;
  ls1 := length(s1);
  ls2 := length(s2);
  a := 1;
  b := 1;
  while a <= ls1 do begin
    s3 := '';
    while (s1[a] <> '*') and (a<=ls1) do begin
      s3 := s3 + s1[a];
      inc(a);
    end;
    inc(a);
    count := ls2-length(s3)+1;
    bool2 := false;
    for c := b to count do begin
      bool2 := true;
      for d := 1 to length(s3) do begin
        if (s3[d] <> s2[d+c-1]) and ((s3[d] <> '?') or (s2[d+c-1] = #1)) then begin
          bool2 := false;
          break
        end
      end;
      if bool2 then begin
        break
      end;
    end;
    inc(b,length(s3));
    if not bool2 then begin
      result := false;
      exit;
    end;
  end;
  result := bool;
end;




function inttostr(i:integer):bytestring;
begin
  str(i,result);
end;

function strtointdef(const s:bytestring;i:integer):integer;
var
  code:integer;
begin
  {$R-}
   val(s,result,code);
   if code <> 0 then result := i;
end;

function inttohex(i,n:integer):bytestring;
const
  hexchar:array[0..15] of bytechar='0123456789ABCDEF';
begin
  result := '';
  while i <> 0 do begin
    result := hexchar[i and $f]+result;
    i := i shr 4;
  end;
  while length(result) < n do result := '0'+result;
end;



function ircupper(const s:bytestring):bytestring;
{ recoded in pascal by plugwash as fpc didn't like the assembler stuff
  changed again by beware/simplifid/optimized 20030402}
var
  counter : integer;
begin
  result := s;
  for counter := length(result) downto 1 do begin
    result[counter] := bytechar(ircuppertable[ord(result[counter])])
  end;
end;

function flag_isset(a,b:integer):boolean;
begin
  result := a and b = b;
end;

procedure setflag;
begin
  a := a or b
end;

procedure clearflag;
begin
  a := a and not b
end;

function p10inttostr(i,chars:integer):bytestring;
const
  base64:array[0..63] of bytechar='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789[]';
var
  a:integer;
begin
  setlength(result,chars);

  for a := chars downto 1 do begin
    result[a] := base64[i and 63];
    i := i shr 6;
  end;
end;

function p10strtoint(const s:bytestring):integer;
const
  base64reverse:array[0..255] of byte=(
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  52,53,54,55,56,57,58,59,60,61,255,255,255,255,255,255,
  255,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,
  15,16,17,18,19,20,21,22,23,24,25,62,0,63,255,255,
  255,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
  41,42,43,44,45,46,47,48,49,50,51,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
  255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
  );

var
  a,b,c:integer;
begin
  result := 0;
  b := 0;
  for a := length(s) downto 1 do begin
    c := base64reverse[ord(s[a])];
    if c = 255 then begin
      result := -1;
      exit;
    end;
    result := result or c shl b;
    inc(b,6);
  end;
end;


function maskmatchup(s1,s2:bytestring):boolean;
var
  a,b,c,d,ls1,ls2,count:integer;
  s3:bytestring;
  bool,bool2:boolean;
begin
  bool := true;
  s1 := #1 + s1 + #1;
  s2 := #1 + s2 + #1;
  ls1 := length(s1);
  ls2 := length(s2);
  a := 1;
  b := 1;
  while a <= ls1 do begin
    s3 := '';
    while (s1[a] <> '*') and (a<=ls1) do begin
      s3 := s3 + s1[a];
      inc(a);
    end;
    inc(a);
    count := ls2-length(s3)+1;
    bool2 := false;
    for c := b to count do begin
      bool2 := true;
      for d := 1 to length(s3) do begin
        if (bytechar(ircuppertable[ord(s3[d])]) <> bytechar(ircuppertable[ord(s2[d+c-1])])) and ((s3[d] <> '?') or (s2[d+c-1] = #1)) then begin
          bool2 := false;
          break
        end
      end;
      if bool2 then begin
        break
      end;
    end;
    inc(b,length(s3));
    if not bool2 then begin
      result := false;
      exit;
    end;
  end;
  result := bool;
end;

function strcompup(const s1,s2:bytestring):boolean;
var
  a,b:integer;
begin
  result := false;
  a := length(s1);
  if a <> length(s2) then exit;
  for b := a downto 1 do begin
    if ircuppertable[ord(s1[b])] <> ircuppertable[ord(s2[b])] then exit;
  end;
  result := true;
end;


function debugstr(const s:bytestring):bytestring;
var
  a:integer;
begin
  result := '';
  for a := 1 to length(s) do begin
    if s[a] in [#32..#127] then result := result + s[a]
    else result := result + #22+inttohex(ord(s[a]),2)+#22;
  end;
end;

procedure getpath;
var
  s:string;
  a,b:integer;
begin
  s := paramstr(0);
  b := 0;
  for a := length(s) downto 1 do begin
    if (s[a] = '\') or (s[a] = '/') then begin
      b := a;
      break;
    end;
  end;
  if b = 0 then exit;
  s := copy(s,1,b-1);
  chdir(s);
end;

end.
