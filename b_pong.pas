(*
 *  beware ircd, Internet Relay Chat server, b_pong.pas
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

unit b_pong;

interface

uses buser,bcmds,bstuff,sysutils;

procedure mu_pong(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_pong(cptr,sptr:tuser;parc:integer;parv:pparams);

procedure m_ping(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_ping(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure mo_ping(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bwelcome,breplies,bsend,btime,bparse,bsock;

procedure mu_pong(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  if not flag_isset(cptr.flags,userlog_nick) then exit;
  if parv[1] = inttostr(cptr.randomid) then begin
    setflag(cptr.flags,userlog_nospoof);
    welcome(cptr);
  end else begin
    sendreply(cptr,ERR_BADPING,getrpl1(ERR_BADPING,inttostr(cptr.randomid)));
  end;
end;

procedure m_pong(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if isclient(cptr) then begin
    if (parc < 2) then begin
      needmoreparams(cptr,cmdnum);
      exit;
    end;
    if strcompup(parv[1],me.name) then begin
      connectionlist[cptr.socknum].pingtime := unixtime;
      clearflag(cptr.flags,userflag_pongneeded);
    end;
  end else begin
    {pong from server is always accepted (no parameter checking)}
    connectionlist[cptr.socknum].pingtime := unixtime;
    clearflag(cptr.flags,userflag_pongneeded);
  end;
end;

procedure m_ping(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  sendto_one(sptr,cprefix(me,MSG_PONG)+me.name+' :'+parv[1]);
end;


procedure mo_ping(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;
  b:boolean;
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  if ((parc >= 3) and (parv[2] <> '')) then if parv[2] <> me.name then begin
    us := findname(parv[2]);
    b := false;
    if us <> nil then if isserver(us) then begin
      b := true;
      sendto_one(us,sprefix(sptr,TOK_PING)+sptr.name+' :'+parv[2])
    end;
    if not b then sendnosuchserver(sptr,parv[2]);
    exit;
  end;
  sendto_one(sptr,cprefix(me,MSG_PONG)+me.name+' :'+parv[1]);
end;

procedure ms_ping(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;
  f,g:float; {defined in btime}
begin
  if (parc < 2) or (parv[1] = '') then exit;

  if parc > 3 then begin
    try
      g := strtofloat(parv[3]);
    except
      exit;
    end;
    f := unixtimefloat;
    {AsLL}
    sendto_one(sptr,sprefix(me,TOK_PONG)+me.idstr+' '+parv[1]+' '+parv[3]+' '+inttostr(trunc((f-g)*1000))+' '+formatfloat('0.000000',f));
    exit
  end;
  if ((parc >= 3) and (parv[2] <> '')) then if parv[2] <> me.name then begin
    us := findname(parv[2]);
    if us <> nil then if isserver(us) then begin
      sendto_one(us,sprefix(sptr,TOK_PING)+parv[1]+' :'+parv[2])
    end else
    sendreply(sptr,ERR_NOSUCHSERVER,getrpl0(ERR_NOSUCHSERVER));
    exit;
  end;
  sendto_one(sptr,sprefix(me,TOK_PONG)+me.idstr+' :'+parv[1]);
end;

end.
