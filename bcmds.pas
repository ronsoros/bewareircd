(*
 *  beware ircd, Internet Relay Chat server, bcmds.pas
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

unit bcmds;

interface

uses bstuff,pgtypes;

const
  numcmds=61

  {delphi 3 doesn't understand const "array of" without [min..max] :(
  }

  {$ifndef noservcmds}
  +6
  {$endif}

  {$ifndef no21011}
  +3
  {$endif}

  {$ifndef nosethost}
  +1
  {$endif}

  {$ifndef nosvsnick}
  +1
  {$endif}

  {$ifndef nosvsjoin}
  +1
  {$endif}

  ;



MFLG_UNREG=1;    {command is allowed from an unregistered connection}
MFLG_IGNORE=2;   {if command is received from an unreg connection, don't send error reply}
mflg_rawstr=4;   {command requires rawstr}
MFLG_DISABLED=8; {command is not supported}
mflg_operonly=16; {only opers can use this command}

MSG_PRIVMSG= 'PRIVMSG';
TOK_PRIVMSG= 'P';

MSG_NICK= 'NICK';
TOK_NICK= 'N';

MSG_NOTICE= 'NOTICE';
TOK_NOTICE= 'O';

MSG_JOIN= 'JOIN';
TOK_JOIN= 'J';

MSG_MODE= 'MODE';
TOK_MODE= 'M';

MSG_QUIT= 'QUIT';
TOK_QUIT= 'Q';

MSG_PART= 'PART';
TOK_PART= 'L';

MSG_TOPIC= 'TOPIC';
TOK_TOPIC= 'T';

MSG_INVITE= 'INVITE';
TOK_INVITE= 'I';

MSG_KICK= 'KICK';
TOK_KICK= 'K';

MSG_WALLOPS= 'WALLOPS';
TOK_WALLOPS= 'WA';

MSG_PING= 'PING';
TOK_PING= 'G';

MSG_PONG= 'PONG';
TOK_PONG= 'Z';

MSG_ERROR= 'ERROR';
TOK_ERROR= 'Y';

MSG_KILL= 'KILL';
TOK_KILL= 'D';

MSG_USER= 'USER';
TOK_USER= 'USER';

MSG_AWAY= 'AWAY';
TOK_AWAY= 'A';

MSG_ISON= 'ISON';
TOK_ISON= 'ISON';

MSG_SERVER= 'SERVER';
TOK_SERVER= 'S';

MSG_SQUIT= 'SQUIT';
TOK_SQUIT= 'SQ';

MSG_WHOIS= 'WHOIS';
TOK_WHOIS= 'W';

MSG_WHO= 'WHO';
TOK_WHO= 'H';

MSG_LIST= 'LIST';
TOK_LIST= 'LIST';

MSG_NAMES= 'NAMES';
TOK_NAMES= 'E';

MSG_USERHOST= 'USERHOST';
TOK_USERHOST= 'USERHOST';

MSG_PASS= 'PASS';
TOK_PASS= 'PA';

MSG_SILENCE= 'SILENCE';
TOK_SILENCE= 'U';

MSG_LUSERS= 'LUSERS';
TOK_LUSERS= 'LU';

MSG_TIME= 'TIME';
TOK_TIME= 'TI';

MSG_OPER= 'OPER';
TOK_OPER= 'OPER';

MSG_CONNECT= 'CONNECT';
TOK_CONNECT= 'CO';

MSG_VERSION= 'VERSION';
TOK_VERSION= 'V';

MSG_STATS= 'STATS';
TOK_STATS= 'R';

MSG_LINKS= 'LINKS';
TOK_LINKS= 'LI';

MSG_ADMIN= 'ADMIN';
TOK_ADMIN= 'AD';

MSG_HELP= 'HELP';
TOK_HELP= 'HELP';

MSG_INFO= 'INFO';
TOK_INFO= 'F';

MSG_MOTD= 'MOTD';
TOK_MOTD= 'MO';

MSG_SETTIME= 'SETTIME';
TOK_SETTIME= 'SE';

MSG_REHASH= 'REHASH';
TOK_REHASH= 'REHASH';

MSG_MAP= 'MAP';
TOK_MAP= 'MAP';

MSG_RESTART= 'RESTART';
TOK_RESTART= 'RESTART';

MSG_DIE= 'DIE';
TOK_DIE= 'DIE';

MSG_GLINE= 'GLINE';
TOK_GLINE= 'GL';

MSG_WHOWAS= 'WHOWAS';
TOK_WHOWAS= 'X';

MSG_TRACE= 'TRACE';
TOK_TRACE= 'TR';

MSG_USERIP= 'USERIP';
TOK_USERIP= 'USERIP';

MSG_BURST= 'BURST';
TOK_BURST= 'B';

MSG_END_OF_BURST= 'END_OF_BURST';
TOK_END_OF_BURST= 'EB';

MSG_EOB_ACK= 'EOB_ACK';
TOK_EOB_ACK= 'EA';

MSG_CREATE= 'CREATE';
TOK_CREATE= 'C';

MSG_DESYNCH= 'DESYNCH';
TOK_DESYNCH= 'DS';

MSG_WALLCHOPS= 'WALLCHOPS';
TOK_WALLCHOPS= 'WC';

MSG_WALLVOICES= 'WALLVOICES';
TOK_WALLVOICES= 'WV';

MSG_POST= 'POST';
TOK_POST= 'POST';

MSG_CPRIVMSG= 'CPRIVMSG';
TOK_CPRIVMSG= 'CPRIVMSG';

MSG_CNOTICE= 'CNOTICE';
TOK_CNOTICE= 'CNOTICE';

MSG_WALLUSERS= 'WALLUSERS';
TOK_WALLUSERS= 'WU';

{$ifndef no21011}
MSG_ACCOUNT= 'ACCOUNT';
TOK_ACCOUNT= 'AC';

MSG_OPMODE= 'OPMODE';
TOK_OPMODE= 'OM';

MSG_CLEARMODE= 'CLEARMODE';
TOK_CLEARMODE= 'CM';
{$endif}

{$ifndef nosvsnick}
MSG_SVSNICK= 'SVSNICK';
TOK_SVSNICK= 'SN';
{$endif}

{$ifndef nosvsjoin}
MSG_SVSJOIN= 'SVSJOIN';
TOK_SVSJOIN= 'SJ';
{$endif}

{$ifndef nosethost}
MSG_SETHOST= 'SETHOST';
TOK_SETHOST= 'SH';
{$endif}

MSG_GET= 'GET';
TOK_GET= 'GET';

MSG_RPING= 'RPING';
TOK_RPING= 'RI';

MSG_RPONG= 'RPONG';
TOK_RPONG= 'RO';

MSG_CLOSE='CLOSE';
TOK_CLOSE='CLOSE';

var

{$ifndef no21011}
cmdaccount,cmdopmode,cmdclearmode,
{$endif}

{$ifndef nosethost}
cmdsethost,
{$endif}

cmdcprivmsg,

{$ifndef noservcmds}
cmdalias1,cmdalias2,cmdalias3,cmdalias4,cmdalias5,cmdalias6,
{$endif}

{$ifndef nosvsjoin}
cmdsvsjoin,
{$endif}

{$ifndef nosvsnick}
cmdsvsnick,
{$endif}

cmdprivmsg,
cmdnotice,
cmdinfo,
cmdnick,
cmdjoin,
cmdpart,
cmdkill,
cmdsquit,
cmdwhois,
cmdlusers,
cmdtime,
cmdversion,
cmdlinks,
cmdadmin,
cmdget,
cmdmotd:integer;



var
  cmdreverse:array[0..26*26-1] of integer;
  tokreverse:array[0..26*26-1] of integer;
  statsm:array[0..numcmds,0..1] of integer;

function cmdstr(num:integer):bytestring;
function tokstr(num:integer):bytestring;

implementation

uses breplies,bparse;

function cmdstr(num:integer):bytestring;
begin
  if num > 1000 then result := rplnumstr[num-1000]
  else result := cmdtable[num].cmd;
end;

function tokstr(num:integer):bytestring;
begin
  if num > 1000 then result := rplnumstr[num-1000]
  else result := cmdtable[num].tok;
end;

end.
