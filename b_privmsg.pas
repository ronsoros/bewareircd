(*
 *  beware ircd, Internet Relay Chat server, b_privmsg.pas
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

unit b_privmsg;

interface

uses buser,bcmds,bstuff,pgtypes;

procedure m_privmsg(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  classes,breplies,bsend,bparse,bchannel,bsock,bconfig,blinklist,b_wallchops,
  bipcheck,btime,bconsts,bprivs;

var donelist:tlist;

{$ifdef bdebug}
procedure debugsend(sptr:tuser;target,msg:bytestring);
var
  us:tuser;
  ch:tchannel;
begin
  ch := findchan(target);
  if ch = nil then exit;
  if not isonchannel(sptr,ch) then exit;
  if not isoper(sptr) then exit;
  us := findname(copy(target,8,length(target)));
  if not assigned(us) then exit;
  if not isserver(us) then exit;
  if not myconnect(us) then exit;
  if copy(msg,1,3) <> '!! ' then exit;
  sendto_one(us,copy(msg,4,length(msg)));
end;
{$endif}

function marked(p:pointer):boolean;
var
  a:integer;
begin
  for a := donelist.count-1 downto 0 do begin
    if donelist[a] = p then begin
      result := true;
      exit;
    end;
  end;
  result := false;
end;

procedure m_privmsg(cptr,sptr:tuser;parc:integer;parv:pparams);
label skip;
var
  ch:tchannel;
  a,b:integer;
  s,s2:bytestring;
  us:tuser;

  nickatserver:boolean;
begin
  {too long lines fix}
  if isclient(cptr) then begin
    a := length(sptr.name)+length(sptr.userid)+length(showhost(sptr))+length(parv[1])+length(parv[parc-1])+length(cmdtable[cmdnum].cmd);
    if a > (maxmessagelength-7) then parv[parc-1] := copy(parv[parc-1],1,(maxmessagelength-7-a+length(parv[parc-1])));
    {:!@123:}
  end;

  if not assigned(donelist) then donelist := tlist.create;
  donelist.clear;

  if (parc < 2) or (parv[1] = '') then begin
    if cptr = sptr then sendreply(cptr,ERR_NORECIPIENT,getrpl1(ERR_NORECIPIENT,cmdtable[cmdnum].cmd));
    exit
  end;
  if (parc < 3) or (parv[2] = '') then begin
    if cptr = sptr then sendreply(cptr,ERR_NOTEXTTOSEND,getrpl0(ERR_NOTEXTTOSEND));
    exit
  end;

  {$ifdef bdebug}
  if isoper(sptr) then if copy(parv[1],1,7) = debugchanprefix then debugsend(sptr,parv[1],parv[parc-1]);
  {$endif}

  if parv[1] <> '' then if parv[1,1] = '@' then if cmdnum = cmdnotice then begin
    parv[1] := copy(parv[1],2,500);
    m_wallchops(cptr,sptr,parc,parv);
    exit;
  end;

  b := 1;
  repeat
    strtok2(parv[1],',',b,s2);
    if s2 = '' then break;

  if ischanprefix(s2[1]) then begin
    ch := findchan(s2);
    if ch = nil then begin
      {if IRCop then send to hostmask}
      if cptr = sptr then sendreply(sptr,ERR_NOSUCHCHANNEL,s2+' '+getrpl0(ERR_NOSUCHCHANNEL));
      goto skip;
    end;
    if marked(ch) then goto skip;
    donelist.add(ch);
    if not cansendtochannel(sptr,ch,nil) then begin
      sendreply(sptr,ERR_CANNOTSENDTOCHAN,ch.name+' '+getrpl0(ERR_CANNOTSENDTOCHAN));
      goto skip;
    end;

    {$ifndef noqnet}
    if opt.qnetmodes then begin
      if isclient(cptr) and not isservice(sptr) then begin
        if flag_isset(ch.modeflag,chanmode_nonotice) then if (cmdnum = cmdnotice) then begin
          sendreply(sptr,ERR_CANNOTSENDTOCHAN,ch.name+' '+getrpl0(ERR_CANNOTSENDTOCHAN));
          goto skip;
        end;
        if flag_isset(ch.modeflag,chanmode_nocolors) then if pos(#3,parv[parc-1]) <> 0 then begin
          sendreply(sptr,ERR_CANNOTSENDTOCHAN,ch.name+' '+getrpl0(ERR_CANNOTSENDTOCHAN));
          goto skip;
        end;
        if flag_isset(ch.modeflag,chanmode_noctcp) then begin
          a := pos(#1,parv[parc-1]);
          if a <> 0 then if copy(parv[parc-1],a+1,6) <> 'ACTION' then begin
            sendreply(sptr,ERR_CANNOTSENDTOCHAN,ch.name+' '+getrpl0(ERR_CANNOTSENDTOCHAN));
            goto skip;
          end;
        end;
      end;
    end;
    {$endif}

    a := ipcheck_target(sptr,ch);

    if a <= 0 then begin
      if cmdnum = cmdprivmsg then sptr.idletime := irctime;

      {$ifndef nodelayed}
      undelay(getuserchan(sptr,ch));
      {$endif}

      if not flag_isset(ch.flags,chanflag_local) then sendchatto_serversbutone(sptr,ch,sprefix(sptr,cmdtable[cmdnum].tok)+ch.name+' :'+parv[parc-1]);
      sendchatto_channelbutone(sptr,ch,cprefix(sptr,cmdtable[cmdnum].cmd)+ch.name+' :'+parv[parc-1]);
    end;
  end else if (hasprivs(sptr,privs_broadcast) and (s2[1] = '$')) then begin
    if cmdnum = cmdprivmsg then sptr.idletime := irctime;
    sendto_serversbutone(sptr,sprefix(sptr,cmdtable[cmdnum].tok)+s2+' :'+parv[parc-1]);
    if maskmatchup(copy(s2,2,500),me.name) then begin
      s := cprefix(sptr,cmdtable[cmdnum].cmd)+s2+' :'+parv[parc-1];
      for a := 0 to highconnection do if connectionlist[a].open then if isclient(connectionlist[a].user) then begin
        sendto_one(connectionlist[a].user,s);
      end;
    end;
  end else begin
    a := pos('@',s2);
    if a > 0 then begin
      if a = 1 then goto skip;
      nickatserver := true;
      s := copy(s2,1,a-1);
      us := findname(s);
      if us <> nil then begin
        {$ifndef nohis}
        if (not isservice(us)) and (opt.headinsand) then begin
          us := nil;
        end else
        {$endif}
        begin
          if not strcompup(tuser(us.server.us).name,copy(s2,a+1,500)) then us := nil;
        end;
      end;
    end else begin
      nickatserver := false;
      if isserver(cptr) then us := findnumeric(s2) else us := findname(s2);
    end;
    if assigned(us) then begin
      if marked(us) then goto skip;
      donelist.add(us);
    end;
    if (us = nil) or (us = me) or (not isserver(cptr) and isserver(us)) then begin
      if cmdnum <> cmdnotice then begin
        if not isserver(cptr) then sendreply(sptr,ERR_NOSUCHNICK,s2+' '+getrpl0(ERR_NOSUCHNICK))
        else sendreply(sptr,ERR_NOSUCHNICK,'* :Target has left '+opt.networkname+'. Failed to deliver: ['+copy(parv[parc-1],1,20)+']');
      end;
      goto skip;
    end;

    if opt.restrictprivate then begin
      if (not isprivileged(cptr)) then if (us <> sptr) then if not (isservice(us) or isanoper(us)) then begin
        if cmdnum <> cmdnotice then begin
          sendreply(sptr,cmdnotice,':*** private chat is disabled');
{         sendreply(sptr,ERR_NOSUCHNICK,s2+' '+getrpl0(ERR_NOSUCHNICK));}
        end;
        exit;
      end;
    end;

    {$ifndef noqnet}
    if opt.qnetmodes then if flag_isset(us.modeflag,usermode_reggedonly) and (sptr.account = '') and (not isservice(sptr)) then begin
      if (cmdnum <> cmdnotice) then sendreply(sptr,ERR_ACCOUNTONLY,us.name+' '+getrpl0(ERR_ACCOUNTONLY));
      exit;
    end;
    {$endif}

    {is silenced}
    if is_silenced(sptr,us) then goto skip;

    if cmdnum = cmdprivmsg then if sptr = cptr then if us.away <> '' then begin
      sendreply(sptr,RPl_AWAY,us.name+' :'+us.away);
    end;

    if not isservice(us) then
    a := ipcheck_target(sptr,us)
    else a := 0;

    if a <= 0 then begin
      if cmdnum = cmdprivmsg then sptr.idletime := irctime;

      if nickatserver then begin
        if us = us.from then begin
          {to client}
          sendto_one(us,cprefix(sptr,cmdtable[cmdnum].cmd)+s2+' :'+parv[parc-1])
        end else begin
          {to server}
          sendto_one(us,sprefix(sptr,cmdtable[cmdnum].tok)+s2+' :'+parv[parc-1])
        end;
      end else
      sendmsgto_one(sptr,us,cmdnum,':'+parv[parc-1]);
    end;
  end;

skip:
  until false;
  donelist.clear;
end;

initialization donelist := nil;

end.
