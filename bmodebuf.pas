(*
 *  beware ircd, Internet Relay Chat server, bmodebuf.pas
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


unit bmodebuf;

interface

uses buser,bconsts,bchannel,pgtypes;

{
unit for centralized mode string beautifying and sending


flags

- send to servers but source
- send to users on channel
- bounce (send to source server)
- opmode
}

{
new modebuf code:

- Tlinklist based item with s and s2 (char and param)
2 linked lists: set and clear

can add unlimited number of entries
flush first sends out all clear then all set modes

- centralized eliminate cancelling modes:
before adding the new entry, find if the cancelling mode exists
(for a new item on list n, its in list n xor 2, the first item found same char, same param)
if so, remove that item and dont add the new one

mode +l exception?

removes the need for "resendopvoice" code.
removes the need for the "modeisundone" function
}

const
  modebufflag_toservers=$1;
  modebufflag_tousers=$2;
  modebufflag_bounce=$4;
  modebufflag_opmode=$8;

{mode +o nick}
procedure modebuf_init(source:tuser;chan:tchannel;flags:integer);

function modebuf_add_internal(bufnum:integer;c:bytechar;param:bytestring):pointer;

procedure modebuf_add_user(setclear,tos:boolean;c:bytechar;uc:tuserchan);
procedure modebuf_add_str(setclear,tos:boolean;c:bytechar;param:bytestring);
procedure modebuf_add_flag(setclear,tos:boolean;c:bytechar);

procedure modebuf_add_flagsdifference(prev,current:integer;tos:boolean);

procedure modebuf_flush;
procedure modebuf_finish(force:boolean);


implementation

uses
  sysutils,bconfig,bcmds,bsend,bstuff,blinklist;

type
  tmodebufentry=class(tlinklist)
    c:bytechar;
    s2:bytestring;
    resend:boolean;
  end;

{$ifndef noresendmode}
const
  resendflag=4;
{$endif}

var
  sptr:tuser;
  ch:tchannel;
  modebufinitlevel:integer;

  {array:
  0=-clear to users,
  1=-clear to servers,
  2=+set to users,
  3=+set to servers}

  modebuflist:array[0..3] of tlinklist;

  toservers:boolean;
  tousers:boolean;
  isopmode:boolean;
  bounce:boolean;

procedure modereset(which:integer);
var
  p:tmodebufentry;
begin
  while modebuflist[which] <> nil do begin
    p := tmodebufentry(modebuflist[which]);
    linklistdel(modebuflist[which],modebuflist[which]);
    p.destroy;
  end;
end;

function modeprefixstr(which:integer):bytestring;
var
  source:tuser;
  tok:bytestring;
begin
  if which and 1 = 0 then begin
    source := sptr;
    if isopmode then source := tuser(sptr.server.us);
    {$ifndef nohis}
    if isserver(source) and (opt.headinsand) then source := me;
    {$endif}
    result := cprefix(source,MSG_MODE)+ch.name+' ';
  end else begin
    if bounce then source := me else source := sptr;

    {$ifndef no21011}
    if isopmode then tok := TOK_OPMODE else
    {$endif}
    tok := TOK_MODE;

    result := sprefix(source,tok)+ch.name+' ';
  end;
end;

procedure modebuf_init;
var
  a:integer;
begin
  if ch <> nil then if (chan <> ch) then begin
    modebuf_finish(true);
  end;
  inc(modebufinitlevel);
  if ch <> nil then exit; {already inited, sub call}
  sptr := source;
  ch := chan;
  for a := 0 to 3 do modereset(a);

  toservers  := ((flags and modebufflag_toservers) <> 0) and not flag_isset(ch.flags,chanflag_local);
  tousers := (flags and modebufflag_tousers) <> 0;
  bounce := (flags and modebufflag_bounce) <> 0;
  isopmode := (flags and modebufflag_opmode) <> 0;
end;

procedure modebuf_send(bufnum:integer;const s:bytestring);
begin
  if bufnum and 1 = 1 then begin
    if bounce then
    sendto_one(sptr,modeprefixstr(bufnum)+s+' '+inttostr(ch.ts))
    else
    sendto_serversbutone(sptr,modeprefixstr(bufnum)+s+' '+inttostr(ch.ts));
  end else begin
    sendto_channel(ch,modeprefixstr(bufnum)+s);
  end;
end;

procedure modebuf_flushinternal(bufnum:integer);
var
  s,s2:bytestring;
  a:integer;

procedure doflush(num:integer;plusmin:bytechar);
var
  p,p2:tmodebufentry;
begin
  p := tmodebufentry(modebuflist[num]);
  if p = nil then exit;
  {get the last entry}
  p2 := nil;
  while p <> nil do begin
    p2 := p;
    p := tmodebufentry(p.next);
  end;
  p := p2;

  s := s + plusmin;
  while p <> nil do begin
    if s = '' then s := plusmin;
    s := s + p.c;
    if p.s2 <> '' then begin
      s2 := s2 + ' '+p.s2;
      inc(a);
    end;
    if a >= maxmodes then begin
      modebuf_send(num,s+s2);
      s := '';
      s2 := '';
      a := 0;
    end;
    p := tmodebufentry(p.prev);
  end;

end;


begin
  s := '';
  s2 := '';
  a := 0;

  doflush(bufnum,'-');
  doflush(bufnum+2,'+');
  if s <> '' then modebuf_send(bufnum,s+s2);
  modereset(bufnum);
  modereset(bufnum+2);
end;

function modebuf_add_internal(bufnum:integer;c:bytechar;param:bytestring):pointer;
var
  t,t2:tmodebufentry;
  b:boolean;
  {$ifndef noresendmode}
  resend:boolean;
  {$endif}
begin
  {$ifndef noresendmode}
  {get resend flag}
  resend := (bufnum and resendflag) <> 0;
  bufnum := bufnum and not resendflag;
  {$endif}

  {find cancelling mode already exists}
  result := nil;
  t := tmodebufentry(modebuflist[bufnum xor 2]);
  while t <> nil do begin
    t2 := tmodebufentry(t.next);
    if t.c = c then begin
      if (t.s2 = param) or (param = '') then begin
        {$ifndef noresendmode}
        if resend then exit;
        {$endif}
        b := t.resend;
        linklistdel(modebuflist[bufnum xor 2],t);
        t.destroy;
        if not b then exit;
      end;
    end;
    t := t2;
  end;

  t := tmodebufentry.create;
  t.c := c;
  t.s2 := param;
  linklistadd(modebuflist[bufnum],tlinklist(t));
  result := t;
end;

{$ifndef noresendmode}
procedure modebuf_add_resend(c:bytechar;uc:tuserchan);
var
  t:tmodebufentry;
begin
  {find same flag already set | +h-o}
  t := tmodebufentry(modebuflist[2]);
  while t <> nil do begin
    if t.c = c then begin
      if (t.s2 = uc.us.name) then exit;
    end;
    t := tmodebufentry(t.next);
  end;

  t := modebuf_add_internal(2 or resendflag,c,uc.us.name);
  if not assigned(t) then exit;
  t.resend := true;
end;
{$endif}

procedure modebuf_add_user(setclear,tos:boolean;c:bytechar;uc:tuserchan);
var
  setclear2:integer;
  a,b:integer;
begin
  if setclear then setclear2 := 2 else setclear2 := 0;
  if tos and toservers then modebuf_add_internal(setclear2+1,c,uc.us.idstr);

  if tousers then modebuf_add_internal(setclear2,c,uc.us.name);

  {$ifndef noresendmode}
  if opt.resendmodes then if (not setclear) then if tousers then begin
    {find table index of this char}
    b := -1;
    for a := 0 to maxuserchanmodetable do if userchanmodetable[a].c = c then begin
      b := a;
      break;
    end;
    if b = -1 then exit;

    {higher flag set}
    for a := maxuserchanmodetable downto b+1 do begin
      if flag_isset(uc.flags,userchanmodetable[a].flag) then exit;
    end;

    {find highest lower flag which is set}
    for a := b-1 downto 0 do begin
      if flag_isset(uc.flags,userchanmodetable[a].flag) then begin
        modebuf_add_resend(userchanmodetable[a].c,uc);
        break;
      end;
    end;
  end;
  {$endif}
end;

procedure modebuf_add_str(setclear,tos:boolean;c:bytechar;param:bytestring);
var
  setclear2:integer;
begin
  if setclear then setclear2 := 2 else setclear2 := 0;
  if tos and toservers then modebuf_add_internal(setclear2+1,c,param);
  if tousers then modebuf_add_internal(setclear2,c,param);
end;

procedure modebuf_add_flag(setclear,tos:boolean;c:bytechar);
var
  setclear2:integer;
begin
  if setclear then setclear2 := 2 else setclear2 := 0;
  if tos and toservers then modebuf_add_internal(setclear2+1,c,'');
  if tousers then modebuf_add_internal(setclear2,c,'');
end;

procedure modebuf_flush;
begin
  modebuf_flushinternal(0);
  modebuf_flushinternal(1);
end;

procedure modebuf_finish;
begin
  if ch = nil then exit;
  dec(modebufinitlevel);
  if (modebufinitlevel <= 0) or force then begin
    modebufinitlevel := 0;
    modebuf_flush;
    ch := nil;
  end;
end;

procedure modebuf_add_flagsdifference(prev,current:integer;tos:boolean);
var
  a:integer;
begin
  for a := 0 to maxchanmodetable do begin
    if (current and chanmodetable[a].flag = 0) and (prev and chanmodetable[a].flag <> 0) then begin
      modebuf_add_flag(false,tos,chanmodetable[a].c);
    end else
    if (current and chanmodetable[a].flag <> 0) and (prev and chanmodetable[a].flag = 0) then begin
      modebuf_add_flag(true,tos,chanmodetable[a].c);
    end;
  end;
end;

initialization begin
  modebufinitlevel := 0;
  ch := nil;
end;

end.
