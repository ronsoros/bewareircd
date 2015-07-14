(*
 *  beware ircd, Internet Relay Chat server, bprivs.pas
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

unit bprivs;

interface

uses buser;

const
  privs_localkill=           $2; {local kills}
  privs_rehash=              $4; {can rehash}
  privs_restart=             $8; {can restart}
  privs_die=                $10; {can stop server}
  privs_localjoin=          $20; {local channels join override}
  privs_globaljoin=         $40; {global channels join override}
  privs_globalkill=         $80; {global kills}

  privs_globalmode=        $200; {global opmode}
  privs_flood=             $400; {flood/fast sending etc}
  privs_targets=           $800; {no target limit}

  privs_globalsvsjoin=    $2000;

  privs_globalsvsnick=    $8000;
  privs_seesecretchans=  $10000; {see +s channels}
  privs_globalconnect=   $20000;
  privs_localconnect=    $40000;
  privs_localsquit=      $80000;
  privs_globalsquit=    $100000;
  privs_localgline=     $200000; {set local glines}
  privs_globalgline=    $400000; {can set global glines}
  privs_glineforce=     $800000; {can set glines with wilds and a longer duration}
  privs_seesecret=     $1000000; {can see +s channels (in /list)}
  privs_showoper=      $2000000; {appears as irc operator to users}
  privs_seehiddenopers=$4000000; {sees opers without showoper flag as oper}
  privs_broadcast=     $8000000; {can send $servermask messages}
  privs_his=          $10000000; {can see through HIS}

  {any flag which a local icrop can't do}
  privs_global=
  privs_globalgline or privs_glineforce or privs_restart or privs_die or
  privs_globaljoin or privs_globalkill or privs_globalmode or
  privs_targets or privs_globalsvsjoin or privs_globalsvsnick or
  privs_globalconnect or privs_globalsquit or privs_seesecret;


function hasprivs(us:tuser;flag:integer):boolean;
function seeoper(source,target:tuser):boolean;

implementation

function hasprivs(us:tuser;flag:integer):boolean;
begin
  if isserver(us) then result := true
  else begin
    if flag and privs_global <> 0 then result := isoper(us) else result := isanoper(us);
  end;
end;

function seeoper;
begin
  result := hasprivs(target,privs_showoper) or (hasprivs(source,privs_seehiddenopers) and isanoper(target));
end;

end.
