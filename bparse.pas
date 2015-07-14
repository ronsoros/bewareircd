(*
 *  beware ircd, Internet Relay Chat server, bparse.pas
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

unit bparse;

interface

uses buser,bstuff,bcmds,bconsts,pgtypes,

  b_away,
  b_burst,
  b_connect,
  b_cprivmsg,
  b_desynch,
  b_die,
  b_error,
  b_gline,
  b_invite,
  b_join,
  b_kick,
  b_kill,
  b_links,
  b_list,
  b_map,
  b_mischandlers,
  b_mode,
  b_motd,
  b_names,
  b_nick,
  b_oper,
  b_pong,
  b_privmsg,
  b_server,
  b_settime,
  b_silence,
  b_squit,
  b_stats,
  b_topic,
  b_trace,
  b_restart,
  b_whois,
  b_who,
  b_wallchops,
  b_wallops,
  b_wallusers,
  b_whowas,
  b_help,
  b_quit,
  {$ifndef nosvsnick}
  b_svsnick,
  {$endif}
  {$ifndef nosvsjoin}
  b_svsjoin,
  {$endif}
  {$ifndef noservcmds}
  b_servaliases,
  {$endif}
  {$ifndef no21011}
  b_account,
  b_opmode,
  b_clearmode,
  {$endif}
  {$ifndef nosethost}
  b_sethost,
  {$endif}
  b_get,
  b_rping,
  b_close,
  b_info;

type
  {
  for the idea using a cmdproc table and m_handlers this way, i have looked at ircu source code.
  }
  tcmdproc=procedure(cptr,sptr:tuser;parc:integer;parv:pparams);

  tcmdtable=record
    cmd,tok:bytestring;
    flags:integer;
    punreg:tcmdproc;
    pclient:tcmdproc;
    pserver:tcmdproc;
    poper:tcmdproc;
    pnum:^integer;
  end;

procedure m_yourenotoper(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_ignore(cptr,sptr:tuser;parc:integer;parv:pparams);
function getcmdreversenum(const s:bytestring):integer;

var
  cmdnum:integer;
  rawstr:bytestring;

var
  cmdtable:array[0..numcmds] of tcmdtable=(
(cmd:MSG_PRIVMSG;tok:TOK_PRIVMSG;flags:0;
punreg:m_ignore;pclient:m_privmsg;pserver:m_privmsg;poper:m_privmsg;pnum:@cmdprivmsg),
(cmd:MSG_NICK;tok:TOK_NICK;flags:MFLG_UNREG;
punreg:mu_nick;pclient:mc_nick;pserver:ms_nick;poper:mc_nick;pnum:@cmdnick),
(cmd:MSG_NOTICE;tok:TOK_NOTICE;flags:MFLG_IGNORE;
punreg:m_ignore;pclient:m_privmsg;pserver:m_privmsg;poper:m_privmsg;pnum:@cmdnotice),
(cmd:MSG_JOIN;tok:TOK_JOIN;flags:0;
punreg:m_ignore;pclient:m_join;pserver:ms_join;poper:m_join;pnum:@cmdjoin),
(cmd:MSG_MODE;tok:TOK_MODE;flags:0;
punreg:m_ignore;pclient:m_mode;pserver:ms_mode;poper:m_mode),
(cmd:MSG_QUIT;tok:TOK_QUIT;flags:MFLG_UNREG;
punreg:m_quit;pclient:m_quit;pserver:m_quit;poper:m_quit),
(cmd:MSG_PART;tok:TOK_PART;flags:0;
punreg:m_ignore;pclient:m_part;pserver:m_part;poper:m_part;pnum:@cmdpart),
(cmd:MSG_TOPIC;tok:TOK_TOPIC;flags:0;
punreg:m_ignore;pclient:m_topic;pserver:ms_topic;poper:m_topic),
(cmd:MSG_INVITE;tok:TOK_INVITE;flags:0;
punreg:m_ignore;pclient:m_invite;pserver:m_invite;poper:m_invite),
(cmd:MSG_KICK;tok:TOK_KICK;flags:0;
punreg:m_ignore;pclient:m_kick;pserver:m_kick;poper:m_kick),
(cmd:MSG_WALLOPS;tok:TOK_WALLOPS;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_wallops;poper:m_wallops),
(cmd:MSG_PING;tok:TOK_PING;flags:0;
punreg:m_ignore;pclient:m_ping;pserver:ms_ping;poper:mo_ping),
(cmd:MSG_PONG;tok:TOK_PONG;flags:MFLG_UNREG;
punreg:mu_pong;pclient:m_pong;pserver:m_pong;poper:m_pong),
(cmd:MSG_ERROR;tok:TOK_ERROR;flags:MFLG_UNREG;
punreg:m_error;pclient:m_ignore;pserver:m_error;poper:m_ignore),
(cmd:MSG_KILL;tok:TOK_KILL;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_kill;poper:m_kill;pnum:@cmdkill),
(cmd:MSG_USER;tok:TOK_USER;flags:MFLG_UNREG;
punreg:m_user;pclient:m_alreadyregistered;pserver:m_ignore;poper:m_alreadyregistered),
(cmd:MSG_AWAY;tok:TOK_AWAY;flags:0;
punreg:m_ignore;pclient:m_away;pserver:m_away;poper:m_away),
(cmd:MSG_ISON;tok:TOK_ISON;flags:0;
punreg:m_ignore;pclient:m_ison;pserver:m_ignore;poper:m_ison),
(cmd:MSG_SERVER;tok:TOK_SERVER;flags:MFLG_UNREG;
punreg:mu_server;pclient:m_alreadyregistered;pserver:ms_server;poper:m_alreadyregistered),
(cmd:MSG_SQUIT;tok:TOK_SQUIT;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_squit;poper:m_squit;pnum:@cmdsquit),
(cmd:MSG_WHOIS;tok:TOK_WHOIS;flags:0;
punreg:m_ignore;pclient:m_whois;pserver:m_whois;poper:m_whois;pnum:@cmdwhois),
(cmd:MSG_WHO;tok:TOK_WHO;flags:0;
punreg:m_ignore;pclient:m_who;pserver:m_ignore;poper:m_who),
(cmd:MSG_LIST;tok:TOK_LIST;flags:0;
punreg:m_ignore;pclient:m_list;pserver:m_ignore;poper:m_list),
(cmd:MSG_NAMES;tok:TOK_NAMES;flags:0;
punreg:m_ignore;pclient:m_names;pserver:m_names;poper:m_names),
(cmd:MSG_USERHOST;tok:TOK_USERHOST;flags:0;
punreg:m_ignore;pclient:m_userhost;pserver:m_ignore;poper:m_userhost),
(cmd:MSG_PASS;tok:TOK_PASS;flags:MFLG_UNREG;
punreg:m_pass;pclient:m_alreadyregistered;pserver:m_ignore;poper:m_alreadyregistered),
(cmd:MSG_SILENCE;tok:TOK_SILENCE;flags:0;
punreg:m_ignore;pclient:m_silence;pserver:ms_silence;poper:m_silence),
(cmd:MSG_LUSERS;tok:TOK_LUSERS;flags:0;
punreg:m_ignore;pclient:m_lusers;pserver:m_lusers;poper:m_lusers;pnum:@cmdlusers),
(cmd:MSG_TIME;tok:TOK_TIME;flags:0;
punreg:m_ignore;pclient:m_time;pserver:m_time;poper:m_time;pnum:@cmdtime),
(cmd:MSG_OPER;tok:TOK_OPER;flags:0;
punreg:m_ignore;pclient:m_oper;pserver:m_ignore;poper:m_oper),
(cmd:MSG_CONNECT;tok:TOK_CONNECT;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_connect;poper:m_connect),
(cmd:MSG_VERSION;tok:TOK_VERSION;flags:MFLG_UNREG;
punreg:m_ignore;pclient:m_version;pserver:m_version;poper:m_version;pnum:@cmdversion),
(cmd:MSG_STATS;tok:TOK_STATS;flags:0;
punreg:m_ignore;pclient:m_stats;pserver:m_stats;poper:m_stats),
(cmd:MSG_LINKS;tok:TOK_LINKS;flags:0;
punreg:m_ignore;pclient:m_links;pserver:m_links;poper:m_links;pnum:@cmdlinks),
(cmd:MSG_ADMIN;tok:TOK_ADMIN;flags:MFLG_UNREG;
punreg:m_admin;pclient:m_admin;pserver:m_admin;poper:m_admin;pnum:@cmdadmin),
(cmd:MSG_HELP;tok:TOK_HELP;flags:0;
punreg:m_ignore;pclient:m_help;pserver:m_ignore;poper:m_help),
(cmd:MSG_INFO;tok:TOK_INFO;flags:0;
punreg:m_ignore;pclient:m_info;pserver:m_info;poper:m_info;pnum:@cmdinfo),
(cmd:MSG_MOTD;tok:TOK_MOTD;flags:0;
punreg:m_ignore;pclient:m_motd;pserver:m_motd;poper:m_motd;pnum:@cmdmotd),
(cmd:MSG_SETTIME;tok:TOK_SETTIME;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_settime;poper:m_settime),
(cmd:MSG_REHASH;tok:TOK_REHASH;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_ignore;poper:m_rehash),
(cmd:MSG_MAP;tok:TOK_MAP;flags:0;
punreg:m_ignore;pclient:m_map;pserver:m_map;poper:m_map),
(cmd:MSG_RESTART;tok:TOK_RESTART;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_ignore;poper:m_restart),
(cmd:MSG_DIE;tok:TOK_DIE;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_ignore;poper:m_die),
(cmd:MSG_GLINE;tok:TOK_GLINE;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:ms_gline;poper:mo_gline),
(cmd:MSG_WHOWAS;tok:TOK_WHOWAS;flags:0;
punreg:m_ignore;pclient:m_whowas;pserver:m_ignore;poper:m_whowas),
(cmd:MSG_TRACE;tok:TOK_TRACE;flags:0;
punreg:m_ignore;pclient:m_trace;pserver:m_trace;poper:m_trace),
(cmd:MSG_USERIP;tok:TOK_USERIP;flags:0;
punreg:m_ignore;pclient:m_userip;pserver:m_ignore;poper:m_userip),
(cmd:MSG_BURST;tok:TOK_BURST;flags:0;
punreg:m_ignore;pclient:m_ignore;pserver:m_burst;poper:m_ignore),
(cmd:MSG_END_OF_BURST;tok:TOK_END_OF_BURST;flags:0;
punreg:m_ignore;pclient:m_ignore;pserver:m_end_of_burst;poper:m_ignore),
(cmd:MSG_EOB_ACK;tok:TOK_EOB_ACK;flags:0;
punreg:m_ignore;pclient:m_ignore;pserver:m_eob_ack;poper:m_ignore),
(cmd:MSG_CREATE;tok:TOK_CREATE;flags:0;
punreg:m_ignore;pclient:m_ignore;pserver:ms_create;poper:m_ignore),
(cmd:MSG_DESYNCH;tok:TOK_DESYNCH;flags:0;
punreg:m_ignore;pclient:m_ignore;pserver:m_desynch;poper:m_ignore),
(cmd:MSG_WALLCHOPS;tok:TOK_WALLCHOPS;flags:0;
punreg:m_ignore;pclient:m_wallchops;pserver:m_wallchops;poper:m_wallchops),
(cmd:MSG_WALLVOICES;tok:TOK_WALLVOICES;flags:0;
punreg:m_ignore;pclient:m_wallvoices;pserver:m_wallvoices;poper:m_wallvoices),
(cmd:MSG_CPRIVMSG;tok:TOK_CPRIVMSG;flags:0;
punreg:m_ignore;pclient:m_cprivmsg;pserver:m_ignore;poper:m_cprivmsg;pnum:@cmdcprivmsg),
(cmd:MSG_CNOTICE;tok:TOK_CNOTICE;flags:0;
punreg:m_ignore;pclient:m_cnotice;pserver:m_ignore;poper:m_cnotice),
(cmd:MSG_WALLUSERS;tok:TOK_WALLUSERS;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_wallusers;poper:m_wallusers),

{$ifndef noservcmds}
(cmd:'X';tok:'X';flags:MFLG_RAWSTR;
punreg:m_ignore;pclient:m_servalias;pserver:m_ignore;poper:m_servalias;pnum:@cmdalias1),
(cmd:'X';tok:'X';flags:MFLG_RAWSTR;
punreg:m_ignore;pclient:m_servalias;pserver:m_ignore;poper:m_servalias;pnum:@cmdalias2),
(cmd:'X';tok:'X';flags:MFLG_RAWSTR;
punreg:m_ignore;pclient:m_servalias;pserver:m_ignore;poper:m_servalias;pnum:@cmdalias3),
(cmd:'X';tok:'X';flags:MFLG_RAWSTR;
punreg:m_ignore;pclient:m_servalias;pserver:m_ignore;poper:m_servalias;pnum:@cmdalias4),
(cmd:'X';tok:'X';flags:MFLG_RAWSTR;
punreg:m_ignore;pclient:m_servalias;pserver:m_ignore;poper:m_servalias;pnum:@cmdalias5),
(cmd:'X';tok:'X';flags:MFLG_RAWSTR;
punreg:m_ignore;pclient:m_servalias;pserver:m_ignore;poper:m_servalias;pnum:@cmdalias6),
{$endif}

{$ifndef no21011}
(cmd:MSG_ACCOUNT;tok:TOK_ACCOUNT;flags:0;
punreg:m_ignore;pclient:m_ignore;pserver:m_account;poper:m_ignore;pnum:@cmdaccount),
(cmd:MSG_OPMODE;tok:TOK_OPMODE;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:ms_opmode;poper:m_opmode;pnum:@cmdopmode),
(cmd:MSG_CLEARMODE;tok:TOK_CLEARMODE;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_clearmode;poper:m_clearmode;pnum:@cmdclearmode),
{$endif}

{$ifndef nosethost}
(cmd:MSG_SETHOST;tok:TOK_SETHOST;flags:0;
punreg:m_ignore;pclient:m_sethost;pserver:ms_sethost;poper:m_sethost;pnum:@cmdsethost),
{$endif}

{$ifndef nosvsnick}
(cmd:MSG_SVSNICK;tok:TOK_SVSNICK;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_svsnick;poper:m_svsnick;pnum:@cmdsvsnick),
{$endif}

{$ifndef nosvsjoin}
(cmd:MSG_SVSJOIN;tok:TOK_SVSJOIN;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_svsjoin;poper:m_svsjoin;pnum:@cmdsvsjoin),
{$endif}

(cmd:MSG_GET;tok:TOK_GET;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_get;poper:m_get;pnum:@cmdget),
(cmd:MSG_POST;tok:TOK_POST;flags:MFLG_UNREG;
punreg:m_quit;pclient:m_ignore;pserver:m_ignore;poper:m_ignore),

(cmd:MSG_CLOSE;tok:TOK_CLOSE;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_ignore;poper:m_close),

(cmd:MSG_RPING;tok:TOK_RPING;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_rping;poper:m_rping),
(cmd:MSG_RPONG;tok:TOK_RPONG;flags:0;
punreg:m_ignore;pclient:m_yourenotoper;pserver:m_rpong;poper:m_rpong)
  );

procedure parsecommand(cptr:tuser;const s:bytestring;real:boolean);
function getcmdnum(const s:bytestring):integer;
function gettoknum(const s:bytestring):integer;

procedure init;

var
  histogram:array[0..512] of integer;

implementation

uses bircdunit,bsend,breplies,blinklist,btime,bserver,bsearchtree,bconfig,bsock,bchannel;

function getcmdnum;
label skip,skip2,eind;
var
  a,b:integer;
begin
  {
  command must already be uppercased

  array[0..26*26-1] of integer
  one reverse lookup table for
  first 2 chars of command

  does almost all commands without any loop,
  fallback for normal/slow lookup in case of 2 commands having the same first 2 chars

  tokens are maximum 2 chars, thus always succeed

  after found the command i check if it's really that command,
  and not something arbitrary which has the same first 2 chars
  }
  result := -1;

  a := getcmdreversenum(s);
  b := cmdreverse[a];
  if (b >= 0) then begin
    if cmdtable[b].cmd = s then begin
      result := b;
      goto eind;
    end;
  end;
  if b = -1 then goto skip2; {not found}
  if b = -2 then begin
    for a := 0 to numcmds do if s = cmdtable[a].cmd then begin
      result := a;
      goto eind;
    end;
  end;
  exit;
skip2:
  {is numeric}
  a := strtointdef(s,-1);
  if a <> -1 then result := a + 1000;
  exit;
eind:
  if (result >= 0) and (result <= numcmds) then if flag_isset(cmdtable[result].flags,MFLG_DISABLED) then result := -1;
end;

function gettoknum(const s:bytestring):integer;
label skip,skip2,eind;
var
  a,b:integer;
begin

    a := getcmdreversenum(s);
    b := tokreverse[a];
    if (b >= 0) then begin
      if cmdtable[b].tok = s then begin
        result := b;
        goto eind;
      end else goto skip;
    end;

    if b = -1 then goto skip; {not found in token, try long commands}

    if b = -2 then begin
      for a := 0 to numcmds do if s = cmdtable[a].tok then begin
        result := a;
        goto eind;
      end;
    end;

    {fall through: not found in token, try command
    (should not happen for a server link)
    }


skip:
  result := getcmdnum(s);
  exit;
eind:
  if (result >= 0) and (result <= numcmds) then if flag_isset(cmdtable[result].flags,MFLG_DISABLED) then result := -1;
end;


procedure m_yourenotoper(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
end;

procedure m_ignore(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  {do nothing}
end;

procedure processpenalty(cptr:tuser;const s:bytestring);
begin
  if ispenalized(cptr) then begin
    inc(cptr.penaltytime,2);

    dec(connectionlist[cptr.socknum].penaltyreceivecount,length(s)+4);
    if connectionlist[cptr.socknum].penaltyreceivecount < 0 then connectionlist[cptr.socknum].penaltyreceivecount := 0;
  end;
end;

procedure parsecommand(cptr:tuser;const s:bytestring;real:boolean);
var
  a,b,c,d:integer;
  cmd,cmd2:bytestring;
  numparams:integer;
  newcommand:boolean;
  params:tparams;
  bool:boolean;
  sender:bytestring;
  sptr:tuser;
  s1:bytestring;
  p:tuser;
  {$ifdef bdebug}
  ch:tchannel;
  {$endif}

begin
  if s = '' then exit;

  if length(s) > maxmessagelength then begin
    if isserver(cptr) then begin
      wallops('Too long message from server '+cptr.name+': length '+inttostr(length(s))+' ['+copy(s,1,50)+']');
    end else if isclient(cptr) then begin
      sendreply(cptr,ERR_INPUTTOOLONG,getrpl0(ERR_INPUTTOOLONG));
      processpenalty(cptr,s);
    end;
    exit;
  end;

  inc(histogram[0]);
  inc(histogram[length(s)]);

  {$ifdef bdebug}
  if isserver(cptr) then begin
    ch := findchan(debugchanprefix+cptr.name);
    if ch <>  nil then sendto_channel(ch,cprefix(me,MSG_PRIVMSG)+ch.name+' :'+debugrecvattr+debugstr(s));
  end;
  {$endif}

  if not flag_isset(cptr.flags,userflag_pongneeded)
  then connectionlist[cptr.socknum].pingtime := unixtime;

  connectionlist[cptr.socknum].lastreceived := irctime;

  processpenalty(cptr,s);

  {parsing parameters is done ugly but i think its faster than a
  fancy looking Tstringlist procedure (the Tstringlist needs creating and such)
  --beware}

  a := 1;
  if s[1] = ':' then begin
    newcommand := false;
    a := pos(' ',s);
    sender := copy(s,2,a-2);
  end else begin
    if isserver(cptr) then begin
      newcommand := true;
      a := pos(' ',s);
      sender := copy(s,1,a-1);
    end else begin
      newcommand := false;
      sender := '';
    end;
  end;
  if a = 0 then exit;
  if sender <> '' then if (a >= length(s)) then exit;

  {a is index in parsed string - get index of start of command}
  while s[a] = ' ' do inc(a);
  b := 0;
  c := length(s);
  bool := false;
  while (a <= c) do begin
    if s[a] = ':' then begin
      bool := true;
      break;
    end;
    if b >= 16 then begin
      dec(a);
      bool := true;
      break;
    end;
    d := a;
    while (s[a] <> ' ') and (a <= c) do inc(a);
    params[b] := copy(s,d,a-d);
    inc(b);
    while (s[a] = ' ') and (a <= c) do inc(a)
  end;
  inc(a);
  if bool then begin
    params[b] := copy(s,a,c);
    inc(b)
  end;

  numparams := b;
  if numparams = 0 then exit; {no command, only a :sender prefix}

  cmd2 := params[0];
  cmd := ircupper(cmd2);
  params[0] := sender;
  if params[0] = '' then params[0] := cptr.name;

  if isserver(cptr) then
  cmdnum := gettoknum(cmd)
  else
  cmdnum := getcmdnum(cmd);

  {unknown command}
  if (cmdnum = -1) or (not isserver(cptr) and (cmdnum >= 1000)) then begin
    if isclient(cptr) then begin
      sendreply(cptr,ERR_UNKNOWNCOMMAND,cmd2+' '+getrpl0(ERR_UNKNOWNCOMMAND));
    end else if isserver(cptr) then locnotice(SNO_OLDSNO,'Unknown command from '+cptr.name+': '+cmd2);
    {else if isunreg(cptr) then do nothing}
    exit
  end;

  {get sender from sender-prefix}
  if isserver(cptr) then begin
    if newcommand then begin
      {prefix had no colon, its a numeric}
      sptr := findnumeric(sender);
    end else begin
      {prefix had a colon, it's a name}
      sptr := findname(sender);
    end;
    if sptr = nil then begin
      if (cmdnum = cmdkill) or (cmdnum = cmdsquit) then begin
        sptr := cptr; {KILL, SQUIT exception}
      end else if cmdnum = cmdnick then begin
        if length(sender) > 2 then
          sendto_one(cptr,sprefix(me,TOK_KILL)+sender+' :'+me.name+'!'+me.name+' (unknown numeric nick)');
        exit;
      end else exit;
    end;
    if sptr.from <> cptr.from then exit;
  end else begin
    sptr := cptr;
  end;

  if isunreg(cptr) then if not flag_isset(cmdtable[cmdnum].flags,MFLG_UNREG) then begin
    if not flag_isset(cmdtable[cmdnum].flags,MFLG_IGNORE) then
    sendreply(cptr,ERR_NOTREGISTERED,cmd+' '+getrpl0(ERR_NOTREGISTERED));
    exit;
  end;
  if cmdnum >= 1000 then begin
    {a numeric and it came from a server}
    s1 := '';
    for a := 2 to numparams-1 do begin
      if s1 <> '' then s1 := s1 + ' ';
      if a = numparams-1 then s1 := s1 + ':';
      s1 := s1 + params[a];
    end;
    p := finduser(params[1],newcommand);

    if p = me then exit; {a reply to me, ignore it}

    if p <> nil then begin
      if cmdnum < 1100 then inc(cmdnum,100); {map 000-099 to 100-199}
      {$ifndef nohis}
      if opt.headinsand and myconnect(p) and not isoper(p) and isclient(p) then
      sendmsgto_one(me,p,cmdnum,s1)
      else
      {$endif}
      sendmsgto_one(sptr,p,cmdnum,s1);
    end;
    exit;
  end;

  inc(statsm[cmdnum,0]);
  inc(statsm[cmdnum,1],length(s));

  {i store rawstr globally available, so it can be displayed for debug purpose}
  if (cmdtable[cmdnum].flags and mflg_rawstr <> 0) then rawstr := s;

  if isserver(cptr) then cmdtable[cmdnum].pserver(cptr,sptr,numparams,@params)
  else if isanoper(cptr) then cmdtable[cmdnum].poper(cptr,sptr,numparams,@params)
  else if isclient(cptr) then begin
    if (cmdtable[cmdnum].flags and mflg_operonly <> 0) then
    m_yourenotoper(cptr,sptr,numparams,@params)
    else
    cmdtable[cmdnum].pclient(cptr,sptr,numparams,@params)
  end else cmdtable[cmdnum].punreg(cptr,sptr,numparams,@params);
end;

{convert a command to the number in the reverse lookup table
string must be non-null
}
function getcmdreversenum(const s:bytestring):integer;
var
  a:integer;
begin
  a := byte(s[1]);
  case a of
    65..90:begin
      result := a-65;
    end;
  else
    result := 0;
  end;
  if length(s) >= 2 then begin
    a := byte(s[2]);
    case a of
      65..90:begin
        inc(result,26*(a-65));
      end;
    end;
  end else inc(result,(26*25));
  {
  in earlier versions, 'X' would have the same table entry as 'XA',
  with tokens, this caused a number of entries to be used for 2 tokens,
  causing the slow exception where a command is being searched with a loop.
  now 'X' has the same entry as 'XZ', no tokens like that exist, problem solved.
  }
end;

procedure init;
var
  a,b:integer;
begin
  helpsorted := false;
  fillchar(cmdreverse,sizeof(cmdreverse),$ff);
  fillchar(tokreverse,sizeof(tokreverse),$ff);
  for a := 0 to numcmds do begin
    b := getcmdreversenum(cmdtable[a].cmd);
    if cmdreverse[b] = -1 then cmdreverse[b] := a
    else cmdreverse[b] := -2;
    b := getcmdreversenum(cmdtable[a].tok);
    if tokreverse[b] = -1 then tokreverse[b] := a
    else tokreverse[b] := -2;
  end;
  for a := 0 to numcmds do if cmdtable[a].pnum <> nil then cmdtable[a].pnum^ := a;
end;


end.

