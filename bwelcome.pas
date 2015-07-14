(*
 *  beware ircd, Internet Relay Chat server, bwelcome.pas
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

unit bwelcome;

interface

uses buser,bconsts,bcreationdate,pgtypes;

{
check if the connection has done everything needed to register
then make the connection a client
accept or deny the user, send to other servers, MOTD, etc

there is a difference in behavior between ircu and beware ircd, about using a nick:

on beware ircd, if the connection sends the NICK to register, 
the nick is stored but not used in the database yet; it isn't found by findname.
for this reason, another one can be using the same nick at the same time.

"invalid nick" and "nick in use" are checked just before the connection becomes client 
and the nick is being sent to other servers.

the nick check is done after the K-lines etc check,
if one is not allowed to enter, he can not find out if user with nick is online or not.
}

procedure welcome(us:tuser);

procedure sendisupport(us:tuser);
function passwordislimit(const s:bytestring;var limitnum,limitprefix:integer):boolean;

implementation

uses
  {$ifndef nosethost}b_sethost,{$endif}
  bstuff,bsend,breplies,bserver,bconfig,btime,b_mischandlers,b_motd,bcmds,
  bsock,bchannel,bircdunit,bipcheck,unitbanmask,bparse,bvaliddef,binipstuff;

procedure sendisupport(us:tuser);
var
  s:bytestring;

begin
    {$ifndef nohis}
    if opt.headinsand then s := '' else
    {$endif}
    s := 'MAP ';
    s := s + 'SILENCE='+inttostr(maxsilence)+' WHOX WALLCHOPS WALLVOICES USERIP CPRIVMSG CNOTICE MODES='+inttostr(maxmodes)+' MAXCHANNELS='+inttostr(opt.maxchannels)+
    ' MAXBANS='+inttostr(opt.maxbans);

    sendreply(us,RPL_ISUPPORT,s+' '+getrpl0(RPL_ISUPPORT));

    s := 'NICKLEN='+inttostr(opt.nicklen)+
    ' TOPICLEN='+inttostr(opt.topiclen)+
    ' AWAYLEN='+inttostr(opt.awaylen)+
    ' KICKLEN='+inttostr(opt.topiclen) +

    ' CHANTYPES='+isupportchantypes+' PREFIX='+isupportprefix+' CHANMODES='+isupportchanmodes+' CASEMAPPING=rfc1459';
    if opt.networkname <> '' then s := s + ' NETWORK='+opt.networkname;
    sendreply(us,RPL_ISUPPORT,s+' '+getrpl0(RPL_ISUPPORT));
end;

function nextnumeric(i:integer):integer;
begin
  if (opt.shortnumerics and (count.localclients < 3072) and (me.server.p10num < 64)) then
  result := succ(i) and 4095
  else
  result := succ(i) and 262143;
end;

function passwordislimit(const s:bytestring;var limitnum,limitprefix:integer):boolean;
var
  a:integer;
begin
  if s = '' then begin
    result := true;
    limitnum := 0;
    limitprefix := -1;
    exit;
  end;

  a := pos('/',s);
  if a = 0 then begin
    {limit}
    limitnum := strtointdef(s,-1);
    limitprefix := -1;
    result := (limitnum >= 0) and (limitnum <= 99);
    if not result then limitnum := -1;
  end else begin
    limitnum := strtointdef(copy(s,1,a-1),-1);
    result := (limitnum >= 0) and (limitnum <= 99);
    if not result then begin
      limitnum := -1;
      exit;
    end;
    limitprefix := strtointdef(copy(s,a+1,100),-1);
    result := (limitprefix >= 0) and (limitprefix <= 128);
    if not result then begin
      limitnum := -1;
      limitprefix := -1;
    end;
  end;
end;

procedure welcome(us:tuser);
var
  b,c,classnum:integer;
  s,s2:bytestring;
  cl:tconfline;
  ipmatchline,namematchline:tconfline;
  yl:tconfline;
  bm:tbanmask;
  us2:tuser;
  iptemp1,iptemp2:tbinip;
  limitnum,limitprefix:integer;
begin
{  conwrite('welcome begin');}
  if flag_isset(us.flags,userlog_dns or userlog_ident) then
  if not flag_isset(us.flags,userflag_parse) then begin

    if flag_isset(us.flags,userlog_initiateserver) then begin
      {send PASS and SERVER}
      sendto_one(us,'PASS :'+us.password);
      us.password := '';
{      connectionlist[us.socknum].linkts := getlinkts;}
      sendto_one(us,'SERVER '+me.name+' 1 '+inttostr(bootts)+' '+inttostr(getlinkts)+' J10 '+convertidstr(me.idstr+p10inttostr(me.server.p10max,CCClen))+{$ifndef noipv6}' +6'+{$endif}' :'+me.fullname);
    end;

    setflag(us.flags,userflag_parse);
    parserecvq(us);
    exit;
  end;
  if not flag_isset(us.flags,userlog_regclient) then exit;
  if count.localclients >= maxclients then begin
    us.error := 'The server is full. Try again later or try another server.';
    us.destroy;
    exit;
  end;

  if not flag_isset(us.flags,userlog_ikline) then begin
    us.userid := copy(us.userid,1,userlen);
    s := makevaliduserid(us.userid);
    if s <> us.userid then begin
      locnotice(SNO_TOOMANY,'Invalid userid from '+us.name+'['+us.userid+'@'+us.host+']');
      us.userid := s;
    end;

    {a user can get here multiple times because of "nick in use"
    a flag is used to do I/K-lines etc only once}
    setflag(us.flags,userlog_ikline);

    banmaskmake_oneuser(@bm,us.userid,'x',us.binip);

    ipmatchline := nil;
    namematchline := nil;
    cl := conflinelist;
    s2 := us.userid+'@'+us.host;
    while cl <> nil do begin
      if cl.c = 'I' then begin
{ if maskmatchup(cl.s1,s) then ipmatchline := cl;}
        if banmaskmatch(@cl.bm,@bm) then ipmatchline := cl;
        if pos('@',cl.s3) = 0 then begin
          if maskmatchup(cl.s3,us.host) then namematchline := cl;
        end else begin
          if maskmatchup(cl.s3,s2) then namematchline := cl;
        end;
        if (namematchline <> nil) or (ipmatchline <> nil) then break;
      end;
      cl := tconfline(cl.next);
    end;
    if namematchline = nil then begin
      if ipmatchline = nil then begin
        us.error := 'No Authorization';
        us.destroy;
        exit;
      end;

      (*
      {no I:line has a matching name, user is known by IP}
      us.host := ircipbintostr(us.binip);
      *)
      namematchline := ipmatchline;
    end;

    {add tilde to userid}
    if connectionlist[us.socknum].hasident then begin
      if copy(us.userid,1,1) = '~' then begin
        us.error := 'Bad username';
        us.destroy;
        exit;
      end;

    end else begin
      if ((pos('@',namematchline.s1) <> 0) or (pos('@',namematchline.s3) <> 0)) then
      us.userid := copy('~'+us.userid,1,userlen);
    end;

    {the L/G-line check, moved to after the ~ for userid}
    if isklined(us,s) then begin
      sendreply(us,ERR_YOUREBANNEDCREEP,':*** '+s+'.');
      us.error := 'K-lined';
      us.destroy;
      exit;
    end;

    if (namematchline.s2 <> '') and not passwordislimit(namematchline.s2,limitnum,limitprefix) then begin
      {the I:line has a password}
      if us.password <> namematchline.s2 then begin
        sendreply(us,ERR_PASSWDMISMATCH,getrpl0(ERR_PASSWDMISMATCH));
        us.error := 'Bad Password';
        us.destroy;
        exit;
      end;
    end;

    {check connection limit for connection class}
    classnum := namematchline.i5;

    yl := getyline(classnum);
    if yl <> nil then begin
      if (classnum > 0) and (classnum <= maxclass) then if yl.i4 > 0 then if classcount[classnum] >= yl.i4 then begin
        us.error := 'Sorry, your connection class is full - try again later or try another server';
        us.destroy;
        exit;
      end;
    end;

    if passwordislimit(namematchline.s2,limitnum,limitprefix) then begin
      if limitprefix = -1 then begin
        c := strtointdef(namematchline.s2,0);
        if (c > 0) and (c < 100) then begin
          if us.ipcheck <> nil then
          b := us.ipcheck.online
          else
          b := 0;
          if b > c then begin
            locnotice(SNO_TOOMANY,'Too many connections from same IP for '+us.name+'['+us.userid+'@'+ircipbintostr(us.binip)+']');
            us.error := 'Too many connections from your host';
            us.destroy;
            exit;
          end;
        end;
      end else begin
        b := 0;
        if (limitnum > 0) then begin
          us2 := tuser(globaluserlist);
          iptemp1 := us.binip;
          maskbits(iptemp1,limitprefix);
          while assigned(us2) do begin
            iptemp2 := us2.binip;
            if isclient(us2) then begin
              maskbits(iptemp2,limitprefix);
              if comparebinip(iptemp1,iptemp2) then begin
                inc(b);
                if (b >= limitnum) then begin
                  locnotice(SNO_TOOMANY,'Too many connections from same prefix for '+us.name+'['+us.userid+'@'+ircipbintostr(us.binip)+']');
                  us.error := 'Too many connections from your prefix';
                  us.destroy;
                  exit;
                end;
              end;
            end;
            us2 := tuser(us2.next);
          end;
        end;
      end;

    end;


    {set user's connection class}

    connectionlist[us.socknum].classnum := classnum;
    if (classnum > 0) and (classnum <= maxclass) then inc(classcount[classnum]);

    if yl = nil then begin
      {no Y:line, fill in some defaults}
      connectionlist[us.socknum].pingfreq := 90;
      connectionlist[us.socknum].maxsendq := 80000;
    end else begin
      connectionlist[us.socknum].pingfreq := strtointdef(yl.s2,0);
      connectionlist[us.socknum].maxsendq := yl.i5;
    end;
    if not opt.penalty then setflag(us.flags,userflag_nopenalty);
  end;

  {check if nick is valid}
  if not validnickfromclient(us.name) then begin
    sendto_one(us,cprefix(me,cmdstr(ERR_ERRONEUSNICKNAME))+'* '+us.name+' '+getrpl0(ERR_ERRONEUSNICKNAME));
    exit;
  end;

  {check if nick exists}
  if nameinuse(ircupper(us.name)) then begin
    sendto_one(us,cprefix(me,cmdstr(ERR_NICKNAMEINUSE))+'* '+us.name+' '+getrpl0(ERR_NICKNAMEINUSE));
    exit;
  end;

  {assign numeric}
  b := p10currentslot and CCCmask;
  while me.server.p10slots[b and me.server.p10max] <> nil do b := nextnumeric(b);

  p10currentslot := nextnumeric(b);
  us.idstr := convertidstr(me.idstr+p10inttostr(b,3));
  b := b and me.server.p10max;
  us.p10slotnum := b;
  me.server.p10slots[b] := us;
  inc(me.server.usercount);

  {from here, it's a client}
  setflag(us.flags,userflag_isclient);
  setname(us,us.name);
  dec(count.unknown);
  inc(count.localclients);
  if count.localclients > count.highestlocalclients then count.highestlocalclients := count.localclients;
  inc(count.globalclients);
  if count.globalclients > count.highestglobalclients then count.highestglobalclients := count.globalclients;
  updatehighestconnections;

  us.signontime := irctime;
  us.ts := irctime;
  us.idletime := irctime;
  us.penaltytime := unixtime; {reset penalty - user already sent 3 commands for registration}
  clearflag(us.flags,userflag_pongneeded);

  for b := 0 to maxusermodetable do if not usermodetable[b].disabled then
  if pos(usermodetable[b].c,opt.autousermode) <> 0 then
  setflag(us.modeflag,usermodetable[b].flag);

  us.snomask := 0;
  if flag_isset(us.modeflag,usermode_notices) then us.snomask := sno_default;

  {set user's modes}
  if flag_isset(us.modeflag,usermode_invisible) then inc(count.invisible);
  {propagate user}

  sendto_serversbutone(me,propagateuserstr(us));

  locnotice(SNO_CONNEXIT,'Client connecting: '+us.name+' ('+us.userid+'@'+us.host+') ['+ircipbintostr(us.binip)+']');

  sendreply(us,RPL_WELCOME,getrpl2(RPL_WELCOME,us.name,us.userid+'@'+us.host));
  sendreply(us,RPL_YOURHOST,':Your host is '+me.name+', running version '+versionstr);
  sendreply(us,RPL_CREATED,':This server was created '+creationdatestr);
  sendreply(us,RPL_MYINFO,me.name+' '+versionstr+' '+usermodesupported+' '+chanmodesupported);

  if opt.send005 then sendisupport(us);

  if not flag_isset(cmdtable[cmdlusers].flags,mflg_operonly) then
  m_lusers(us,us,0,nil);

  m_motdsignon(us,us,0,nil);

  ipcheck_connectsuccess(us);

  s := usermodestr(us,true);
  if s <> '' then sendto_one(us,cprefix(us,MSG_MODE)+us.name+s);
  {tell client about his modes}

  {$ifndef novhost}
  {$ifndef nosethost}
  autosethost(us);
  {$endif}

  checkxhost(us);
  {$endif}

  {forced join on connect here}
{  conwrite('welcome end');}
end;

end.
