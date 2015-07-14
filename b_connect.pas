(*
 *  beware ircd, Internet Relay Chat server, b_connect.pas
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

unit b_connect;

interface

uses buser,bcmds,bstuff,pgtypes;

procedure m_connect(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  bconfig,bsend,breplies,bsock,bserver,bconnect,bprivs,bparse;

procedure m_connect(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  p,p2:tconfline;
  searchstr:bytestring;
  srv:tuser;
  port:bytestring;
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;

  if not hasprivs(sptr,privs_localconnect) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;

  if isserver(cptr) then if parc < 4 then begin
    needmoreparams(sptr,cmdnum);
    exit;
  end;

  if (parv[3] <> '') and (parc >= 4) then begin
    if not hasprivs(sptr,privs_globalconnect) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;

    srv := getremoteserver(parv[3],not isserver(cptr));

    if srv = nil then begin
      sendnosuchserver(sptr,parv[3]);
      exit;
    end;
    if srv <> me then begin
      sendto_one(srv,sprefix(sptr,TOK_CONNECT)+parv[1]+' '+parv[2]+' :'+srv.idstr);
      exit;
    end;
  end;

  searchstr := ircupper(parv[1]);
  p := conflinelist;
  p2 := nil;
  while p <> nil do begin
    if p.c = 'C' then if maskmatchup(searchstr,p.s3) then begin
      p2 := p;
      break;
    end;
    p := tconfline(p.next);
  end;
  if p2 = nil then begin
    sendreply(sptr,cmdnotice,':*** Server not listed in configuration: '+parv[1]);
    exit;
  end;

  if parc < 3 then begin
    port := '0';
  end else begin
    port := parv[2];
  end;
  if strtointdef(port,0) = 0 then begin
    port := inttostr(p2.i4);
  end;
  if strtointdef(port,0) = 0 then begin
    port := '4400';
  end;

  if not myconnect(sptr) then wallops('Remote CONNECT '+parv[1]+' '+parv[2]+' from '+sptr.name);

  connect(sptr,p2,port);
end;

end.
