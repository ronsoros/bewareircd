(*
 *  beware ircd, Internet Relay Chat server, b_whois.pas
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

unit b_whois;

interface

uses buser,bchannel,bcmds,bstuff;

procedure m_whois(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,bconfig,breplies,bserver,bparse,blinklist,btime,bpremaskmatch,bsock,
  bprivs,bconsts,binipstuff,pgtypes;

var
  done:boolean;

procedure dowhois(sptr,us:tuser;remoteparam:boolean);
var
  s,s2,headerstr:bytestring;
  p:tlinklist;
  ch:tchannel;
  a,b,headerlen,count:integer;
  bool:boolean;
begin
  done := true;
  sendreply(sptr,RPl_WHOISUSER,us.name+' '+showuserid(us)+' '+showhost(us)+' * :'+us.fullname);

  if not isservice(us) then begin
    p := us.channel;

    if isserver(sptr.from) then
    headerstr := sprefix(me,cmdstr(RPl_WHOISCHANNELS))+sptr.idstr
    else
    headerstr := cprefix(me,cmdstr(RPl_WHOISCHANNELS))+sptr.name;
    headerstr := headerstr + ' '+us.name+' :';

    {":sendername 123 targetname nick :" ":-123---:" }
    {"sendernum 123 targetnum nick :" "-123---:"}
    headerlen := 9+length(me.name)+length(sptr.name)+length(us.name);
    if length(headerstr) > headerlen then headerlen := length(headerstr);



    s := headerstr;
    count := headerlen;
    bool := true;
    while p <> nil do begin
      ch := tuserchan(p).ch;

      {$ifndef nohis}
      if (ch.name[1] <> '&') or ((not opt.headinsand) or hasprivs(sptr,privs_his) or (sptr = us)) or remoteparam then
      {$endif}
      if canseechannel(sptr,ch) then begin
        s2 := '';
        if flag_isset(us.modeflag,usermode_deaf) then s2 := s2 + '-';
        a := tuserchan(p).flags;
        for b := maxuserchanmodetable downto 0 do if flag_isset(a,userchanmodetable[b].flag) then begin
          s2 := s2 + userchanmodetable[b].prefix;
          break;
        end;
        {$ifndef nodelayed}
        if flag_isset(a,userchanflag_delayed) then s2 := s2 + '<';
        {$endif}

        s2 := s2 + ch.name;
        a := length(s2);
        if count+a > (maxmessagelength-1) then begin {"-1" for the space}
          sendto_one(sptr,s);
          s := headerstr;
          count := headerlen;
          bool := true;
        end;
        if bool then bool := false else begin
          s := s + ' ';
          inc(count);
        end;
        s := s + s2;
        inc(count,a);
      end;
      p := p.next;
    end;
    if not bool then sendto_one(sptr,s);
  end;
  {$ifndef nohis}
  if opt.headinsand and not hasprivs(sptr,privs_his) and (sptr <> us) then
  sendreply(sptr,RPl_WHOISSERVER,us.name+' '+opt.headinsandname+' :'+opt.headinsandinfo)
  else
  {$endif}
  sendreply(sptr,RPl_WHOISSERVER,us.name+' '+tuser(us.server.us).name+' :'+tuser(us.server.us).fullname);


  if us.away <> '' then
  {$ifndef nohis}
  if ((not opt.headinsand) or hasprivs(sptr,privs_his) or (sptr = us)) or
  (remoteparam) then
  {$endif}
  sendreply(sptr,RPl_AWAY,us.name+' :'+us.away);


  if seeoper(sptr,us) then
  sendreply(sptr,RPl_WHOISOPERATOR,us.name+' '+getrpl0(RPL_WHOISOPERATOR));

  {$ifndef no21011}
  if us.account <> '' then begin
    sendreply(sptr,RPl_WHOISACCOUNT,us.name+' '+us.account+' '+getrpl0(RPl_WHOISACCOUNT));
  end;
  {$endif}

  {$ifndef novhost}
  if flag_isset(us.flags,userflag_hasvhost) then
  if (us = sptr) or (isanoper(sptr)) then
  sendreply(sptr,RPL_WHOISACTUALLY,us.name+' '+us.userid+'@'+us.host+' '+ircipbintostr(us.binip)+' '+getrpl0(RPL_WHOISACTUALLY));
  {$endif}

  {$ifdef bdebug}
  if isprivileged(sptr) then sendreply(sptr,RPL_NONE,us.name+' '+us.idstr+' '+tuser(us.server.us).idstr+' :numeric');
  {$endif}

  if myconnect(us)
  {$ifndef nohis}and ((not opt.headinsand) or remoteparam or (sptr = us) or hasprivs(sptr,privs_his)){$endif}
  then begin
    a := irctime-us.idletime;
    sendreply(sptr,RPl_WHOISIDLE,us.name+' '+inttostr(a)+' '+inttostr(us.signontime)+' '+getrpl0(RPL_WHOISIDLE));
  end;
end;

procedure m_whois(cptr,sptr:tuser;parc:integer;parv:pparams);
const maxwhois=50;
var
  us:tuser;
  remotestr,searchstr:bytestring;
  srv:tuser;
  a,wildcount:integer;

  s:bytestring;
  count:integer;
  remoteparam:boolean;

  premask:tpremask;
  {$ifndef nohis}
  restricted:boolean;
  {$endif}
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;

  {$ifndef nohis}
  restricted := opt.headinsand and (not hasprivs(cptr,privs_his));
  {$endif}
  remoteparam := (parc > 2) and (parv[2] <> '');

  if remoteparam then begin
    searchstr := parv[2];
    {$ifndef nohis}
    if restricted then
    remotestr := parv[2]
    else
    {$endif}
    remotestr := parv[1];
  end else begin
    searchstr := parv[1];
    remotestr := '';
  end;

  srv := getremoteserver(remotestr,not isserver(cptr));

  {$ifndef nohis}
  if restricted then if findnick(searchstr) = nil then begin
    {if searchstr (which is both requested user, and remote server)
    is not an existing nick, always process as local whois
    should prevent all possible tricks}
    srv := me;
    remoteparam := false;
  end;
  {$endif}

  {prevent a user from sending comma separated or wild whois to remote server, always. for bandwidth.}
  if not isprivileged(cptr) then if srv <> me then begin
    if (pos('*',searchstr) <> 0) or (pos('?',searchstr) <> 0) or (pos(',',searchstr) <> 0) then srv := me;
  end;

  if srv = nil then begin
    {for convienience, opers can do "/whois 0 nick" for remote whois}
    srv := findnick(searchstr);
    if assigned(srv) then srv := tuser(srv.server.us);
  end;
  if srv = nil then begin
    sendnosuchserver(sptr,remotestr);
    exit;
  end;
  if srv <> me then begin
    sendmsgto_one(sptr,srv,cmdwhois,searchstr);
    exit;
  end;

  wildcount := 3; {prevent one from using excessive CPU by limiting the number of params which can be wild}

  a := 1;
  count := 0;
  repeat
    strtok2(searchstr,',',a,s);
    if s = '' then break;
    done := false;

    us := findname(s);
    if us <> nil then begin
      if isclient(us) then begin
        dowhois(sptr,us,remoteparam);
        inc(count);
      end;
    end else begin
      if (pos('*',s) <> 0) or (pos('?',s) <> 0) then begin
        if wildcount <= 0 then break;
        dec(wildcount);
        {wildcard search}
        premaskmake(@premask,ircupper(s));
        us := tuser(globaluserlist);
        while us <> nil do begin
          if canseeuser(sptr,us) then
          if premaskmatchup(@premask,us.name) then
          if maskmatchup(s,us.name) then

          if isclient(us) then begin
            dowhois(sptr,us,remoteparam);
            inc(count);
          end;
          us := tuser(us.next);
          if count > maxwhois then break;
        end;
      end;
    end;
    if not done then sendreply(sptr,ERR_NOSUCHNICK,s+' '+getrpl0(ERR_NOSUCHNICK));
    if count > maxwhois then break;
  until false;

  sendreply(sptr,RPL_ENDOFWHOIS,searchstr+' '+getrpl0(RPL_ENDOFWHOIS));

  if count > maxwhois then sendreply(sptr,ERR_QUERYTOOLONG,'WHOIS '+getrpl0(ERR_QUERYTOOLONG));
  {always an end-of-whois, but not if nosuchserver}
end;

end.
