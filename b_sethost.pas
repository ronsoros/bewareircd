(*
 *  beware ircd, Internet Relay Chat server, b_sethost.pas
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

unit b_sethost;

{$ifdef novhost}
'vhost support required for sethost'
{$endif}


interface

uses buser,bstuff,bchannel,pgtypes;

procedure dosethost(us:tuser;const par1,par2:bytestring;parc:integer;sendmode:boolean;sender:tuser);
procedure doclearhost(us:tuser);

function sethhost(us:tuser;const newuserhost:bytestring;propagate:boolean):boolean;
procedure m_sethost(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_sethost(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure autosethost(us:tuser);

implementation

uses bsend,breplies,bcmds,blinklist,bconfig,bparse,bconsts,unitbanmask;

function validsethost(const s:bytestring):boolean;
var
  a:integer;
begin
  result := false;
  if s = '' then exit;
  if length(s) > hostlen then exit;
  for a := 1 to length(s) do begin
    if not ((s[a] in ['A'..'Z']) or (s[a] in ['0'..'9']) or (s[a] = '\') or (s[a] = '[') or (s[a] = ']') or (s[a] = '^')
    or (s[a] in ['a'..'z']) or (s[a] = '|') or (s[a] = '{') or (s[a] = '}')
    or (s[a] = '_') or (s[a] = '-') or (s[a] = '~') or (s[a] = '.')) then exit
  end;
  result := true
end;

function sethhost(us:tuser;const newuserhost:bytestring;propagate:boolean):boolean;
var
  newuserid,newhost:bytestring;
  s1:bytestring;
  a:integer;
begin
  result := false;
  a := pos('@',newuserhost);
  if a = 0 then begin
    newuserid := '';
    newhost := newuserhost;
  end else begin
    newuserid := copy(newuserhost,1,a-1);
    newhost := copy(newuserhost,a+1,500);
  end;
  newuserid := copy(newuserid,1,userlen);
  if newuserid <> '' then s1 := newuserid else s1 := us.userid;
  newhost := copy(newhost,1,62-length(s1));


  {valid userid and valid host checks (looser validhost rules, nick chars)}
  if (newhost <> '') or (newuserid <> '') then begin
    if not (validsethost(newhost) and validsethost(s1)) then begin
      sendreply(us,ERR_BADHOSTMASK,newuserhost+' '+getrpl0(ERR_BADHOSTMASK));
      {invalid user@host}
      exit;
    end;
    if propagate then sendto_serversbutone(us,sprefix(us,TOK_MODE)+us.name+' +h '+newuserhost);
  end else begin
    if propagate then sendto_serversbutone(us,sprefix(us,TOK_MODE)+us.name+' -h');
  end;
  if (newuserid = '') and (newhost = '') then begin
    if flag_isset(us.modeflag,usermode_xhost) then newhost := makexhost(us);
  end;
  result := true;
  setvhost(us,newuserid,newhost,'Host change');
end;

procedure dosethost;
var
  newuser,newhost,newuserhost:bytestring;
  a:integer;
  cl:tconfline;
  bm:tbanmask;
  freeform:boolean;
  hack:boolean;
begin
  hack := opt.usermodehacking and isulinedserver(sender);
  if not opt.sethostuser then if not hack then if not (isoper(us) or isserver(us.from)) then begin
    sendreply(us,err_noprivileges,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;
  if (par1 = '') or (parc <= 1) then begin
    sendreply(us,err_needmoreparams,MSG_SETHOST+' '+getrpl0(ERR_NEEDMOREPARAMS));
    exit;
  end;
  freeform := false;
  if myconnect(us) then begin
    banmaskmake_oneuser(@bm,us.userid,us.host,us.binip);
    if hack or (isoper(us) and opt.sethostfreeform) then begin
      {set user, host, search user, host match in S:line otherwise its freeform}
      if (parc > 2) and (par2 <> '') then begin
        newuser := par1;
        newhost := par2;
      end else begin
        a := pos('@',par1);
        if a <> 0 then begin
          newuser := copy(par1,1,a-1);
          newhost := copy(par1,a+1,500);
        end else begin
          newuser := showuserid(us);
          newhost := par1;
        end;
      end;

      {
      s4 is real ident (must match if set)
      empty fields for real ident/host means always match
      s1 fake host never has user@, users can never change userids,
      opers can use any userid if the host is in the S:line
      }

      a := 0;
      cl := conflinelist;
      while cl <> nil do begin
        if cl.c = 'S' then begin
          if banmaskmatch(@cl.bm,@bm) then if strcompup(newhost,cl.s1) then begin
            a := 1;
            {take case from S:line}
            newhost := cl.s1;
          end;
        end;
        cl := tconfline(cl.next);
      end;
      newuserhost := newuser+'@'+newhost;
      freeform := a = 0;
    end else begin
      if (par2 = '') or (parc <= 2) then begin
        sendreply(us,err_needmoreparams,MSG_SETHOST+' '+getrpl0(ERR_NEEDMOREPARAMS));
        exit;
      end;

      {search "host password" match}
      newhost := par1;
      newuser := showuserid(us);

      a := 0;
      cl := conflinelist;
      while cl <> nil do begin
        if cl.c = 'S' then begin
          if banmaskmatch(@cl.bm,@bm) and strcompup(newhost,cl.s1) and ((par2 = cl.s2) or (cl.s2 = '')) then begin
            a := 1;
            newhost := cl.s1;
          end;
        end;
        cl := tconfline(cl.next);
      end;

      if newuser[1] = '~' then newuser := copy(newuser,2,userlen);

      newuserhost := newuser+'@'+newhost;
      if a = 0 then begin
        sendreply(us,ERR_HOSTUNAVAIL,newhost+' '+getrpl0(ERR_HOSTUNAVAIL));
        exit;
      end;
    end;
  end else newuserhost := par1;

  if sethhost(us,newuserhost,true) then begin
    if freeform then begin
      if hack then begin
        locnotice(SNO_OLDSNO,'SETHOST ('+showuserid(us)+'@'+showhost(us)+') on ('+us.name+'!'+us.userid+'@'+us.host+') by '+sender.name+' (hack)');
      end else begin
        locnotice(SNO_OLDSNO,'SETHOST ('+showuserid(us)+'@'+showhost(us)+') by ('+us.name+'!'+us.userid+'@'+us.host+'): using freeform');
      end;
    end;
    setflag(us.modeflag,usermode_hhost);
  end;
end;

procedure doclearhost(us:tuser);
begin
  sethhost(us,'',true);
end;

procedure m_sethost(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if not opt.sethostuser then if not isoper(sptr) then begin
    sendreply(sptr,err_noprivileges,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;

  {undo situation here}
  if (parv[1] = 'undo') and (parc = 2) then begin
    if flag_isset(sptr.modeflag,usermode_hhost) then begin
      sethhost(sptr,'',true);
      clearflag(sptr.modeflag,usermode_hhost);
    end;
    exit;
  end;

  if isoper(sptr) then if (parv[2] = '') or (parc <= 2) then begin
    parv[2] := parv[1];
    parv[1] := showuserid(sptr);
    parc := 3;
  end;
  if checkneedmoreparams(cptr,cmdnum,2,parc,parv) then exit;

  dosethost(sptr,parv[1],parv[2],3,true,sptr);
end;

{SH SSCCC user host}
procedure ms_sethost(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;

begin
  if not isulinedserver(sptr) then exit;
  if not opt.usermodehacking then exit;
  if checkneedmoreparams(cptr,cmdnum,3,parc,parv) then exit;

  us := findnumeric(parv[1]);
  if not assigned(us) then exit;
  if not isclient(us) then exit;

  if myconnect(us) then begin
    dosethost(us,parv[2],parv[3],3,true,sptr);
  end else begin
    sendto_one(us.from,sprefix(sptr,tokstr(cmdnum))+parv[1]+' '+parv[2]+' '+parv[3]);
  end;


end;

procedure autosethost(us:tuser);
var
  cl:tconfline;
  bm:tbanmask;
  pass:bytestring;
  parv:tparams;
begin
  if not (opt.sethostauto and opt.sethostuser) then exit;
  banmaskmake_oneuser(@bm,us.userid,us.host,us.binip);
  pass := us.password;
  cl := conflinelist;
  while cl <> nil do begin
    if cl.c = 'S' then begin
      if ((cl.s3 <> '') and (cl.s3 <> '*')) or (cl.s2 <> '') then
      if banmaskmatch(@cl.bm,@bm) and ((pass = cl.s2) or (cl.s2 = '')) then begin
        parv[1] := cl.s1;
        if cl.s2 = '' then parv[2] := '0' else parv[2] := pass;
        m_sethost(us,us,3,@parv);
        exit;
      end;
    end;
    cl := tconfline(cl.next);
  end;
end;

end.

