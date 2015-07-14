(*
 *  beware ircd, Internet Relay Chat server, b_mode.pas
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

unit b_mode;

interface

uses buser,bstuff,bchannel,pgtypes;

procedure m_mode(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_mode(cptr,sptr:tuser;parc:integer;parv:pparams);

function hacknoticemodestring(parc:integer;parv:pparams;cmd:bytestring):bytestring;

implementation

uses bsend,breplies,bcmds,blinklist,bconfig,bparse,bconsts;

function hacknoticemodestring(parc:integer;parv:pparams;cmd:bytestring):bytestring;
var
  a:integer;
  us:tuser;
begin
  result := '';
  for a := 0 to parc-1 do begin
    us := findnumeric(parv[a]);
    if us <> nil then result := result + us.name+' ' else result := result + parv[a]+' ';
    if a = 0 then result := result + cmd+' ';
  end;
end;

procedure m_mode(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a:integer;
  s:bytestring;
  ch:tchannel;
  p:tlinklist;
  us:tuser;
begin
  {only clients}
  if checkneedmoreparams(sptr,cmdnum,1,parc,parv) then exit;
  if ischanprefix(parv[1,1]) then begin
    {channel}
    ch := findchan(parv[1]);
    if ch = nil then begin
      sendreply(sptr,ERR_NOSUCHCHANNEL,parv[1]+' '+getrpl0(ERR_NOSUCHCHANNEL));
      exit;
    end;
    if parc < 3 then begin
      {wants to see modes}
      if isonchannel(sptr,ch) then begin
        if hasops(sptr,ch,nil) then a := 1 else a := 2;
      end else a := 0;
      s := chanmodestr(ch,a);
      if s = '' then s := ' +';
      sendreply(sptr,RPL_CHANNELMODEIS,ch.name+s);
      sendreply(sptr,RPL_CREATIONTIME,ch.name+' '+inttostr(ch.ts));
      exit;
    end;
    if ((parv[2] = '+b') or (parv[2] = 'b')) and (parc < 4) then begin
      {wants to see bans}
      p := ch.banlist;
      while p <> nil do begin
        sendreply(sptr,RPL_BANLIST,ch.name+' '+tban(p).mask+' '+tban(p).sender+' '+inttostr(tban(p).date));
        p := p.next;
      end;
      sendreply(sptr,RPL_ENDOFBANLIST,ch.name+' '+getrpl0(RPL_ENDOFBANLIST));
      exit;
    end;
    if not isonchannel(sptr,ch) then begin
      sendreply(sptr,ERR_NOTONCHANNEL,ch.name+' '+getrpl0(ERR_NOTONCHANNEL));
      exit;
    end;
    if not {$ifdef nohalfop}hasops{$else}hasoporhalfop{$endif} (sptr,ch,nil) then begin
      sendreply(sptr,ERR_CHANOPRIVSNEEDED,ch.name+' '+getrpl0(ERR_CHANOPRIVSNEEDED));
      exit;
    end;
    {$ifndef nomodeless}
    if flag_isset(ch.flags,chanflag_modeless) then exit; {extra check}
    {$endif}
    setchanmode(ch,cptr,sptr,parc,parv,false);
  end else begin
    us := findnick(parv[1]);
    setusermode(us,cptr,sptr,parc,parv);
  end
end;

function gettsparam(parc:integer;parv:pparams):integer;
var
  a,b:integer;
  s:bytestring;
  setclear:integer;
begin
  result := 0;
  if parc <= 3 then exit; {#channel +m}
  result := strtointdef(parv[parc-1],0);
  if result < oldest_ts then exit; {last param is not a number}

  {count the number of params which the chars need}
  s := parv[2];
  setclear := 0;
  b := 3;
  for a := 1 to length(s) do begin
    case s[a] of
      '+':setclear := 2;
      '-':setclear := 1;
      else if charhasparam(s[a],setclear) then inc(b);
    end;
  end;
  if parc <= b then begin
    {all params are used for the mode params, no extra param for TS}
    result := 0;
    exit;
  end;
end;


procedure ms_mode(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  ch:tchannel;
  us:tuser;
  ts:integer;
begin
  {a MODE from a server without 2 parameters doesn't make sense}
  if (parv[2] = '') or (parc < 3) then exit;

  if ischanprefix(parv[1,1]) then begin
    {channel}
    ch := findchan(parv[1]);
    if ch = nil then exit;
    if flag_isset(ch.flags,chanflag_local) then exit;
    {$ifndef nomodeless}
    if flag_isset(ch.flags,chanflag_modeless) then exit;
    {$endif}

    {check for timestamp, bounce if needed, or update channel's TS}
    ts := gettsparam(parc,parv);
    if (ch.ts <> 0) and (ts > ch.ts) then begin
      locnotice(SNO_HACK2,'HACK(2): '+hacknoticemodestring(parc,parv,MSG_MODE));
      bouncechanmode(ch,sptr,parc,parv,false);
      exit;
    end;
    if (ts <> 0) and ((ch.ts = 0) or (ch.ts > ts)) then ch.ts := ts;

    if (isclient(sptr) and {$ifdef nohalfop}hasops{$else}hasoporhalfop{$endif}(sptr,ch,nil)) then begin
      {ops, rightful mode change}
    end else if flag_isset(sptr.server.flags,servflag_ulined) then begin
      {U:lined (4)}
      locnotice(SNO_HACK4,'HACK(4): '+hacknoticemodestring(parc,parv,MSG_MODE));
    end else if isserver(sptr) then begin
      {server (3)}
      locnotice(SNO_HACK3,'HACK(3): '+hacknoticemodestring(parc,parv,MSG_MODE));
    end else begin
      {client without ops: bounce (2)}
      locnotice(SNO_HACK2,'HACK(2): '+hacknoticemodestring(parc,parv,MSG_MODE));
      bouncechanmode(ch,sptr,parc,parv,true);
      exit;
    end;
    setchanmode(ch,cptr,sptr,parc,parv,false);
    exit;
  end;
  us := findnick(parv[1]);
  setusermode(us,cptr,sptr,parc,parv);
end;


end.
