(*
 *  beware ircd, Internet Relay Chat server, b_oper.pas
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

unit b_oper;

interface

uses buser,bcmds,bstuff,pgtypes;

procedure m_oper(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bconfig,bsend,breplies,passcryp,bsock,unitbanmask,bparse;

procedure m_oper(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  found1,found2:boolean;
  cl,cl2,yl:tconfline;
  s2:bytestring;
  a,newclass:integer;
  bm:tbanmask;
  prevflags:integer;
begin
  if isserver(cptr) then exit;

  if checkneedmoreparams(cptr,cmdnum,2,parc,parv) then exit;
  cl := conflinelist;
  cl2 := nil;
  found1 := false;
  found2 := false;

  banmaskmake_oneuser(@bm,sptr.userid,sptr.host,sptr.binip);

  while cl <> nil do begin
    if (cl.c = 'O') or (cl.c = 'o') then begin
      yl := getyline(cl.i5);
      if yl <> nil then a := yl.i4 else a := 0;
      if strcompup(cl.s3,parv[1]) then if  {force using the same nick}
      (classcount[cl.i5] < a) or (a = 0) or (connectionlist[sptr.socknum].classnum = cl.i5) then if
      banmaskmatch(@cl.bm,@bm)
      then begin
        found1 := true;
        if passmatch(parv[2],cl.s2) then begin
          found2 := true;
          cl2 := cl;
          break;
        end;
      end;
    end;
    cl := tconfline(cl.next);
  end;
  if not (found1 and found2) then begin
    if opt.operfailedglobal then
    desynchwallops('Failed OPER attempt by '+sptr.name+'['+sptr.userid+'@'+sptr.host+'] using UID '+parv[1])
    else
    locnotice(SNO_OLDSNO,'Failed OPER attempt by '+sptr.name+'['+sptr.userid+'@'+sptr.host+'] using UID '+parv[1]);

  end;
  if not found1 then begin
    sendreply(sptr,ERR_NOOPERHOST,getrpl0(ERR_NOOPERHOST));
    exit;
  end;

  if not found2 then begin
    sendreply(sptr,ERR_PASSWDMISMATCH,getrpl0(ERR_PASSWDMISMATCH));
    exit;
  end;
  newclass := cl2.i5;

  if isoper(cptr) then dec(count.oper);


  {
  all this code to make the mode change sent to the user good looking (containing only changes)
  }
  prevflags := sptr.modeflag;

  if (cl2.c = 'o') then begin
    clearflag(sptr.modeflag,usermode_oper);
    setflag(sptr.modeflag,usermode_locop);
  end;
  if (cl2.c = 'O') then begin
    clearflag(sptr.modeflag,usermode_locop);
    setflag(sptr.modeflag,usermode_oper);
  end;

  setflag(sptr.modeflag,usermode_wallops or usermode_notices or usermode_debug);

  sptr.snomask := opt.snodefaultoper;{SNO_DEFAULTOPER;}

  {send mode}
  s2 := usermodestrdiff(prevflags,sptr.modeflag,false);
  if s2 <> '' then sendto_one(sptr,cprefix(sptr,MSG_MODE)+sptr.name+' :'+s2);

  s2 := usermodestrdiff(prevflags,sptr.modeflag,true);
  if s2 <> '' then sendto_serversbutone(me,sprefix(sptr,TOK_MODE)+sptr.name+' :'+s2);

  if opt.operfailedglobal then begin
    desynchwallops(sptr.name+' ('+sptr.userid+'@'+sptr.host+') is now operator ('+cl.c+') using UID '+parv[1]);
  end else begin
    locnotice(SNO_OLDSNO,sptr.name+' ('+sptr.userid+'@'+sptr.host+') is now operator ('+cl.c+')');
  end;
  sendreply(sptr,RPL_YOUREOPER,getrpl0(RPL_YOUREOPER));
  if not islocop(cptr) then inc(count.oper);

  {change connection class, sendq}
  a := connectionlist[cptr.socknum].classnum;
  if (a > 0) and (a <= maxclass) then dec(classcount[a]);

  connectionlist[cptr.socknum].classnum := newclass;
  if (newclass > 0) and (newclass <= maxclass) then inc(classcount[newclass]);

  cl := getyline(newclass);
  if cl <> nil then begin
    connectionlist[cptr.socknum].maxsendq := cl.i5;
    connectionlist[cptr.socknum].pingfreq := strtointdef(cl.s2,90);
  end;

  {oper no penalty
  if opt.opernopenalty then if isoper(sptr) then setflag(sptr.flags,userflag_nopenalty);}
end;

end.
