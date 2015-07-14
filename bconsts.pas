(*
 *  beware ircd, Internet Relay Chat server, bconsts.pas
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

unit bconsts;

interface

const
  maxmessagelength=510; {length of message without termination}

  maxgcoslength=50;
  maxservername=63;
  hostlen=63;
  maxnicklength=30; {nicklen hard limit; opt.nicklen is the soft limit for nicks set by local clients}
  maxkeylength=23;
  maxbanlength=67;
  maxsilence=15;
  unregtimeout=90; {timeout unregistered connections}

  versionstr='beware1.6.3'
  {$ifdef bdebug}+'.debug' {$endif}
  ;

  maxmodes=6;
  maxserverlink=31;
  oldest_ts=780000000;
  target_delayshift=7;
  target_delay=1 shl target_delayshift;
  nickdelay=30;
  userlen=10;
  iplen=15;
  {$ifdef shortnumerics}
  'use extended numerics compile and enable "shortnumerics" option'
  SSlen=1;
  CCClen=2;
  numericsname='short';
  SSmask=$3f;
  CCCmask=$fff;
  {$else}
  SSlen=2;
  CCClen=3;
  numericsname='extended';
  SSmask=$fff;
  CCCmask=$3ffff;
  {$endif}
  SSCCClen=SSlen+CCClen;

  {$ifdef bdebug}
  {prefix for text sent to &debug channel}
  debugchanprefix='&debug.';
  debugsendattr=#3'04,01'; {mirc color red on black}
  debugrecvattr=#3'09,01'; {mirc color green on black}
  {$endif}

  TS_LAG_TIME=3600;
  {MAGIC_REMOTE_JOIN_TS=1270080000;}

  {$ifdef mswindows}
  platformstr = 'win'
    {$ifdef win64}+'64'{$else}+'32'{$endif}
  {$else}
  platformstr = 'unix'
  {$endif}
  {$ifdef fpc}
  +'-fpc'
  {$endif}
  ;

implementation

end.
