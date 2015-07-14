(*
 *  beware ircd, Internet Relay Chat server, b_rping.pas
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

unit b_rping;

interface

uses buser,bcmds,bstuff,sysutils,pgtypes;

procedure m_rping(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_rpong(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses breplies,bsend,btime,bparse,bsock,bserver;

procedure m_rping(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  extraparam:bytestring;
  startserver,destserver:tuser;
  fl:double;
begin
  if (parc > 5) and isserver(cptr) then begin
    destserver := getremoteserver(parv[1],false);
    if not assigned(destserver) then exit;
    if (destserver = me) then begin
      sendto_one(sptr.from,sprefix(me,TOK_RPONG)+' '+sptr.name+' '+parv[2]+' '+parv[3]+' '+parv[4]+' :'+parv[parc-1]);
    end else begin
      sendto_one(destserver.from,sprefix(sptr,TOK_RPING)+parv[1]+' '+parv[2]+' '+parv[3]+' '+parv[4]+' :'+parv[parc-1]);
    end;
  end else begin
    if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
    startserver := nil;
    if parc > 3 then begin
      startserver := getremoteserver(parv[2],isclient(cptr));
      if not assigned(startserver) then begin
        sendreply(sptr,ERR_NOSUCHSERVER,parv[2]+' '+getrpl0(ERR_NOSUCHSERVER));
        exit;
      end;
      extraparam := parv[3]
    end else if (parc > 2) then begin
      startserver := getremoteserver(parv[2],isclient(cptr));
      if not assigned(startserver) then begin
        extraparam := parv[2];
        startserver := me;
      end else begin
        extraparam := 'none';
      end;
    end else if (parc > 1) then begin
      startserver := me;
      extraparam := 'none';
    end;
    if (startserver = me) then begin
      destserver := getremoteserver(parv[1],true);
      if not assigned(destserver) then begin
        sendreply(sptr,ERR_NOSUCHSERVER,parv[1]+' '+getrpl0(ERR_NOSUCHSERVER));
        exit;
      end;
      if (destserver = me) then begin
        sendreply(sptr,cmdnotice,':trying to ping myself');
        exit;
      end;
      fl := unixtimefloat;
      sendto_one(destserver.from,sprefix(me,TOK_RPING)+destserver.idstr+' '+sptr.idstr+' '+inttostr(trunc(fl))+' '+inttostr(trunc(frac(fl)*1000000))+' :'+extraparam);
    end else begin
      sendto_one(startserver.from,sprefix(sptr,TOK_RPING)+parv[1]+' '+startserver.idstr+' :'+extraparam);
    end;
  end;
end;

procedure m_rpong(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  startserver,oper:tuser;
  pingedserver:bytestring;
  lag:bytestring;
begin
  if (parc > 5) then begin
    startserver := getremoteserver(parv[1],true); {server name}
    if not assigned(startserver) then exit;
    if (startserver <> me) then begin
      sendto_one(startserver.from,sprefix(sptr,TOK_RPONG)+startserver.name+' '+parv[2]+' '+parv[3]+' '+parv[4]+' :'+parv[parc-1]);
      exit;
    end;
    {here, start server is local}
    pingedserver := sptr.name;
    startserver := me;
    oper := findnumeric(parv[2]);
    try
      lag := inttostr(trunc((unixtimefloat-(strtointdef(parv[3],0)+strtointdef(parv[4],0)/1000000))*1000));
    except
      lag := '0';
    end;
  end else if (parc > 4) then begin
    pingedserver := parv[2];
    startserver := sptr;
    oper := findnumeric(parv[1]);
    lag := parv[3];
  end else exit;
  if not assigned(oper) then exit;
  if (oper.server <> me.server) then begin
    sendto_one(oper.from,sprefix(startserver,TOK_RPONG)+oper.idstr+' '+pingedserver+' '+lag+' :'+parv[parc-1]);
    exit;
  end;

  {here, requesting oper is local}
  sendto_one(oper,cprefix(startserver,MSG_RPONG)+oper.name+' '+pingedserver+' '+lag+' :'+parv[parc-1]);
end;

end.
