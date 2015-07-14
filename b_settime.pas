(*
 *  beware ircd, Internet Relay Chat server, b_settime.pas
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

unit b_settime;

interface

uses
  buser,bcmds,bstuff;

procedure m_settime(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses btime,bconsts,bsend,bconfig,bserver,bsock,pgtypes;

procedure m_settime(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  t,t2,dt,dt2:integer;
  us:tuser;
  s:bytestring;
  a:integer;
begin
  if (parv[1] = '') or (parc < 2) then begin
    t2 := irctime;
  end else begin
    t2 := strtointdef(parv[1],0);
  end;


  if t2 = 0 then exit;

  if opt.reliableclock then begin
    t := irctime;
  end else begin
    t := t2;
  end;

  dt := irctime - t;
  dt2 := irctime - t2;
  if (t < OLDEST_TS) or (dt < -9000000) then exit;

  {send to servers which are not lagged}

  s := sprefix(sptr,TOK_SETTIME)+inttostr(t);

  for a := 1 to maxserverlink do if serverlinklist[a] <> nil then begin
    us := tuser(serverlinklist[a].us);
    if us <> nil then
    if us <> sptr.from then
{    if us.server.lag <= 1 then}
    if connectionlist[us.socknum].sendqsize < 8000 then begin
      sendto_one(us,s);
    end;
  end;

  if opt.reliableclock then begin
    locnotice(SNO_OLDSNO,'SETTIME from '+sptr.name+', '+inttostr(-dt2)+' seconds difference')
  end else begin
    if dt < 0 then
    s := 'clock is set '+inttostr(-dt)+' seconds forwards'
    else
    s := 'clock is set '+inttostr(dt)+' seconds backwards';

    locnotice(SNO_OLDSNO,'SETTIME from '+sptr.name+', '+s);
    if not isserver(sptr) then sendreply(sptr,cmdnotice,':'+s);
    settime(t);
  end;
end;

end.
