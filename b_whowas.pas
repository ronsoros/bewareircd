(*
 *  beware ircd, Internet Relay Chat server, b_whowas.pas
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

unit b_whowas;

interface

uses bstuff,bcmds,buser,bconfig,breplies,pgtypes;

const
  {must be power of 2-1}
  maxwhowas=255;

type
  Twhowas=record
    name:bytestring;
    showuserid:bytestring;
    fullname:bytestring;
    showhost:bytestring;
    {$ifndef novhost}
    realhost:bytestring;
    realuserid:bytestring;
    {$endif}
    server:bytestring;
    time:integer;
  end;

var
  whowas:array[0..maxwhowas] of twhowas;
  whowaspoint:integer;

procedure m_whowas(cptr,sptr:tuser;parc:integer;parv:pparams);

procedure addwhowas(us:tuser);

implementation

uses btime,bsend;

procedure addwhowas(us:tuser);
begin
  {$ifdef nowhowas}exit;{$endif}

  whowas[whowaspoint].name := us.name;
  whowas[whowaspoint].showuserid := showuserid(us);
  whowas[whowaspoint].fullname := us.fullname;
  whowas[whowaspoint].showhost := showhost(us);
  {$ifndef novhost}
  whowas[whowaspoint].realhost := us.host;
  whowas[whowaspoint].realuserid := us.userid;
  {$endif}
  whowas[whowaspoint].server := tuser(us.server.us).name;
  whowas[whowaspoint].time := irctime;
  whowaspoint := succ(whowaspoint) and maxwhowas;
end;

procedure m_whowas(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a,c,d:integer;
  s:bytestring;
begin
  if (parc < 2) or (parv[1] = '') then begin
    sendreply(sptr,ERR_NONICKNAMEGIVEN,getrpl0(ERR_NONICKNAMEGIVEN));
    exit;
  end;
  s := ircupper(parv[1]);
  if parc > 2 then
  d := strtointdef(parv[2],0)
  else d := 0;
  if d = 0 then d := 10;
  c := d;
  a := whowaspoint;

  repeat
    if strcompup(whowas[a].name,s) then begin
      {$ifndef novhost}
      if isanoper(sptr) then
      sendreply(sptr,RPL_WHOWASUSER,whowas[a].name+' '+whowas[a].realuserid+' '+whowas[a].realhost+' * :'+whowas[a].fullname)
      else
      {$endif}
      sendreply(sptr,RPL_WHOWASUSER,whowas[a].name+' '+whowas[a].showuserid+' '+whowas[a].showhost+' * :'+whowas[a].fullname);

      {$ifndef nohis}
      if opt.headinsand and (not isanoper(sptr)) then
      sendreply(sptr,RPL_WHOISSERVER,whowas[a].name+' '+opt.headinsandname+' :'+timestrshort(whowas[a].time))
      else
      {$endif}
      sendreply(sptr,RPL_WHOISSERVER,whowas[a].name+' '+whowas[a].server+' :'+timestrshort(whowas[a].time));

      dec(c);
      if c = 0 then a := whowaspoint+1;
    end;
    a := pred(a);
    if a < 0 then a := maxwhowas;
  until a = whowaspoint;
  if c = d then sendreply(sptr,ERR_WASNOSUCHNICK,parv[1]+' '+getrpl0(ERR_WASNOSUCHNICK));
  sendreply(sptr,RPL_ENDOFWHOWAS,parv[1]+' '+getrpl0(RPL_ENDOFWHOWAS));
end;

end.
