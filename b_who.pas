(*
 *  beware ircd, Internet Relay Chat server, b_who.pas
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

unit b_who;

interface

uses bstuff,buser,breplies,bcmds,bprivs,pgtypes;

{

}

const
  whoflag_nick=         $1; {nN}
  whoflag_userid=       $2; {uU}
  whoflag_host=         $4; {hH}
  whoflag_ip=           $8; {iI}
  whoflag_server=      $10; {sS}
  whoflag_realname=    $20; {rR}
  whoflag_ircop=      $100; {oO}
  whoflag_hidden=     $200; {Xx}
  {$ifndef novhost}
  whoflag_showrhost=  $400; {yY}
  {$endif}
  whoflag_matchflags= whoflag_nick or whoflag_userid or whoflag_host or whoflag_ip or whoflag_server or whoflag_realname;
  whoflag_default= whoflag_nick or whoflag_userid or whoflag_realname or whoflag_host;

  whoflag_whox=       $1000; {WHOX mode}
  whoxflag_channel=   $2000; {c}
  whoxflag_hops=      $4000; {d}
  whoxflag_flags=     $8000; {f}
  whoxflag_host=     $10000; {h}
  whoxflag_ip=       $20000; {i}
  whoxflag_idle=     $40000; {l}
  whoxflag_nick=     $80000; {n}
  whoxflag_realname=$100000; {r}
  whoxflag_server=  $200000; {s}
  whoxflag_query=   $400000; {t}
  whoxflag_user=    $800000; {u}
  whoxflag_account=$1000000; {a}

procedure m_who(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bchannel,bconfig,bsend,bpremaskmatch,btime,unitbanmask,binipstuff,bsock;

type
  Twhomarked=array[0..512] of Tuser;

var
  showcount:integer;
  premask:tpremask;
  whomax:integer;
  whoquerytype:bytestring;
  whobm:tbanmask;

procedure whomark(us:tuser);
begin
  setflag(us.flags,userflag_whomarked);
end;

function iswhomarked(us:tuser):boolean;
begin
  result := flag_isset(us.flags,userflag_whomarked);
end;

procedure whoshowuser(sptr,us:tuser;ch:tchannel;params1:bytestring;flags:integer;visible:boolean);
label shortcut;
var
  showi:boolean;
  s3:bytestring;
  uc,p:tuserchan;
  bm:tbanmask;
  a:integer;
begin
  if not isclient(us) then exit;
  if iswhomarked(us) then exit;
  whomark(us);

  {only want to see ircops, this isnt an ircop}
  if (flags and whoflag_ircop) <> 0 then if not seeoper(sptr,us) then exit;
  {"visible" means i can always see this user (common channels)}
  showi := visible or flag_isset(flags,whoflag_hidden);
  if sptr = us then showi := true;
  if strcompup(params1,us.name) then showi := true;
  if (us.modeflag and usermode_invisible <> 0) and not showi then exit;

  if params1 = '*' then goto shortcut;

  if (flags and whoflag_nick) <> 0 then
  if premaskmatchup(@premask,us.name) then
  if maskmatchup(params1,us.name) then goto shortcut;

  if (flags and whoflag_userid) <> 0 then
  if premaskmatchup(@premask,showuserid(us)) then
  if maskmatchup(params1,showuserid(us)) then goto shortcut;

  if (flags and whoflag_host) <> 0 then begin
    if premaskmatchup(@premask,showhost(us)) then
    if maskmatchup(params1,showhost(us)) then goto shortcut;
    {$ifndef novhost}
    if isanoper(sptr) then if flag_isset(us.flags,userflag_hasvhost) then begin
      if premaskmatchup(@premask,us.host) then
      if maskmatchup(params1,us.host) then goto shortcut;
    end;
    {$endif}
  end;

  if (flags and whoflag_ip) <> 0 then begin
    if ((us = sptr) or isanoper(sptr)) or
    (not (opt.secretuserip or flag_isset(us.flags,userflag_hasvhost)))
    then begin
      banmaskmake_oneuser(@bm,'','',us.binip);
      if banpremaskmatch(@premask,@whobm,@bm,params1,ircipbintostr(us.binip)) then goto shortcut;
    end;
  end;

  if (flags and whoflag_realname) <> 0 then
  if premaskmatchup(@premask,us.fullname) then
  if maskmatchup(params1,us.fullname) then goto shortcut;

  if (flags and whoflag_server) <> 0 then
  if premaskmatchup(@premask,tuser(us.server.us).name) then
  if maskmatchup(params1,tuser(us.server.us).name) then goto shortcut;

  exit;
shortcut:
  {if ch = nil then if not visible then if canseeuser(sptr,us) then exit;}
  if flag_isset(us.flags,userflag_whomarkshow) then exit;
  setflag(us.flags,userflag_whomarkshow);
  {get channel and userchan to show in reply}
  if ch <> nil then begin
    uc := getuserchan(us,ch);
  end else begin
    {if we get here, user is not in common channels. skip +s +p}
    uc := nil;
    if not isservice(us) then begin
      p := tuserchan(us.channel);
      while p <> nil do begin
        if (p.ch.modeflag and (chanmode_secret or chanmode_private) = 0) and not flag_isset(p.ch.flags,chanflag_local) then begin
          uc := p;
          break;
        end;
        p := tuserchan(p.next);
      end;
    end
  end;

  if flag_isset(flags,whoflag_whox) then
  s3 := cprefix(me,'354')
  else
  s3 := cprefix(me,'352');

  s3 := s3 + sptr.name+' ';

  if flag_isset(flags,whoxflag_query) then s3 := s3 + whoquerytype+' ';

  if flag_isset(flags,whoxflag_channel) then begin
    if uc <> nil then s3 := s3 + uc.ch.name else s3 := s3 + '*';
    s3 := s3 + ' ';
  end;

  if flag_isset(flags,whoxflag_user) then s3 := s3 + showuserid(us)+' ';

  if flag_isset(flags,whoxflag_ip) then begin
    if ((us = sptr) or isanoper(sptr)) or
    (not (opt.secretuserip or flag_isset(us.flags,userflag_hasvhost)))
    then s3 := s3 + ircipbintostr(us.binip)
    else s3 := s3 + fakeipstr;

    s3 := s3 + ' ';
  end;

  if flag_isset(flags,whoxflag_host) then begin
    {$ifndef novhost}
    if flag_isset(flags,whoflag_showrhost) then
    s3 := s3 + us.host+' '
    else
    {$endif}
    s3 := s3 + showhost(us)+' ';
  end;

  if flag_isset(flags,whoxflag_server) then begin
    {$ifndef nohis}
    if opt.headinsand and (us <> sptr) and (not hasprivs(sptr,privs_his)) then s3 := s3 + opt.headinsandname+' '
    else
    {$endif}
    s3 := s3 + tuser(us.server.us).name+' ';
  end;

  if flag_isset(flags,whoxflag_nick) then s3 := s3 + us.name+' ';

  if flag_isset(flags,whoxflag_flags) then begin
    if us.away <> '' then s3 := s3 + 'G' else s3 := s3 + 'H';
    if seeoper(sptr,us) then s3 := s3 + '*';
    if uc <> nil then begin
      for a := maxuserchanmodetable downto 0 do if flag_isset(uc.flags,userchanmodetable[a].flag) then begin
        s3 := s3 + userchanmodetable[a].prefix;
        break;
      end;
    end;
    if flag_isset(us.modeflag,usermode_deaf) then s3 := s3 + 'd';
    if isanoper(sptr) then begin
      if flag_isset(us.modeflag,usermode_invisible) then s3 := s3 + 'i';
      if flag_isset(us.modeflag,usermode_wallops) then s3 := s3 + 'w';
      if flag_isset(us.modeflag,usermode_notices) then s3 := s3 + 's';
      if flag_isset(us.modeflag,usermode_debug) then s3 := s3 + 'g';
    end;
    if flag_isset(us.flags,userflag_hasvhost) then s3 := s3 + 'x';
    s3 := s3 + ' ';
  end;

  if not flag_isset(flags,whoflag_whox) then s3 := s3 + ':';

  if flag_isset(flags,whoxflag_hops) then begin
    {$ifndef nohis}
    if opt.headinsand and (us <> sptr) and (not hasprivs(sptr,privs_his)) then s3 := s3 + '3'
    else
    {$endif}
    s3 := s3 + inttostr(us.hops);
    s3 := s3 + ' ';
  end;

  if flag_isset(flags,whoxflag_idle) then begin
    if myconnect(us)
    {$ifndef nohis}and ((not opt.headinsand) or (sptr = us) or hasprivs(sptr,privs_his)){$endif}
    then s3 := s3 + inttostr(irctime-us.idletime) else s3 := s3 + '0';
    s3 := s3 + ' ';
  end;

  if flag_isset(flags,whoxflag_account) then begin
    if us.account <> '' then s3 := s3 + us.account else s3 := s3 + '0';
    s3 := s3 + ' ';
  end;

  if flag_isset(flags,whoxflag_realname) then begin
    if flag_isset(flags,whoflag_whox) then s3 := s3 + ':';
    s3 := s3 + us.fullname;
  end;

  sendto_one(sptr,s3);

  inc(showcount);
end;


procedure whoshowchannel(sptr:tuser;ch:tchannel;params1:bytestring;flags:integer);
var
  isinchannel:boolean;
  uc:tuserchan;
begin
  isinchannel := isonchannel(sptr,ch);
  if isinchannel then begin
    uc := tuserchan(ch.user);
    while uc <> nil do begin
      whoshowuser(sptr,uc.us,ch,params1,flags,true);
      if showcount > whomax then exit;
      uc := tuserchan(uc.next2);
    end;
  end else begin
    if (ch.modeflag and (chanmode_secret or chanmode_private) = 0) or (flag_isset(flags,whoflag_hidden)) then begin
      uc := tuserchan(ch.user);
      while uc <> nil do begin
        whoshowuser(sptr,uc.us,ch,params1,flags,false);
        if showcount > whomax then exit;
        uc := tuserchan(uc.next2);
      end;
    end;
  end;
end;

procedure whoshowcommonchannels(sptr:tuser;params1:bytestring;flags:integer);
var
  uc:tuserchan;
begin
  uc := tuserchan(sptr.channel);
  while uc <> nil do begin
    whoshowchannel(sptr,uc.ch,params1,flags);
    if showcount > whomax then exit;
    uc := tuserchan(uc.next);
  end;
end;

procedure m_who(cptr,sptr:tuser;parc:integer;parv:pparams);
label eind;
const
  limiterinitial=10;
var
  s,searchmask,searchmask2:bytestring;
  s1,s2:bytestring;
  a,b,flags,whoxflags:integer;
  us:tuser;
  ch:tchannel;
  limiter:integer;
begin
  if (parc < 2) or (parv[1] = '') then begin
    searchmask := '';
  end else begin
    searchmask := parv[1];
    if parc = 4 then searchmask := parv[3]
    else searchmask := parv[1];
  end;

  if parc > 2 then begin
    a := pos('%',parv[2]);
    if a > 0 then begin
      s1 := copy(parv[2],1,a-1);
      s2 := copy(parv[2],a+1,length(parv[2]));
    end else begin
      s1 := parv[2];
      s2 := '';
    end;
  end else begin
    s1 := '';
    s2 := '';
  end;

  a := pos(',',s2);
  whoquerytype := '';
  if a > 0 then begin
    s := copy(s2,a+1,3);
    for b := 1 to length(s) do if (s[b] in ['0'..'9']) then whoquerytype := whoquerytype + s[b];
    s2 := copy(s2,1,a-1);
  end;
  if whoquerytype = '' then whoquerytype := '0';

  flags := 0;

  if s1 <> '' then begin
    s1 := ircupper(s1);
    if (pos('O',s1) <> 0) then setflag(flags,whoflag_ircop);
    if (pos('X',s1) <> 0) then setflag(flags,whoflag_hidden);
    {$ifndef novhost}
    if (pos('Y',s1) <> 0) then setflag(flags,whoflag_showrhost);
    {$endif}

    if (pos('N',s1) <> 0) then setflag(flags,whoflag_nick);
    if (pos('R',s1) <> 0) then setflag(flags,whoflag_realname);
    if (pos('U',s1) <> 0) then setflag(flags,whoflag_userid);
    if (pos('I',s1) <> 0) then setflag(flags,whoflag_ip);
    if (pos('H',s1) <> 0) then setflag(flags,whoflag_host);
    if (pos('S',s1) <> 0) then setflag(flags,whoflag_server);
  end;

  {$ifndef nohis}
  {head in sand: no "s" flag for users}
  if opt.headinsand then if not hasprivs(sptr,privs_his) then clearflag(flags,whoflag_server);
  {$endif}
  if not isanoper(sptr) then clearflag(flags,whoflag_hidden);
  {$ifndef novhost}
  if not isanoper(sptr) then clearflag(flags,whoflag_showrhost);
  {$endif}

  if flags and whoflag_matchflags = 0 then begin
    {no match flags have been set, set default flags}
    flags := flags or whoflag_default;
  end;

  if (searchmask = '') or (searchmask = '0') then searchmask := '*';

  whoxflags := 0;
  if s2 <> '' then begin
    s2 := ircupper(s2);
    if pos('A',s2) <> 0 then setflag(whoxflags,whoxflag_account);
    if pos('C',s2) <> 0 then setflag(whoxflags,whoxflag_channel);
    if pos('D',s2) <> 0 then setflag(whoxflags,whoxflag_hops);
    if pos('F',s2) <> 0 then setflag(whoxflags,whoxflag_flags);
    if pos('H',s2) <> 0 then setflag(whoxflags,whoxflag_host);
    if pos('I',s2) <> 0 then setflag(whoxflags,whoxflag_ip);
    if pos('L',s2) <> 0 then setflag(whoxflags,whoxflag_idle);
    if pos('N',s2) <> 0 then setflag(whoxflags,whoxflag_nick);
    if pos('R',s2) <> 0 then setflag(whoxflags,whoxflag_realname);
    if pos('S',s2) <> 0 then setflag(whoxflags,whoxflag_server);
    if pos('T',s2) <> 0 then setflag(whoxflags,whoxflag_query);
    if pos('U',s2) <> 0 then setflag(whoxflags,whoxflag_user);
  end;
  if whoxflags <> 0 then begin
    setflag(flags,whoflag_whox);
    whomax := 4;
    for a := 0 to 31 do if whoxflags and (1 shl a) <> 0 then inc(whomax);
    whomax := 2048 div whomax;
  end else begin
    {set default whox flags}
    whoxflags := whoxflag_channel or whoxflag_user or whoxflag_host or
    whoxflag_server or whoxflag_nick or whoxflag_flags or whoxflag_hops or
    whoxflag_realname;
    whomax := 200;
  end;

  {one channel: no limit}
  ch := findchan(searchmask);
  if ch <> nil then whomax := ch.usercount;
  if whomax < 1 then whomax := 1;

  flags := flags or whoxflags;

  if isanoper(sptr) then if opt.opernowholimit then whomax := maxlongint;

  showcount := 0;

  searchmask2 := searchmask;
  limiter := limiterinitial;
  a := 1;
  repeat
    strtok2(searchmask2,',',a,searchmask);
    if searchmask = '' then goto eind;
    premaskmake(@premask,ircupper(searchmask));
    banmaskmake(@whobm,searchmask);

    ch := findchan(searchmask);
    if ch <> nil then begin
      whoshowchannel(sptr,ch,'*',flags);

    end else begin
      if limiter < limiterinitial then begin
        us := tuser(globaluserlist);
        while us <> nil do begin
          clearflag(us.flags,userflag_whomarked);
          us := tuser(us.next);
        end;
      end;
      dec(limiter);
      if limiter <= 0 then goto eind;
      {show common channels}
      whoshowcommonchannels(sptr,ircupper(searchmask),flags);
      if showcount > whomax then goto eind;
      s := ircupper(searchmask);
      us := tuser(globaluserlist);
      while us <> nil do begin
        whoshowuser(sptr,us,nil,s,flags,false);
        if showcount > whomax then goto eind;
        us := tuser(us.next);
      end;
    end;
  until false;

eind:
  if searchmask2 = '' then searchmask2 := '*';
  sendreply(sptr,RPL_ENDOFWHO,searchmask2+' '+getrpl0(RPL_ENDOFWHO));

  if showcount > whomax then
  sendreply(sptr,ERR_QUERYTOOLONG,MSG_WHO+' '+getrpl0(ERR_QUERYTOOLONG));

  {clear who marked}

  us := tuser(globaluserlist);
  while us <> nil do begin
    clearflag(us.flags,userflag_whomarked or userflag_whomarkshow);
    us := tuser(us.next);
  end;
end;


end.
