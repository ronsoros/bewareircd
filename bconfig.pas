(*
 *  beware ircd, Internet Relay Chat server, bconfig.pas
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

unit bconfig;

{contains all options and lines, and code to read/write config files}

interface

{$include bircd.inc}

uses blinklist,bstuff,bconsts,classes,unitbanmask,bsend,dnscore,unitmotdcache,pgtypes;

const
  conffile:bytestring='ircd.conf';
  {$ifndef noini}
  inifile:bytestring='bircd.ini';
  {$endif}
  maxclass=99;
  defaultsecretstatsstr='aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTUvVwWxXyYzZ';

type
  tconfline=class(tlinklist)
    c:bytechar;
    s1:bytestring;
    s2:bytestring;
    s3:bytestring;
    s4:bytestring;
    i4:integer;
    i5:integer;
    bm:tbanmask;
  end;

  {K-lines their own list}

var
  opt:record
    {server's identity}
    servername:bytestring;
    servergcos:bytestring;
    admininfo:array[0..2] of bytestring;
    p10num:integer;
    networkname:bytestring;

    mylocaladdr:bytestring;

    {things to do when someone logs in}
    dnslookup:boolean;   {if disabled, users are known by IP}
    dnsserver:bytestring;
    identlookup:boolean; {if disabled, all users have ~prefix}
    nospoof:boolean;
    statusnotices:boolean;{one may find them ugly}
    lookuptimeout:integer;
    send005:boolean;

    {limits, isupport options, etc}
    nicklen:integer;
    topiclen:integer;
    awaylen:integer;
    channamelen:integer;
    maxbans:integer;
    maxchannels:integer;
    floodbufsize:integer;
    accountlen:integer;

    {switches}
    topicburst:boolean;
    quitprefix:boolean;
    irculusers:boolean;
    penalty:boolean;

    {$ifndef nowinnt}
    runasservice:boolean;
    servicename:bytestring;
    {$endif}
    nothrottle:boolean;
    opergline:integer;
    opernoflood:boolean;
    opernotargetlimit:boolean;
    opermodek:boolean;
    reliableclock:boolean;
    hub:boolean;

    nodie:boolean;
    norestart:boolean;

    {switches - policy}
    secretwallops:boolean;
    secretnotices:boolean;
    secretstats:bytestring;
    restrictcreate:integer;
    restrictprivate:boolean;
    secretuserip:boolean;

    {misc}
    createmode:bytestring;
    autousermode:bytestring;
    maxclients:integer;
    randseed:bytestring;
    signalport:bytestring;
    autostart:boolean;
    operonlycmds:bytestring;
    opernowholimit:boolean;
    shortnumerics:boolean;
    netriderkick:boolean;
    listsecretchannels:boolean;
    joinoverride:boolean;
    halfop:boolean;
    starttargets:integer;
    resendmodes:boolean;
    operfailedglobal:boolean;
    maxtotalsendq:integer;
    snodefaultoper:integer;
    usermodehacking:boolean;
    relaxedchannelchars:boolean;

    {$ifndef noqnet}
    qnetmodes:boolean;
    {$endif}
    {$ifndef nodelayed}
    delayedjoin:boolean;
    {$endif}

    shortmotd:boolean;
    shortmotdstr:bytestring;

    {$ifndef novhost}
      {hidden host}
    vhostaccountstr:bytestring;
    vhoststyle:integer;
    vhostcryptstr:bytestring;
    vhostquitreason:bytestring;
    {$endif}

    {$ifndef nohis}
      {head in sand}
    headinsand:boolean;
    headinsandname:bytestring;
    headinsandinfo:bytestring;
    headinsandmapstr:bytestring;
    headinsandkillwho:boolean;
    {$endif}
    headinsandgline:boolean;

    {$ifndef nosvsnick}
    svsnick:integer;
    {$endif}
    {$ifndef nosvsjoin}
    svsjoin:integer;
    {$endif}
    {$ifndef nosethost}
    sethost:boolean;
    sethostfreeform:boolean;
    sethostuser:boolean;
    sethostauto:boolean;
    {$endif}

    {$ifndef no21011}
    u21011:boolean;
    opmode:boolean;
    clearmode:boolean;
    {$endif}

    {$ifndef noservcmds}
      {services}
    servaliases:bytestring;
    {$endif}
  end;


const
  maxoptiontable=53
  {$ifndef nodnsquery}
  +1
  {$endif}
  {$ifndef nowinnt}
  +2
  {$endif}
  {$ifndef nohis}
  +5
  {$endif}
  {$ifndef no21011}
  +4
  {$endif}
  {$ifndef noqnet}
  +1
  {$endif}
  {$ifndef nodelayed}
  +1
  {$endif}
  {$ifndef novhost}
  +4
  {$endif}
  {$ifndef noservcmds}
  +1
  {$endif}
  {$ifndef nosvsnick}
  +1
  {$endif}
  {$ifndef nosvsjoin}
  +1
  {$endif}
  {$ifndef nosethost}
  +4
  {$endif}
  {$ifndef nohalfop}
  +1
  {$endif}
  ;

  opt_int=1;
  opt_bool=2;
  opt_str=3;

type
  toptiontable=record
    p:pointer;   {pointer to option var}
    typ:integer;   {type of option var}
    name:bytestring; {id name of option}
    info:bytestring;  {description}
    min,max:integer;
    def_s:bytestring; {default if string}
    case integer of
      0: (def_i:integer); {default if integer}
      1: (def_b:boolean) {default if boolean}
  end;

var
  optiontable:array[0..maxoptiontable] of toptiontable=(
  (
  p:@opt.createmode;
  typ:opt_str;
  name:'ChannelMode';
  info:'the modes which are set on a channel created by a local client';
  def_s:'nt'),
  (
  p:@opt.autousermode;
  typ:opt_str;
  name:'AutoUserMode';
  info:'the user modes which are set on a connecting local client';
  def_s:''),
  (
  p:@opt.dnslookup;
  typ:opt_bool;
  name:'DNSlookup';
  info:'reverse DNS is done to get the hostname of a connection';
  def_b:true),
  {$ifndef nodnsquery}
  (
  p:@opt.dnsserver;
  typ:opt_str;
  name:'DNSserver';
  info:'contact DNS server directly, instead of windows DNS lookup';
  def_s:''),
  {$endif}
  (
  p:@opt.floodbufsize;
  typ:opt_int;
  name:'FloodBufSize';
  info:'max size of input buffer of client connections';
  def_i:1024),
  (
  p:@opt.hub;
  typ:opt_bool;
  name:'Hub';
  info:'This server can be hub';
  def_b:true),
  (
  p:@opt.identlookup;
  typ:opt_bool;
  name:'Ident';
  info:'identd lookup is performed to get a user''s userid';
  def_b:true),
  (
  p:@opt.irculusers;
  typ:opt_bool;
  name:'IrcuLusers';
  info:'/lusers shows "highest connection count" for ircu look and feel';
  def_b:true),
  (
  p:@opt.listsecretchannels;
  typ:opt_bool;
  name:'ListSecretChannels';
  info:'allow opers to see secret channels using "list S"';
  def_b:false),
  (
  p:@opt.statusnotices;
  typ:opt_bool;
  name:'LookupNotice';
  info:'the notices like "*** looking up your hostname"';
  def_b:true),
  (
  p:@opt.lookuptimeout;
  typ:opt_int;
  name:'LookupTimeout';
  info:'timeout/cancel DNS/ident lookups if it takes longer than nn seconds';
  def_i:12),
  (
  p:@opt.maxbans;
  typ:opt_int;
  name:'MaxBans';
  info:'maximum size of a channel banlist (45)';
  def_i:45),
  (
  p:@opt.maxclients;
  typ:opt_int;
  name:'MaxClients';
  info:'maximum number of local clients (needs restart!)';
  def_i:512),
  (
  p:@opt.maxchannels;
  typ:opt_int;
  name:'MaxJoins';
  info:'maximum channels a user can be member of (10)';
  def_i:10),
  (
  p:@opt.nicklen;
  typ:opt_int;
  name:'MaxNick';
  info:'maximum length of a nick';
  min:9;
  max:maxnicklength;
  def_i:12),
  (
  p:@opt.topiclen;
  typ:opt_int;
  name:'MaxTopic';
  info:'maximum length of topics, quit reasons, etc';
  def_i:160),
  (
  p:@opt.awaylen;
  typ:opt_int;
  name:'AwayLen';
  info:'maximum length of /away message';
  def_i:160),
  (
  p:@opt.channamelen;
  typ:opt_int;
  name:'ChanNameLen';
  info:'maximum length of channel names (200=ircu, 63=old bircd)';
  def_i:200),
 (
  p:@opt.relaxedchannelchars;
  typ:opt_bool;
  name:'RelaxedChannelChars';
  info:'allow control chars (below 32) in channel names';
  def_b:false),
  (
  p:@opt.networkname;
  typ:opt_str;
  name:'NetworkName';
  info:'if non-null, name is shown as NETWORK= token. must not contain spaces.';
  def_s:''),
  (
  p:@opt.maxtotalsendq;
  typ:opt_int;
  name:'MaxTotalSendq';
  info:'maximum size of all sendQ buffers combined';
  def_i:30000000),
  (
  p:@opt.nodie;
  typ:opt_bool;
  name:'NoDie';
  info:'/die can''t be used';
  def_b:false),
  (
  p:@opt.norestart;
  typ:opt_bool;
  name:'NoRestart';
  info:'/restart can''t be used';
  def_b:false),
  (
  p:@opt.nospoof;
  typ:opt_bool;
  name:'NoSpoof';
  info:'anti spoof (pingpong with hard to guess number) is done, for security';
  def_b:true),
  (
  p:@opt.nothrottle;
  typ:opt_bool;
  name:'NoThrottle';
  info:'disable throttling (anti attack) and anti-spam code.';
  def_b:false),
  (
  p:@opt.netriderkick;
  typ:opt_bool;
  name:'NetriderKick';
  info:'use kick to prevent someone from joining a channel with modes +i/k using a netsplit';
  def_b:true),
  {$ifndef nowinnt}
  (
  p:@opt.runasservice;
  typ:opt_bool;
  name:'NTservice';
  info:'program runs as system service (don''t set manually, use bircd install or uninstall)';
  def_b:false),
  (
  p:@opt.servicename;
  typ:opt_str;
  name:'NTserviceName';
  info:'the name of the service in the service manager';
  def_s:'BewareIRCD'),
  {$endif}
  (
  p:@opt.operfailedglobal;
  typ:opt_bool;
  name:'GlobalOperFailed';
  info:'global notice (desync wallops) for failed oper attempt';
  def_b:false),
  (
  p:@opt.opergline;
  typ:opt_int;
  name:'OperGline';
  info:'opers can set/remove G-lines (0=disabed, 1=local G-lines only, 2=Global G-lines)';
  def_i:0),
(
  p:@opt.opermodek;
  typ:opt_bool;
  name:'OperModek';
  info:'oper can set umode +k (network service)';
  def_b:false),
  (
  p:@opt.opernoflood;
  typ:opt_bool;
  name:'OperNoFlood';
  info:'ircops don''t excess flood';
  def_b:false),
  (
  p:@opt.opernotargetlimit;
  typ:opt_bool;
  name:'OperNoTargetLimit';
  info:'ircops always have a free target';
  def_b:true),
  (
  p:@opt.opernowholimit;
  typ:opt_bool;
  name:'OperNoWhoLimit';
  info:'unlimited /WHO reply for opers';
  def_b:false),
  (
  p:@opt.joinoverride;
  typ:opt_bool;
  name:'OperJoinOverride';
  info:'allow opers to join global channels walk through modes using "OVERRIDE" key';
  def_b:true),
  (
  p:@opt.snodefaultoper;
  typ:opt_int;
  name:'SnoDefaultOper';
  info:'default oper server notice mask';
  def_i:SNO_DEFAULTOPER),
  (
  p:@opt.penalty;
  typ:opt_bool;
  name:'Penalty';
  info:'enable flood protection (allow roughly 1 command per 2 seconds)';
  def_b:true),
  (
  p:@opt.quitprefix;
  typ:opt_bool;
  name:'QuitPrefix';
  info:'"Quit: " prefix on user''s quit reasons';
  def_b:true),
  (
  p:@opt.randseed;
  typ:opt_str;
  name:'RandSeed';
  info:'fill in something random and hard to guess here; used for nospoof ping';
  def_s:'12345678'),
  (
  p:@opt.reliableclock;
  typ:opt_bool;
  name:'ReliableClock';
  info:'set if the clock of this pc is kept at the exact time. leave disabled if in doubt.';
  def_b:false),
  (
  p:@opt.resendmodes;
  typ:opt_bool;
  name:'ResendModes';
  info:'resend lower priority membership mode if higher priority mode is unset and lower is set (-o+v)';
  def_b:true),
  (
  p:@opt.restrictprivate;
  typ:opt_bool;
  name:'RestrictPrivate';
  info:'disallow private chat';
  def_b:false),
  (
  p:@opt.restrictcreate;
  typ:opt_int;
  name:'RestrictCreate';
  info:'create channel restriction for users: 0=disabled, 1=can''t create, 2=not chanop';
  def_i:0),
  (
  p:@opt.secretnotices;
  typ:opt_bool;
  name:'SecretNotices';
  info:'non-opers can''t set mode +s (read server notices)';
  def_b:true),
  (
  p:@opt.secretstats;
  typ:opt_str;
  name:'SecretStats';
  info:'non-opers can''t do /stats. include all chars you want to disallow. use "1" to get all default characters';
  def_s:defaultsecretstatsstr),
  (
  p:@opt.secretwallops;
  typ:opt_bool;
  name:'SecretWallops';
  info:'non-opers can''t read wallops, only wallusers';
  def_b:true),
  (
  p:@opt.secretuserip;
  typ:opt_bool;
  name:'SecretUserip';
  info:'non-opers can''t use the /userip command';
  def_b:false),
  (
  p:@opt.send005;
  typ:opt_bool;
  name:'Send005';
  info:'005 reply (ISUPPORT) sent to client to inform about server capabilities';
  def_b:true),
  (
  p:@opt.signalport;
  typ:opt_str;
  name:'SignalPort';
  info:'UDP port (127.0.0.1 only) for rehash, restart, die "signals"';
  def_s:'46789'),
  (
  p:@opt.shortmotd;
  typ:opt_bool;
  name:'ShortMotd';
  info:'Short MOTD, as on undernet';
  def_b:false),
  (
  p:@opt.shortmotdstr;
  typ:opt_str;
  name:'ShortMotdStr';
  info:'Short MOTD welcome string';
  def_s:''),
  (
  p:@opt.shortnumerics;
  typ:opt_bool;
  name:'ShortNumerics';
  info:'send P10 short numerics whenever possible, like universal-ircd. servers/services can be incompatible.';
  def_b:false),
  (
  p:@opt.starttargets;
  typ:opt_int;
  name:'StartTargets';
  info:'initial free targets';
  def_i:10),
  (
  p:@opt.topicburst;
  typ:opt_bool;
  name:'TopicBurst';
  info:'on netburst, server sends channel topics';
  def_b:false),

  {$ifndef nohalfop}
  (
  p:@opt.halfop;
  typ:opt_bool;
  name:'HalfOp';
  info:'enable support for "half op", channel mode +h nick';
  def_b:false),
  {$endif}

  {$ifndef nohis}
  (
  p:@opt.headinsand;
  typ:opt_bool;
  name:'HeadInSand';
  info:'"CFV-165" less relevant info is hidden to make life harder for attackers';
  def_b:false),
  (
  p:@opt.headinsandinfo;
  typ:opt_str;
  name:'HeadInSandDesc';
  info:'server info to display in whois reply (if headinsand is enabled)';
  def_s:'my IRC network'),
  (
  p:@opt.headinsandname;
  typ:opt_str;
  name:'HeadInSandName';
  info:'server name to display in whois reply (if headinsand is enabled)';
  def_s:'*.mynet.org'),
  (
  p:@opt.headinsandmapstr;
  typ:opt_str;
  name:'HeadInSandMapStr';
  info:'/MAP and /LINKS has been disabled reply string';
  def_s:'has been disabled'),
  (
  p:@opt.headinsandkillwho;
  typ:opt_bool;
  name:'HeadInSandKillWho';
  info:'hide sender of KILL, also if it''s not a server';
  def_b:false),
  {$endif}
  (
  p:@opt.headinsandgline;
  typ:opt_bool;
  name:'HeadInSandGline';
  info:'hide G-line reason in Quit';
  def_b:true),
  {$ifndef no21011}
  (
  p:@opt.u21011;
  typ:opt_bool;
  name:'u21011features';
  info:'ircu 2.10.11 new features';
  def_b:true),
  (
  p:@opt.clearmode;
  typ:opt_bool;
  name:'Clearmode';
  info:'enable CLEARMODE for IRCops on this server';
  def_b:true),
  (
  p:@opt.opmode;
  typ:opt_bool;
  name:'OpMode';
  info:'enable OPMODE for IRCops on this server';
  def_b:true),
  (
  p:@opt.usermodehacking;
  typ:opt_bool;
  name:'UserModeHacking';
  info:'allow services to change another user''s modes';
  def_b:false),
  (
  p:@opt.accountlen;
  typ:opt_int;
  name:'AccountLen';
  info:'maximum length of a valid account name';
  def_i:12),
  {$endif}
  {$ifndef noqnet}
  (
  p:@opt.qnetmodes;
  typ:opt_bool;
  name:'QnetModes';
  info:'channel modes +cCNu no colors, no ctcp, no channel notices, no part/quit reasons';
  def_b:false),
  {$endif}
  {$ifndef nodelayed}
  (
  p:@opt.delayedjoin;
  typ:opt_bool;
  name:'DelayedJoin';
  info:'enable support for channel mode +D delayed join/auditorium mode';
  def_b:false),
  {$endif}
  {$ifndef novhost}
  (
  p:@opt.vhostaccountstr;
  typ:opt_str;
  name:'VhostAccountStr';
  info:'hidden host suffix string. also used for other vhost modes than "account"; change this if hosts look "wrong"';
  def_s:'.users.mynet.org'),
  (
  p:@opt.vhostcryptstr;
  typ:opt_str;
  name:'VHostCryptStr';
  info:'hard to guess "seed" string used for IP encryption. must be the same on all servers on the net.';
  def_s:'this is a secret'),
  (
  p:@opt.vhoststyle;
  typ:opt_int;
  name:'VHostStyle';
  info:'virtual host (mode +x) style: 0:disabled 1:account name (ircu2.10.11), 2:crypted IP, 3:host=vhostaccountstr';
  def_i:0),
  (
  p:@opt.vhostquitreason;
  typ:opt_str;
  name:'VHostQuitReason';
  info:'the "quit reason" which appears to other users when one changes host for mode +x';
  def_s:'Registered'),
  {$endif}
  {$ifndef noservcmds}
  (
  p:@opt.servaliases;
  typ:opt_str;
  name:'ServAliases';
  info:'aliases such as /nickserv, syntax is semicolon (;) separated list of command;nick@server';
  def_s:''),
  {$endif}
  {$ifndef nosvsnick}
  (
  p:@opt.svsnick;
  typ:opt_int;
  name:'SvsNick';
  info:'/svsnick command supported (0=no, 1=for services and opers, 2=only for services)';
  def_i:2),
  {$endif}
  {$ifndef nosvsjoin}
  (
  p:@opt.svsjoin;
  typ:opt_int;
  name:'SvsJoin';
  info:'/svsjoin command supported (0=no, 1=for services and opers, 2=only for services)';
  def_i:0),
  {$endif}
  {$ifndef nosethost}
  (
  p:@opt.sethost;
  typ:opt_bool;
  name:'SetHost';
  info:'enable quakenet style /sethost, umode +h';
  def_b:false),
  (
  p:@opt.sethostfreeform;
  typ:opt_bool;
  name:'SetHostFreeform';
  info:'allow opers to set any valid virtual user@host independent of S:lines';
  def_b:false),
  (
  p:@opt.sethostuser;
  typ:opt_bool;
  name:'SetHostUser';
  info:'allow users to use S:lines, quakenet style';
  def_b:false),
  (
  p:@opt.sethostauto;
  typ:opt_bool;
  name:'SetHostAuto';
  info:'matching S:line applies to user on connecting';
  def_b:false),
  {$endif}
  (
  p:@opt.operonlycmds;
  typ:opt_str;
  name:'OperOnlyCmds';
  info:'comma separated list of commands which can only be used by irc operators (without leading slash)';
  def_s:'')
  );



{called on startserver, and on rehash}
procedure init;

{$ifndef noini}
procedure writecfg;
{$endif}

{
ircu ircd.conf lines

P:acceptmask:localIP:SCH:port
U:servermask:juped,nicks:*
T:hostmask:filename
I:ip:clones/pass:host:port:class
Y:class:pingfreq:connfreq:maxlinks:sendq:
}
function addconfline(var list:tconfline;c:bytechar;s1,s2,s3,s4,s5:bytestring):tconfline;
procedure loadconf;
function getyline(classnum:integer):tconfline;

{$ifndef noini}
procedure parseoptions(s:bytestring);
{$endif}

{params must already be uppercased}
function isklined(us_:tobject;var reason:bytestring):boolean;

function isulined(name:bytestring):boolean;

function optionstr(num:integer):bytestring;

var
  conflinelist:tconfline;
  klist:tconfline;
  jupenicklist:tstringlinklist;
  classcount:array[0..maxclass] of integer;

implementation

uses
  breplies,bserver,buser,b_gline,bsock,bparse,bcmds,bdns,lcorernd,btime,
  bchannel,readtxt2,bipcheck,b_servaliases,bircdunit;

function getyline(classnum:integer):tconfline;
var
  p:tconfline;
begin
  result := nil;
  p := conflinelist;
  while p <> nil do begin
    if p.c = 'Y' then if strtointdef(p.s1,0) = classnum then begin
      result := p;
      exit;
    end;
    p := tconfline(p.next);
  end;
end;

function optionstr(num:integer):bytestring;
begin
  case optiontable[num].typ of
      opt_int:result := inttostr(integer(optiontable[num].p^));
      opt_bool:result := inttostr(ord(boolean(optiontable[num].p^)));
      opt_str:result := bytestring(optiontable[num].p^);
    end;
end;

{$ifndef noini}
procedure writecfg;
var
  t:textfile;
  a:integer;

procedure writestr(s1,s2,s3:bytestring);
begin
  writeln(t,s1+'='+s2);
  writeln(t,';'+s3);
  writeln(t);
end;

begin
  assignfile(t,inifile);
  filemode := 2;
  {$i-}rewrite(t);{$i+}
  if ioresult <> 0 then exit;

  for a := 0 to maxoptiontable do begin
    writestr(optiontable[a].name,optionstr(a),optiontable[a].info)
  end;

  {custom replies}
  writeln(t,';example and syntax for how to do custom reply messages:  RPL242=Server Up %s days, %s');
  writeln(t);
  for a := 0 to maxrpl do if rpl[a] <> rplconst[a].s then begin
    writeln(t,'RPL'+inttostr(rplconst[a].n)+'='+rpl[a]);
  end;

  closefile(t);
end;

procedure parseoptions(s:bytestring);
var
  s2,sv,sn:bytestring;
  a,b:integer;
begin
  if s = '' then exit;
  if s[1] = ';' then exit;
  if s[1] = ' ' then exit;
  while s[length(s)] = ' ' do setlength(s,length(s)-1); {strip off spaces at the end}

      s2 := ircupper(s);
      a := pos('=',s);
      if a <> 0 then begin
        sv := copy(s2,1,a-1);
        sn := copy(s,a+1,length(s))
      end;

      for a := 0 to maxoptiontable do if ircupper(optiontable[a].name) = sv then begin
        case optiontable[a].typ of
          opt_int:begin
            b := strtointdef(sn,integer(optiontable[a].p^));
            if (optiontable[a].min <> 0) and (optiontable[a].max <> 0) then begin
              if b < optiontable[a].min then b := optiontable[a].min;
              if b > optiontable[a].max then b := optiontable[a].max;
            end;
            integer(optiontable[a].p^) := b;
          end;
          opt_bool:begin
            if sn = '0' then
            boolean(optiontable[a].p^) := false
            else if sn = '1' then
            boolean(optiontable[a].p^) := true
          end;
          opt_str:begin
            bytestring(optiontable[a].p^) := sn;
          end;
        end;
        break;
      end;


      {custon replies}
      if copy(sv,1,3) = 'RPL' then begin
        a := strtointdef(copy(sv,4,3),-1);
        if a >= 0 then begin
          if rplrev[a] >= 0 then rpl[rplrev[a]] := sn;
        end;
      end;

      {options not (yet) used}
      (*
      if sv = 'OPERGLINE' then opergline := sn = '1';
      if sv = 'OPERJOINLIMIT' then operjoinlimit := sn = '1';

      if sv = 'SCANNER' then scannerenable := sn = '1';
      if sv = 'SCANNERSERVICE' then scannerservice := sn;
      if sv = 'SCANWINGATE' then scanwingateenable := sn = '1';
      if sv = 'SCANPORTS' then parsescanports(sn);
      *)
end;

procedure loadini;
var
  failedtoopen:boolean;
  a:integer;
  Pt:treadtxt;
begin
  failedtoopen := false;

  try
    pt := treadtxt.createf(inifile);
  except
    pt := nil;
  end;

  if not assigned(pt) then begin
    failedtoopen := true;
    if serverisrunning then begin
      locnotice(SNO_OLDSNO,'Error opening '+inifile);
      exit;
    end;
  end;

  {set default options from table}
  for a := 0 to maxoptiontable do begin
    case optiontable[a].typ of
      opt_int:integer(optiontable[a].p^) := optiontable[a].def_i;
      opt_bool:boolean(optiontable[a].p^) := optiontable[a].def_b;
      opt_str:bytestring(optiontable[a].p^) := optiontable[a].def_s;
    end;
  end;

  for a := 0 to maxrpl do rpl[a] := rplconst[a].s;

  if failedtoopen then exit;

  while not pt.eof do parseoptions(pt.readline);
  pt.destroy;
end;
{$endif}

procedure loadconf;
var
  p:tparams;
  s,s2:bytestring;
  c:bytechar;
  p2:tconfline;
  parc,a:integer;
  sl:tstringlinklist;
  cl:tconfline;
  failedtoopen:boolean;
  pt:treadtxt;
  bool:boolean;
begin
  failedtoopen := false;
  try
    pt := treadtxt.createf(conffile);
  except
    pt := nil;
  end;
  if not assigned(pt) then begin
    failedtoopen := true;
    if serverisrunning then begin
      locnotice(SNO_OLDSNO,'Error opening '+conffile);
      exit;
    end;
  end;

  while conflinelist <> nil do begin
    p2 := conflinelist;
    linklistdel(tlinklist(conflinelist),tlinklist(conflinelist));
    p2.destroy;
  end;
  while klist <> nil do begin
    p2 := klist;
    linklistdel(tlinklist(klist),tlinklist(klist));
    p2.destroy;
  end;

  while jupenicklist <> nil do begin
    sl := jupenicklist;
    linklistdel(tlinklist(jupenicklist),tlinklist(jupenicklist));
    sl.destroy;
  end;

  with opt do begin
    {in ircd.conf}
    {default servername/info}
    servername := 'my.server.name';
    servergcos := '<insert catchy phrase here>';
    for a := 0 to 2 do admininfo[a] := '';
    if p10num = 0 then p10num := randomdword and SSmask;
  end;

  if failedtoopen then begin
    {no ircd.conf, add default conf lines}
    addconfline(conflinelist,'P','','','','6667','');
    addconfline(conflinelist,'Y','1','90','0','500','80000');
    addconfline(conflinelist,'I','*@*','3','*@*','','1');
    exit;
  end;

  while not pt.eof do begin
    s := pt.readline;
    if s = '' then continue;
    if s[1] = '#' then continue;
    bool := true;
    for a := 1 to length(s) do begin
      if s[a] = '"' then bool := not bool;
      if s[a] = ':' then if bool then s[a] := #255;
    end;
    parc := strtok(s,#255,@p);
    for a := 0 to parc-1 do begin
      if p[a] <> '' then if p[a,1] = '"' then p[a] := copy(p[a],2,500);
      if p[a] <> '' then if p[a,length(p[a])] = '"' then p[a] := copy(p[a],1,length(p[a])-1);
    end;
    for a := parc to mparams do p[a] := '';
    if length(p[0]) = 1 then begin
      c := p[0,1];
      case c of
        'M':begin
          if parc < 6 then begin
            conwrite('M:line has not enough fields, check colons.');
            halt; {invalid M:line}
          end;
          opt.servername := p[1];
          opt.mylocaladdr := p[2];
          opt.servergcos := p[3];
          if opt.servergcos = '' then begin
            conwrite('empty server info field in M:line');
            halt; {invalid M:line}
          end;
          if p[5] <> '' then begin
            opt.p10num := strtointdef(p[5],opt.p10num) and SSmask;
          end;
          if me <> nil then me.fullname := copy(opt.servergcos,1,maxgcoslength);
        end;
        'A':begin
          opt.admininfo[0] := p[1];
          opt.admininfo[1] := p[2];
          opt.admininfo[2] := p[3];
        end;
        'Y','P','H':addconfline(conflinelist,c,p[1],p[2],p[3],p[4],p[5]);
        'U':begin
          addconfline(conflinelist,c,p[1],p[2],p[3],p[4],p[5]);
          a := 1;
          repeat
            strtok2(p[2],',',a,s2);
            sl := tstringlinklist.create;
            sl.s := ircupper(s2);
            linklistadd(tlinklist(jupenicklist),tlinklist(sl));
          until s2 = '';

        end;
        'K':begin
          cl := addconfline(klist,c,p[1],p[2],p[3],p[4],p[5]);
          if p[3] <> '' then s2 := p[3] else s2 := '*';
          s2 := s2 + '@'+p[1];
          banmaskmake(@cl.bm,s2);
        end;
        'O','o','C','N','T','I':begin
          {lines where the first param is a host/ip mask}
          cl := addconfline(conflinelist,c,p[1],p[2],p[3],p[4],p[5]);
          banmaskmake(@cl.bm,p[1]);
        end;
        {$ifndef nosethost}
        'S':begin
          cl := addconfline(conflinelist,c,p[1],p[2],p[3],p[4],p[5]);
          s2 := p[4];
          if s2 = '' then s2 := '*';
          s2 := s2 + '@';
          if p[3] <> '' then s2 := s2 + p[3] else s2 := s2 + '*';
          banmaskmake(@cl.bm,s2);
        end;
        {$endif}
      end;
    end;
  end;
  pt.destroy;
end;

function addconfline(var list:tconfline;c:bytechar;s1,s2,s3,s4,s5:bytestring):tconfline;
var
  cl:tconfline;
begin
  cl := tconfline.create;
  linklistadd(tlinklist(list),tlinklist(cl));
  cl.c := c;
  cl.s1 := s1;
  cl.s2 := s2;
  cl.s3 := s3;
  cl.s4 := s4;
  cl.i4 := strtointdef(s4,0);
  cl.i5 := strtointdef(s5,0);
  result := cl;
end;

procedure init;
var
  a:integer;
  us:tuser;
  srv:tserver;
  s:bytestring;
  prevshortnumerics:boolean;
  cl:tconfline;
  bm:tbanmask;
begin
  prevshortnumerics := opt.shortnumerics;

  {$ifndef noini}
  loadini;
  {$endif}
  loadconf;
  {things to do after config changed}

  if serverisrunning then bsock.setlistener;

  {update U-lined}
  srv := tserver(globalserverlist);
  while srv <> nil do begin
    if isulined(tuser(srv.us).name) then
    setflag(srv.flags,servflag_ulined)
    else
    clearflag(srv.flags,servflag_ulined);
    srv := tserver(srv.next);
  end;

  {shortnumerics setting changed, convert all numerics}
  if opt.shortnumerics <> prevshortnumerics then begin
    us := tuser(globaluserlist);
    while us <> nil do begin
      if isclient(us) or isserver(us) then us.idstr := convertidstr(us.idstr);
      us := tuser(us.next);
    end;
  end;

  if opt.secretstats = '0' then opt.secretstats := '' else
  if opt.secretstats = '1' then opt.secretstats := defaultsecretstatsstr;

  {check for my numeric changed}
  if me <> nil then begin
    opt.p10num := opt.p10num and SSmask;
    if me.server.p10num <> opt.p10num then if p10server[opt.p10num] = nil then begin
      {my numeric changed, the numeric is not used by another server}
      {break all server links}
      s := convertidstr(p10inttostr(opt.p10num,SSlen));
      for a := 1 to highserverlink do if serverlinklist[a] <> nil then begin
        us := tuser(serverlinklist[a].us);
        us.error := me.name+' server numeric changed: '+me.idstr+' to '+s;
        us.destroy;
      end;

      p10server[me.server.p10num] := nil;
      me.server.p10num := opt.p10num;
      me.idstr := s;
      p10server[me.server.p10num] := me.server;

      {change the idstr of all local clients}
      for a := 0 to highconnection do if connectionlist[a].open then begin
        us := connectionlist[a].user;
        if isclient(us) then begin
          if length(us.idstr) = 3 then begin
            us.idstr := convertidstr(me.idstr+'A'+copy(us.idstr,2,2));
          end else begin
            us.idstr := convertidstr(me.idstr+copy(us.idstr,3,3));
          end;

        end;
      end;
    end;
  end;

  {$ifndef nosvsnick}
    {svsnick: set command enabled or not}
  if (opt.svsnick <> 0) then
  clearflag(cmdtable[cmdsvsnick].flags,MFLG_DISABLED)
  else
  setflag(cmdtable[cmdsvsnick].flags,MFLG_DISABLED);
  {$endif}

  {$ifndef nosvsjoin}
    {svsjoin: set command enabled or not}
  if (opt.svsjoin <> 0) then
  clearflag(cmdtable[cmdsvsjoin].flags,MFLG_DISABLED)
  else
  setflag(cmdtable[cmdsvsjoin].flags,MFLG_DISABLED);
  {$endif}

  {$ifndef nosethost}
    {sethost: set command enabled or not}
  if opt.sethost then
  clearflag(cmdtable[cmdsethost].flags,MFLG_DISABLED)
  else
  setflag(cmdtable[cmdsethost].flags,MFLG_DISABLED);
  {$endif}

  {$ifndef noservcmds}
  setservicealiases(opt.servaliases);
  {$endif}

  {$ifndef no21011}
    {2.10.11 commands enabled or not}
  if opt.u21011 then begin
    clearflag(cmdtable[cmdaccount].flags,MFLG_DISABLED);
    clearflag(cmdtable[cmdopmode].flags,MFLG_DISABLED);
    clearflag(cmdtable[cmdclearmode].flags,MFLG_DISABLED);
  end else begin
    setflag(cmdtable[cmdaccount].flags,MFLG_DISABLED);
    setflag(cmdtable[cmdopmode].flags,MFLG_DISABLED);
    setflag(cmdtable[cmdclearmode].flags,MFLG_DISABLED);
  end;
  {$endif}

  {reliable clock set: force clock = irctime}
  if opt.reliableclock then settime(0);

  {$ifndef no21011}
  chanmodetable[chanmodetable_reggedonly].disabled := not opt.u21011;
  {$endif}

  {$ifndef noqnet}
  chanmodetable[chanmodetable_nocolors].disabled := not opt.qnetmodes;
  chanmodetable[chanmodetable_noctcp].disabled := not opt.qnetmodes;
  chanmodetable[chanmodetable_noquitreason].disabled := not opt.qnetmodes;
  chanmodetable[chanmodetable_nonotice].disabled := not opt.qnetmodes;
  usermodetable[usermodetable_reggedonly].disabled := not opt.qnetmodes;
  {$endif}
  {$ifndef nodelayed}
  chanmodetable[chanmodetable_delayedjoin].disabled := not opt.delayedjoin;
  chanmodetable[chanmodetable_delayedjoin2].disabled := not opt.delayedjoin;
  {$endif}
  {$ifndef nohalfop}
  userchanmodetable[userchanmodetable_halfop].disabled := not opt.halfop;
  {$endif}
  schanmodesupported := ''; {invalidate supported chanmodes}
  sisupportchanmodes := '';
  susermodesupported := '';

  {motd cache}
  clearmotdcache;

  {clear cached unix dns server info}
  cleardnsservercache;

  {update operonly commands}
  for a := 0 to numcmds do clearflag(cmdtable[a].flags,mflg_operonly);
  s := ','+ircupper(opt.operonlycmds)+',';
  for a := 0 to numcmds do begin
    if pos(','+cmdtable[a].cmd+',',s) <> 0 then setflag(cmdtable[a].flags,mflg_operonly);
  end;

  if opt.starttargets < 1 then opt.starttargets := 1;
  if opt.starttargets > maxtargets then opt.starttargets := maxtargets;

  {apply K:lines}

  if serverisrunning then for a := 0 to highconnection do if connectionlist[a].open then begin
    us := connectionlist[a].user;
    if isclient(us) then begin
      banmaskmake_oneuser(@bm,us.userid,us.host,us.binip);

      cl := klist;
      while cl <> nil do begin
        if banmaskmatch(@cl.bm,@bm) then begin
          us.error := 'K-lined';
          us.destroy;
          break;
        end;
        cl := tconfline(cl.next);
      end;
    end;
  end;

end;

function isklined(us_:tobject;var reason:bytestring):boolean;
var
  p:tconfline;
  gl:tgline;
  bm:tbanmask;
  us:tuser;
begin
  result := false;
  us := tuser(us_);
  banmaskmake_oneuser(@bm,us.userid,us.host,us.binip);

  gl := tgline(glist);
  while gl <> nil do begin
    if banmaskmatch(@gl.bm,@bm) then
    if isactivegline(gl) then begin
      result := true;
      reason := gl.reason;
      exit
    end;
    gl := tgline(gl.next);
  end;

  p := klist;
  while p <> nil do begin
    if banmaskmatch(@p.bm,@bm) then begin
      result := true;
      reason := p.s2;
      exit;
    end;
    p := tconfline(p.next);
  end;
end;

function isulined(name:bytestring):boolean;
var
  p:tconfline;
begin
  result := false;
  name := ircupper(name);
  p := conflinelist;
  while p <> nil do begin
    if p.c = 'U' then if maskmatchup(p.s1,name) then begin
      result := true;
      exit
     end;
    p := tconfline(p.next);
  end;
end;

begin
  opt.p10num := 0;
  conflinelist := nil;
  klist := nil;
  jupenicklist := nil;
end.
