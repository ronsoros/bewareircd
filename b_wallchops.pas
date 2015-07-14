(*
 *  beware ircd, Internet Relay Chat server, b_wallchops.pas
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

unit b_wallchops;

interface

uses buser,bcmds,bstuff;

procedure m_wallchops(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_wallvoices(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses breplies,bsend,bparse,bchannel,bsock,bconfig,blinklist,bipcheck,pgtypes;

{wallchops channel :text - notice @#channel :text}

procedure wallchopsvoices(cptr,sptr:tuser;parc:integer;parv:pparams;flags:integer;const flagchar,token:bytestring);
var
  ch:tchannel;
  s:bytestring;
begin
  if (parc < 2) or (parv[1] = '') then begin
    if cptr = sptr then sendreply(cptr,ERR_NORECIPIENT,getrpl1(ERR_NORECIPIENT,cmdtable[cmdnum].cmd));
    exit
  end;
  if (parc < 3) or (parv[2] = '') then begin
    if cptr = sptr then sendreply(cptr,ERR_NOTEXTTOSEND,getrpl0(ERR_NOTEXTTOSEND));
    exit
  end;
  ch := findchan(parv[1]);
  if ch = nil then begin
    if isclient(cptr) then sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
    exit;
  end;
  if not cansendtochannel(sptr,ch,nil) then begin
    if isclient(cptr) then sendreply(sptr,ERR_CANNOTSENDTOCHAN,ch.name+' '+getrpl0(ERR_CANNOTSENDTOCHAN));
    exit;
  end;

  if ipcheck_target(sptr,ch) > 0 then exit;
  if isserver(cptr) then s := '' else s := flagchar+' ';
  sendchatto_serversbutone_flags(sptr,ch,flags,sprefix(sptr,token)+ch.name+' :'+s+parv[parc-1]);
  sendchatto_channelbutone_flags(sptr,ch,flags,cprefix(sptr,MSG_NOTICE)+'@'+ch.name+' :'+s+parv[parc-1]);
end;

procedure m_wallchops(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  wallchopsvoices(cptr,sptr,parc,parv,
  userchanflag_op
  {$ifndef nohalfop} or userchanflag_halfop{$endif}
  ,'@',tok_wallchops);
end;

procedure m_wallvoices(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  wallchopsvoices(
  cptr,sptr,parc,parv,
  userchanflag_op or userchanflag_voice
  {$ifndef nohalfop} or userchanflag_halfop{$endif}
  ,'+',tok_wallvoices);
end;

end.
