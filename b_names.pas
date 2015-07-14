(*
 *  beware ircd, Internet Relay Chat server, b_names.pas
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

unit b_names;

interface

uses bstuff,buser,breplies,bcmds,bchannel,pgtypes;

procedure m_names(cptr,sptr:tuser;parc:integer;parv:pparams);
function nameschannel(us:tuser;ch:tchannel;mode:integer):boolean;

implementation

uses
  bsock,bconfig,bsend,bconsts,bprivs,bserver;

var
  allchannels:boolean=false;

{
mode:

0 = default (hide invisible)
1 = show only invisible, -D numeric (asuka)
2 = show all, normal numeric

}

function nameschannel(us:tuser;ch:tchannel;mode:integer):boolean;
var
  a:integer;
  headerlen,count:integer;
  headerstr:bytestring;
  ison:boolean;
  uc:tuserchan;
  s,s2,s3:bytestring;
  bool:boolean;

{$ifndef nodelayed}
function showmembership(uc:tuserchan):boolean;
begin
  if mode = 2 then begin
    result := true;
    exit;
  end;
  result := (not flag_isset(uc.flags,userchanflag_delayed)) or (uc.us = us);
  if mode = 1 then result := not result;
end;
{$endif}

begin
  result := false;
  if ch = nil then exit;
  ison := isonchannel(us,ch);
  if (ch.modeflag and (chanmode_secret or chanmode_private) <> 0) then
    if not ison then exit;

  {$ifndef nodelayed}
  if mode = 1 then s := '355' else
  {$endif}
  s := cmdstr(RPl_NAMREPLY);

  if issecret(ch) then s2 := '@'
  else if isprivate(ch) then s2 := '*'
  else s2 := '=';

  if isserver(us.from) then
  headerstr := sprefix(me,s)+us.idstr
  else
  headerstr := cprefix(me,s)+us.name;
  headerstr := headerstr +' '+s2+' '+ch.name+' :';

  {":sender.name 123 targetname = #channel :"  ":-123--=--:"}
  headerlen := 11+length(me.name)+length(us.name)+length(ch.name);
  if length(headerstr) > headerlen then headerlen := length(headerstr);

  s := headerstr;
  count := headerlen;

  uc := tuserchan(ch.user);
  bool := true;
  while uc <> nil do begin
    if ison or (uc.us.modeflag and usermode_invisible = 0) then
    {$ifndef nodelayed}
    if showmembership(uc) then
    {$endif}
    begin
      s3 := '';
      for a := maxuserchanmodetable downto 0 do if flag_isset(uc.flags,userchanmodetable[a].flag) then begin
        s3 := s3 + userchanmodetable[a].prefix;
        break;
      end;
      s3 := s3 + uc.us.name;

      if count+length(s3) > (maxmessagelength-1) then begin {@nick, space}
        sendto_one(us.from,s);
        s := headerstr;
        count := headerlen;
        bool := true;
      end;
      if bool then bool := false else begin
        s := s + ' ';
        inc(count)
      end;
      s := s + s3;
      inc(count,length(s3));
    end;
    if allchannels then setflag(uc.us.flags,userflag_whomarked);
    uc := tuserchan(uc.next2);
  end;
  sendto_one(us.from,s);
  result := true;
  if not allchannels then sendreply(us,RPL_ENDOFNAMES,ch.name+' '+getrpl0(RPL_ENDOFNAMES));
end;

procedure namesnullchannel(us:tuser);
var
  us2:tuser;
  s:bytestring;
  bool:boolean;
begin
  s := cprefix(me,cmdstr(RPl_NAMREPLY))+us.name+' = * :';
  us2 := tuser(globaluserlist);
  bool := true;
  while us2 <> nil do begin
    if (us2.modeflag and usermode_invisible = 0) then
    if (not flag_isset(us2.flags,userflag_whomarked)) and isclient(us2) then begin
      if length(s)+length(us2.name) > (maxmessagelength-1) then begin {@nick, space}
        sendto_one(us.from,s);
        s := cprefix(me,cmdstr(RPl_NAMREPLY))+us.name+' = * :';
        bool := true;
      end;
      if bool then bool := false else s := s + ' ';
      s := s + us2.name;

    end;
    clearflag(us2.flags,userflag_whomarked);
    us2 := tuser(us2.next);
  end;
  if not bool then sendto_one(us.from,s);
  sendreply(us,RPL_ENDOFNAMES,'* '+getrpl0(RPL_ENDOFNAMES));
end;

procedure m_names(cptr,sptr:tuser;parc:integer;parv:pparams);
label eind;
var
  ch:tchannel;
  us:tuser;
  a,mode:integer;
  srv:tuser;
  extraparam:bytestring;
  chanparam:bytestring;
  serverparam:bytestring;
  s,s2:bytestring;
begin
  extraparam := '';
  chanparam := '';
  serverparam := '';
  if (parc > 1) then if (parv[1] <> '') then begin
    if parv[1,1] = '-' then begin
      extraparam := parv[1];
      a := 2;
    end else a := 1;
    if (parc > a) then if (parv[a] <> '') then begin
      chanparam := parv[a];
    end;
    inc(a);
    if (parc > a) then if (parv[a] <> '') then begin
      serverparam := parv[a];

      if not isprivileged(cptr) then begin
        {protect remote names because it can generate a lot of traffic}
        sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
        exit;
      end;

      srv := getremoteserver(parv[a],not isserver(cptr));
      if srv = nil then begin
        sendnosuchserver(sptr,parv[a]);
        exit;
      end;
      if srv <> me then begin
        s := extraparam;
        if s <> '' then s := s + ' ';
        s := s + chanparam;
        sendto_one(srv,sprefix(sptr,TOK_NAMES)+s+' '+srv.idstr);
        exit;
      end;
    end;
  end;

  mode := 0;
  {$ifndef nodelayed}
  extraparam := ircupper(extraparam);
  if extraparam = '-D' then mode := 1
  else if extraparam = '-D2' then mode := 2;
  {$endif}

  if chanparam = '' then chanparam := '*';

  if chanparam = '0' then begin
    if isserver(cptr) then exit; {no remote /names 0}
    allchannels := true;
    ch := tchannel(globalchanlist);
    while ch <> nil do begin
      nameschannel(sptr,ch,mode);
      if connectionlist[cptr.socknum].sendqexceeded then begin
        {must unset the whomarked flags which were set}
        us := tuser(globaluserlist);
        while assigned(us) do begin
          clearflag(us.flags,userflag_whomarked);
          us := tuser(us.next);
        end;
        exit;
      end;
      ch := tchannel(ch.next);
    end;
    namesnullchannel(sptr);
    allchannels := false;
  end else begin
    a := 1;
    s := chanparam;
    repeat
      strtok2(s,',',a,s2);
      if s2 = '' then break;
      ch := findchan(s2);
      if not nameschannel(sptr,ch,mode)
      then
      sendreply(sptr,RPL_ENDOFNAMES,s2+' '+getrpl0(RPL_ENDOFNAMES));
    until false;
  end;

eind:
end;


end.
