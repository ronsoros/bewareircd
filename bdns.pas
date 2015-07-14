(*
 *  beware ircd, Internet Relay Chat server, bdns.pas
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

unit bdns;

{DNS lookup code in this unit}

interface

{$include bircd.inc}

uses buser,blinklist,pgtypes;

const
  noticednsstart='Looking up your hostname';
  noticednsfound='Found your hostname';
  noticednsmismatch='Your forward and reverse DNS do not match, ignoring hostname';
  noticednscached='Found your hostname, cached';
  noticednsfailed='Couldn''t look up your hostname';
  noticednsinvalid='Invalid hostname';
  noticeidentstart='Checking Ident';
  noticeidentfound='Got ident response';
  noticeidentfailed='No ident response';

procedure dnsstart(us:tuser);
procedure dnstimeout(num:integer);

implementation

uses
  {$ifdef mswindows}winsock,{$endif}lsocket,
  bircdunit,bconfig,bstuff,bsend,bwelcome,bsock,bdnscache,bconsts,unitbanmask,
  bvaliddef,dnsasync,binipstuff;

type
  tic=class
    {wsocket dns lookup}

    {dnsquery dns lookup}
    {$ifndef nodnsquery}
    procedure requestdone(sender:tobject;error:word);
    {$endif}
  end;

var
  ic:tic;

procedure dnsfinish(us:tuser;const resolvedlist:tbiniplist;hasresolved:boolean);
var
  a:integer;
begin
  if hasresolved then begin
    {scan all IPs, look if any one of them is correct}
    for a := biniplist_getcount(resolvedlist)-1 downto 0 do begin
      if comparebinip(biniplist_get(resolvedlist,a),us.binip) then begin
        send_statusnotice(us,noticednsfound);
        dnscache_add(us.binip,us.host);
        exit;
      end
    end;

    {if not, return a mismatch}
    send_statusnotice(us,noticednsmismatch);
    locnotice(SNO_IPMISMATCH,'IP# Mismatch: '+ircipbintostr(us.binip)+' != '+us.host+'['+ircipbintostr(biniplist_get(resolvedlist,0))+']');
    us.host := ircipbintostr(us.binip);
  end else begin
    us.host := ircipbintostr(us.binip);
    send_statusnotice(us,noticednsfailed);
  end;
  dnscache_add(us.binip,us.host);
end;

{$ifndef nodnsquery}
procedure tic.requestdone(sender:tobject;error:word);
var
  us:tuser;
  num:integer;
  s:bytestring;
  //biniptemp:tbinip;
  tempiplist:tbiniplist;

procedure done;
begin
  setflag(us.flags,userlog_dns);
  connectionlist[num].dnsq.destroy;
  connectionlist[num].dnsq := nil;
  welcome(us);
end;

begin
  num := tdnsasync(sender).tag;

  if not connectionlist[num].open then exit;

  us := connectionlist[num].user;
  if flag_isset(us.flags,userflag_dnsreverse) then begin
    tempiplist := tdnsasync(sender).dnsresultlist;
    dnsfinish(us,tempiplist,biniplist_getcount(tempiplist) > 0);
    done;
  end else begin
    s := tdnsasync(sender).dnsresult;
    if s <> '' then begin
      if not validhost(s) then begin
        us.host := ircipbintostr(us.binip);
        send_statusnotice(us,noticednsinvalid);
        dnscache_add(us.binip,us.host);
        done;
      end else begin
        us.host := s;
        setflag(us.flags,userflag_dnsreverse);
        tdnsasync(sender).overrideaf := us.binip.family;
        tdnsasync(sender).forwardlookup(us.host);
      end;
    end else begin
      us.host := ircipbintostr(us.binip);
      dnscache_add(us.binip,us.host);
      send_statusnotice(us,noticednsfailed);
      done;
    end;
  end;
end;
{$endif}

function dontreverse(const ip:tbinip):bytestring;
var
  a:integer;
begin
  result := '';
  if ip.family = AF_INET then begin
    a := htonl(ip.ip);
    if (a and $ff000000 = $7f000000) then begin
      result := me.name;
    end;
  end else if ip.family = AF_INET6 then begin
    if comparebinip(ip,ipstrtobinf('::1')) then result := me.name;
  end;
end;

procedure dnsstart(us:tuser);
var
  dns:tdnscache;
  s:bytestring;
begin
  s := dontreverse(us.binip);
  if s <> '' then begin
    us.host := s;
    setflag(us.flags,userlog_dns);
    welcome(us);
  end else begin
    send_statusnotice(us,noticednsstart);
    dns := dnscache_find(us.binip);
    if dns = nil then begin
      with connectionlist[us.socknum] do begin
        dnsq := tdnsasync.create(nil);
        dnsq.addr := opt.dnsserver;
        dnsq.tag := us.socknum;
        dnsq.onrequestdone := ic.requestdone;
        try
          dnsq.reverselookup(us.binip);
        except
          connectionlist[us.socknum].dnsq.destroy;
          connectionlist[us.socknum].dnsq := nil;
          send_statusnotice(us,noticednsfailed);
          setflag(us.flags,userlog_dns);
          welcome(us);
        end;
      end;
    end else begin
      send_statusnotice(us,noticednscached);
      us.host := dns.name;

      setflag(us.flags,userlog_dns);
      welcome(us);
    end;
  end;
end;

procedure dnstimeout(num:integer);
var
  us:tuser;
begin
  us := connectionlist[num].user;

  {$ifndef nodnsquery}
  if assigned(connectionlist[num].dnsq) then begin
    connectionlist[num].dnsq.destroy;
    connectionlist[num].dnsq := nil;
  end;
  {$endif}
  us.host := ircipbintostr(us.binip);
  dnscache_add(us.binip,us.host);
  send_statusnotice(us,noticednsfailed);
  setflag(us.flags,userlog_dns);
  welcome(us);
end;

end.
