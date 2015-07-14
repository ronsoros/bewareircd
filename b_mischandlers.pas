(*
 *  beware ircd, Internet Relay Chat server, b_mischandlers.pas
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

unit b_mischandlers;

{
basic commands with little code, may be put in separate units later

i dont necessarily put one command in a unit,
i want to keep the number of units controllable
--beware

}

interface

uses bcmds,buser,bstuff,bconsts,pgtypes;

procedure m_lusers(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_pass(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_alreadyregistered(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_user(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_end_of_burst(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_eob_ack(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_rehash(cptr,sptr:tuser;parc:integer;parv:pparams);

procedure m_ison(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_userhost(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_userip(cptr,sptr:tuser;parc:integer;parv:pparams);

{requests which can have server parameter}
procedure m_time(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_admin(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_version(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,bconfig,breplies,bserver,blinklist,bwelcome,bchannel,bparse,btime,
bmodebuf,bprivs,binipstuff,bsock;

procedure m_lusers(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  srv:tuser;
{lusers servermask remoteserver}
begin
  if (parc >= 3) and (parv[2] <> '') then begin
    {$ifndef nohis}
    if opt.headinsand and not hasprivs(cptr,privs_his) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    {$endif}
    srv := getremoteserver(parv[2],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[2]);
      exit;
    end;
    if srv <> me then begin
      sendto_one(srv,sprefix(sptr,TOK_LUSERS)+parv[1]+' '+srv.idstr);
      exit;
    end;
  end;


  sendreply(sptr,RPL_LUSERCLIENT,
  getrpl3(RPL_LUSERCLIENT,
  inttostr(count.globalclients-count.invisible),
  inttostr(count.invisible),
  inttostr(count.globalservers)
  ));

  if count.unknown > 0 then
  sendreply(sptr,RPL_LUSERUNKNOWN,inttostr(count.unknown)+' '+
  getrpl0(RPL_LUSERUNKNOWN));

  if count.oper > 0 then
  sendreply(sptr,RPL_LUSEROP,inttostr(count.oper)+' '+
  getrpl0(RPL_LUSEROP));

  if count.channels > 0 then
  sendreply(sptr,RPL_LUSERCHANNELS,inttostr(count.channels)+' '+
  getrpl0(RPL_LUSERCHANNELS));

  sendreply(sptr,RPL_LUSERME,
  getrpl2(RPL_LUSERME,
  inttostr(count.localclients),
  inttostr(count.localservers)
  ));

  if opt.irculusers then begin
    sendreply(sptr,cmdnotice,getrpl2(RPL_STATSCONN,inttostr(count.highestconnections),inttostr(count.highestlocalclients)))
  end else begin
    sendreply(sptr,1265,getrpl2(1265,inttostr(count.localclients),inttostr(count.highestlocalclients)));
    sendreply(sptr,1266,getrpl2(1266,inttostr(count.globalclients),inttostr(count.highestglobalclients)));
  end;
end;


procedure m_pass(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  cptr.password := parv[1];
end;

procedure m_alreadyregistered(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  sendreply(cptr,ERR_ALREADYREGISTRED,getrpl0(ERR_ALREADYREGISTRED));
end;

procedure m_user(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a:integer;
begin
  if checkneedmoreparams(cptr,cmdnum,4,parc,parv) then exit;

  if (flag_isset(cptr.flags,userlog_user)) then exit;
  if cptr.userid = '' then begin
    a := pos('@',parv[1]);
    if a > 0 then parv[1] := copy(parv[1],1,a-1);
    if parv[1] = '' then begin
      cptr.error := 'USER: Bogus userid.';
      cptr.destroy;
    end;
    cptr.userid := parv[1];
  end;
  cptr.fullname := copy(parv[parc-1],1,maxgcoslength);
  setflag(cptr.flags,userlog_user);
  welcome(cptr);
end;

procedure m_end_of_burst(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if not isserver(sptr) then exit;
  if flag_isset(sptr.server.flags,servflag_joining) then begin
    dec(receivingburst);
    channelcheck;
    if sptr = cptr then sendto_one(cptr,sprefix(me,TOK_EOB_ACK));
    sendto_serversbutone(cptr,sprefix(sptr,TOK_END_OF_BURST));
    clearflag(sptr.server.flags,servflag_joining);
    clearflag(sptr.server.flags,servflag_ghost);
    locnotice(SNO_NETWORK,'Completed net.burst from '+sptr.name+'.');
  end;
end;

procedure m_eob_ack(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if not isserver(sptr) then exit;
  if flag_isset(sptr.server.flags,servflag_burstack) then exit;
  if flag_isset(sptr.server.flags,servflag_joining) then begin
    locnotice(SNO_OLDSNO,sptr.name+' EA without EB');
  end;
  if flag_isset(sptr.server.flags,servflag_joining) then exit;
  setflag(sptr.server.flags,servflag_burstack);
  sendto_serversbutone(cptr,sprefix(sptr,TOK_EOB_ACK));
  locnotice(SNO_NETWORK,sptr.name+' acknowledged end of net.burst.');
end;

procedure m_admin(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  srv:tuser;
begin
  if (parc >= 2) and (parv[1] <> '') then begin
    {don't allow unreg to do remote request}
    if isunreg(cptr) then exit;

    {$ifndef nohis}
    if opt.headinsand and not hasprivs(cptr,privs_his) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    {$endif}
    srv := getremoteserver(parv[1],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[1]);
      exit;
    end;
    if srv <> me then begin
      sendmsgto_one(sptr,srv,cmdadmin,'');
      exit;
    end;
  end;
  if (opt.admininfo[0] = '') and (opt.admininfo[1] = '') and (opt.admininfo[2] = '') then begin
    sendreply(sptr,ERR_NOADMININFO,me.name+' '+getrpl0(ERR_NOADMININFO));
    exit;
  end;
  sendreply(sptr,RPL_ADMINME,me.name+' '+getrpl0(RPL_ADMINME));
  sendreply(sptr,RPL_ADMINLOC1,':'+opt.admininfo[0]);
  sendreply(sptr,RPL_ADMINLOC2,':'+opt.admininfo[1]);
  sendreply(sptr,RPL_ADMINEMAIL,':'+opt.admininfo[2]);
end;


procedure m_time(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  srv:tuser;
begin
  if (parc >= 2) and (parv[1] <> '') then begin
    {$ifndef nohis}
    if opt.headinsand and not hasprivs(cptr,privs_his) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    {$endif}
    srv := getremoteserver(parv[1],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[1]);
      exit;
    end;
    if srv <> me then begin
      sendmsgto_one(sptr,srv,cmdtime,'');
      exit;
    end;
  end;
  sendreply(sptr,RPL_TIME,me.name+' '+inttostr(irctime)+' '+inttostr(settimebias)+' :'+timestring(irctime));
end;


procedure m_version(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  srv:tuser;
begin
  if (parc >= 2) and (parv[1] <> '') then begin
    {don't allow unreg to do remote request}
    if isunreg(cptr) then exit;

    {$ifndef nohis}
    if opt.headinsand and not hasprivs(cptr,privs_his) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    {$endif}
    srv := getremoteserver(parv[1],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[1]);
      exit;
    end;
    if srv <> me then begin
      sendmsgto_one(sptr,srv,cmdversion,'');
      exit;
    end;
  end;
  sendreply(sptr,RPL_VERSION,versionstr+' '+me.name+' :B'+inttostr(opt.maxtotalsendq div 1000000)+'EFfIKMpStUvW');

  sendisupport(sptr);
  {the last parameter is fake but clients want a last parameter}
end;


procedure m_rehash(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if not hasprivs(sptr,privs_rehash) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;
  sendreply(sptr,RPL_REHASHING,conffile+' '+getrpl0(RPL_REHASHING));
  locnotice(SNO_OLDSNO,sptr.name+' is rehashing Server config file');
  bconfig.init;
end;


procedure m_ison(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s,s2,s3:bytestring;
  a,b:integer;
  us:tuser;
begin
  if checkneedmoreparams(sptr,cmdnum,1,parc,parv) then exit;
  s := '';
  for a := 1 to parc-1 do begin
    s2 := parv[a];
    b := 1;
    repeat
      strtok2(s2,' ',b,s3);
      us := findnick(s3);
      if us <> nil then begin
        if s <> '' then s := s + ' ';
        s := s + us.name;
      end;
    until s3 = '';
  end;
  sendreply(sptr,RPL_ISON,':'+s);
end;

procedure m_userhost(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
  a,b,c,d:integer;
  us:tuser;
  parv2:tparams;
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  s := '';
  d := 5;
  for a := 1 to parc-1 do begin
    c := strtok(parv[a],' ',@parv2);
    for b := 0 to c-1 do if d > 0 then begin
      dec(d);
      us := findnick(parv2[b]);
      if us <> nil then begin
        if s <> '' then s := s + ' ';
        s := s + us.name;
        if seeoper(sptr,us) then s := s + '*';
        s := s + '=';
        if us.away <> '' then s := s + '-' else s := s + '+';

        {$ifndef novhost}
        {mirc has 2 ways to get his own host (for DCC)
        using "welcome nick!user@host" reply, or by doing a userhost on himself.}
        if (sptr = us) then
        s := s + us.userid+'@'+us.host
        else
        {$endif}
        s := s + showuserid(us)+'@'+showhost(us);
      end;
    end;
  end;
  sendreply(sptr,RPL_USERHOST,':'+s);
end;

procedure m_userip(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
  a,b,c,d:integer;
  us:tuser;
  parv2:tparams;
begin
  if not isprivileged(sptr) then if opt.secretuserip then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  s := '';
  d := 5;
  for a := 1 to parc-1 do begin
    c := strtok(parv[a],' ',@parv2);
    for b := 0 to c-1 do if d > 0 then begin
      dec(d);
      us := findnick(parv2[b]);
      if us <> nil then begin
        if s <> '' then s := s + ' ';
        s := s + us.name;
        if seeoper(sptr,us) then s := s + '*';
        s := s + '=';
        if us.away <> '' then s := s + '-' else s := s + '+';
        {$ifndef novhost}
        if flag_isset(us.flags,userflag_hasvhost) and not (sptr = us) then
        s := s + showuserid(us)+'@'+fakeipstr
        else
        {$endif}
        s := s + us.userid+'@'+ircipbintostr(us.binip);
      end;
    end;
  end;
  sendreply(sptr,RPL_USERIP,':'+s);
end;

end.
