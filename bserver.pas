(*
 *  beware ircd, Internet Relay Chat server, bserver.pas
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

unit bserver;

interface

uses buser,blinklist,bstuff,bconsts,bsend,pgtypes;

type
  pointerarray=array[0..0] of pointer;
  ppointerarray=^pointerarray;

var
  p10server:array[0..SSmask] of tserver;

  {all Tservers (including me.server)}
  globalserverlist:tlinklist;
                                          
  serverlinklist:array[0..maxserverlink] of tserver;

  highserverlink:integer;

  p10currentslot:integer;
  bootts:integer;
  starttime:integer;

  serverisrunning:boolean;
  receivingburst:integer;
  {
  the number of J servers, thus, if > 0, if a netburst is being received
  }

function addserver(us:tuser;p10num,p10max:integer;parentserver:tserver):tserver;
procedure destroyserver(self:tserver);
procedure init;

{for "/request <server>" like commands,
this returns the Tuser of the server;
checks servername, nick, and *servermask}
function getremoteserver(const s:bytestring;fromclient:boolean):tuser;

procedure markdestroyingserver(srv:tserver);

{dstroy any empty channels (after a netburst)}
procedure channelcheck;

procedure tsfromserver(sptr:tuser;ts:integer);

function getlinkts:integer;

implementation

uses bparse,bchannel,bircdunit,btime,bconfig,bcmds,bsock;

var
  lastlinkts:integer=0;

function getlinkts:integer;
var
  a:integer;
begin
  if lastlinkts >= irctime then begin
    result := lastlinkts+1;
  end else begin
    result := irctime;
  end;

  for a := 0 to highserverlink do if serverlinklist[a] <> nil then begin
    if (serverlinklist[a].linktime >= result) then result := (serverlinklist[a].linktime + 1);
  end;

  lastlinkts := result;
end;

function addserver(us:tuser;p10num,p10max:integer;parentserver:tserver):tserver;
begin
  result := tserver.create;
  result.protoversion := 10;
  linklistadd(globalserverlist,tlinklist(result));

  result.us := us;
  us.server := result;

  setflag(us.flags,userflag_isserver);

  result.p10num := p10num;
  p10server[p10num] := result;

  us.idstr := convertidstr(p10inttostr(p10num,SSlen));

  result.p10max := p10max;
  result.parentserver := parentserver;
  getmem(result.p10slots,(p10max+1) shl 2);
  fillchar(result.p10slots^,(p10max+1) shl 2,0);

  inc(count.globalservers);
end;

procedure init;
var
  a:integer;
begin
  globalserverlist := nil;
  for a := 0 to SSmask do p10server[a] := nil;
  for a := 0 to maxserverlink do serverlinklist[a] := nil;
  highserverlink := 0;
end;

function getremoteserver(const s:bytestring;fromclient:boolean):tuser;
var
  p:tserver;
begin
  result := nil;
  if (s = '') or (s = '*') then begin
    result := me;
    exit;
  end;
  if not fromclient then begin
    result := findnumeric(s);
    exit;
  end;

  {try exact match}
  p := tserver(findname(s));
  if p <> nil then begin
    result := tuser(tuser(p).server.us);
    exit;
  end;
  {try maskmatch of servername}
  p := tserver(globalserverlist);
  while p <> nil do begin
    if maskmatchup(s,tuser(p.us).name) then begin
      result := tuser(p.us);
      exit;
    end;
    p := tserver(p.next);
  end;
end;

procedure destroyserver;
var
  p,p2:tlinklist;
{  counter:integer; - for nonblocking split}
begin

{  if serverisrunning then processmessages;}

{  counter := 0;}

  p := globaluserlist;
  while p <> nil do begin
    {AV crash location during netsplit (fixed by blocking netsplit)}
    p2 := p.next;
    if (tuser(p).server = self) and isclient(tuser(p)) then begin
      {don't send a QUIT to other servers, for a user which splits off}
      setflag(tuser(p).flags,userflag_globalkill);
      tuser(p).error := tuser(self.us).error;
      tuser(p).destroy;

{      inc(counter);
      if counter and 255 = 0 then if serverisrunning then processmessages;}
    end;
    p := p2;
  end;

  if flag_isset(self.flags,servflag_joining) then begin
    dec(receivingburst);
    channelcheck;
  end;
  freemem(self.p10slots);
  p10server[self.p10num] := nil;
  dec(count.globalservers);
  if self.parentserver = me.server then serverlinklist[self.serverlinknum] := nil;
  linklistdel(globalserverlist,self);
end;

procedure markdestroyingserver2(srv:tserver);
var
  p:tlinklist;
begin
  if flag_isset(srv.flags,servflag_destroying) then exit;
  setflag(srv.flags,servflag_destroying);
  p := globalserverlist;
  while p <> nil do begin
    if tserver(p).parentserver = srv then markdestroyingserver2(tserver(p));
    p := p.next;
  end;
end;

procedure markdestroyingserver(srv:tserver);
var
  p:tlinklist;
begin
  if flag_isset(srv.flags,servflag_destroying) then exit;
  setflag(srv.flags,servflag_destroying);
  setflag(srv.flags,servflag_destroying_root);
  p := globalserverlist;
  while p <> nil do begin
    if tserver(p).parentserver = srv then markdestroyingserver2(tserver(p));
    p := p.next;
  end;
end;

procedure channelcheck;
var
  p,p2:tchannel;
begin
  if receivingburst > 0 then exit;
  p := tchannel(globalchanlist);
  while p <> nil do begin
    p2 := tchannel(p.next);
    if p.usercount <= 0 then p.destroy;
    p := p2;
  end;
end;

procedure tsfromserver(sptr:tuser;ts:integer);
begin
  if ts < OLDEST_TS then exit;
  sptr.server.lag := irctime-ts;

  if opt.reliableclock then
  if abs(ts-irctime) >= 30 then
  if connectionlist[sptr.from.socknum].sendqsize < 8000 then begin
    sendto_one(sptr.from,sprefix(me,TOK_SETTIME)+inttostr(irctime));
    locnotice(sno_oldsno,'TS difference of '+inttostr(ts-irctime)+' seconds from '+tuser(sptr.server.us).name+', sent SETTIME.');
  end;
end;

begin
  {they may already be zero'd but i dont take any risk}
  serverisrunning := false;
  me := nil;
  globalserverlist := nil;
end.
