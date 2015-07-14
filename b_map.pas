(*
 *  beware ircd, Internet Relay Chat server, b_map.pas
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

unit b_map;

interface

uses buser,bcmds,bstuff,pgtypes;

procedure m_map(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bserver,breplies,bsend,bconfig,bprivs;

procedure mapd(sptr:tuser;parentserver:tserver;prestr,mask:bytestring);
var
  p,p2:tserver;
  a:integer;
  s,s2:bytestring;
  bool:boolean;
begin
  s := prestr;

  if flag_isset(parentserver.flags,servflag_joining) then s2 := '*' else
  if not flag_isset(parentserver.flags,servflag_burstack) then s2 := '!' else s2 := '';
  if s <> '' then s[length(s)] := '-';
  if parentserver.lag < 0 then a := 0 else a := parentserver.lag;

  if maskmatchup(mask,tuser(parentserver.us).name) then begin
    sendreply(sptr,RPL_MAP,':'+s+s2+
    tuser(parentserver.us).name+
    ' ('+tuser(parentserver.us).idstr+':'+inttostr(parentserver.p10num)+
    ') ('+inttostr(a)+'s) ['+inttostr(parentserver.usercount)+' clients]');
  end;
  if length(prestr) > 1 then if prestr[length(prestr)-1] = '`' then prestr[length(prestr)-1] := ' ';
  bool := true;
  p := tserver(globalserverlist);
  while bool do begin
    if p = nil then begin
      bool := false;
    end else begin
      if (p.parentserver = parentserver) and (p <> parentserver)
      then bool := false;
    end;
    if bool then p := tserver(p.next);
  end;

  while p <> nil do begin

    {search next}
    bool := true;
    p2 := tserver(p.next);
    while bool do begin
      if p2 = nil then begin
        bool := false;
      end else begin
        if (p2.parentserver = parentserver) and (p2 <> parentserver)
        then bool := false;
      end;
      if bool then p2 := tserver(p2.next);
    end;

    s := prestr;
    if p2 = nil then s := s + '`' else s := s + '|';
    mapd(sptr,p,s+' ',mask);

    p := p2;
  end;

end;


procedure m_map(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
begin
  {$ifndef nohis}
  if opt.headinsand then if not hasprivs(cptr,privs_his) then begin
    sendreply(sptr,cmdnotice,':/MAP '+opt.headinsandmapstr);
    exit;
  end;
  {$endif}
  if (parc < 2) or (parv[1] = '') then s := '*' else s := parv[1];
  mapd(sptr,me.server,'',ircupper(s));
  sendreply(sptr,RPL_MAPEND,getrpl0(RPL_MAPEND));
end;

end.
