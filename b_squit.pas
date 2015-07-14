(*
 *  beware ircd, Internet Relay Chat server, b_squit.pas
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

unit b_squit;

interface

uses buser,bstuff,bcmds;

procedure m_squit(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  {$ifdef mswindows}wcore,{$else}lcore,{$endif}
  bconfig,breplies,bsend,btime,bserver,bparse,b_gline,blinklist,
  bircdunit,bconsts,bprivs,pgtypes;

procedure m_squit(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a:integer;
  us:tuser;
  srv:tserver;
  s,s2:bytestring;
  tsparam:integer;
  reason:bytestring;
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;

  {
  find server, check for multiple matches:
  servers taking a different decision is disastrous
  }
  s := parv[1];
  us := nil;
  srv := tserver(globalserverlist);
  a := 0;

  if isclient(cptr) then begin
    while srv <> nil do begin
      if strcompup(tuser(srv.us).name,s) then begin
        a := 1;
        us := tuser(srv.us);
        break;
      end;
      if maskmatchup(s,tuser(srv.us).name) then begin
        inc(a);
        us := tuser(srv.us);
      end;
      srv := tserver(srv.next);
    end;
    if (a > 1) or (us = nil) then begin
      sendnosuchserver(sptr,parv[1]);
      exit;
    end;
    {squit from local client: can't squit me}
    if us = me then exit;

    if (parc < 3) then reason := '' else reason := parv[parc-1];
    tsparam := 0;
  end else begin
    if (parc = 3) then begin
      {<sender> SQ <target> :<reason>}
      tsparam := 0;
    end else if (parc >= 4) then begin
      {<sender> SQ <target> <ts> :<reason>}
      tsparam := strtointdef(parv[2],0);
    end else begin
      needmoreparams(sptr,cmdnum);
      exit;
    end;
    us := findname(parv[1]);
    if us = nil then exit;
    reason := parv[parc-1];
  end;

  if not ((hasprivs(sptr,privs_localsquit) and myconnect(us)) or hasprivs(sptr,privs_globalsquit)) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;

  if reason = '' then s2 := sptr.name else s2 := reason;

  if us = me then us := cptr;

  if (tsparam <> 0) and (tsparam <> us.server.linktime) then begin
    locnotice(SNO_NETWORK,'ignoring SQUIT for '+us.name+' from '+sptr.name+', wrong timestamp: '+inttostr(us.server.linktime)+' != '+inttostr(tsparam)+' ('+reason+')');
    exit;
  end;

  begin
    if us.server.parentserver.us <> sptr then begin
      if isclient(sptr) then
      locnotice(SNO_NETWORK,'Received SQUIT '+us.name+' from '+sptr.name+'['+sptr.userid+'@'+sptr.host+']: '+reason)
      else
      locnotice(SNO_NETWORK,'Received SQUIT '+us.name+' from '+sptr.name+': '+reason);
    end;
    if not flag_isset(us.server.flags,servflag_destroying) then begin
      setflag(us.server.flags,servflag_nosquit);
      us.error := s2;

      if us = us.from then begin
        if us <> cptr then sendto_one(us,sprefix(sptr,TOK_SQUIT)+me.name+' 0 :'+reason); {this squit is needed to preserve source of message}
        for a := 1 to highserverlink do begin
          if serverlinklist[a] <> nil then if serverlinklist[a].us <> cptr
          then if serverlinklist[a].us <> us then
          sendto_one(tuser(serverlinklist[a].us),sprefix(sptr,TOK_SQUIT)+us.name+' '+inttostr(us.server.linktime)+' :'+reason);
        end;
      end else begin
        sendto_serversbutone(sptr,sprefix(sptr,TOK_SQUIT)+us.name+' '+inttostr(us.server.linktime)+' :'+reason);
      end;
     { addtask(mainc.squitmsg,nil,word(us.from.socknum),integer(us)); }
     us.destroy;
    end;
  end;
end;

end.
