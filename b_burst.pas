(*
 *  beware ircd, Internet Relay Chat server, b_burst.pas
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

unit b_burst;

interface

uses
  buser,bcmds,bstuff,bconsts,bmodebuf,pgtypes;

procedure m_burst(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  bchannel,breplies,bsend,btime,bconfig,blinklist,bircdunit,bserver,bparse;

{
SENDER  #channel TS +modes USERS :%bans
0       1        2

}

procedure m_burst(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  ch:tchannel;
  clearlocal,ignore,bool:boolean;
  count,a,b,c,d,e:integer;
  sendstr:bytestring;

  us:tuser;
  uc:tuserchan;
  s,s2,s3:bytestring;

  ban:tban;

begin

  if not isserver(sptr) then begin
    cptr.error := 'received BURST message, origin is a user';
    cptr.destroy;
    exit;
  end;
  if (parv[2] = '') or (parc < 3) then begin
    cptr.error := 'Received BURST from '+sptr.name+', not enough params';
    cptr.destroy;
    exit;
  end;

  {$ifdef nomodeless}
  {deliberately ignoring +channels to allow test burst with +channels to work}
  if parv[1,1] = '+' then exit;
  {$endif}

  if (parv[1,1] = '&') or not validchanname(parv[1]) then begin
    cptr.error := 'Received BURST from '+sptr.name+' for '+parv[1];
    cptr.destroy;
    exit;
  end;

  if not isulinedserver(sptr) then
  if not flag_isset(sptr.server.flags,servflag_joining) then begin
    cptr.error := 'Received BURST from '+sptr.name+', after netburst completion';
    cptr.destroy;
    exit;
  end;
  a := strtointdef(parv[2],0);


  parv[1] := copy(parv[1],1,opt.channamelen);
  ch := findchan(parv[1]);
  if ch = nil then begin
    ch := createchannel;
    setchanname(ch,parv[1]);
    {$ifndef nomodeless}
    if parv[1,1] = '+' then begin
      setflag(ch.flags,chanflag_modeless);
      setflag(ch.modeflag,chanmode_noexternal or chanmode_topic);
      a := 0;
    end;
    {$endif}
  end;

  clearlocal := false;
  if (ch.ts = 0) and (a > 0) then clearlocal := true
  else if (ch.ts > a) and (a > 0) then clearlocal := true;

  ignore := false;
  if (a = 0) and (ch.ts > 0) then ignore := true
  else if (a > ch.ts) and (ch.ts > 0) then ignore := true;

  {$ifndef nomodeless}
  if flag_isset(ch.flags,chanflag_modeless) then begin
    ignore := true;
    clearlocal := false;
  end;

  if not flag_isset(ch.flags,chanflag_modeless) then
  {$endif}
  begin
    bool := false;
    if (ch.ts = 0) and (a > 0) then bool := true
    else if (ch.ts > a) and (a > 0) then bool := true;
    if bool then ch.ts := a;
  end;


  {kick net riders on +k, +i code}
  if clearlocal and opt.netriderkick then for a := 0 to parc do if parv[a] <> '' then begin
    if parv[a,1] = '+' then
    if ((pos('k',parv[a]) <> 0) and (ch.key <> parv[a+1])) or (pos('i',parv[a]) <> 0)
    then begin
      channelstayflag := true;
      while ch.localuser <> nil do begin
        us := tuser(ch.localuser.p);
        sendto_one(us,cprefix(me,MSG_KICK)+ch.name+' '+us.name+' :Net Rider');
        sendto_serversbutone(me,sprefix(me,TOK_KICK)+ch.name+' '+us.idstr+' :Net Rider');
        deluserfromchannel(us,ch,nil);
      end;
      channelstayflag := false;

    end;
  end;

  modebuf_init(sptr,ch,modebufflag_tousers);

  if clearlocal then begin
    {clear modes}
    if ch.limit <> 0 then modebuf_add_flag(false,false,'l');
    ch.limit := 0;

    if ch.key <> '' then modebuf_add_str(false,false,'k',ch.key);
    ch.key := '';
    a := ch.modeflag;
    ch.modeflag := 0;

    {$ifndef nodelayed}
    modedupdate(ch,false);
    {$endif}
    modebuf_add_flagsdifference(a,ch.modeflag,false);
    {clear ops/voice}
    uc := tuserchan(ch.user);
    while uc <> nil do begin
      for a := 0 to maxuserchanmodetable do if flag_isset(uc.flags,userchanmodetable[a].flag)
      then modebuf_add_user(false,false,userchanmodetable[a].c,uc);
      uc.flags := uc.flags and not userchanmodeflagmask;
      uc := tuserchan(uc.next2);
    end;

    while ch.banlist <> nil do begin
      ban := tban(ch.banlist);
      modebuf_add_str(false,false,'b',ban.mask);
      linklistdel(tlinklist(ch.banlist),tlinklist(ch.banlist));
      ban.destroy;
    end;
    ch.bancount := 0;

    {clear invites}
    while ch.invites <> nil do begin
      delinvitefromchannel(ch.invites.us,ch,ch.invites)
    end;

    {clear topic}
    if ch.topic <> '' then begin
      ch.topic := '';
      ch.topicby := '';
      ch.topictime := 0;
      sendto_channel(ch,cprefix(me,MSG_TOPIC)+ch.name+' :');
    end;
  end;

  sendstr := '';
  count := 3;

  {safety, don't ever access a param with too high index}
  if parc > mparams-3 then parc := mparams-3;

  while count < parc do begin
    if parv[count] = '' then break;
    if parv[count,1] = '+' then begin
      {modes}
      b := count;
      if ignore then begin
        if pos('k',parv[b]) <> 0 then inc(count);
        if pos('l',parv[b]) <> 0 then inc(count);
      end else begin
        d := ch.modeflag;
	for a := 1 to length(parv[b]) do begin
          for c := 0 to maxchanmodetable do if parv[b,a] = chanmodetable[c].c then if not chanmodetable[c].disabled then begin
            setflag(ch.modeflag,chanmodetable[c].flag);
          end;
          if parv[b,a] = 'l' then begin
            inc(count);
            c := strtointdef(parv[count],0);
            {use the new limit if it's smaller than the existing limit, or we have no limit}
            if ((ch.limit > c) or (ch.limit <= 0)) and (c > 0) then begin
              ch.limit := c;
              modebuf_add_str(true,false,'l',inttostr(ch.limit));
            end;
          end;
          if parv[b,a] = 'k' then begin
            inc(count);
            if ((ch.key > parv[count]) or (ch.key = '')) and (parv[count] <> '') then begin
              if (ch.key <> '') then modebuf_add_str(false,false,'k',ch.key);
              modebuf_add_str(true,false,'k',hiddenkey);
              ch.key := parv[count];
            end;
          end;
        end;
        {$ifndef nodelayed}
        modedupdate(ch,false);
        {$endif}
        modebuf_add_flagsdifference(d,ch.modeflag,false);

        for a := b to count do sendstr := sendstr + ' '+parv[a];
      end;
    end else if parv[count,1] = '%' then begin
      {bans and end of line}
      if not ignore then begin
        sendstr := sendstr + ' :'+parv[count];
        s2 := copy(parv[count],2,500);
        a := 1;
        repeat
          strtok2(s2,' ',a,s);
          if s = '' then break;
          s := cookmask(s);
          if addban(sptr,ch,s,false) then modebuf_add_str(true,false,'b',s);
        until false;
      end;
      count := parc;
    end else begin
      {users}
      {check if the user exists and us.from = sptr.from;
      if not, dont add.
      if ignore, add but dont set ops/voice}
      {sendstr := sendstr + ' ';}
      c := 0;
      e := 0;
      s2 := '';
      a := 1;
      s3 := parv[count];
      repeat
        strtok2(s3,',',a,s);
        if s = '' then break;
        d := pos(':',s);
        if d <> 0 then begin
          us := findnumeric(copy(s,1,d-1));
          c := 0;
          if not ignore then begin
            s := copy(s,d+1,10);
            for b := maxuserchanmodetable downto 0 do if not userchanmodetable[b].disabled then
            if pos(userchanmodetable[b].c,s) <> 0 then c := c or userchanmodetable[b].flag;
          end;
        end else begin
          us := findnumeric(s);
        end;

        {
        if user doesnt exist or is from another direction, ignore (don't add)
        it may no longer exist because of a nick kill; nothing wrong

        but the "user" should not be a server; break link
        }

        if (us <> nil) then if (us.from = sptr.from) then begin

          if not isclient(us) then begin
            cptr.error := 'received BURST, numeric isn''t a client';
            cptr.destroy;
            exit;
          end;

            uc := addusertochannel(us,ch);
            for b := maxuserchanmodetable downto 0 do if flag_isset(c,userchanmodetable[b].flag) then begin
              modebuf_add_user(true,false,userchanmodetable[b].c,uc);
            end;
            uc.flags := c;

            {$ifndef nodelayed}
            if (ch.modeflag and chanmode_delayedjoin <> 0) and not hasopsorvoice(us,ch,uc) then begin
              setflag(uc.flags,userchanflag_delayed);
              inc(ch.delayedcount);
            end else
            {$endif}
            sendto_channel(ch,cprefix(us,MSG_JOIN)+':'+ch.name);

            if s2 <> '' then s2 := s2 + ',';
            s2 := s2 + us.idstr;
            if c <> e then begin
              s2 := s2 + ':';
              for b := maxuserchanmodetable downto 0 do
              if flag_isset(c,userchanmodetable[b].flag) then s2 := s2 + userchanmodetable[b].c;
              e := c;
            end;

        end;

      until false;
      if s2 <> '' then sendstr := sendstr + ' '+s2;
    end;
    inc(count);
  end;
  modebuf_finish(true);
  sendto_serversbutone(sptr,sprefix(sptr,TOK_BURST)+ch.name+' '+inttostr(ch.ts)+sendstr);
  clearbancache(ch);
  if ch.usercount = 0 then begin
    if receivingburst <= 0 then ch.destroy
    {else channel will be destroyed later}
  end
end;

end.
