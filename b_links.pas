(*
 *  beware ircd, Internet Relay Chat server, b_links.pas
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

unit b_links;

interface

uses buser,bchannel,bcmds,bstuff,pgtypes;

procedure m_links(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,bconfig,breplies,bserver,bparse,blinklist,bprivs;

procedure m_links(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  remotestr,searchstr:bytestring;
  srv:tuser;
  p:tserver;
  us:tuser;
  s:bytestring;
begin
  {$ifndef nohis}
  if opt.headinsand then if not hasprivs(sptr,privs_his) then begin
    sendreply(sptr,cmdnotice,':/LINKS '+opt.headinsandmapstr);
    sendreply(sptr,RPL_ENDOFLINKS,'* '+getrpl0(RPL_ENDOFLINKS));
    exit;
  end;
  {$endif}
  if (parv[1] = '') or (parc < 2) then begin
    searchstr := '*';
    remotestr := '';
  end else if (parv[2] = '') or (parc < 3) then begin
    searchstr := parv[1];
    remotestr := '';
  end else begin
    searchstr := parv[2];
    remotestr := parv[1];
  end;
  srv := getremoteserver(remotestr,not isserver(cptr));
  if srv = nil then begin
    sendnosuchserver(sptr,remotestr);
    exit;
  end;
  if srv <> me then begin
    sendmsgto_one(sptr,srv,cmdlinks,':'+searchstr);
    exit;
  end;
  p := tserver(globalserverlist);
  if searchstr = '' then searchstr := '*';

  while p <> nil do begin
    us := tuser(p.us);
    if maskmatchup(searchstr,us.name) then begin
      if flag_isset(p.flags,servflag_joining) then s := ' J' else s := ' P';
      s := s + inttostr(us.server.protoversion);
      sendreply(sptr,RPL_LINKS,us.name+' '+tuser(us.server.parentserver.us).name+' :'+inttostr(us.hops)+s+' '+us.fullname);
    end;
    p := tserver(p.next);
  end;
  sendreply(sptr,RPL_ENDOFLINKS,searchstr+' '+getrpl0(RPL_ENDOFLINKS));
end;

end.
