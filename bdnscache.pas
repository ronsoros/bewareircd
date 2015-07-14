(*
 *  beware ircd, Internet Relay Chat server, bdnscache.pas
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

unit bdnscache;

interface

uses blinklist,binipstuff,pgtypes;

const
  dnscache_expiration=300;

type
  tdnscache=class(tlinklist)
    name:bytestring;
    ip:tbinip;
    expiration:integer;
  end;

var
  dnscachelist:tlinklist;

procedure dnscache_add(const ip:tbinip;name:bytestring);
procedure timehandler;
function dnscache_find(const ip:tbinip):tdnscache;

implementation

uses
  btime;

function dnscache_find(const ip:tbinip):tdnscache;
var
  p:tlinklist;
begin
  result := nil;
  p := dnscachelist;
  while p <> nil do begin
    if comparebinip(tdnscache(p).ip,ip) then begin
      result := tdnscache(p);
      exit;
    end;
    p := p.next;
  end;
end;

procedure dnscache_add(const ip:tbinip;name:bytestring);
var
  dns:tdnscache;
begin
  dns := dnscache_find(ip);
  if dns = nil then begin
    dns := tdnscache.create;
    dns.expiration := unixtime+dnscache_expiration;
    dns.name := name;
    dns.ip := ip;
    linklistadd(dnscachelist,tlinklist(dns));
  end;
end;

procedure timehandler;
var
  p,p2:tdnscache;
begin
  if tickcount and 15 <> 0 then exit;  {once / 16 secs}
  p := tdnscache(dnscachelist);
  while p <> nil do begin
    p2 := tdnscache(p.next);
    if p.expiration <= unixtime then begin
      linklistdel(dnscachelist,tlinklist(p));
      p.destroy;
    end;
    p := p2;
  end;
end;

begin
  dnscachelist := nil;
end.
