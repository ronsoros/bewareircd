(*
 *  beware ircd, Internet Relay Chat server, passcryp.pas
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

{$g+,n-,e-,r-,s-,q-,d-,l-,y-,x+}

unit passcryp;

interface

uses
  {$ifndef ver70}bstuff,lcorernd,{$endif}
  fastmd5,pgtypes;

const
  cryptedpasslen=24;

function passmatch(const pass,crypted:bytestring):boolean;
function passnewcrypt(const pass:bytestring):bytestring;

function passcryptinternal(const pass:bytestring;salt:longint):bytestring;

function base64enc(var buf):bytestring;
procedure base64dec(var buf;const s:bytestring);
procedure passcryptinternalbin(const pass:bytestring;salt:longint;var result);

implementation


{
in TP7 (dos), mkpassword.exe, use these base64 routines.

in delphi, bircd.exe, use those from bstuff unit}

{$ifdef ver70}

function p10inttostr(i,chars:longint):bytestring;
const
  base64:array[0..63] of char='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789[]';
var
  a:integer;
  s:bytestring;
begin
  if i >= 64 then if chars < 2 then chars := 2;

  s[0] := chr(chars);

  for a := chars downto 1 do begin
    s[a] := base64[i and 63];
    i := i shr 6;
  end;
  p10inttostr := s;
end;

function p10strtoint(const s:bytestring):longint;
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
  a,b,c,i:integer;
begin
  i := 0;
  b := 0;
  for a := length(s) downto 1 do begin
    c := base64reverse[ord(s[a])];
    if c = 255 then begin
      i := -1;
      exit;
    end;
    i := i or c shl b;
    inc(b,6);
  end;
  p10strtoint := i;
end;

{$endif}


function base64enc(var buf):bytestring;
var
  buf2:array[0..5,0..2] of byte absolute buf;
  a:integer;
  s:bytestring;
begin
  s := '';
  for a := 0 to 5 do begin
    s := s + p10inttostr(
    longint(buf2[a,0]) shl 16+
    longint(buf2[a,1]) shl 8+
    longint(buf2[a,2]),4);
  end;
  base64enc := s;
end;

procedure base64dec(var buf;const s:bytestring);
var
  a,b:integer;
  buf2:array[0..5,0..2] of byte absolute buf;
  bbuf:array[0..3] of byte absolute b;
begin
  for a := 0 to 5 do begin
    b := p10strtoint(copy(s,a shl 2+1,4));
    buf2[a,0] := bbuf[2];
    buf2[a,1] := bbuf[1];
    buf2[a,2] := bbuf[0];
  end;
end;

function passcryptinternal(const pass:bytestring;salt:longint):bytestring;
var
  buf:array[0..17] of byte;
begin
  passcryptinternalbin(pass,salt,buf);
  passcryptinternal := base64enc(buf);
end;

procedure passcryptinternalbin(const pass:bytestring;salt:longint;var result);
var
  buf:array[0..17] of byte absolute result;
  s:bytestring;
begin
  s := chr(salt shr 8) + chr(salt and $ff) + pass;
  buf[0] := salt shr 8;
  buf[1] := salt and $ff;
  getmd5(s[1],length(s),buf[2]);
end;

function passmatch(const pass,crypted:bytestring):boolean;
var
  buf:array[0..17] of byte;
  i:longint;
begin
  if length(crypted) <> cryptedpasslen then begin
    passmatch := (crypted = pass);
    exit;
  end;
  base64dec(buf,crypted);
  {get salt from password}
  i := buf[0] shl 8 or buf[1];
  passmatch := passcryptinternal(pass,i) = crypted;
end;

function randomword:word;
begin
  {$ifdef ver70}
  result := random(65535)
  {$else}
  result := randominteger($10000);
  {$endif}
end;

function passnewcrypt(const pass:bytestring):bytestring;
begin
  if length(pass) = cryptedpasslen then
  passnewcrypt := pass
  else
  passnewcrypt := passcryptinternal(pass,randomword);
end;

end.
