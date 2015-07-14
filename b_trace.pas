(*
 *  beware ircd, Internet Relay Chat server, b_trace.pas
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

unit b_trace;

interface

uses buser,bcmds,bstuff,bconsts;

procedure m_trace(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  bconfig,bsend,breplies,bsock,bserver,bconnect,btime,bprivs,binipstuff;

procedure traceshowuser(sptr,us:tuser);
var
  b,c:integer;
  srv:tserver;
begin
  {only direct connected}
  if us <> us.from then exit;

  if isserver(us) then begin
    srv := tserver(globalserverlist);
    b := 0;
    c := 0;
    while srv <> nil do begin
      if tuser(srv.us).from = us then begin
        inc(b);
        inc(c,srv.usercount);
      end;
      srv := tserver(srv.next);
    end;
    sendreply(sptr,RPL_TRACESERVER,'Serv '+
    inttostr(connectionlist[us.socknum].classnum)+' '+
    inttostr(b)+'S '+
    inttostr(c)+'C '+
    us.name+' '+
    connectionlist[us.socknum].connectby_str+' :'+inttostr(irctime-connectionlist[us.socknum].lastreceived));
  end else if seeoper(sptr,us) then begin
    sendreply(sptr,RPL_TRACEOPERATOR,'Oper '+
    inttostr(connectionlist[us.socknum].classnum)+' '+
    us.name+'['+us.host+'] :'+inttostr(irctime-connectionlist[us.socknum].lastreceived));
  end else if isclient(us) then begin
    sendreply(sptr,RPL_TRACEUSER,'User '+
    inttostr(connectionlist[us.socknum].classnum)+' '+
    us.name+'['+us.host+'] :'+inttostr(irctime-connectionlist[us.socknum].lastreceived));
  end else begin
    sendreply(sptr,RPL_TRACEUNKNOWN,'???? '+
    inttostr(connectionlist[us.socknum].classnum)+' '+
    ircipbintostr(us.binip)+' :'+inttostr(irctime-connectionlist[us.socknum].lastreceived));
  end;
end;

procedure m_trace(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;
  targetserver:tuser;
  a:integer;
begin
  {$ifndef nohis}
  if opt.headinsand and not hasprivs(cptr,privs_his) then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;
  {$endif}

  if (parc < 2) or (parv[1] = '') then us := me else begin
   if (pos('*',parv[1]) <> 0) or (pos('?',parv[1]) <> 0) then
   us := getremoteserver(parv[1],true)
   else
   us := findname(parv[1]);
  end;
  if us = nil then begin
    sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;

  if isserver(cptr) and (parc > 2) and (parv[2] <> '') then targetserver := findnumeric(parv[2]) else begin
    targetserver := tuser(us.server.us);
  end;

  if us.server <> me.server then begin
    sendto_one(us.from,sprefix(sptr,TOK_TRACE)+parv[1]+' '+targetserver.idstr);
    sendreply(sptr,RPL_TRACELINK,'Link '+versionstr+' '+parv[1]+' :'+us.from.name);
    exit;
  end;

  if us <> me then begin
    {about one of my clients}
    traceshowuser(sptr,us);
    exit
  end;

  {about me}
  for a := 1 to maxserverlink do if serverlinklist[a] <> nil then begin
    us := tuser(serverlinklist[a].us);
    traceshowuser(sptr,us);
  end;
  for a := 0 to highconnection do if connectionlist[a].open then begin
    us := connectionlist[a].user;
    if isanoper(us) or isunreg(us) then traceshowuser(sptr,us);
  end;
end;

{
trace replies

206 nick Serv classnum ##S ##C name connectby :seconds ago received last message


}

end.
