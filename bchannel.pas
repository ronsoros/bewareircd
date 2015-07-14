(*
 *  beware ircd, Internet Relay Chat server, bchannel.pas
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

unit bchannel;

interface

uses blinklist,buser,bstuff,bconsts,bcmds,unitbanmask,pgtypes;

const
  chanmode_inviteonly= $1;
  chanmode_moderated=  $2;
  chanmode_noexternal= $4;
  chanmode_private=    $8;
  chanmode_secret=    $10;
  chanmode_topic=     $20;
  {$ifndef no21011}
  chanmode_reggedonly=$40;
  {$endif}
  {$ifndef noqnet}
  chanmode_nocolors=$80;
  chanmode_noctcp=$100;
  chanmode_noquitreason=$200;
  chanmode_nonotice=$400;
  {$endif}
  {$ifndef nodelayed}
  chanmode_delayedjoin=$800;
  chanmode_delayedjoin2=$1000;
  {$endif}

  chanflag_destroying=$10000;
  {$ifndef nomodeless}
  chanflag_modeless=  $20000;
  {$endif}
  chanflag_local=     $40000;
  chanflag_nameset=   $80000;


  userchanflag_voice=  $1;
  userchanflag_op=     $2;
  {$ifndef nohalfop}
  userchanflag_halfop= $4;
  {$endif}
  userchanflag_banned=$100;
  userchanflag_bancached=$200;

  {$ifndef nodelayed}
  userchanflag_delayed=$400;
  {$endif}

  isupportchantypes={$ifndef nomodeless}'+'+{$endif}'#&';
  hiddenkey='*';

type
  {one ban}
  tban=class(tlinklist)
    mask:bytestring;
    date:integer;
    sender:bytestring;
    bm:tbanmask;
  end;
  tinvite=class(tlinklist2)
    us:tuser;
    ch:tlinklist;
  end;
  tchannel=class(tthing)

    modeflag:integer;
    flags:integer;
    limit:integer;
    key:bytestring;
    user:tlinklist2;
    banlist:tban;
    bancount:integer;
    topic:bytestring;
    topicby:string{$ifdef shortstrings}[maxnicklength]{$endif};
    topictime:integer;
    localuser:tplinklist;
    usercount:integer;
    {$ifndef nodelayed}
    delayedcount:integer;
    {$endif}
    ts:integer;
    invites:tinvite;

    serverlinkcount:array[0..maxserverlink] of smallint;
    {number of non-deaf users behind this link, used for chat routing}

    destructor destroy; override;
  end;

  {channel-user relationship. prev,next are user's channel list. prev2,next2 are channel's user list}
  tuserchan=class(tlinklist2)
    ch:tchannel;
    us:tuser;
    flags:integer; {ops, voice}
    lu:tplinklist; {local-user struct, if any}
  end;

{---------------------------------------------------------------------------------}

var
  {$ifndef no21011}
  chanmodetable_reggedonly,
  {$endif}
  {$ifndef noqnet}
  chanmodetable_nocolors,chanmodetable_noctcp,chanmodetable_noquitreason,chanmodetable_nonotice,
  {$endif}
  {$ifndef nodelayed}
  chanmodetable_delayedjoin,chanmodetable_delayedjoin2,
  {$endif}
  chanmodetable_inviteonly,chanmodetable_moderated,
  chanmodetable_noexternal,chanmodetable_private,
  chanmodetable_secret,chanmodetable_topic:integer;

type
  tchanmodetable=record
    c:bytechar;               {mode char}
    flag:integer;         {mode flag}
    disabled:boolean;     {disabled by options (cant be seen/used by clients)}
    auto:boolean;         {no special precautions needed when changing the mode, by a client}
    num:^integer;
  end;

const
  maxchanmodetable=5
  {$ifndef no21011}+1{$endif}
  {$ifndef noqnet}+4{$endif}
  {$ifndef nodelayed}+2{$endif}
  ;
  chanmodetable:array[0..maxchanmodetable] of tchanmodetable=(
  {$ifndef no21011}
  (c:'r';flag:chanmode_reggedonly;auto:true;num:@chanmodetable_reggedonly),
  {$endif}
  {$ifndef noqnet}
  (c:'c';flag:chanmode_nocolors;auto:true;num:@chanmodetable_nocolors),
  (c:'C';flag:chanmode_noctcp;auto:true;num:@chanmodetable_noctcp),
  (c:'N';flag:chanmode_nonotice;auto:true;num:@chanmodetable_nonotice),
  (c:'u';flag:chanmode_noquitreason;auto:true;num:@chanmodetable_noquitreason),
  {$endif}
  {$ifndef nodelayed}
  (c:'D';flag:chanmode_delayedjoin;num:@chanmodetable_delayedjoin),
  (c:'d';flag:chanmode_delayedjoin2;num:@chanmodetable_delayedjoin2),
  {$endif}
  (c:'i';flag:chanmode_inviteonly;auto:true;num:@chanmodetable_inviteonly),
  (c:'m';flag:chanmode_moderated;auto:true;num:@chanmodetable_moderated),
  (c:'n';flag:chanmode_noexternal;auto:true;num:@chanmodetable_noexternal),
  (c:'p';flag:chanmode_private;num:@chanmodetable_private),
  (c:'s';flag:chanmode_secret;num:@chanmodetable_secret),
  (c:'t';flag:chanmode_topic;auto:true;num:@chanmodetable_topic)
  );

{---------------------------------------------------------------------------------}
type
  tuserchanmodetable=record
    c:bytechar;           {mode char}
    prefix:bytechar;      {prefix char}
    flag:integer;         {mode flag}
    disabled:boolean;     {disabled by options (cant be seen/used by clients)}
    num:^integer;
  end;

{$ifndef nohalfop}
var
  userchanmodetable_halfop:integer;
{$endif}

const
  userchanmodeflagmask=userchanflag_voice+userchanflag_op
  {$ifndef nohalfop}+userchanflag_halfop{$endif}
  ;
  maxuserchanmodetable=1
  {$ifndef nohalfop}+1{$endif}
  ;
  userchanmodetable:array[0..maxuserchanmodetable] of tuserchanmodetable=(
  (c:'v';prefix:'+';flag:userchanflag_voice),
  {$ifndef nohalfop}
  (c:'h';prefix:'%';flag:userchanflag_halfop;num:@userchanmodetable_halfop),
  {$endif}
  (c:'o';prefix:'@';flag:userchanflag_op)
  {op must be last entry in table}
  );

  {definition of all supported list mode types. is used in a number of places
  must be typed because of freepascal}
  listmodessupported:bytestring='b';

  {all mode chars that need a param when setting or unsetting that are not a list or userchan mode}
  setunsetparammodessupported:bytestring='k';

  {all mode chars that need a param when setting but not when unsetting}
  setparammodessupported:bytestring='l';

{---------------------------------------------------------------------------------}
var
  globalchanlist:tlinklist;
  schanmodesupported:bytestring;
  sisupportchanmodes:bytestring;
  channelstayflag:boolean;

function ischanprefix(c:bytechar):boolean;
function validchanname(const s:bytestring):boolean;
function validchannamefromclient(const s:bytestring):boolean;

{return ch for given name, nil if not exists, s does not need to be uppercased}
function findchan(const s:bytestring):tchannel;

function findbanmatch(ch:tchannel;mask:bytestring):tban;

{
change the name of a channel
channel's names don't change, but a routine like this
better allows things like a search tree
}
procedure setchanname(ch:tchannel;const s:bytestring);

{create user/channel relation (but don't send anything)  returns the chanuser}
function addusertochannel(us:tuser;ch:tchannel):tuserchan;

{remove user/channel relation,
if cu is not nil, it is used instead of a slower seacrh
if channel became empty, it is destroyed

the user must be on the channel (no checking done here)
}
procedure deluserfromchannel(us:tuser;ch:tchannel;uc:tuserchan);

{make a new channel, add it to list}
function createchannel:tchannel;

{returns true if us is member of ch. allows parameters to be nil}
function isonchannel(us:tuser;ch:tchannel):boolean;

function getuserchan(us:tuser;ch:tchannel):tuserchan;

{if user can see channel (in whois etc)}
function canseechannel(us:tuser;ch:tchannel):boolean;
function issecret(ch:tchannel):boolean;
function isprivate(ch:tchannel):boolean;
function ismoderated(ch:tchannel):boolean;
function isnoexternal(ch:tchannel):boolean;

function cansendtochannel(us:tuser;ch:tchannel;uc:tuserchan):boolean;
function hasops(us:tuser;ch:tchannel;uc:tuserchan):boolean;
{$ifndef nohalfop}
function hasoporhalfop(us:tuser;ch:tchannel;uc:tuserchan):boolean;
{$endif}
function hasopsorvoice(us:tuser;ch:tchannel;uc:tuserchan):boolean;
function isbanned(us:tuser;ch:tchannel;uc:tuserchan):boolean;

function chanmodestr(ch:tchannel;params:integer):bytestring;

{adds a ban to the channel. if the ban overlaps existing bans,
theyll be removed and a modechange sent to local users}
function addban(sender:tuser;ch:tchannel;const s:bytestring;isopmode:boolean):boolean;

{returns pointer to ban or nil if the ban is not found}
function findban(ch:tchannel;mask:bytestring):tban;

function charhasparam(c:bytechar;setclear:integer):boolean;
procedure setchanmode(ch:tchannel;cptr,sptr:tuser;parc:integer;parv:pparams;isopmode:boolean);

{returns true if the user is invited}
function isinvited(us:tuser;ch:tchannel):boolean;
function addinvitetochannel(us:tuser;ch:tchannel):tinvite;
procedure delinvitefromchannel(us:tuser;ch:tchannel;uc:tinvite);

function chanmodesupported:bytestring;
function isupportchanmodes:bytestring;
function isupportprefix:bytestring;

procedure clearbancache(ch:tchannel);
procedure clearbancacheuser(us:tuser);

procedure bouncechanmode(ch:tchannel;sptr:tuser;parc:integer;parv:pparams;deop:boolean);

{$ifndef nodelayed}
procedure undelay(uc:tuserchan);
procedure modedupdate(ch:tchannel;modebuf:boolean);
{$endif}

procedure serverlinkcountchange(ch:tchannel;linknum,diff:integer);

procedure burst_channels(target:tuser);

implementation

uses bircdunit,bsearchtree,b_list,btime,bsend,breplies,bconfig,bserver,bmodebuf;

var
  chantree:thashtable;

function chanmodesupported:bytestring;
var
  a:integer;
  s:bytestring;
begin
  if schanmodesupported <> '' then begin
    result := schanmodesupported;
    exit;
  end;
  s := '';
  for a := 0 to maxchanmodetable do begin
    if not chanmodetable[a].disabled then s := s + chanmodetable[a].c;
  end;
  s := s + listmodessupported+setunsetparammodessupported+setparammodessupported; {non-flag and non-membership modes}

  for a := 0 to maxuserchanmodetable do if not userchanmodetable[a].disabled then s := s + userchanmodetable[a].c;

  {alphabetically sort s into result, aAbB....}
  result := '';
  for a := 1 to 26 do begin
    if pos(chr(a+96),s) <> 0 then result := result + chr(a+96);
    if pos(chr(a+64),s) <> 0 then result := result + chr(a+64);
  end;
  schanmodesupported := result;
end;

function isupportchanmodes:bytestring;
var
  a:integer;
begin
  if sisupportchanmodes <> '' then begin
    result := sisupportchanmodes;
    exit;
  end;
  result := listmodessupported+','+setunsetparammodessupported+','+setparammodessupported+',';
  for a := 0 to maxchanmodetable do begin
    if not chanmodetable[a].disabled then result := result + chanmodetable[a].c;
  end;
  sisupportchanmodes := result;
end;

function isupportprefix:bytestring;
var
  a:integer;
  s:bytestring;
begin
  result := '(';
  for a := maxuserchanmodetable downto 0 do if not userchanmodetable[a].disabled then begin
    result := result + userchanmodetable[a].c;
    s := s + userchanmodetable[a].prefix;
  end;
  result := result + ')'+s;
end;

function ischanprefix(c:bytechar):boolean;
begin
  result := pos(c,isupportchantypes) > 0;
end;

function validchanname(const s:bytestring):boolean;
var
  a:integer;
begin
  result := false;
  if s = '' then exit;
  if length(s) > opt.channamelen then exit;
  if not ischanprefix(s[1]) then exit;
  if length(s) > 1 then for a := 2 to length(s) do begin
    if (s[a] = #7) or (s[a] = ',') or (s[a] = #0) or (s[a] = #32) then exit
  end;
  result := true
end;

function validchannamefromclient(const s:bytestring):boolean;
var
  a:integer;
begin
  result := false;
  if s = '' then exit;
  if length(s) > opt.channamelen then exit;
  if not ischanprefix(s[1]) then exit;
  if opt.relaxedchannelchars then begin
    if length(s) > 1 then for a := 2 to length(s) do begin
      if (s[a] = #7) or (s[a] = ',') or (s[a] = #0) or (s[a] = #32) then exit
    end;
  end else begin
    if length(s) > 1 then for a := 2 to length(s) do begin
      if (s[a] = ',') or (s[a] <= #32) then exit
    end;
  end;
  result := true
end;

destructor tchannel.destroy;
var
  p:tban;
begin
  if flag_isset(self.flags,chanflag_destroying) then exit;
  setflag(self.flags,chanflag_destroying);

  while self.user <> nil do deluserfromchannel(tuserchan(self.user).us,self,nil);

  {list in progress - remove}
  listinprogress_destroychan(self);

  while self.banlist <> nil do begin
    p := self.banlist;
    linklistdel(tlinklist(self.banlist),tlinklist(self.banlist));
    p.destroy;
  end;

  while self.invites <> nil do begin
    delinvitefromchannel(self.invites.us,self,self.invites) {delete invite key}
  end;

  setchanname(self,'');  {de-init channel name}
  linklistdel(globalchanlist,tlinklist(self));
  dec(count.channels);
  inherited destroy;
end;


function findchan(const s:bytestring):tchannel;
begin
  result := findtree(@chantree,ircupper(s));
end;

procedure serverlinkcountchange(ch:tchannel;linknum,diff:integer);
const
  maxlinkcount=32760;
begin
  if ch.serverlinkcount[linknum] < maxlinkcount then
  inc(ch.serverlinkcount[linknum],diff);
end;

function addusertochannel(us:tuser;ch:tchannel):tuserchan;
var
  uc:tuserchan;
  lu:tplinklist;
begin
  uc := tuserchan.create;

  uc.ch := ch;
  uc.us := us;

  linklistadd(us.channel,tlinklist(uc));
  linklist2add(ch.user,tlinklist2(uc));

  inc(us.chancount);
  inc(ch.usercount);

  if myconnect(us) then begin
    lu := tplinklist.create;
    lu.p := us;
    uc.lu := lu;
    linklistadd(tlinklist(ch.localuser),tlinklist(lu));
  end;
  if not flag_isset(us.modeflag,usermode_deaf)
  then serverlinkcountchange(ch,us.server.serverlinknum,1);
  result := uc;
end;

function addinvitetochannel(us:tuser;ch:tchannel):tinvite;
var
  uc:tinvite;
begin
  uc := tinvite.create;

  uc.ch := ch;
  uc.us := us;

  linklistadd(tlinklist(us.invites),tlinklist(uc));
  linklist2add(tlinklist2(ch.invites),tlinklist2(uc));

  result := uc;
end;

procedure deluserfromchannel(us:tuser;ch:tchannel;uc:tuserchan);
begin
  if uc = nil then begin
    {search userchan}
    uc := tuserchan(us.channel);
    while uc <> nil do begin
      if uc.ch = ch then begin
        break;
      end;
      uc := tuserchan(uc.next);
    end;
  end;

  if uc.lu <> nil then begin
    linklistdel(tlinklist(ch.localuser),tlinklist(uc.lu));
    uc.lu.destroy
  end;

  {$ifndef nodelayed}
  if flag_isset(uc.flags,userchanflag_delayed) then begin
    dec(ch.delayedcount);
    if serverisrunning then begin
      modebuf_init(me,ch,modebufflag_tousers);
      modedupdate(ch,true);
      modebuf_finish(false);
    end;
  end;
  {$endif}

  linklistdel(us.channel,uc);
  linklist2del(ch.user,uc);
  uc.destroy;
  dec(us.chancount);
  dec(ch.usercount);


  if not flag_isset(us.modeflag,usermode_deaf)
  then serverlinkcountchange(ch,us.server.serverlinknum,-1);

  if ch.usercount <= 0 then
  if (not channelstayflag) then
  if not flag_isset(ch.flags,chanflag_destroying) then ch.destroy;
end;


procedure delinvitefromchannel(us:tuser;ch:tchannel;uc:tinvite);
begin
  if uc = nil then begin
    {search userchan}
    uc := tinvite(us.invites);
    while uc <> nil do begin
      if uc.ch = ch then begin
        break;
      end;
      uc := tinvite(uc.next);
    end;
  end;
  if uc = nil then exit;
  linklistdel(tlinklist(us.invites),tlinklist(uc));
  linklist2del(tlinklist2(ch.invites),tlinklist2(uc));
  uc.destroy;
end;

function createchannel;
begin
  result := tchannel.create;
  linklistadd(globalchanlist,tlinklist(result));
  inc(count.channels);
end;

procedure setchanname(ch:tchannel;const s:bytestring);
begin
  if flag_isset(ch.flags,chanflag_nameset) then deltree(@chantree,ircupper(ch.name));
  ch.name := s;
  if ch.name <> '' then begin
    addtree(@chantree,ircupper(ch.name),ch);
    setflag(ch.flags,chanflag_nameset)
  end else
  clearflag(ch.flags,chanflag_nameset);
end;

function isonchannel(us:tuser;ch:tchannel):boolean;
begin
  result := getuserchan(us,ch) <> nil;
end;

function getuserchan(us:tuser;ch:tchannel):tuserchan;
var
  p2:tlinklist2;
begin
  result := nil;
  if (ch = nil) or (us = nil) then exit;
  if us.chancount <= ch.usercount then begin
    {faster to check user for all channels}
    p2 := tlinklist2(us.channel);
    while p2 <> nil do begin
      if tuserchan(p2).ch = ch then begin
        result := tuserchan(p2);
        exit;
      end;
      p2 := tlinklist2(p2.next);
    end;
  end else begin
    {faster to check channel for all users}
    p2 := ch.user;
    while p2 <> nil do begin
      if tuserchan(p2).us = us then begin
        result := tuserchan(p2);
        exit;
      end;
      p2 := p2.next2;
    end;
  end;
end;

function issecret(ch:tchannel):boolean;
begin
  result := flag_isset(ch.modeflag,chanmode_secret);
end;

function isprivate(ch:tchannel):boolean;
begin
  result := flag_isset(ch.modeflag,chanmode_private);
end;

function ismoderated(ch:tchannel):boolean;
begin
  result := flag_isset(ch.modeflag,chanmode_moderated);
end;

function isnoexternal(ch:tchannel):boolean;
begin
  result := flag_isset(ch.modeflag,chanmode_noexternal);
end;

function cansendtochannel(us:tuser;ch:tchannel;uc:tuserchan):boolean;
begin
  result := false;

  if flag_isset(ch.flags,chanflag_local) then if us.server <> me.server then exit;

  if isservice(us) or isserver(us) then begin
    result := true;
    exit;
  end;
  if uc = nil then begin
    uc := tuserchan(us.channel);
    while uc <> nil do begin
      if uc.ch = ch then begin
        break;
      end;
      uc := tuserchan(uc.next);
    end;
  end;
  if uc = nil then begin
    {not on channel}
    result := not (ismoderated(ch) or isnoexternal(ch));
    if result and myconnect(us) then result := not isbanned(us,ch,nil);
    exit;
  end;

  if hasopsorvoice(us,ch,uc) then begin
    result := true;
    exit;
  end;

  if ismoderated(ch) then exit;
  if myconnect(us) then if isbanned(us,ch,uc) then exit;
  result := true;
end;

function hasops(us:tuser;ch:tchannel;uc:tuserchan):boolean;
begin
  result := false;
  if uc = nil then begin
    uc := tuserchan(us.channel);
    while uc <> nil do begin
      if uc.ch = ch then begin
        break;
      end;
      uc := tuserchan(uc.next);
    end;
  end;
  if uc = nil then exit;
  result := flag_isset(uc.flags,userchanflag_op);
end;

{$ifndef nohalfop}
function hasoporhalfop(us:tuser;ch:tchannel;uc:tuserchan):boolean;
begin
  result := false;
  if uc = nil then begin
    uc := tuserchan(us.channel);
    while uc <> nil do begin
      if uc.ch = ch then begin
        break;
      end;
      uc := tuserchan(uc.next);
    end;
  end;
  if uc = nil then exit;
  result := uc.flags and ( userchanflag_op or userchanflag_halfop ) <> 0;
end;
{$endif}

function hasopsorvoice(us:tuser;ch:tchannel;uc:tuserchan):boolean;
begin
  result := false;
  if uc = nil then begin
    uc := tuserchan(us.channel);
    while uc <> nil do begin
      if uc.ch = ch then begin
        break;
      end;
      uc := tuserchan(uc.next);
    end;
  end;
  if uc = nil then exit;
  result := (uc.flags and (
  userchanflag_voice or userchanflag_op
  {$ifndef nohalfop}or userchanflag_halfop{$endif}
  )) <> 0;
end;


{
match the real host and the virtual host
known issue: someone is banned with virtual host, can reconnect and come back without virtual host
}

function isbanned(us:tuser;ch:tchannel;uc:tuserchan):boolean;
label eind;
var
  p:tban;
  bmu:tbanmask_user;
begin
  if assigned(uc) then if flag_isset(uc.flags,userchanflag_bancached) then begin
    result := flag_isset(uc.flags,userchanflag_banned);
    exit;
  end;

  result := false;
  banmaskmatch_user_init(bmu,us);
  p := ch.banlist;
  while p <> nil do begin
    if banmaskmatch_user(bmu,us,p.bm,p.mask) then begin
      result := true;
      goto eind;
    end;
    p := tban(p.next);
  end;
eind:

  if assigned(uc) then begin
    setflag(uc.flags,userchanflag_bancached);
    if result then
    setflag(uc.flags,userchanflag_banned)
    else
    clearflag(uc.flags,userchanflag_banned);
  end;
end;


function canseechannel(us:tuser;ch:tchannel):boolean;
begin
  if not (flag_isset(ch.modeflag,chanmode_secret) or
  flag_isset(ch.modeflag,chanmode_private)) then begin
    result := true;
    exit;
  end;
  result := isonchannel(us,ch);
end;

function chanmodestr(ch:tchannel;params:integer):bytestring;
var
  s2:bytestring;
  a:integer;
begin
  result := '';
  if (ch.modeflag = 0) and (ch.key = '') and (ch.limit = 0) then begin
    exit;
  end;
  {$ifndef nomodeless}
  if flag_isset(ch.flags,chanflag_modeless) then exit;
  {$endif}
  result := ' +';
  s2 := '';

  for a := 0 to maxchanmodetable do begin
    if ch.modeflag and chanmodetable[a].flag <> 0 then result := result + chanmodetable[a].c;
  end;
  if ch.key <> '' then begin
    result := result + 'k';
    if params = 1 then s2 := s2 + ' '+ch.key else s2 := s2 + ' '+hiddenkey;
  end;
  if ch.limit > 0 then begin
    result := result + 'l';
    s2 := s2 + ' '+inttostr(ch.limit);
  end;
  if params <> 0 then result := result + s2;
end;

function addban;
var
  b,b2,b3:tban;
begin
  result := false;

  if findbanmatch(ch,s) <> nil then exit; {already exists/overlapped}

  b := tban.create;
  banmaskmake(@b.bm,s);

  modebuf_init(sender,ch,modebufflag_tousers); {does nothing if called from setchanmode}

  {remove overlapped bans and send (to local clients only)}

  b3 := ch.banlist;
  while b3 <> nil do begin
    b2 := tban(b3.next);
    if banmaskmatch(@b.bm,@b3.bm) then begin
      modebuf_add_str(false,true,'b',b3.mask);

      linklistdel(tlinklist(ch.banlist),tlinklist(b3));
      b3.destroy;
      dec(ch.bancount);
    end;
    b3 := b2;
  end;

  {removing overlapped bans did not cause a free ban}
  if not isserver(sender.from) then if (ch.bancount >= opt.maxbans) then begin
    sendreply(sender,ERR_BANLISTFULL,ch.name+' '+s+' '+getrpl0(ERR_BANLISTFULL));
    b.destroy;
    modebuf_finish(false); {does nothing if called from setchanmode}
    exit;
  end;
  result := true;

  b.mask := s;
  if isopmode then sender := tuser(tserver(sender.server).us);
  if opt.headinsand then if isserver(sender) then sender := me;
  b.sender := sender.name;
  b.date := irctime;
  linklistadd(tlinklist(ch.banlist),tlinklist(b));
  inc(ch.bancount);

  modebuf_finish(false); {does nothing if called from setchanmode}
end;

function findban(ch:tchannel;mask:bytestring):tban;
var
  b:tban;
begin
  result := nil;
  b := ch.banlist;
  while b <> nil do begin
    if strcompup(b.mask,mask) then begin
      result := b;
      exit;
    end;
    b := tban(b.next);
  end;
end;

function findbanmatch(ch:tchannel;mask:bytestring):tban;
var
  b:tban;
  bm:tbanmask;
begin
  result := nil;
  banmaskmake(@bm,mask);

  b := ch.banlist;
  while b <> nil do begin
    if banmaskmatch(@b.bm,@bm) then begin
      result := b;
      exit;
    end;
    b := tban(b.next);
  end;
end;

function charhasparam(c:bytechar;setclear:integer):boolean;
var
  a:integer;
begin
  if pos(c,listmodessupported) <> 0 then begin
    result := true;
    exit;
  end;
  if pos(c,setunsetparammodessupported) <> 0 then begin
    result := true;
    exit;
  end;
  if pos(c,setparammodessupported) <> 0 then begin
    result := setclear = 2;
    exit;
  end;

  for a := 0 to maxuserchanmodetable do if userchanmodetable[a].c = c then begin
    result := true;
    exit;
  end;

  result := false;
end;


function isinvited(us:tuser;ch:tchannel):boolean;
var
  p:tinvite;
begin
  result := false;
  p := tinvite(us.invites);
  while p <> nil do begin
    if p.us = us then if p.ch = ch then begin
      result := true;
      exit
    end;
    p := tinvite(p.next);
  end;
end;


procedure setchanmode(ch:tchannel;cptr,sptr:tuser;parc:integer;parv:pparams;isopmode:boolean);
var
  cc,pc:integer;
  a,setclear:integer;
  s,s2:bytestring;
  ban:tban;
  byserver:boolean;
  chardone:boolean;
  banchanged:boolean;
  wasops:boolean;
  limitdone:boolean;

{+n}
procedure setmodechar(k:bytechar;flag:integer;setclear:integer);
begin
  chardone := true;
  if setclear = 2 then begin
    {if not byserver then} if ch.modeflag and flag <> 0 then exit; {no change}
    modebuf_add_flag(true,true,k);
    ch.modeflag := ch.modeflag or flag;
  end else begin
    {if not byserver then} if ch.modeflag and flag = 0 then exit; {no change}
    modebuf_add_flag(false,true,k);
    ch.modeflag := ch.modeflag and not flag;
  end;
end;

{+o user}
procedure setmodechannick(k:bytechar;flag:integer;setclear:integer;nick:bytestring);
var
  us:tuser;
  uc:tuserchan;
begin
  chardone := true;
  if byserver then
  us := findnumeric(nick)
  else
  us := findnick(nick);
  if us = nil then begin
    if not byserver then if nick <> '' then sendreply(sptr,ERR_NOSUCHNICK,nick+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;
  uc := getuserchan(us,ch);
  if uc = nil then begin
    if not byserver then sendreply(sptr,ERR_USERNOTINCHANNEL,us.name+' '+ch.name+' '+getrpl0(ERR_USERNOTINCHANNEL));
    exit;
  end;

  {$ifndef nohalfop}
  if ((flag = userchanflag_op) or (flag = userchanflag_halfop)) and not wasops and not byserver and not isopmode then begin
    sendreply(sptr,ERR_CHANOPRIVSNEEDED,ch.name+' '+getrpl0(ERR_CHANOPRIVSNEEDED));
    exit;
  end;
  {$endif}

  if setclear = 2 then begin
    {if not byserver then} if uc.flags and flag <> 0 then exit; {no change}
    modebuf_add_user(true,true,k,uc);
    uc.flags := uc.flags or flag;
    {$ifndef nodelayed}
    undelay(uc);
    {$endif}
  end else begin
    {if not byserver then} if uc.flags and flag = 0 then exit; {no change}

    if flag = userchanflag_op then if isservice(uc.us) then if not (byserver or isopmode) then begin
      sendreply(sptr,ERR_ISCHANSERVICE,uc.us.name+' '+uc.ch.name+' '+getrpl0(ERR_ISCHANSERVICE));
      exit;
    end;

    modebuf_add_user(false,true,k,uc);
    uc.flags := uc.flags and not flag;
  end;
end;

begin
  banchanged := false;
  byserver := isserver(cptr);
  wasops := hasops(sptr,ch,nil);
  s := parv[2];
  setclear := 2;
  pc := 3;

  a := modebufflag_toservers or modebufflag_tousers;
  if isopmode then a := a or modebufflag_opmode;
  modebuf_init(sptr,ch,a);

  if isclient(cptr) then
  parv[3+maxmodes] := ''; {trick to have max. 6 modes with parameters}
  a := pos(' ',parv[parc-1]);
  if a > 0 then begin
    parv[parc-1] := copy(parv[parc-1],1,a-1);
  end;
  limitdone := false;
  for cc := 1 to length(s) do begin
    chardone := false;
    case s[cc] of
      '-':setclear := 1;
      '+':setclear := 2;
      else begin

          case s[cc] of
            'p':begin
              chardone := true;
              if setclear = 2 then if flag_isset(ch.modeflag,chanmode_secret) then setmodechar('s',chanmode_secret,1);
              setmodechar('p',chanmode_private,setclear);
            end;
            's':begin
              chardone := true;
              if setclear = 2 then if flag_isset(ch.modeflag,chanmode_private) then setmodechar('p',chanmode_private,1);
              setmodechar('s',chanmode_secret,setclear);
            end;
            {$ifndef nodelayed}
            'D':begin
              if (setclear <> 2) or (opt.delayedjoin) then begin
                {must have exception for +D because of setting +d fake mode}
                chardone := true;
                setmodechar('D',chanmode_delayedjoin,setclear);
                modedupdate(ch,true);
              end;
            end;
            'd':begin
              chardone := true;
            end;
            {$endif}
            'b':begin
              chardone := true;
              if parv[pc] <> '' then begin
                s2 := cookmask(parv[pc]);
                if setclear = 2 then begin


                  if addban(sptr,ch,s2,isopmode) then begin
                    modebuf_add_str(true,true,'b',s2);
                    banchanged := true;
                  end;
                end else begin
                  ban := findban(ch,s2);
                  if ban <> nil then begin
                    linklistdel(tlinklist(ch.banlist),tlinklist(ban));
                    ban.destroy;
                    dec(ch.bancount);
                    modebuf_add_str(false,true,'b',s2);
                    banchanged := true;
                  end;
                end;
              end;
            end;
            'k':if pc < parc then begin
              chardone := true;
              {s2 := '';
              for a := 1 to length(parv[pc]) do if parv[pc,a] > #32 then s2 := s2 + parv[pc,a];}

              s2 := copy(parv[pc],1,maxkeylength);
              if s2 <> '' then begin
                if setclear = 2 then begin
                  if (ch.key <> '') and not (isopmode or isserver(cptr)) then begin
                    sendreply(sptr,ERR_KEYSET,ch.name+' '+getrpl0(ERR_KEYSET));
                  end else begin
                    if ch.key <> s2 then begin
                      ch.key := s2;
                      modebuf_add_str(true,true,'k',ch.key);
                    end;
                  end;
                end else begin
                  if (ircupper(ch.key) = ircupper(s2)) or isopmode or isserver(cptr) then begin
                    if ch.key <> '' then modebuf_add_str(false,true,'k',ch.key);
                    ch.key := '';
                  end;
                end;
              end;
            end else chardone := true;
            'l':begin
              chardone := true;
              if setclear = 2 then begin
                a := strtointdef(parv[pc],0);
                if a > 0 then begin
                  if (a <> ch.limit) then begin
                    if not limitdone then begin
                      limitdone := true;
                      ch.limit := a;
                      modebuf_add_str(true,true,'l',inttostr(ch.limit));
                    end;
                  end;
                end;
              end else begin
                if (ch.limit <> 0) {or byserver} then begin
                  ch.limit := 0;
                  modebuf_add_flag(false,true,'l');
                end;
              end;
            end;
          else
            for a := 0 to maxuserchanmodetable do if userchanmodetable[a].c = s[cc] then begin
              if (setclear <> 2) or (not userchanmodetable[a].disabled) then
              setmodechannick(userchanmodetable[a].c,userchanmodetable[a].flag,setclear,parv[pc]);
            end;
            for a := 0 to maxchanmodetable do if chanmodetable[a].c = s[cc] then
            if chanmodetable[a].auto then begin
              if (setclear <> 2) or (not chanmodetable[a].disabled) then
              setmodechar(chanmodetable[a].c,chanmodetable[a].flag,setclear);
            end;
             {}
          end;
          if not byserver then if not chardone then sendreply(sptr,ERR_UNKNOWNMODE,s[cc]+' '+getrpl0(ERR_UNKNOWNMODE));

      end
    end;
    if charhasparam(s[cc],setclear) then begin
      inc(pc);
      if isclient(cptr) then if pc > 3+maxmodes then pc := 3+maxmodes;
    end;
  end;

  if banchanged then clearbancache(ch);

  modebuf_finish(false);

end;

procedure bouncechanmode(ch:tchannel;sptr:tuser;parc:integer;parv:pparams;deop:boolean);
var
  a,cc,pc:integer;
  setclear:integer;
  s:bytestring;
  us:tuser;
  uc:tuserchan;
  bool:boolean;
  bm:tbanmask;
  ban:tban;
begin
  modebuf_init(sptr.from,ch,modebufflag_bounce or modebufflag_toservers);

  {send deop, if client and is in channel}

  if deop then if isclient(sptr) then begin
    uc := getuserchan(sptr,ch);
    if uc <> nil then modebuf_add_user(false,true,'o',uc);
  end;
  setclear := 0;
  s := parv[2];
  pc := 3;
  for cc := 1 to length(s) do begin
    case s[cc] of
      '-':setclear := 1;
      '+':setclear := 2;
      'k':begin
        if setclear = 2 then
          modebuf_add_str(false,true,s[cc],parv[pc]);
        if ch.key <> '' then modebuf_add_str(true,true,s[cc],ch.key);
        inc(pc);
      end;
      'l':begin
        if setclear = 2 then begin
          if ch.limit > 0 then
          modebuf_add_str(true,true,s[cc],inttostr(ch.limit))
          else
          modebuf_add_flag(false,true,s[cc]);
          inc(pc);
        end else begin
          if ch.limit <> 0 then modebuf_add_str(true,true,s[cc],inttostr(ch.limit));
        end;
      end;
      'b':begin
        if setclear = 2 then begin
          {check that the same (overlapping) ban does not exist, unset this ban, then re-send all overlapped bans}
          banmaskmake(@bm,parv[pc]);
          bool := false;
          ban := ch.banlist;
          while ban <> nil do begin
            if banmaskmatch(@ban.bm,@bm) then begin
              bool := true;
              break;
            end;
            ban := tban(ban.next);
          end;
          if not bool then begin
            modebuf_add_str(false,true,s[cc],parv[pc]);
            ban := ch.banlist;
            while ban <> nil do begin
              if banmaskmatch(@bm,@ban.bm) then modebuf_add_str(true,true,s[cc],ban.mask);
              ban := tban(ban.next);
            end;
          end;
        end else begin
          {set this ban if it exists}
          ban := ch.banlist;
          while ban <> nil do begin
            if strcompup(ban.mask,parv[pc]) then begin
              modebuf_add_str(true,true,s[cc],ban.mask);
              break;
            end;
            ban := tban(ban.next);
          end;
        end;
        inc(pc);
      end;
    else
      for a := 0 to maxuserchanmodetable do if s[cc] = userchanmodetable[a].c then begin
        us := findnumeric(parv[pc]);
        inc(pc);
        if us <> nil then begin
          uc := getuserchan(us,ch);
          if uc <> nil then begin
            bool := flag_isset(uc.flags,userchanmodetable[a].flag);
            if setclear = 2 then begin
              if not bool then modebuf_add_user(false,true,s[cc],uc);
            end else
              if bool then modebuf_add_user(true,true,s[cc],uc);
          end;
        end;
      end;
      for a := 0 to maxchanmodetable do begin
        if s[cc] = chanmodetable[a].c then begin
          if setclear = 2 then begin
            if (ch.modeflag and chanmodetable[a].flag) = 0 then modebuf_add_flag(false,true,s[cc]);
          end else begin
            if (ch.modeflag and chanmodetable[a].flag) <> 0 then modebuf_add_flag(true,true,s[cc]);
          end;
        end;
      end;
    end;
  end;
  modebuf_finish(false);
end;


procedure clearbancache(ch:tchannel);
var
  uc:tuserchan;
begin
  uc := tuserchan(ch.user);
  while uc <> nil do begin
    uc.flags := uc.flags and not (userchanflag_bancached or userchanflag_banned);
    uc := tuserchan(uc.next2);
  end;
end;

procedure clearbancacheuser(us:tuser);
var
  uc:tuserchan;
begin
  uc := tuserchan(us.channel);
  while uc <> nil do begin
    uc.flags := uc.flags and not (userchanflag_bancached or userchanflag_banned);
    uc := tuserchan(uc.next);
  end;
end;


{$ifndef nodelayed}
procedure undelay(uc:tuserchan);
begin
  if uc = nil then exit;
  if not flag_isset(uc.flags,userchanflag_delayed) then exit;
  clearflag(uc.flags,userchanflag_delayed);
  dec(uc.ch.delayedcount);
  sendto_channelbutone(uc.us,uc.ch,cprefix(uc.us,MSG_JOIN)+uc.ch.name);
  modebuf_init(me,uc.ch,modebufflag_tousers);
  modedupdate(uc.ch,true);
  modebuf_finish(false);
end;

procedure modedupdate(ch:tchannel;modebuf:boolean);
var
  needsmalld:boolean;
begin
  needsmalld := (ch.delayedcount > 0) and (not flag_isset(ch.modeflag,chanmode_delayedjoin));
  if flag_isset(ch.modeflag,chanmode_delayedjoin2) xor needsmalld then begin
    if modebuf then modebuf_add_flag(needsmalld,false,chanmodetable[chanmodetable_delayedjoin2].c);
    ch.modeflag := ch.modeflag xor chanmode_delayedjoin2;
  end;
end;
{$endif}

procedure burst_channels(target:tuser);
var
  a,b,c:integer;
  s:bytestring;
  ch:tchannel;
  bool:boolean;
  uc:tuserchan;
  ban:tban;
begin
  ch := tchannel(globalchanlist);
  while ch <> nil do begin
    if not flag_isset(ch.flags,chanflag_local) then begin
      s := sprefix(me,TOK_BURST)+ch.name+' '+inttostr(ch.ts)+chanmodestr(ch,1);
      bool := true;
      b := 0;
      for a := 0 to userchanmodeflagmask do begin
        uc := tuserchan(ch.user);
        while (uc <> nil) do begin
          if (uc.flags and userchanmodeflagmask) = a then begin
            if length(s) > (maxmessagelength-1-5-1-3) then begin {,SSCCC:ovh}
              sendto_one(target,s);
              bool := true;
              s := sprefix(me,TOK_BURST)+ch.name+' '+inttostr(ch.ts);
              b := 0;
            end;
            if bool then begin
              bool := false;
              s := s + ' '
            end else s := s + ',';
            s := s + uc.us.idstr;
            if a <> b then begin
              s := s + ':';
              for c := maxuserchanmodetable downto 0 do if flag_isset(a,userchanmodetable[c].flag) then s := s + userchanmodetable[c].c;
              b := a;
            end;
          end;
          uc := tuserchan(uc.next2);
        end;
      end;
      bool := true;
      ban := ch.banlist;
      while (ban <> nil) do begin
        if length(s)+length(ban.mask) > (maxmessagelength-3) then begin  {_:%}
          sendto_one(target,s);
          bool := true;
          s := sprefix(me,TOK_BURST)+ch.name+' '+inttostr(ch.ts);
        end;
        if bool then begin
          bool := false;
          s := s + ' :%';
        end else s := s + ' ';
        s := s + ban.mask;
        ban := tban(ban.next);
      end;
      sendto_one(target,s);

      if opt.topicburst then if ch.topic <> '' then
      sendto_one(target,sprefix(me,TOK_TOPIC)+ch.name+' '+inttostr(ch.ts)+' '+inttostr(ch.topictime)+' :'+ch.topic);
    end;
    ch := tchannel(ch.next);
  end;
end;

procedure init;
var
  a:integer;
begin
  globalchanlist := nil;

  for a := 0 to maxuserchanmodetable do if userchanmodetable[a].num <> nil then
  userchanmodetable[a].num^ := a;

  for a := 0 to maxchanmodetable do if chanmodetable[a].num <> nil then
  chanmodetable[a].num^ := a;
end;

initialization init;

end.

