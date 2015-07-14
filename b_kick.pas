(*
 *  beware ircd, Internet Relay Chat server, b_kick.pas
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

unit b_kick;

interface

uses buser,bcmds,bstuff,pgtypes;

procedure m_kick(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bchannel,bsend,breplies,blinklist,bconfig,bmodebuf,bparse;

procedure m_kick(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a:integer;
  ch:tchannel;
  us:tuser;
  uc:tuserchan;
  s:bytestring;
  from:tuser;
  allowed:boolean;
begin
  if checkneedmoreparams(cptr,cmdnum,2,parc,parv) then exit;

  ch := findchan(parv[1]);
  if ch = nil then begin
    sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;

  if isserver(cptr) then if flag_isset(ch.flags,chanflag_local) then exit;

  {must do some check first, to prevent finding out memberships in secret/private channels}
  if not isserver(cptr) then begin
    if not {$ifdef nohalfop}hasops{$else}hasoporhalfop{$endif}(sptr,ch,nil) then begin
      sendreply(sptr,ERR_CHANOPRIVSNEEDED,ch.name+' '+getrpl0(ERR_CHANOPRIVSNEEDED));
      exit;
    end;
  end;

  if isserver(cptr) then
  us := findnumeric(parv[2])
  else
  us := findnick(parv[2]);

  if us = nil then begin
    if sptr = cptr then sendreply(sptr,ERR_NOSUCHNICK,parv[2]+' '+getrpl0(ERR_NOSUCHNICK));
    exit;
  end;

  uc := getuserchan(us,ch);
  if not assigned(uc) then begin
    if sptr = cptr then sendreply(sptr,ERR_USERNOTINCHANNEL,us.name+' '+ch.name+' '+getrpl0(ERR_USERNOTINCHANNEL));
    exit;
  end;

  if isservice(us) then if isclient(cptr) then begin
    sendreply(sptr,ERR_ISCHANSERVICE,us.name+' '+ch.name+' '+getrpl0(ERR_ISCHANSERVICE));
    exit;
  end;

  s := parv[parc-1]; {reason}


  allowed := hasops(sptr,ch,nil);
  {$ifndef nohalfop}
  if not allowed then if hasoporhalfop(sptr,ch,nil) then if not hasoporhalfop(us,ch,uc) then allowed := true;
  {$endif}

  if not isserver(cptr) then if not allowed then begin
    sendreply(sptr,ERR_CHANOPRIVSNEEDED,ch.name+' '+getrpl0(ERR_CHANOPRIVSNEEDED));
    exit;
  end;

  {bounce/hack code}
  if isserver(cptr) then if not allowed then begin
    if isserver(sptr) or (flag_isset(sptr.server.flags,servflag_ulined)) then begin
      {allow kick by server, or U:lined}
      if (sptr <> us.server.us) then begin
        locnotice(SNO_HACK4,'HACK(4) '+sptr.name+' KICK '+ch.name+' '+us.name+' ('+s+')')
      end;
    end else begin
      {normal client; desync; bounce if possible}
      if us.from <> cptr then begin
        locnotice(SNO_HACK2,'HACK(2) '+sptr.name+' KICK '+ch.name+' '+us.name+' ('+s+')');
        sendto_one(cptr,sprefix(us,TOK_JOIN)+ch.name);
        modebuf_init(cptr,ch,modebufflag_bounce or modebufflag_toservers);
        if getuserchan(sptr,ch) <> nil then modebuf_add_user(false,true,'o',getuserchan(sptr,ch));
        for a := 0 to maxuserchanmodetable do if flag_isset(uc.flags,userchanmodetable[a].flag)
          then modebuf_add_user(true,true,userchanmodetable[a].c,uc);
        modebuf_finish(true);
        exit;
      end else
      locnotice(SNO_HACK3,'HACK(3) '+sptr.name+' KICK '+ch.name+' '+us.name+' ('+s+')');
    end;
  end;

  if not flag_isset(ch.flags,chanflag_local) then
  sendto_serversbutone(sptr,sprefix(sptr,TOK_KICK)+ch.name+' '+us.idstr+' :'+s);

  {$ifndef nohis}
  if opt.headinsand and isserver(sptr) then
  from := me
  else
  {$endif}
  from := sptr;

  {$ifndef nodelayed}
  if flag_isset(uc.flags,userchanflag_delayed) then begin
    if us.server = me.server then
    sendto_one(us,cprefix(from,MSG_KICK)+ch.name+' '+us.name+' :'+s);
    if us <> sptr then if sptr.server = me.server then
    sendto_one(sptr,cprefix(from,MSG_KICK)+ch.name+' '+us.name+' :'+s);
  end else
  {$endif}
  sendto_channel(ch,cprefix(from,MSG_KICK)+ch.name+' '+us.name+' :'+s);
  if isserver(cptr) then if myconnect(us) then sendto_one(cptr,sprefix(us,TOK_PART)+ch.name);
  deluserfromchannel(us,ch,uc)
end;

end.
