(*
 *  beware ircd, Internet Relay Chat server, breplies.pas
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

{
maintaining reply/error strings, and functions to get them.
i use a way which allows changing reply strings at runtime
(they are saved in the ini file as "rpl###=reply")
}

unit breplies;

interface

uses pgtypes;

const
  maxrpl=92;

{
the reples have the number+1000 to easily identify all commands and numerics with a number in functions.
}

RPL_WELCOME         =1001;
RPL_YOURHOST        =1002;
RPL_CREATED         =1003;
RPL_MYINFO          =1004;
RPL_ISUPPORT        =1005;
RPL_SNOMASK         =1008;
RPL_STATMEMTOT      =1009;
RPL_STATMEM         =1010;
RPL_MAP             =1015;
RPL_MAPMORE         =1016;
RPL_MAPEND          =1017;
RPL_TRACELINK       =1200;
RPL_TRACECONNECTING =1201;
RPL_TRACEHANDSHAKE  =1202;
RPL_TRACEUNKNOWN    =1203;
RPL_TRACEOPERATOR   =1204;
RPL_TRACEUSER       =1205;
RPL_TRACESERVER     =1206;
RPL_TRACENEWTYPE    =1208;
RPL_TRACECLASS      =1209;
RPL_STATSLINKINFO   =1211;
RPL_STATSCOMMANDS   =1212;
RPL_STATSCLINE      =1213;
RPL_STATSNLINE      =1214;
RPL_STATSILINE      =1215;
RPL_STATSKLINE      =1216;
RPL_STATSPLINE      =1217;
RPL_STATSYLINE      =1218;
RPL_ENDOFSTATS      =1219;
RPL_UMODEIS         =1221;
RPL_STATSSLINE	    =1229;
RPL_SERVICEINFO     =1231;
RPL_ENDOFSERVICES   =1232;
RPL_SERVICE         =1233;
RPL_SERVLIST        =1234;
RPL_SERVLISTEND     =1235;
RPL_STATSLLINE      =1241;
RPL_STATSUPTIME     =1242;
RPL_STATSOLINE      =1243;
RPL_STATSHLINE      =1244;
RPL_STATSTLINE      =1246;
RPL_STATSGLINE      =1247;
RPL_STATSULINE      =1248;
RPL_STATSDEBUG      =1249;
RPL_STATSCONN       =1250;
RPL_LUSERCLIENT     =1251;
RPL_LUSEROP         =1252;
RPL_LUSERUNKNOWN    =1253;
RPL_LUSERCHANNELS   =1254;
RPL_LUSERME         =1255;
RPL_ADMINME         =1256;
RPL_ADMINLOC1       =1257;
RPL_ADMINLOC2       =1258;
RPL_ADMINEMAIL      =1259;
RPL_TRACELOG        =1261;
RPL_TRACEPING       =1262;
RPL_SILELIST        =1271;
RPL_ENDOFSILELIST   =1272;
RPL_STATSDLINE      =1275;
RPL_GLIST           =1280;
RPL_ENDOFGLIST      =1281;
RPL_NONE            =1300;
RPL_AWAY            =1301;
RPL_USERHOST        =1302;
RPL_ISON            =1303;
RPL_TEXT            =1304;
RPL_UNAWAY          =1305;
RPL_NOWAWAY         =1306;
RPL_USERIP          =1340;
RPL_WHOISUSER       =1311;
RPL_WHOISSERVER     =1312;
RPL_WHOISOPERATOR   =1313;
RPL_WHOWASUSER      =1314;
RPL_ENDOFWHO        =1315;
RPL_WHOISIDLE       =1317;
RPL_ENDOFWHOIS      =1318;
RPL_WHOISCHANNELS   =1319;
RPL_LISTSTART       =1321;
RPL_LIST            =1322;
RPL_LISTEND         =1323;
RPL_CHANNELMODEIS   =1324;
RPL_CREATIONTIME    =1329;
RPL_WHOISACCOUNT    =1330;
RPL_NOTOPIC         =1331;
RPL_TOPIC           =1332;
RPL_TOPICWHOTIME    =1333;
RPL_LISTUSAGE       =1334;
RPL_INVITING        =1341;
RPL_INVITELIST      =1346;
RPL_ENDOFINVITELIST =1347;
RPL_VERSION         =1351;
RPL_WHOREPLY        =1352;
RPL_NAMREPLY        =1353;
RPL_WHOSPCRPL       =1354;
RPL_KILLDONE        =1361;
RPL_CLOSING         =1362;
RPL_CLOSEEND        =1363;
RPL_LINKS           =1364;
RPL_ENDOFLINKS      =1365;
RPL_ENDOFNAMES      =1366;
RPL_BANLIST         =1367;
RPL_ENDOFBANLIST    =1368;
RPL_ENDOFWHOWAS     =1369;
RPL_INFO            =1371;
RPL_MOTD            =1372;
RPL_INFOSTART       =1373;
RPL_ENDOFINFO       =1374;
RPL_MOTDSTART       =1375;
RPL_ENDOFMOTD       =1376;
RPL_YOUREOPER       =1381;
RPL_REHASHING       =1382;
RPL_MYPORTIS        =1384;
RPL_NOTOPERANYMORE  =1385;
RPL_WHOISACTUALLY   =1338;
RPL_TIME            =1391;
RPL_HOSTHIDDEN      =1396;
ERR_FIRSTERROR      =1400;
ERR_NOSUCHNICK      =1401;
ERR_NOSUCHSERVER    =1402;
ERR_NOSUCHCHANNEL   =1403;
ERR_CANNOTSENDTOCHAN=1404;
ERR_TOOMANYCHANNELS =1405;
ERR_WASNOSUCHNICK   =1406;
ERR_TOOMANYTARGETS  =1407;
ERR_NOORIGIN        =1409;
ERR_NORECIPIENT     =1411;
ERR_NOTEXTTOSEND    =1412;
ERR_NOTOPLEVEL      =1413;
ERR_WILDTOPLEVEL    =1414;
ERR_QUERYTOOLONG    =1416;
ERR_INPUTTOOLONG    =1417;
ERR_UNKNOWNCOMMAND  =1421;
ERR_NOMOTD          =1422;
ERR_NOADMININFO     =1423;
ERR_NONICKNAMEGIVEN =1431;
ERR_ERRONEUSNICKNAME=1432;
ERR_NICKNAMEINUSE   =1433;
ERR_NICKCOLLISION   =1436;
ERR_BANNICKCHANGE   =1437;
ERR_NICKTOOFAST     =1438;
ERR_TARGETTOOFAST   =1439;
ERR_USERNOTINCHANNEL=1441;
ERR_NOTONCHANNEL    =1442;
ERR_USERONCHANNEL   =1443;
ERR_NOTREGISTERED   =1451;
ERR_NEEDMOREPARAMS  =1461;
ERR_ALREADYREGISTRED=1462;
ERR_NOPERMFORHOST   =1463;
ERR_PASSWDMISMATCH  =1464;
ERR_YOUREBANNEDCREEP=1465;
ERR_YOUWILLBEBANNED =1466;
ERR_KEYSET          =1467;
ERR_INVALIDUSERNAME =1468;
ERR_CHANNELISFULL   =1471;
ERR_UNKNOWNMODE     =1472;
ERR_INVITEONLYCHAN  =1473;
ERR_BANNEDFROMCHAN  =1474;
ERR_BADCHANNELKEY   =1475;
ERR_BADCHANMASK     =1476;
ERR_NEEDREGGEDNICK  =1477;
ERR_BANLISTFULL     =1478;
ERR_BADCHANNAME     =1479;
ERR_NOPRIVILEGES    =1481;
ERR_CHANOPRIVSNEEDED=1482;
ERR_CANTKILLSERVER  =1483;
ERR_ISCHANSERVICE   =1484;
ERR_ACCOUNTONLY     =1486;
ERR_VOICENEEDED     =1489;
ERR_NOOPERHOST      =1491;
ERR_ISOPERLCHAN     =1498;
ERR_UMODEUNKNOWNFLAG=1501;
ERR_USERSDONTMATCH  =1502;
ERR_SILELISTFULL    =1511;
ERR_NOSUCHGLINE     =1512;
ERR_BADPING         =1513;
ERR_BADEXPIRE       =1515;
ERR_DONTCHEAT       =1516;
ERR_DISABLED        =1517;
ERR_TOOMANYUSERS    =1519;
ERR_MASKTOOWIDE     =1520;
ERR_BADHOSTMASK     =1550;
ERR_HOSTUNAVAIL     =1551;

rplconst:array[0..maxrpl] of record
  n:integer;
  s:bytestring
end =(
(n:1;  s:'Welcome to the Internet Relay Network %s'),
(n:5;  s:'are supported by this server'),
(n:8;  s:': Server notice mask (%s)'),
(n:17; s:'End of /MAP'),
(n:218;s:'End of G-line List'),
(n:219;s:'End of /STATS report'),
(n:242;s:'Server Up %s days, %s'),
(n:250;s:'Highest connection count: %s (%s clients)'),
(n:251;s:'There are %s users and %s invisible on %s servers'),
(n:252;s:'operator(s) online'),
(n:253;s:'unknown connection(s)'),
(n:254;s:'channels formed'),
(n:255;s:'I have %s clients and %s servers'),
(n:256;s:'Administrative info'),
(n:265;s:'Current local users: %s  Max: %s'),
(n:266;s:'Current global users: %s  Max: %s'),
(n:272;s:'End of Silence List'),
(n:281;s:'End of G-line List'),
(n:305;s:'You are no longer marked as being away'),
(n:306;s:'You have been marked as being away'),
(n:313;s:'is an IRC Operator'),
(n:315;s:'End of /WHO list.'),
(n:317;s:'seconds idle, signon time'),
(n:318;s:'End of /WHOIS list.'),
(n:323;s:'End of /LIST'),
(n:330;s:'is logged in as'),
(n:331;s:'No topic is set'),
(n:347;s:'End of Invite List'),
(n:365;s:'End of /LINKS list.'),
(n:366;s:'End of /NAMES list.'),
(n:368;s:'End of channel ban list'),
(n:369;s:'End of WHOWAS'),
(n:374;s:'End of /INFO list.'),
(n:375;s:'- %s Message of the day'),
(n:376;s:'End of /MOTD command.'),
(n:381;s:'You are now an IRC Operator'),
(n:382;s:'Rehashing'),
(n:338;s:'Actual user@host, Actual IP'),
(n:396;s:'is now your hidden host'),
(n:401;s:'No such nick'),
(n:402;s:'No such server'),
(n:403;s:'No such channel'),
(n:404;s:'Cannot send to channel'),
(n:405;s:'you have joined too many channels'),
(n:406;s:'There was no such nickname'),
(n:411;s:'No recipient given (%s)'),
(n:412;s:'No text to send'),
(n:416;s:'Too many lines in the output, restrict your query'),
(n:417;s:'Input line was too long'),
(n:421;s:'Unknown command'),
(n:422;s:'MOTD File is missing'),
(n:431;s:'No nickname given'),
(n:423;s:'No administrative info available'),
(n:432;s:'Erroneus nickname'),
(n:433;s:'Nickname is already in use'),
(n:437;s:'Cannot change nickname while banned on channel'),
(n:438;s:'Nick change too fast. Please wait %s seconds.'),
(n:439;s:'Target change too fast. Please wait %s seconds.'),
(n:441;s:'They aren''t on that channel'),
(n:442;s:'You''re not on that channel'),
(n:443;s:'is already on channel'),
(n:451;s:'Register first.'),
(n:461;s:'Not enough parameters'),
(n:462;s:'You may not reregister'),
(n:464;s:'Password incorrect'),
(n:465;s:'You are banned from this server'),
(n:467;s:'Channel key already set'),
(n:471;s:'Cannot join channel (+l)'),
(n:472;s:'is unknown mode char to me'),
(n:473;s:'Cannot join channel (+i)'),
(n:474;s:'Cannot join channel (+b)'),
(n:475;s:'Cannot join channel (+k)'),
(n:477;s:'Cannot join channel (+r)'),
(n:478;s:'Channel ban/ignore list is full'),
(n:479;s:'Cannot join channel (access denied on this server)'),
{(n:481;s:'Permission Denied- You''re not an IRC operator'),}
(n:481;s:'Permission Denied: Insufficient privileges'),
(n:482;s:'You''re not channel operator'),
(n:483;s:'You cant kill a server!'),
(n:484;s:'Cannot kill, kick or deop channel service'),
(n:486;s:'You must be authed in order to message this user'),
(n:489;s:'You''re neither voiced nor channel operator'),
(n:491;s:'No O-lines for your host'),
(n:501;s:'Unknown MODE flag'),
(n:502;s:'Cant change mode for other users'),
(n:511;s:'Your silence list is full'),
(n:513;s:'To connect, type /QUOTE PONG %s'),
(n:515;s:'Bad expire time'),
(n:516;s:'Don''t Cheat'),
(n:517;s:'Command disabled.'),
(n:519;s:'Too many users affected by mask'),
(n:520;s:'Mask is too wide'),
(n:550;s:'Invalid username/hostmask'),
(n:551;s:'sethost not found')
);

var
  rpl:array[0..maxrpl] of string;

{reply reverse lookup - get a reply quickly by knowing the numeric}
rplrev:array[0..999] of integer;
rplnumstr:array[0..999] of string[3];

function getrpl0(num:integer):bytestring;
function getrpl1(num:integer;par1:bytestring):bytestring;
function getrpl2(num:integer;par1,par2:bytestring):bytestring;
function getrpl3(num:integer;par1,par2,par3:bytestring):bytestring;


implementation

uses bstuff;

function rplstr(num:integer):bytestring;
begin
  if rplrev[num] < 0 then begin
    result := 'undefined';
    exit;
  end;
  result := rpl[rplrev[num]];
end;

function getrpl0(num:integer):bytestring;
begin
  result := ':'+rplstr(num-1000);
end;

function getrpl1;
var
  a:integer;
  s:bytestring;
begin
  s := rplstr(num-1000);
  a := pos('%s',s);
  result := ':'+copy(s,1,a-1)+par1+copy(s,a+2,512);
end;

function getrpl2;
var
  a:integer;
  s:bytestring;
begin
  s := rplstr(num-1000);
  a := pos('%s',s);
  result := ':'+copy(s,1,a-1)+par1+copy(s,a+2,512);
  a := pos('%s',result);
  if a > 0 then result := copy(result,1,a-1)+par2+copy(result,a+2,512);
end;

function getrpl3;
var
  a:integer;
  s:bytestring;
begin
  s := rplstr(num-1000);
  a := pos('%s',s);
  result := ':'+copy(s,1,a-1)+par1+copy(s,a+2,512);
  a := pos('%s',result);
  if a > 0 then begin
    result := copy(result,1,a-1)+par2+copy(result,a+2,512);
    a := pos('%s',result);
    if a > 0 then result := copy(result,1,a-1)+par3+copy(result,a+2,512);
  end;
end;

procedure init;
var
  a:integer;
begin
  for a := 0 to 999 do rplrev[a] := -1;
  for a := 0 to maxrpl do begin
    rplrev[rplconst[a].n] := a;
  end;
  for a := 0 to 999 do begin
    rplnumstr[a] := inttostr(a);
    if a < 10 then rplnumstr[a] := '00'+rplnumstr[a]
    else if a < 100 then rplnumstr[a] := '0'+rplnumstr[a];
  end;
end;

begin
  init;
end.

