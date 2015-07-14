(*
 *  beware ircd, Internet Relay Chat server, b_gline.pas
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

unit b_gline;

interface

uses buser,bcmds,bstuff,blinklist,bsend,bsock,bpremaskmatch,unitbanmask,binipstuff,pgtypes;

const
  glineflag_active=   $1;
  glineflag_badchan=  $2;
  glineflag_local=    $4;
  glineflag_ldeact=   $8;
  glineflag_force=   $10;

  glineflag_actmask=glineflag_active or glineflag_ldeact;

  GLINE_MAX_EXPIRE=86400; {test}
  {glinemaxusercount is customizeable and defaults to 20}

  inactivelifetime=86400; {lifetime of inactivated g-line, counting from last modification}

type
  tgline=class(tlinklist)
    expire:integer;
    lastmod:integer;
    flags:integer;
    mask:bytestring;
    reason:bytestring;
    bm:tbanmask;
  end;

var
  glist:tlinklist;

  glnextts:integer;

procedure ms_gline(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure mo_gline(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure timehandler;
procedure list_glines(sptr:tuser;mask:bytestring);
function isactivegline(gl:tgline):boolean;
function isremactivegline(gl:tgline):boolean;
procedure glineburst(target:tuser);

function glinebinmatch(us:tuser;var reason:bytestring):boolean;

function getlifetime(gl:tgline):integer;

implementation

uses btime,bchannel,breplies,bconfig,bserver,bprivs,bparse;

{active on this server (actually kills users)}
function isactivegline(gl:tgline):boolean;
begin
  result := ((gl.flags and glineflag_active) <> 0) and ((gl.flags and glineflag_ldeact) = 0)
end;

function getlifetime(gl:tgline):integer;
begin
  if isactivegline(gl) then begin
    result := gl.expire;
  end else begin
    result := gl.lastmod + inactivelifetime;
  end;
end;

{active on the rest of the net (+ on burst)}
function isremactivegline(gl:tgline):boolean;
begin
  result := (gl.flags and glineflag_active) <> 0;
end;

function isbadchan(gl:tgline):boolean;
begin
  result := (gl.flags and glineflag_badchan) <> 0;
end;

function islocalgline(gl:tgline):boolean;
begin
  result := (gl.flags and glineflag_local) <> 0;
end;

function str_min_plus(b:boolean):bytestring;
begin
  if b then result := '+' else result := '-';
end;

function str_gline_badchan(b:boolean):bytestring;
begin
  if b then result := 'BADCHAN' else result := 'GLINE';
end;

function str_gline_local(b:boolean):bytestring;
begin
  if b then result := 'local ' else result := '';
end;

function findgline(s:bytestring):tgline;
var
  gl:tgline;
begin
  {return g-line with the same mask}
  result := nil;
  if s = '' then exit;
  gl := tgline(glist);

  while gl <> nil do begin
    if strcompup(gl.mask,s) then begin
      result := gl;
      exit
    end;
    gl := tgline(gl.next);
  end;
end;

function convertglinemask(s:bytestring):bytestring;
begin
  result := s;
  if (s[1] = '&') or (s[1] = '#') or (s[1] = '$') then exit;   {badchan or special}
  if pos('@',result) = 0 then result := '*@'+result;
end;

procedure freegline(gl:tgline);
begin
  linklistdel(glist,tlinklist(gl));
  gl.destroy;
end;

procedure gline_propagate(cptr,sptr:tuser;gl:tgline);
var
  s,s2:bytestring;
  uline:boolean;
begin
  if islocalgline(gl) then exit; {dont propagate it}

  uline := (gl.lastmod = 0) and isulinedserver(sptr);

  if uline and not isactivegline(gl) then begin
    s := '';
  end else begin
    s := s + ' '+inttostr(gl.expire-irctime);
    if not (uline and (gl.lastmod = 0)) then s := s + ' '+inttostr(gl.lastmod);
    s := s + ' :'+gl.reason;
  end;
  if (gl.flags and glineflag_force) <> 0 then s2 := '!' else s2 := '';
  sendto_serversbutone(cptr,
  sprefix(sptr,TOK_GLINE)+'* '+
  s2+str_min_plus(isactivegline(gl))+gl.mask+s);
end;

procedure applygline(gl:tgline);
var
  us:tuser;
  a:integer;
  ch,ch2:tchannel;
  bm:tbanmask;
begin
  if not isactivegline(gl) then exit;

  if isbadchan(gl) then begin
    ch := tchannel(globalchanlist);
    while ch <> nil do begin
      ch2 := tchannel(ch.next);
      if maskmatchup(gl.mask,ch.name) then begin
        while ch.localuser <> nil do begin
          us := tuser(ch.localuser.p);
          sendto_serversbutone(me,sprefix(me,TOK_KICK)+ch.name+' '+us.idstr+' :Bad channel ('+gl.reason+')');
          sendto_one(us,cprefix(me,MSG_KICK)+ch.name+' '+us.name+' :Bad channel ('+gl.reason+')');
          deluserfromchannel(us,ch,nil);
        end;
      end;
      ch := ch2;
    end;
    exit;
  end;

  {check all local clients - using the connectionlist array}

  for a := 0 to highconnection do if connectionlist[a].open then begin
    us := connectionlist[a].user;
    if isclient(us) then begin
      banmaskmake_oneuser(@bm,us.userid,us.host,us.binip);
      if banmaskmatch(@gl.bm,@bm) then begin
        locnotice(SNO_GLINE,'G-line active for '+us.name+'['+us.userid+'@'+us.host+']');
        sendreply(us,ERR_YOUREBANNEDCREEP,':*** '+gl.reason+'.');
        if opt.headinsandgline then
        us.error := 'G-lined'
        else
        us.error := 'G-lined ('+gl.reason+#15')';
        us.destroy;
      end;
    end;
  end;
end;

function glineinfostr(gl:tgline):bytestring;
begin
  result := '';

  if isactivegline(gl) then result := result + '+' else
  if isremactivegline(gl) then result := result + '=' else
  result := result + '-';

{  if isbadchan(gl) then result := result + 'b';}
  if gl.lastmod <> 0 then result := result + 'o';
  if islocalgline(gl) then result := result + 'l';
end;

function durationtoexpire(duration:integer):integer;
begin
  if (duration > (irctime - 157680000)) then begin
    result := duration;
  end else begin
    result := duration+irctime;
    if result < 0 then result := maxlongint;
  end;
end;
{
guaranteed:

- mask is non null
- flags does not have "badchan" set.
- gline with exact same mask does not exist yet


ERR_MASKTOOWIDE
ERR_BADEXPIRE
}
procedure addgline(cptr,sptr:tuser;mask,reason:bytestring;duration,lastmod,flags:integer);
var
  expire:integer;
  bm:tbanmask;
  gl,gl2,gl3:tgline;

begin
  if (mask[1] = '#') or (mask[1] = '&') then begin
    flags := flags or glineflag_badchan;
  end else begin

  end;

  expire := durationtoexpire(duration);

  locnotice(SNO_GLINE,sptr.name+' adding '+
  str_gline_local(flags and glineflag_local <> 0)+
  str_gline_badchan(flags and glineflag_badchan <> 0)+
  ' for '+mask+', expiring at '+inttostr(expire)+': '+reason);

  {make the G-line}
  banmaskmake(@bm,mask);

  {check if new g-line is overlapped}
  if not flag_isset(flags,glineflag_badchan) then begin
    gl2 := tgline(glist);
    while gl2 <> nil do begin
      if banmaskmatch(@gl2.bm,@bm) and (gl2.expire >= expire) then begin
        exit;
      end;
      gl2 := tgline(gl2.next);
    end;
  end;

  {remove overlapped G-lines}
  if not flag_isset(flags,glineflag_badchan) then begin
    gl2 := tgline(glist);
    while gl2 <> nil do begin
      gl3 := tgline(gl2.next);
      if not flag_isset(gl2.flags,glineflag_badchan) then if banmaskmatch(@bm,@gl2.bm) and (expire >= gl2.expire) then begin
        freegline(gl2);
      end;
      gl2 := gl3;
    end;
  end;

  gl := tgline.create;
  gl.flags := flags;
  gl.mask := mask;
  gl.bm := bm;
  gl.expire := expire;
  gl.lastmod := lastmod;
  gl.reason := reason;
  linklistadd(glist,tlinklist(gl));

  gline_propagate(cptr,sptr,gl);

  applygline(gl);

  glnextts := irctime+1;
end;

procedure activategline(cptr,sptr:tuser;gl:tgline;mask,reason:bytestring;duration,lastmod,flags:integer);
var
  prevflags:integer;
  noactivechange:boolean;
begin
  prevflags := gl.flags;

  if length(reason) > 1 then gl.reason := reason;

  if flag_isset(flags,glineflag_local) then begin
    gl.flags := gl.flags and not glineflag_ldeact;
  end else begin
    gl.flags := gl.flags or glineflag_active;
    gl.flags := gl.flags and not glineflag_ldeact;
    if gl.lastmod <> 0 then begin
      if gl.lastmod >= lastmod then inc(gl.lastmod) else gl.lastmod := lastmod
    end;
  end;

  noactivechange := (prevflags and glineflag_actmask) = (gl.flags and glineflag_actmask);

  if not isserver(cptr) then begin
    if (((gl.flags and glineflag_actmask) <> 0) and (durationtoexpire(duration) <> gl.expire) and hasprivs(sptr,privs_glineforce)) then begin
      gl.expire := durationtoexpire(duration);
    end else begin
      if noactivechange then exit;
    end;
  end else
    gl.expire := durationtoexpire(duration);

  if noactivechange then begin
    locnotice(SNO_GLINE,sptr.name+' resetting expiration time on '+str_gline_badchan(gl.flags and glineflag_badchan <> 0)+
    ' for '+mask+', expiring at '+inttostr(gl.expire)+': '+gl.reason);
  end else begin
    locnotice(SNO_GLINE,sptr.name+' activating '+str_gline_badchan(gl.flags and glineflag_badchan <> 0)+
    ' for '+mask+', expiring at '+inttostr(gl.expire)+': '+gl.reason);
  end;

  if not flag_isset(flags,glineflag_local) then
  gline_propagate(cptr,sptr,gl);
  applygline(gl);

  glnextts := irctime+1;  
end;

procedure deactivategline(cptr,sptr:tuser;gl:tgline;mask,reason:bytestring;duration,lastmod,flags:integer);
var
  prevflags:integer;
  msg:bytestring;
begin
  prevflags := gl.flags;

  if length(reason) > 1 then gl.reason := reason;

  if islocalgline(gl) then begin
    msg := 'removing local';
  end else
  if (gl.lastmod = 0) and (not flag_isset(flags,glineflag_local)) then begin
    msg := 'removing';
    gl.flags := gl.flags and not glineflag_active;
  end else begin
    msg := 'deactivating';
    if gl.expire > irctime + 86400 then gl.expire := irctime+86400;
    if (flags and glineflag_local) <> 0 then begin
      if flag_isset(gl.flags,glineflag_active) then
      gl.flags := gl.flags or glineflag_ldeact;
    end else begin
      gl.flags := gl.flags and not glineflag_ldeact;
      gl.flags := gl.flags and not glineflag_active;
      if gl.lastmod <> 0 then begin
        if gl.lastmod >= lastmod then inc(gl.lastmod) else gl.lastmod := lastmod
      end;
    end;
    if (prevflags and glineflag_actmask) = (gl.flags and glineflag_actmask) then exit; {was inactive to begin with}
  end;

  locnotice(SNO_GLINE,sptr.name+' '+msg+' '+str_gline_badchan(isbadchan(gl))+' for '+gl.mask+', expiring at '+inttostr(gl.expire)+': '+gl.reason);

  if not flag_isset(flags,glineflag_local) then
  gline_propagate(cptr,sptr,gl);

  if islocalgline(gl) or (gl.lastmod = 0) then freegline(gl);
  glnextts := irctime+1;
end;


{
new:

from U:lined
<sender> GL <target> <[+|-]hostmask> <duration> :<reason>

from other server:
<sender> GL <target> <[+|-]hostmask> <duration> <lastmod> :<reason>





}

{
server can be one server, or nil for global
maskforce means !hostmask
lastmod <> 0 means param present.
ircop handler sets lastmod=irctime before calling this

}

procedure ms_gline(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  mask:bytestring;
  flags:integer;
  lastmod:integer;
  duration:integer;
  target:tuser;
  gl:tgline;
  reason:bytestring;
  s:bytestring;
begin
  if checkneedmoreparams(sptr,cmdnum,2,parc,parv) then exit;

  mask := parv[2];
  flags := 0;

  if mask[1] = '!' then begin
    mask := copy(mask,2,length(mask));
    setflag(flags,glineflag_force);
  end;
  if mask = '' then exit;

  if mask[1] = '+' then begin
    mask := copy(mask,2,length(mask));
    setflag(flags,glineflag_active);
  end else if mask[1] = '-' then begin
    mask := copy(mask,2,length(mask));
  end else exit;

  if mask = '' then exit;

  if copy(mask,1,2) = '*!' then mask := copy(mask,3,500);

  if ((not flag_isset(flags,glineflag_active)) and (parc = 3)) or (parc = 5) then begin
    {UWorld}
    if not flag_isset(sptr.server.flags,servflag_ulined) then begin
      needmoreparams(sptr,cmdnum);
      exit;
    end;
    lastmod := 0;
  end else if parc > 5 then begin
    lastmod := strtointdef(parv[4],0);
    if lastmod = 0 then exit;
  end else begin
    needmoreparams(sptr,cmdnum);
    exit;
  end;

  {target server param}
  if parv[1] = '*' then begin
    {global G-line}
    target := nil;
  end else begin
    target := findnumeric(parv[1]);
    if target = nil then target := findname(parv[1]);

    if target = nil then exit;
    {not existing target}

    if target <> me then begin
      {local gline for other server - pass it on}
      s := sprefix(sptr,TOK_GLINE)+parv[1]+' '+parv[2]+' '+parv[3];
      if lastmod <> 0 then s := s + ' '+inttostr(lastmod);
      s := s + ' :'+parv[parc-1];
      sendto_one(target,s);
      exit;
    end;
    {local G-line for me}
  end;
  if target <> nil then flags := flags or glineflag_local;
  if isserver(sptr) then flags := flags or glineflag_force;

  reason := parv[parc-1];
  duration := strtointdef(parv[3],0);

  {mask := convertglinemask(mask); - dont convert masks from servers to allow future mask formats}
  gl := findgline(mask);

  {from uworld and gline does not exist: only propagate}
  if (not flag_isset(flags,glineflag_active)) and (gl = nil) and (lastmod = 0) then begin
    sendto_serversbutone(sptr,sprefix(sptr,TOK_GLINE)+parv[1]+' '+parv[2]);
    exit;
  end;

  {irc has no more "resetting expiration time" notice
  - different from ircu: allow from server (uline) to change the expiration time,
  in activate/deactivategline
  }

  if assigned(gl) then begin

    {if gline exists and is local, make it global if needed}
    if (flags and glineflag_local = 0) then
    gl.flags := gl.flags and not glineflag_local;

    {incoming gline is older or the same as what we already have, ignore}
    if (gl.lastmod <> 0) and (lastmod <> 0) and (lastmod <= gl.lastmod) then exit;

    if (flags and glineflag_active <> 0) then
    activategline(cptr,sptr,gl,mask,reason,duration,lastmod,flags)
    else
    deactivategline(cptr,sptr,gl,mask,reason,duration,lastmod,flags);

  end else begin
    if flag_isset(flags,glineflag_active) then
    addgline(cptr,sptr,mask,reason,duration,lastmod,flags);
  end;
end;

procedure list_glines(sptr:tuser;mask:bytestring);
var
  gl:tgline;
  bm:tbanmask;
  s:bytestring;
begin
  banmaskmake(@bm,mask);
  gl := tgline(glist);
  while gl <> nil do begin
    if banmaskmatch(@bm,@gl.bm) then sendreply(sptr,RPL_STATSGLINE,'G '+s+gl.mask+' '+inttostr(gl.expire)+' '+glineinfostr(gl)+' :'+gl.reason);
    gl := tgline(gl.next);
  end;
end;

{
from oper:

GLINE !mask = force

GLINE +mask = activate
GLINE -mask = deactivate
GLINE mask = list

      1    2        3
GLINE mask duration reason
GLINE mask target duration reason

- limit on number of global users a G-line affects
}


procedure mo_gline(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  mask:bytestring;
  reason:bytestring;
  duration:integer;
  flags:integer;
  gl:tgline;
  target:tuser;

  bm:tbanmask;
  toowide,toowide2:boolean;
  a,b:integer;
begin
  if checkneedmoreparams(sptr,cmdnum,1,parc,parv) then exit;

  mask := parv[1];
  flags := 0;

  if mask[1] = '!' then begin
    mask := copy(mask,2,length(mask));
    if hasprivs(sptr,privs_glineforce) then setflag(flags,glineflag_force); {privs - gline_force}
  end;
  if mask = '' then exit;

  if mask[1] = '+' then begin
    mask := copy(mask,2,length(mask));
    setflag(flags,glineflag_active);
  end else if mask[1] = '-' then begin
    mask := copy(mask,2,length(mask));
  end else begin
    list_glines(sptr,mask);
    sendreply(sptr,RPL_ENDOFGLIST,getrpl0(RPL_ENDOFGLIST));
    exit;
  end;
  if mask = '' then exit;

  if not hasprivs(sptr,privs_localgline) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;

  if (opt.opergline = 0) then begin
    sendreply(sptr,ERR_DISABLED,MSG_GLINE+' '+getrpl0(ERR_DISABLED));
    exit;
  end;

  if not ((parc > 3) and (parv[3] <> '')) then begin
    needmoreparams(sptr,cmdnum);
    exit;
  end;
  duration := strtointdef(parv[parc-2],0);
  reason := parv[parc-1];

  if isclient(sptr) and myconnect(sptr) then begin

    if (duration <= 0) or (not flag_isset(flags,glineflag_force) and (duration > GLINE_MAX_EXPIRE)) then begin
      sendreply(sptr,ERR_BADEXPIRE,inttostr(duration)+' '+getrpl0(ERR_BADEXPIRE));
      exit;
    end;

    banmaskmake(@bm,mask);

    toowide := false;
    toowide2 := false;


    if not banmaskisbin(@bm) then begin
      if (copy(mask,length(mask),1) = '.') then toowide2 := true;

      if pos('*',mask) <> 0 then toowide := true;
      if not toowide then if pos('?',mask) <> 0 then toowide := true;

      if toowide then begin
        b := 0;
        for a := length(mask) downto 1 do begin
          if mask[a] = '.' then begin
            inc(b);
            if (b >= 2) then break;
          end;
          if (mask[a] = '?') or (mask[a] = '*') and (b < 2) then begin
            toowide2 := true;
            break;
          end;
        end;
      end;
    end else begin
      if (bm.ip.family = AF_INET) then begin
        if (bm.cidr < 16) then toowide2 := true
        else if (bm.cidr <> 32) then toowide := true;
      end else if (bm.ip.family = AF_INET6) then begin
        if (bm.cidr < 28) then toowide2 := true
        else if (bm.cidr <> 128) then toowide := true;
      end;
    end;

    if not flag_isset(flags,glineflag_force) then begin
      {count users <= max (20)}
    end;

    {single userid}
    if ((bm.user <> '') and (pos('*',bm.user) = 0) and (pos('?',bm.user) = 0)) then begin
      toowide := toowide2;
      toowide2 := false;
    end;

    if toowide2 or (toowide and not flag_isset(flags,glineflag_force)) then begin
      sendreply(sptr,ERR_MASKTOOWIDE,mask+' '+getrpl0(ERR_MASKTOOWIDE));
      exit;
    end;

   { ircu doesn't do this

    if flag_isset(flags,glineflag_force) then if (not toowide) and (duration <= GLINE_MAX_EXPIRE) then begin
      sendreply(sptr,ERR_DONTCHEAT,getrpl0(ERR_DONTCHEAT));
      exit;
    end; }

  end;


  if ((parc > 4) and (parv[4] <> '')) then begin
    {target}
    if parv[2] = '*' then begin
      {global gline}
      target := nil;
    end else begin
      target := getremoteserver(parv[2],true);
      if target = nil then begin
        sendnosuchserver(sptr,parv[2]);
        exit;
      end;
    end;
  end else target := me;

  if (target <> me) then begin
    if not hasprivs(sptr,privs_globalgline) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    if (opt.opergline <> 2) then begin
      sendreply(sptr,ERR_DISABLED,MSG_GLINE+' '+getrpl0(ERR_DISABLED));
      exit;
    end;
  end else begin
    setflag(flags,glineflag_local);
  end;

  mask := convertglinemask(mask);

  if (target <> me) and (target <> nil) then begin
    {local on other server}
    sendto_one(target,sprefix(me,TOK_GLINE)+target.idstr+' '+str_min_plus(flag_isset(flags,glineflag_active))+mask+' '+inttostr(duration)+' '+inttostr(irctime)+' :'+reason);
    exit;
  end;

  gl := findgline(mask);

  if assigned(gl) then begin
    if flag_isset(flags,glineflag_active) then
    activategline(cptr,sptr,gl,mask,reason,duration,irctime,flags)
    else
    deactivategline(cptr,sptr,gl,mask,reason,duration,irctime,flags);
  end else begin
   { if flag_isset(flags,glineflag_active) then}
    addgline(cptr,sptr,mask,reason,duration,irctime,flags);
  end;
end;

{called by the ontimer event once/sec}
procedure timehandler;
var
  gl,gl2:tgline;
  a:integer;
begin
  if irctime < glnextts then exit;

  gl := tgline(glist);
  while gl <> nil do begin
    gl2 := tgline(gl.next);
    if getlifetime(gl) <= irctime then begin
      locnotice(SNO_GLINE,str_gline_badchan(flag_isset(gl.flags,glineflag_badchan))+' for '+gl.mask+' expired ('+gl.reason+#15')');
      freegline(gl);
    end;
    gl := gl2;
  end;

  glnextts := maxlongint;
  gl := tgline(glist);
  while gl <> nil do begin
    a := getlifetime(gl);
    if a < glnextts then glnextts := a;
    gl := tgline(gl.next);
  end;
end;

procedure glineburst(target:tuser);
var
  gl:tgline;

begin
  gl := tgline(glist);
  while gl <> nil do begin
    if (gl.lastmod <> 0) and not islocalgline(gl) then
    sendto_one(target,sprefix(me,TOK_GLINE)+'* '+str_min_plus(isremactivegline(gl))+gl.mask+' '+inttostr(gl.expire-irctime)+' '+inttostr(gl.lastmod)+' :'+gl.reason);
    gl := tgline(gl.next);
  end;
end;

function glinebinmatch(us:tuser;var reason:bytestring):boolean;
var
  gl:tgline;
  bm:tbanmask;
begin
  result := false;
  banmaskmake_oneuser(@bm,us.userid,us.host,us.binip);

  gl := tgline(glist);
  while gl <> nil do begin
    if banmaskisbin(@gl.bm) then if gl.bm.nouserid then if banmaskmatch(@gl.bm,@bm) then if isactivegline(gl) then begin
      result := true;
      reason := gl.reason;
      exit
    end;
    gl := tgline(gl.next);
  end;
end;

begin
  glist := nil;
  glnextts := 0;
end.
