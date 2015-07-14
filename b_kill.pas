(*
 *  beware ircd, Internet Relay Chat server, b_kill.pas
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

unit b_kill;

interface

uses buser,bcmds,bstuff,pgtypes;

var
  killnoticeflag:boolean;

procedure m_kill(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure dokill(cptr,sptr,us:tuser;parv2:bytestring);

implementation

uses bchannel,breplies,bsend,btime,blinklist,bconfig,bconsts,bserver,bprivs,
  bparse;

function hidepath(s:bytestring):bytestring;
var
  a,b,c:integer;

begin
  result := s;
  {find the first ( which is the start of the reason}
  a := pos(' (',s);
  if a = 0 then exit;

  b := -1;
  {find the last !}
  for c := a downto 1 do begin
    if result[c] = '!' then begin
      b := c;
      break
    end
  end;
  if b = -1 then exit;
  a := b-1;
  b := -1;
  {find the ! before the last !}
  for c := a downto 1 do begin
    if result[c] = '!' then begin
      b := c;
      break
    end
  end;
  if b = -1 then exit;
  result := copy(result,b+1,500);
end;

procedure dokill(cptr,sptr,us:tuser;parv2:bytestring);
var
  showreason,showsender:bytestring;
  a,b,c,d:integer;
  from:tuser;
begin
  if isclient(cptr) then begin
    {coming from a local client, format the reason-string}
    parv2 := sptr.host+'!'+sptr.name+' ('+parv2+#15')';
  end else begin
    {first check for broken services sending format without brackets}
    if pos(' (',parv2) = 0 then parv2 := sptr.name+' ('+parv2+#15')';

    {add directly connected server to path}
    parv2 := cptr.name+'!'+parv2;

  end;
  {
  get the sender and reason in "Killed (sender (reason))"
  }

  {first space in reason (end of path, start of comment)}
  d := pos(' ',parv2);
  if d = 0 then d := length(parv2);

  {c  last ! in path}
  c := 0;
  for a := d downto 1 do begin
    if parv2[a] = '!' then begin
      c := a;
      break
    end;
  end;

  {b  last ) in reason}
  b := 0;
  for a := length(parv2) downto 1 do begin
    if parv2[a] = ')' then begin
      b := a;
      break
    end;
  end;

  a := pos('(',parv2);

  if b = 0 then b := length(parv2)+1;

  if a <> 0 then begin
    showreason := copy(parv2,a+1,b-a-1);
    showsender := copy(parv2,c+1,a-c-2);
  end else begin
    showsender := copy(parv2,c+1,500);
    showreason := '';
  end;
  {$ifndef nohis}
  if (opt.headinsand and (pos('.',showsender) <> 0)) or opt.headinsandkillwho then showsender := opt.headinsandname;
  {$endif}
  if killnoticeflag then begin
    if isserver(sptr) then a := SNO_SERVKILL else a := SNO_OPERKILL;
    locnotice(a,'Received KILL message for '+us.name+'['+us.userid+'@'+us.host+']. From '+sptr.name+' Path: '+parv2);
  end;

  if us.server = me.server then begin
    {the target is local on this server, send the KILL message to it}


    {$ifndef nohis}
    if (opt.headinsand and isserver(sptr)) or opt.headinsandkillwho then from := me
    else
    {$endif}
    from := sptr;
    us.killer := from;
    sendto_one(us,cprefix(from,MSG_KILL)+us.name+' :'+showsender+' ('+showreason+')');
  end;

  {i don't do "local kill by" to have all kills look the same (head in sand)}
  if showreason = '' then
  us.error := 'Killed ('+showsender+')'
  else
  us.error := 'Killed ('+showsender+' ('+showreason+'))';

  {parv2 := me.name+'!' + parv2;}  {server is added on receiving not sending}

  {if local kill, and not server kill (collision) send QUIT instead of KILL}
  if (sptr.server = me.server) and (us.server = me.server) and (sptr <> me) then
  else begin
    setflag(us.flags,userflag_globalkill);
    sendto_serversbutone(sptr,sprefix(sptr,TOK_KILL)+us.idstr+' :'+parv2);
  end;

  channelstayflag := isserver(sptr) and (receivingburst > 0);
  us.destroy;
  channelstayflag := false;
end;



procedure m_kill(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;
begin
  if isclient(cptr) then if checkneedmoreparams(sptr,cmdnum,2,parc,parv) then exit;
  if (parv[1] = '') or (parc < 2) then exit;

  if isclient(cptr) then
  us := findname(parv[1])
  else
  us := findnumeric(parv[1]);

  {no chasing implemented (yet)}

  if us = nil then begin
    if isclient(cptr) then sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;

  if not isclient(us) then begin
    if isclient(cptr) then sendreply(sptr,ERR_CANTKILLSERVER,getrpl0(ERR_CANTKILLSERVER));
    exit;
  end;

  if not isserver(cptr) then begin
    if not ((myconnect(us) and hasprivs(sptr,privs_localkill)) or hasprivs(sptr,privs_globalkill)) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    if isservice(us) then if isclient(cptr) then begin
      sendreply(sptr,ERR_ISCHANSERVICE,'KILL '+parv[1]+' '+getrpl0(ERR_ISCHANSERVICE));
      exit;
    end;
  end;
  killnoticeflag := true;
  if isserver(cptr) then sendto_one(cptr,sprefix(me,TOK_KILL)+parv[1]+' :'+me.name+'!'+me.name+' (Ghost 5 Numeric Collided)');

  dokill(cptr,sptr,us,parv[parc-1]);
end;

end.
