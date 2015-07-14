(*
 *  beware ircd, Internet Relay Chat server, b_join.pas
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


unit b_join;

interface

uses buser,bcmds,bstuff,bipcheck,pgtypes;

procedure m_join(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_part(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_join(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_create(cptr,sptr:tuser;parc:integer;parv:pparams);

procedure remotejoincreate(cptr,sptr:tuser;parc:integer;parv:pparams;creating:boolean);

var
  forcedjoin:boolean=false;

implementation

uses
  bchannel,breplies,bsend,btime,blinklist,bconfig,bconsts,b_gline,bparse,
  b_names,bmodebuf,bserver,bprivs;

const
  magic_remote_join_ts=1270080000;


{
convert foreign language chars to lowercase for channel join
ISO8859-1 (latin1)
map 192-223 to 224-255, except 215 and 223

i did this up to 1.6.1.1
i implemented this once to make channel names case tolerance apply to "high characters",
and to do so in a way that is independent from client support

quakenet and undernet do not do this, and it breaks utf-8 in channel names
so i removed it. uncomment if you need the old behavior for some reason.
}
{
const
  forcelowertable:array[0..255] of byte=(
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
  16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,
  32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,
  48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,
  64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,
  80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,
  96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,
  112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,
  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
  160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
  176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
  240,241,242,243,244,245,246,215,248,249,250,251,252,253,254,223,
  224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
  240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
  );

procedure forcelower(var s:bytestring);
var
  a:integer;
begin
  for a := 1 to length(s) do s[a] := char(forcelowertable[byte(s[a])]);
end;
}

function matchone(key:bytestring;keys:bytestring):boolean;
begin
  result := pos(','+key+',',','+keys+',') <> 0;
end;

procedure m_join(cptr,sptr:tuser;parc:integer;parv:pparams);
label joinskip,invitedskip;
var
  ch:tchannel;
  a,b:integer;
  created,invited:boolean;
  uc:tuserchan;
  chnames,s2,keystr:bytestring;
  p:tlinklist;
  gl:tgline;
  hackjoinstr:bytestring;

function hasoverride:boolean;
begin
  result := false;

  if parc > 2 then if matchone('OVERRIDE',keystr) then begin
    if not ((flag_isset(ch.flags,chanflag_local) and hasprivs(sptr,privs_localjoin))
    or hasprivs(sptr,privs_globaljoin)) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit
    end;
    result := true;
  end;

  if result then if not opt.joinoverride then if not flag_isset(ch.flags,chanflag_local) then begin
    result := false;
    sendreply(sptr,cmdnotice,':function disabled');
  end;
end;

begin
  if checkneedmoreparams(sptr,cmdnum,1,parc,parv) then exit;

  a := 1;
  b := 0;
  chnames := parv[1];
  repeat
    strtok2(chnames,',',a,s2);
    if s2 = '' then break;
    if s2 = '0' then b := a;
  until false;
  if b <> 0 then begin
    {left all channels}
    p := sptr.channel;
    while p <> nil do begin
      uc := getuserchan(sptr,tuserchan(p).ch);
      sendmsgto_channel(sptr,tuserchan(p).ch,cmdpart,tuserchan(p).ch.name+' :Left all channels',uc);
      deluserfromchannel(sptr,tuserchan(p).ch,uc);
      p := sptr.channel;
    end;
    sendto_serversbutone(sptr,sprefix(sptr,TOK_JOIN)+'0');

    chnames := copy(chnames,b,1000);
  end;
  if parc >= 3 then keystr := parv[2] else keystr := '';

  a := 1;
  repeat
    strtok2(chnames,',',a,s2);
    if s2 = '' then break;
    s2 := copy(s2,1,opt.channamelen);
    {forcelower(s2);}

    if not validchannamefromclient(s2) then begin
      sendreply(cptr,ERR_NOSUCHCHANNEL,s2+' '+getrpl0(ERR_NOSUCHCHANNEL));
      goto joinskip;
    end;
    ch := findchan(s2);
    if ch <> nil then if isonchannel(sptr,ch) then goto joinskip;
    if sptr.chancount >= opt.maxchannels then if not isanoper(sptr) then if not forcedjoin then begin
      sendreply(sptr,ERR_TOOMANYCHANNELS,s2+' '+getrpl0(ERR_TOOMANYCHANNELS));
      exit;
    end;

    {check badchan}
    if not isanoper(sptr) then begin
      gl := tgline(glist);
      while gl <> nil do begin
        if flag_isset(gl.flags,glineflag_badchan) then if isactivegline(gl) then if maskmatchup(gl.mask,s2) then begin
          sendreply(sptr,ERR_BADCHANNAME,s2+' '+getrpl0(ERR_BADCHANNAME));
          goto joinskip;
        end;
        gl := tgline(gl.next);
      end;
    end;

    if ch = nil then begin
      if (opt.restrictcreate = 1) then if not isprivileged(sptr) then begin
        sendreply(sptr,ERR_NOSUCHCHANNEL,s2+' '+getrpl0(ERR_NOSUCHCHANNEL));
        goto joinskip;
      end;

      ch := createchannel;
      ch.ts := irctime;
      {$ifndef nomodeless}
      if s2[1] = '+' then begin
        setflag(ch.flags,chanflag_modeless);
        ch.ts := 0;
      end else
      {$endif}
      if s2[1] = '&' then setflag(ch.flags,chanflag_local);
      setchanname(ch,s2);
      created := true;

    end else begin
      hackjoinstr := '';
      if ipcheck_target(sptr,ch) > 0 then goto joinskip;

      created := false;
      {check if the user is allowed to enter}

      invited := isinvited(sptr,ch) or forcedjoin;

      {$ifndef no21011}
      if flag_isset(ch.modeflag,chanmode_reggedonly) then begin
        if invited then goto invitedskip
        else if sptr.account = '' then begin
          if hasoverride then begin
            hackjoinstr := hackjoinstr + 'r';
          end else begin
            sendreply(sptr,ERR_NEEDREGGEDNICK,ch.name+' '+getrpl0(ERR_NEEDREGGEDNICK));
            goto joinskip;
          end;
        end;
      end;
      {$endif}

      if ch.key <> '' then if not matchone(ch.key,keystr) then begin
        if invited then goto invitedskip
        else begin
          if hasoverride then begin
            hackjoinstr := hackjoinstr + 'k';
          end else begin
            sendreply(sptr,ERR_BADCHANNELKEY,ch.name+' '+getrpl0(ERR_BADCHANNELKEY));
            goto joinskip;
          end
        end;
      end;

      if flag_isset(ch.modeflag,chanmode_inviteonly) then begin
        if invited then goto invitedskip
        else begin
          if hasoverride then begin
            hackjoinstr := hackjoinstr + 'i';
          end else begin
            sendreply(sptr,ERR_INVITEONLYCHAN,ch.name+' '+getrpl0(ERR_INVITEONLYCHAN));
            goto joinskip;
          end;
        end;
      end;

      if (ch.limit > 0) and (ch.usercount >= ch.limit) then begin
        if invited then goto invitedskip
        else begin
          if hasoverride then begin
            hackjoinstr := hackjoinstr + 'l';
          end else begin
            sendreply(sptr,ERR_CHANNELISFULL,ch.name+' '+getrpl0(ERR_CHANNELISFULL));
            goto joinskip;
          end
        end;
      end;

      if isbanned(sptr,ch,nil) then begin
        if invited then goto invitedskip
        else begin
          if hasoverride then begin
            hackjoinstr := hackjoinstr + 'b';
          end else begin
            sendreply(sptr,ERR_BANNEDFROMCHAN,ch.name+' '+getrpl0(ERR_BANNEDFROMCHAN));
            goto joinskip;
          end
        end;
      end;

      if hasoverride and (hackjoinstr = '') then begin
        sendreply(sptr,ERR_DONTCHEAT,ch.name+' '+getrpl0(ERR_DONTCHEAT));
        exit;
      end;

      if (hackjoinstr <> '') then begin
        if flag_isset(ch.flags,chanflag_local) then
        locnotice(SNO_HACK4,'HACK(4): '+sptr.name+' JOIN '+ch.name+', overriding modes +'+hackjoinstr)
        else
        desynchwallops('HACK: '+sptr.name+' JOIN '+ch.name+', overriding modes +'+hackjoinstr);
      end;

invitedskip:

      delinvitefromchannel(sptr,ch,nil) {delete invite key}
    end;

    uc := addusertochannel(sptr,ch);
    if created then
    {$ifndef nomodeless}if not flag_isset(ch.flags,chanflag_modeless) then{$endif}
    uc.flags := userchanflag_op;

    {if (ch.ts = 0) or (ch.ts > irctime) then ch.ts := irctime;}
    if not flag_isset(ch.flags,chanflag_local) then begin
      if created {$ifndef nomodeless}and (not flag_isset(ch.flags,chanflag_modeless)){$endif} then
      sendto_serversbutone(sptr,sprefix(sptr,TOK_CREATE)+ch.name+' '+inttostr(ch.ts))
      else
      sendto_serversbutone(sptr,sprefix(sptr,TOK_JOIN)+ch.name+' '+inttostr(ch.ts));
    end;

    if flag_isset(ch.flags,chanflag_local) then
    modebuf_init(sptr,ch,0)
    else
    modebuf_init(sptr,ch,modebufflag_toservers);

    if created then
    {$ifndef nomodeless}if not flag_isset(ch.flags,chanflag_modeless) then{$endif}
    if opt.createmode <> '' then begin
      for b := 0 to maxchanmodetable do begin
        if pos(chanmodetable[b].c,opt.createmode) <> 0 then begin
          setflag(ch.modeflag,chanmodetable[b].flag);
          modebuf_add_flag(true,true,chanmodetable[b].c)
        end;
      end;
    end;
    {$ifndef nomodeless}
    if created then if flag_isset(ch.flags,chanflag_modeless) then begin
      setflag(ch.modeflag,chanmode_noexternal or chanmode_topic);
    end;
    {$endif}

    if (opt.restrictcreate = 2) and (not isprivileged(sptr)) then begin
      if flag_isset(uc.flags,userchanflag_op) then begin
        clearflag(uc.flags,userchanflag_op);
        modebuf_add_user(false,true,'o',uc);
      end;
    end;

    modebuf_finish(false);

    {$ifndef nodelayed}
    if flag_isset(ch.modeflag,chanmode_delayedjoin) then begin
      if not hasopsorvoice(sptr,ch,uc) then begin
        setflag(uc.flags,userchanflag_delayed);
        inc(ch.delayedcount);
      end;
    end;
    {$endif}
    sendmsgto_channel(sptr,ch,cmdjoin,':'+ch.name,uc);

    if ch.topic <> '' then begin
      sendreply(sptr,RPL_TOPIC,ch.name+' :'+ch.topic);
      sendreply(sptr,RPL_TOPICWHOTIME,ch.name+' '+ch.topicby+' '+inttostr(ch.topictime));
    end;


    nameschannel(sptr,ch,0);
joinskip:
  until false;
end;

procedure remotejoincreate(cptr,sptr:tuser;parc:integer;parv:pparams;creating:boolean);
label joinskip;
var
  a,incomingts:integer;
  namestr,s2:bytestring;
  ch:tchannel;
  uc:tuserchan;
  created:boolean;
  p:tlinklist;
  bounce:boolean;
begin
  if (parv[1] = '') or (parc < 2) then exit; {nothing to do}

  if isserver(sptr) then begin
    cptr.error := 'Server '+sptr.name+' tried to join a channel';
    cptr.destroy;
    exit
  end;
  if (parc > 2) then incomingts := strtointdef(parv[2],0) else incomingts := 0;

  if creating and not flag_isset(sptr.server.flags,servflag_joining) then tsfromserver(sptr,incomingts);

  namestr := parv[1];
  a := 1;
  repeat
    strtok2(namestr,',',a,s2);
    if s2 = '' then break;

    if s2 = '0' then begin
      {left all channels}
      p := sptr.channel;
      while p <> nil do begin
        uc := getuserchan(sptr,tuserchan(p).ch);
        sendmsgto_channel(sptr,tuserchan(p).ch,cmdpart,tuserchan(p).ch.name+' :Left all channels',uc);
        deluserfromchannel(sptr,tuserchan(p).ch,uc);
        p := sptr.channel;
      end;

      sendto_serversbutone(sptr,sprefix(sptr,TOK_JOIN)+'0');
      goto joinskip;
    end;


    if (not validchanname(s2) or (copy(s2,1,1) = '&')) then begin
      cptr.error := sptr.name+' tried to join '+s2;
      cptr.destroy;
      exit;
    end;
    ch := findchan(s2);
    if isonchannel(sptr,ch) then goto joinskip;
    if ch = nil then begin
      ch := createchannel;
      {$ifndef nomodeless}
      if s2[1] = '+' then setflag(ch.flags,chanflag_modeless);
      {$endif}
      setchanname(ch,s2);
      created := true;
      if (not creating) and (incomingts = 0) then ch.ts := magic_remote_join_ts
      else ch.ts := incomingts;
    end else created := false;

    if not (creating or created) then ipcheck_target(sptr,ch);

    bounce := (ch.ts <> magic_remote_join_ts) and ((incomingts > ch.ts) or (incomingts < irctime-TS_LAG_TIME));

    uc := addusertochannel(sptr,ch);

    {$ifndef nomodeless}
    if not flag_isset(ch.flags,chanflag_modeless) then
    {$endif}
    if creating then begin
      if bounce then begin
        modebuf_init(cptr,ch,modebufflag_toservers or modebufflag_bounce);
        modebuf_add_user(false,true,'o',uc);
        modebuf_finish(true);
        locnotice(SNO_HACK2,'HACK(2): '+sptr.name+' CREATE '+ch.name+' '+inttostr(incomingts));
      end else begin
        uc.flags := uc.flags or userchanflag_op;
      end;
    end;

    if not bounce then ch.ts := incomingts;

    {$ifndef nodelayed}
    if (ch.modeflag and chanmode_delayedjoin <> 0) and not hasopsorvoice(sptr,ch,uc) then begin
      setflag(uc.flags,userchanflag_delayed);
      inc(ch.delayedcount);
    end else
    {$endif}
    sendto_channel(ch,cprefix(sptr,MSG_JOIN)+':'+ch.name);

    if flag_isset(uc.flags,userchanflag_op) then begin
      sendto_serversbutone(cptr,sprefix(sptr,TOK_CREATE)+ch.name+' '+inttostr(ch.ts));
      modebuf_init(me,ch,modebufflag_tousers);
      modebuf_add_user(true,false,'o',uc);
      modebuf_finish(false);
    end else begin
      sendto_serversbutone(cptr,sprefix(sptr,TOK_JOIN)+ch.name+' '+inttostr(ch.ts));
    end;

joinskip:
  until false;
end;

procedure ms_join(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  remotejoincreate(cptr,sptr,parc,parv,false);
end;

procedure ms_create(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  remotejoincreate(cptr,sptr,parc,parv,true);
end;


procedure m_part(cptr,sptr:tuser;parc:integer;parv:pparams);
label skip;
var
  s1,s2:bytestring;
  a:integer;
  ch:tchannel;
  uc:tuserchan;
  reason:bytestring;
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;

  a := 1;
  s1 := parv[1];
  repeat
    if parc > 2 then reason := parv[parc-1] else reason := '';
    strtok2(s1,',',a,s2);
    if s2 = '' then break;
    ch := findchan(s2);
    if ch = nil then begin
      if cptr = sptr then sendreply(sptr,ERR_NOSUCHCHANNEL,s2+' '+getrpl0(ERR_NOSUCHCHANNEL));
      goto skip;
    end;
    uc := getuserchan(sptr,ch);
    if not assigned(uc) then begin
      if isclient(cptr) then begin
        sendreply(sptr,ERR_NOTONCHANNEL,ch.name+' '+getrpl0(ERR_NOTONCHANNEL))
      end else begin
        {a part for a user not on channel, from a server. propagate because of "transactional kick"}
        sendto_serversbutone(cptr,sprefix(sptr,TOK_PART)+ch.name);
      end;
      goto skip;
    end;
    {permission to speak - zero reason}
    if sptr = cptr then if reason <> '' then begin
      if not cansendtochannel(sptr,ch,uc) then reason := '';
      reason := copy(reason,1,opt.topiclen);

      {$ifndef noqnet}
      if flag_isset(ch.modeflag,chanmode_noquitreason) then reason := '';

        {no colors?}
      if flag_isset(ch.modeflag,chanmode_nocolors) then
      if pos(#3,reason) <> 0 then reason := '';
      {$endif}
    end;
    {send part message}
    if reason <> '' then begin
      if not flag_isset(ch.flags,chanflag_local) then
      sendto_serversbutone(sptr,sprefix(sptr,TOK_PART)+ch.name+' :'+reason);

      sendmsgto_channel(sptr,ch,cmdpart,ch.name+' :'+reason,uc);
    end else begin
      if not flag_isset(ch.flags,chanflag_local) then
      sendto_serversbutone(sptr,sprefix(sptr,TOK_PART)+ch.name);

      sendmsgto_channel(sptr,ch,cmdpart,ch.name,uc);
    end;
    deluserfromchannel(sptr,ch,uc);
skip:
  until false;
end;

end.
