(*
 *  beware ircd, Internet Relay Chat server, b_list.pas
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

unit b_list;

interface

uses buser,bstuff,blinklist,bchannel,pgtypes;

procedure m_list(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure listinprogresshandler(us:tuser);
procedure listinprogress_destroychan(ch:tchannel);

const
  listingflag_secret=1;

type
  tlistinprogress=class(tlinklist)
    us:tuser;
    ch:tchannel;
    minusers:integer;
    maxusers:integer;
    mintopic:integer;
    maxtopic:integer;
    mints:integer;
    maxts:integer;
    flags:integer;
    destructor destroy; override;
  end;

var
  listinprogresslist:tlinklist;

implementation

uses bsend,breplies,bsock,btime,bconfig,bprivs;

procedure listinprogress_end(us:tuser);
begin
    sendreply(us,RPL_LISTEND,getrpl0(RPL_LISTEND));
    getsock(us).ondatasent := nil;
    tlistinprogress(us.listinprogress).destroy;
    us.listinprogress := nil;
end;

{
list: a linklist of all currently in process lists,

containing:

user which does the list
next channel to be listed
minusers, maxusers,
oldest topic, youngest topic (topic 0 sec ago = no topic)
oldest channel, youngest channel

on channel.destroy, check if this channel is in list in progress,
if so: change "next channel" to be ch.next,

if the on-list sees next channel is nil, it does end of list

if the user is destroyed, there must be checked that the list in progress is aborted

}

function converttime(i:integer):integer;
begin
  if i >= 80000000 then result := i else result := irctime-(i*60);
end;

procedure m_list(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  p:tlistinprogress;
  a,b:integer;
  minusers,maxusers,mintopic,maxtopic,mints,maxts,flags:integer;
  s,s2:bytestring;
  bool:boolean;
  ch:tchannel;
  cansee:boolean;
begin
  if cptr.listinprogress <> nil then begin
    if (parc < 2) or (ircupper(parv[1]) = 'STOP') then listinprogress_end(cptr);
    exit;
  end;
  p := nil;
  minusers := 0;
  maxusers := maxlongint;
  mintopic := -maxlongint;
  maxtopic := maxlongint;
  mints := -maxlongint;
  maxts := maxlongint;
  flags := 0;
  bool := false;
  if parc >= 2 then if parv[1] <> '' then begin
    if ischanprefix(parv[1,1]) then begin
      sendreply(cptr,RPL_LISTSTART,'Channel :Users  Name');
      s2 := parv[1];
      a := 1;
      repeat
        strtok2(s2,',',a,s);
        if s = '' then break;
        ch := findchan(s);
        if assigned(ch) then begin
          cansee := canseechannel(sptr,ch) or (not flag_isset(ch.modeflag,chanmode_secret));
          if cansee then sendreply(cptr,RPL_LIST,ch.name+' '+inttostr(ch.usercount)+' :'+ch.topic);
        end;  
      until false;
      sendreply(cptr,RPL_LISTEND,getrpl0(RPL_LISTEND));
      exit;
    end;
    for a := 1 to parc-1 do begin
      s2 := parv[a];
      b := 1;
      repeat
        strtok2(s2,',',b,s);
        if s = '' then break;
        s := ircupper(s);
        if copy(s,1,1) = '<' then maxusers := strtointdef(copy(s,2,10),0)
        else if copy(s,1,1) = '>' then minusers := strtointdef(copy(s,2,10),0)
        else if copy(s,1,2) = 'C<' then mints := converttime(strtointdef(copy(s,3,10),0))
        else if copy(s,1,2) = 'C>' then maxts := converttime(strtointdef(copy(s,3,10),0))
        else if copy(s,1,2) = 'T<' then mintopic := converttime(strtointdef(copy(s,3,10),0))
        else if copy(s,1,2) = 'T>' then maxtopic := converttime(strtointdef(copy(s,3,10),0))
        else if (s = 'S') and opt.listsecretchannels then begin
          if hasprivs(sptr,privs_seesecret) then setflag(flags,listingflag_secret)
          else begin
            sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
            exit;
          end
        end else bool := true;
      until false;
    end;
  end;
  if bool then begin
    sendreply(sptr,RPL_LISTUSAGE,':Usage: /QUOTE LIST parameters');
    sendreply(sptr,RPL_LISTUSAGE,':Where parameters is a space or comma seperated list of one or more of:');
    sendreply(sptr,RPL_LISTUSAGE,': <max_users    ; Show all channels with less than max_users.');
    sendreply(sptr,RPL_LISTUSAGE,': >min_users    ; Show all channels with more than min_users.');
    sendreply(sptr,RPL_LISTUSAGE,': C<max_minutes ; Channels that exist less than max_minutes.');
    sendreply(sptr,RPL_LISTUSAGE,': C>min_minutes ; Channels that exist more than min_minutes.');
    sendreply(sptr,RPL_LISTUSAGE,': T<max_minutes ; Channels with a topic last set less than max_minutes ago.');
    sendreply(sptr,RPL_LISTUSAGE,': T>min_minutes ; Channels with a topic last set more than min_minutes ago.');
    sendreply(sptr,RPL_LISTUSAGE,':Example: LIST <3,>1,C<10,T>0  ; 2 users, younger than 10 min., topic set.');
    exit;
  end;

  if (flags and listingflag_secret) <> 0 then desynchwallops('LIST S by '+sptr.name+'['+sptr.userid+'@'+sptr.host+']');
  p := tlistinprogress.create;
  linklistadd(listinprogresslist,tlinklist(p));
  p.us := cptr;
  p.ch := tchannel(globalchanlist);
  {parse min-max here}
  p.minusers := minusers;
  p.maxusers := maxusers;
  p.mintopic := mintopic;
  p.maxtopic := maxtopic;
  p.mints := mints;
  p.maxts := maxts;
  p.flags := flags;
  p.us.listinprogress := p;

  sendreply(cptr,RPL_LISTSTART,'Channel :Users  Name');
  getsock(cptr).ondatasent := bsock.sc.datasenthandler;
  listinprogresshandler(p.us);
end;

procedure listinprogress_destroychan(ch:tchannel);
var
  p:tlinklist;
begin
  p := listinprogresslist;
  while p <> nil do begin
    if tlistinprogress(p).ch = ch then tlistinprogress(p).ch := tchannel(ch.next);
    p := p.next;
  end;
end;

procedure listinprogresshandler(us:tuser);
label skip;
var
  p:tlistinprogress;
  a:integer;
  cansee:boolean;
begin
  if us.listinprogress = nil then exit;
  p := tlistinprogress(us.listinprogress);
  a := 1;
  {ircu sends fixed 64 channels each time}
  while (p.ch <> nil) and (a > 0) do begin
    cansee := canseechannel(p.us,p.ch) or flag_isset(p.flags,listingflag_secret) or (not flag_isset(p.ch.modeflag,chanmode_secret));
    if not cansee then goto skip;
    if (p.ch.usercount <= p.minusers) or (p.ch.usercount >= p.maxusers) then goto skip;
    if (p.maxtopic < maxlongint) then if (p.ch.topic = '') then goto skip;
    if (p.mintopic >= p.ch.topictime) or (p.maxtopic <= p.ch.topictime) then goto skip;
    if (p.mints >= p.ch.ts) or (p.maxts <= p.ch.ts) then goto skip;
    sendreply(us,RPL_LIST,p.ch.name+' '+inttostr(p.ch.usercount)+' :'+p.ch.topic);
    {send enough channels that it almost fills one packet,
    itll sometimes but not often overflow on a long topic, causing another,
    small, packet to be sent}
    if connectionlist[us.socknum].sendqsize > 1250 then a := 0;
  skip:
    p.ch := tchannel(p.ch.next);
  end;

  if p.ch = nil then listinprogress_end(us);

end;

destructor tlistinprogress.destroy;
begin
  linklistdel(listinprogresslist,tlinklist(self));
  inherited destroy;
end;

end.
