(*
 *  beware ircd, Internet Relay Chat server, unitbanmask.pas
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

unit unitbanmask;

interface

uses bstuff,bconsts,bpremaskmatch,binipstuff,pgtypes;

{
unit to speed up banlist/G-list checking by doing binary match if possible

binary IP adresses and masks are stored as cpu byte order


}

type
  tbanmask=packed record
    ip:tbinip;
    user:bytestring;
    host:bytestring;
    cidr:byte;
    notip:boolean;
    nouserid:boolean;
  end;
  pbanmask=^tbanmask;

procedure banmaskmake(p:pbanmask;s:bytestring);
function banmaskmatch(p1,p2:pbanmask):boolean;
function banpremaskmatch(premask:ppremask;p1,p2:pbanmask;s1,s2:bytestring):boolean;
function getmaskstr(p:tbanmask):bytestring;
procedure banmaskmake_oneuser(p:pbanmask;userid,host:bytestring;const ip:tbinip);

function banmaskisbin(p:pbanmask):boolean;

procedure maskbits(var binip:tbinip;bits:integer);

function isipmask(const s:bytestring):boolean;

implementation

{this checks if the mask can possibly be an IP mask, because it only has characters that can be in an IP mask
otherwise, skip any code for matching it as an IP}
function isipmask(const s:bytestring):boolean;
var
  a,b:integer;
  ch:bytechar;
begin
  result := false;
  b := pos('@',s)+1;

  for a := b to length(s) do begin
    ch := s[a];
    if not ((ch in ['0'..'9']) or (ch = '.') or (ch = '*') or (ch = '?')
    {$ifndef noipv6} or (ch = ':') or (ch in ['A'..'F']) or (ch in ['a'..'f']){$endif}
    ) then exit;
  end;
  result := true;
end;

{function getbitmask(p:pbanmask):integer;
begin
  if p.cidr = 0 then result := 0
  else
  result := $ffffffff shl (32-p.cidr);
end;
}

{
 ffff 128
 ffxx 127
 ffxx 121
 ff00 120


}

procedure maskbits(var binip:tbinip;bits:integer);
const
  ipmax={$ifndef noipv6}15{$else}3{$endif};
type tarr=array[0..ipmax] of byte;
var
  arr:^tarr;
  a,b:integer;
begin
  arr := @binip.ip;
  if bits = 0 then b := 0 else b := ((bits-1) div 8)+1;
  for a := b to ipmax do begin
    arr[a] := 0;
  end;
  if (bits and 7 <> 0) then begin
    arr[bits shr 3] := arr[bits div 8] and not ($ff shr (bits and 7))
  end;
end;

function banmaskisbin(p:pbanmask):boolean;
begin
  result := p.cidr <> 255;
end;

procedure banmaskmake(p:pbanmask;s:bytestring);
label nobin;
var
  a,b,c,d,e:integer;
  ok:boolean;
  s2,s3:bytestring;
begin
  {separate userid and host}
  a := pos('@',s);
  if a = 0 then begin
    p.nouserid := true;
    p.user := '';
  end else begin
    p.user := copy(s,1,a-1);
    s := copy(s,a+1,hostlen);
    if p.user = '*' then begin
      p.user := '';
      p.nouserid := true;
    end else begin
      p.nouserid := false;
    end;
  end;

  p.host := s;
  p.notip := false;

  if (s = '*') or (s = '') then goto nobin;

  {s is guaranteed to be non null}

  a := pos('/',s);
  if a <> 0 then begin
    {CIDR notation}
    s2 := copy(s,1,a-1);
    s3 := copy(s,a+1,255);
{$ifndef noipv6}
    if pos(':',s2) <> 0 then begin
      a := strtointdef(s3,-1);
      if (a < 0) or (a > 128) then goto nobin; {wrong bits}
      ipstrtobin(s2,p.ip);
      p.cidr := a;
      if p.ip.family <> AF_INET6 then goto nobin;
      maskbits(p.ip,p.cidr);
      exit;
    end else
{$endif}
    begin
      d := 0;
      for b := 1 to length(s2) do if s2[b] = '.' then inc(d);
      while d < 3 do begin
        s2 := s2 + '.0';
        inc(d);
      end;
      ipstrtobin(s2,p.ip);
      if p.ip.family <> AF_INET then goto nobin; {wrong ip}
      a := strtointdef(s3,-1);
      if (a < 0) or (a > 32) then goto nobin; {wrong bits}
      p.cidr := a;
      maskbits(p.ip,p.cidr);
    end;
    exit;
  end;

{$ifndef noipv6}
  {v4 or v6 exact match}
  ipstrtobin(s,p.ip);
  if p.ip.family = AF_INET6 then begin
    p.cidr := 128;
    exit;
  end else if p.ip.family = AF_INET then begin
    p.cidr := 32;
    exit;
  end;

{$endif}

  {normal ip mask or single ip. if fails, will be string mask}

  fillchar(p.ip,sizeof(p.ip),0);
  e := 0;
  p.cidr := 0;
  a := 0;
  d := 0;
  ok := true;
  repeat
    s2 := '';
    {s must be non null}
    repeat
      inc(a);
      if s[a] <> '.' then s2 := s2 + s[a];
    until (a >= length(s)) or (s[a] = '.');
    if s2 = '*' then begin
      {}
    end else begin

      if d <> p.cidr then begin
        ok := false;
        break;
      end;
      c := strtointdef(s2,-1);
      if (c < 0) or (c > 255) then begin
        ok := false;
        break;
      end;
      e := e or (c shl (24-d));
      inc(p.cidr,8);
    end;
    inc(d,8);
    if (d >= 32) or ((a = length(s)) and (s[a] = '*')) then begin
      ok := (a = length(s)) and (s[a] <> '.');
      break;
    end;
  until false;

  if ok then begin
    p.ip.family := AF_INET;
    p.ip.ip := htonl(e);
    maskbits(p.ip,p.cidr);
    exit;
  end;

nobin:
{string mask, no binary}
  p.notip := not isipmask(s);
  p.cidr := 255;
  fillchar(p.ip,sizeof(p.ip),0);
end;

procedure banmaskmake_oneuser(p:pbanmask;userid,host:bytestring;const ip:tbinip);
begin
  p.ip := ip;
  {$ifndef noipv6}
  if ip.family = AF_INET6 then p.cidr := 128 else
  {$endif}
  if p.ip.family = AF_INET then p.cidr := 32 else p.cidr := 255;
  p.notip := false;
  p.host := host;
  p.nouserid := false;
  p.user := userid;
end;


{
check if p1 overlaps p2
}

function banmaskmatch(p1,p2:pbanmask):boolean;
var
  a:integer;
  biniptemp,biniptemp2:tbinip;
begin
  result := false;

  if banmaskisbin(p1) and banmaskisbin(p2) then begin
    if (p1.ip.family <> p2.ip.family) then exit;

    biniptemp := p2.ip;
    maskbits(biniptemp,p1.cidr);
    result := comparebinip(p1.ip,biniptemp);
    {result := p1.ip = (p2.ip and getbitmask(p1));}
    if (p2.cidr < p1.cidr) then if result then begin
      {a := getbitmask(p1) and getbitmask(p2);
      if (p1.ip and a) = (p2.ip and a) then result := false;}
      a := p1.cidr;
      if p2.cidr < a then a := p2.cidr;
      biniptemp2 := p1.ip;
      maskbits(biniptemp,a);
      maskbits(biniptemp2,a);
      result := not comparebinip(biniptemp,biniptemp2);
      {p1 1.2.0.0/24 does not overlap p2 1.2.0.0/20 situation}
    end;
  end else begin
    result := maskmatchup(p1.host,p2.host);

    if not result then if not p1.notip then begin
      {banning *2* }
      result := maskmatchup(p1.host,ipbintostr(p2.ip));
    end;

  end;
  if not result then exit;
  if p1.nouserid then exit;
  result := maskmatchup(p1.user,p2.user);
end;


function banpremaskmatch(premask:ppremask;p1,p2:pbanmask;s1,s2:bytestring):boolean;
begin
  if banmaskisbin(p1) then begin
    if banmaskisbin(p2) then begin
      result := banmaskmatch(p1,p2);
    end else begin
      result := premaskmatchup(premask,s2);
      if result then result := maskmatchup(s1,s2);
    end;
  end else begin
    if banmaskisbin(p2) and p1.notip then begin
      result := false;
    end else begin
      result := premaskmatchup(premask,s2);
      if result then result := maskmatchup(s1,s2);
    end;
  end;
end;

function getmaskstr(p:tbanmask):bytestring;
begin
  if p.nouserid then result := '*' else result := p.user;
  result := result + '@'+p.host;
end;

end.


