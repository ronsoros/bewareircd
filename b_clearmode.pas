(*
 *  beware ircd, Internet Relay Chat server, b_clearmode.pas
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

unit b_clearmode;

interface

uses buser,bstuff,bchannel,bconsts,pgtypes;

procedure m_clearmode(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,breplies,bcmds,blinklist,bconfig,bparse,b_mode,bprivs,bmodebuf;

procedure m_clearmode(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
  ch:tchannel;
  a:integer;

procedure checkflag(chr:bytechar;i:integer);
begin
  if pos(chr,s) <> 0 then if flag_isset(ch.modeflag,i) then begin
    modebuf_add_flag(false,false,chr);
    ch.modeflag := ch.modeflag and not i;
  end;
end;

procedure checkuserchanflag(chr:bytechar;i:integer);
var
  uc:tuserchan;
begin
  if pos(chr,s) = 0 then exit;
  uc := tuserchan(ch.user);
  while uc <> nil do begin
    if flag_isset(uc.flags,i) then begin
      modebuf_add_user(false,false,chr,uc);
      uc.flags := uc.flags and not i;
    end;
    uc := tuserchan(uc.next2);
  end;
end;

procedure checkbanlist(chr:bytechar;var list:tban);
var
  b:tban;
begin
  if pos(chr,s) = 0 then exit;
  while list <> nil do begin
    b := list;
    modebuf_add_str(false,false,chr,b.mask);
    linklistdel(tlinklist(list),b);
    b.destroy;
  end;
end;

begin
  if isclient(cptr) then if not opt.clearmode then begin
    sendreply(sptr,ERR_DISABLED,MSG_CLEARMODE+' '+getrpl0(ERR_DISABLED));
    exit;
  end;

  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;

  ch := findchan(parv[1]);
  if ch = nil then begin
    sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;
  {$ifndef nomodeless}
  if flag_isset(ch.flags,chanflag_modeless) then begin
    sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;
  {$endif}
  if isserver(cptr) then if flag_isset(ch.flags,chanflag_local) then exit;

  {if it's a local operator, can only change modes of a &channel}
  if not ((flag_isset(ch.flags,chanflag_local) and isanoper(sptr))
  or hasprivs(sptr,privs_globalmode)) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit
  end;

  if (parc < 3) or (parv[2] = '') then begin
    s := chanmodesupported; {string which contains all possible channel modes}
  end else begin
    s := parv[2];
  end;

  modebuf_init(tuser(sptr.server.us),ch,modebufflag_tousers);

  for a := 0 to maxchanmodetable do checkflag(chanmodetable[a].c,chanmodetable[a].flag);

  {$ifndef nodelayed}
  modedupdate(ch,true);
  {$endif}

  {clear ops/voice}
  for a := 0 to maxuserchanmodetable do checkuserchanflag(userchanmodetable[a].c,userchanmodetable[a].flag);

  {clear bans}
  if pos('b',s) <> 0 then begin
    checkbanlist('b',ch.banlist);
    clearbancache(ch);
    ch.bancount := 0;
  end;

  {clear key, limit}
  if pos('k',s) <> 0 then if ch.key <> '' then begin
    modebuf_add_str(false,false,'k',ch.key);
    ch.key := '';
  end;

  if pos('l',s) <> 0 then if ch.limit <> 0 then begin
    modebuf_add_flag(false,false,'l');
    ch.limit := 0;
  end;

  locnotice(SNO_HACK4,'HACK(4): '+hacknoticemodestring(parc,parv,MSG_CLEARMODE));

  modebuf_finish(false);

  if not flag_isset(ch.flags,chanflag_local) then sendto_serversbutone(cptr,sprefix(sptr,TOK_CLEARMODE)+ch.name+' '+s);
end;


end.
