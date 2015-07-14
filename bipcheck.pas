(*
 *  beware ircd, Internet Relay Chat server, bipcheck.pas
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

unit bipcheck;

{
"IPcheck" does connection throttling, counting clones, and free targets

based on the idea of ircu's IPcheck.c (and designed to do exactly the same)

}

interface

uses blinklist,btime,bcmds,bstuff,bconsts,binipstuff,pgtypes;

const
  ipcheck_tablesize=$1000;
  ipcheck_connectinterval=30;
  ipcheck_connectmax=4;
  maxtargets=20;

type
  tipcheck=class(tlinklist)
    ip:tbinip;
    online:integer;
    nexttarget:integer;
    lastconnect:integer;
    attempt:integer;
    target:array[0..maxtargets-1] of byte;
    constructor create;
    destructor destroy; override;
  end;

var
  ipchecktable:array[0..ipcheck_tablesize-1] of tipcheck;
  ipcheckdebugcount:integer;

function ipcheck_hash(const ip:tbinip):integer;
function ipcheck_find(hash:integer;const ip:tbinip):tipcheck;
function ipcheck_connect(const ip:tbinip):tipcheck;
procedure ipcheck_connectsuccess(p:pointer);
procedure ipcheck_connectfailed(ipc:tipcheck);
procedure ipcheck_remoteclient(p:pointer);
procedure ipcheck_disconnect(ipc:tipcheck);

procedure ipcheck_destroyall;
procedure timehandler;
function ipcheck_target(us,target:pointer):integer;
{$ifdef bdebug}
procedure ipcheckdebug(psptr:pointer);
{$endif}

implementation

uses buser,bsend,bserver,bconfig,breplies,bsock;

function serverisstarting:boolean;
begin
  result := (unixtime - starttime) < 600;
end;

{$ifdef bdebug}
procedure ipcheckdebug;
var
  sptr:tuser;
  a,b,count:integer;
  ipc:tipcheck;
  s:bytestring;
begin
  sptr := tuser(psptr);
  count := 0;
  for a := 0 to ipcheck_tablesize-1 do begin
    ipc := ipchecktable[a];
    while ipc <> nil do begin
      s := inttostr(a)+' '+ircipbintostr(ipc.ip)+' '+inttostr(ipc.online)+' '+inttostr(ipc.attempt)+' '+inttostr(ipc.lastconnect-unixtime)+' '+inttostr(ipc.nexttarget-unixtime)+' *';
      for b := 0 to maxtargets-1 do s := s + ' '+inttostr(ipc.target[b]);
      sendreply(sptr,1300,':'+s);
      inc(count);
      ipc := tipcheck(ipc.next);
    end;
  end;
  sendreply(sptr,cmdnotice,':'+inttostr(count)+' items');
end;
{$endif}

function ipcheck_hash(const ip:tbinip):integer;
var
  a:integer;
begin
  {$ifndef noipv6}
  if ip.family = AF_INET6 then begin
    a := ip.ip6.s6_addr32[0] xor ip.ip6.s6_addr32[1] xor ip.ip6.s6_addr32[2] xor ip.ip6.s6_addr32[3];
    result := (a xor (a shr 16)) and (ipcheck_tablesize-1);
  end else
  {$endif}
  begin
    result := (ip.ip xor (ip.ip shr 16)) and (ipcheck_tablesize-1);
  end;
end;

function ipcheck_find(hash:integer;const ip:tbinip):tipcheck;
var
  ipc:tipcheck;
begin
  result := nil;
  ipc := ipchecktable[hash];
  while ipc <> nil do begin
    if comparebinip(ipc.ip,ip) then begin
      result := ipc;
      exit
    end;
    ipc := tipcheck(ipc.next);
  end;
end;

function oneattempt(ipc:tipcheck):boolean;
begin
  if (ipc.lastconnect <= unixtime-ipcheck_connectinterval) or opt.nothrottle then ipc.attempt := 0;
  ipc.lastconnect := unixtime;
  inc(ipc.attempt);
  if ipc.attempt >= ipcheck_connectmax then begin
    ipc.attempt := ipcheck_connectmax;
    result := serverisstarting;
  end else result := true
end;

function ipcheck_connect(const ip:tbinip):tipcheck;
var
  hash:integer;
  ipc:tipcheck;
begin
  hash := ipcheck_hash(ip);
  ipc := ipcheck_find(hash,ip);

  if ipc = nil then begin
    ipc := tipcheck.create;
    ipc.ip := ip;
    linklistadd(tlinklist(ipchecktable[hash]),tlinklist(ipc));
  end;
  if oneattempt(ipc) then begin
    inc(ipc.online);
    result := ipc
  end else result := nil
end;

procedure ipcheck_connectsuccess(p:pointer);
var
  us:tuser absolute p;
  a:integer;
  tr:bytestring;
begin
  if us.ipcheck = nil then exit;

  if us.ipcheck.nexttarget = 0 then tr := '' else tr := ' tr';

  a := unixtime-(opt.starttargets-1)*target_delay;
  if us.ipcheck.nexttarget < a then us.ipcheck.nexttarget := a;

  a := ((unixtime-us.ipcheck.nexttarget) div target_delay) + 1;
  if unixtime < us.ipcheck.nexttarget then a := 0;

{  if a > starttargets then a := starttargets;}
  if not opt.nothrottle then begin
    sendreply(us,cmdnotice,
    ':on '+inttostr(us.ipcheck.online)+
    ' ca '+inttostr(us.ipcheck.attempt)+'('+inttostr(ipcheck_connectmax)+') ft '+
    inttostr(a)+'('+inttostr(opt.starttargets)+')'+tr);
  end;
end;

procedure ipcheck_connectfailed(ipc:tipcheck);
begin
  if ipc <> nil then begin
    dec(ipc.attempt);
    dec(ipc.online);
  end;
end;

procedure ipcheck_remoteclient(p:pointer);
var
  us:tuser absolute p;
  hash:integer;
  ipc:tipcheck;
  a:integer;
begin
  hash := ipcheck_hash(us.binip);
  ipc := ipcheck_find(hash,us.binip);

  if ipc = nil then begin
    ipc := tipcheck.create;
    ipc.ip := us.binip;
    linklistadd(tlinklist(ipchecktable[hash]),tlinklist(ipc));
  end;
  us.ipcheck := ipc;
  oneattempt(ipc);
  inc(us.ipcheck.online);

  a := unixtime-(opt.starttargets-1)*target_delay;
  if us.ipcheck.nexttarget < a then us.ipcheck.nexttarget := a;
end;

{one client}
procedure ipcheck_disconnect(ipc:tipcheck);
begin
  if ipc = nil then exit;
  dec(ipc.online);
end;


procedure timehandler;
var
  a:integer;
  ipc,ipc2:tipcheck;
begin
  if tickcount and 15 <> 0 then exit;
  {expire items}
  for a := ipcheck_tablesize-1 downto 0 do begin
    ipc := ipchecktable[a];
    while ipc <> nil do begin
      ipc2 := tipcheck(ipc.next);
      if ipc.online <= 0 then begin
        if (ipc.lastconnect < unixtime-200) and ((unixtime-ipc.nexttarget) >= (maxtargets shl target_delayshift)) then begin
          linklistdel(tlinklist(ipchecktable[a]),tlinklist(ipc));
          ipc.destroy;
        end;
      end;
      ipc := ipc2;
    end;
  end;
end;

procedure ipcheck_destroyall;
var
  a:integer;
  p,p2:tipcheck;
begin
  for a := ipcheck_tablesize-1 downto 0 do begin
    p := ipchecktable[a];
    while p <> nil do begin
      p2 := tipcheck(p.next);
      linklistdel(tlinklist(ipchecktable[a]),tlinklist(p));
      p.destroy;
      p := p2;
    end;
  end;
  fillchar(ipchecktable,sizeof(ipchecktable),0);
end;


function ipcheck_target(us,target:pointer):integer;
var
  a:integer;
  ipc:tipcheck;
  hash:byte;
  i:array[0..3] of byte absolute target;
begin
  result := 0;
  if opt.nothrottle then exit;

  {global oper always has a free target}
  if isoper(us) then if opt.opernotargetlimit then exit;

  {only keep track of target changes of local users}
  if tuser(us).server <> me.server then exit;

  hash := i[0] xor i[1] xor i[2] xor i[3];

  ipc := tuser(us).ipcheck;
  if ipc = nil then exit;

  if ipc.target[0] = hash then exit;

  for a := 1 to maxtargets-1 do begin
    if ipc.target[a] = hash then begin
      move(ipc.target[0],ipc.target[1],a);
      ipc.target[0] := hash;
      exit;
    end;
  end;

  if ipc.nexttarget < unixtime-target_delay*(maxtargets-1) then
  ipc.nexttarget := unixtime-target_delay*(maxtargets-1);

  if (unixtime < ipc.nexttarget) and (myconnect(us)) then begin
{    if ipc.nexttarget - unixtime < target_delay+8 then begin}
      inc(ipc.nexttarget,2);
      sendreply(us,ERR_TARGETTOOFAST,tthing(target).name+' '+getrpl1(ERR_TARGETTOOFAST,inttostr(ipc.nexttarget-unixtime)));
{    end;}
    result := 1;
    exit;
  end else begin
    {sendreply(tuser(us),cmdnotice,':New target: '+tthing(target).name+', ft '+inttostr((unixtime-ipc.nexttarget) shr target_delayshift));}
    inc(ipc.nexttarget,target_delay);
  end;

  move(ipc.target[0],ipc.target[1],maxtargets-1);
  ipc.target[0] := hash;
end;

constructor tipcheck.create;
begin
  inherited create;
  inc(ipcheckdebugcount);
end;

destructor tipcheck.destroy;
begin
  dec(ipcheckdebugcount);
  inherited destroy;
end;

begin
  fillchar(ipchecktable,sizeof(ipchecktable),0);
end.
