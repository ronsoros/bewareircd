(*
 *  beware ircd, Internet Relay Chat server, b_server.pas
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

unit b_server;

interface

uses buser,bserver,bcmds,bstuff,bvaliddef,pgtypes;

procedure mu_server(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_server(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  breplies,bsend,bconfig,btime,bchannel,bircdunit,bconsts,bsock,bipcheck,
  bparse,unitbanmask,b_gline;

{return:

0: no collision
1: remove local connection of new server
2: remove new server
3: remove existing server
4: remove existing, mark new server as "introduced ghost"
5: second youngest link


}
function servercollision(newnum:integer;newname:bytestring;newfrom:tuser;newts:integer;var resultstr:bytestring):integer;
label finish;
var
  a:integer;
  existingname:tuser;
  existingnum:tuser;

  youngestlink,us:tuser;
  youngestlinkts,secondlinkts:integer;
  greatername1,greatername2:bytestring;greaternamelink:tuser;

function greaternames(s1,s2:bytestring):boolean;
var
  s3:bytestring;
begin
  s1 := ircupper(s1);
  s2 := ircupper(s2);
  if s1 < s2 then begin
    s3 := s1;
    s1 := s2;
    s2 := s3;
  end;
  result := false;
  if s1 > greatername1 then begin
    result := true;
  end else if s1 = greatername1 then begin
    result := s2 > greatername2;
  end;
  if result then begin
    greatername1 := s1;
    greatername2 := s2;
  end;
end;

procedure greaternameloop;
begin
  while us <> me do begin
    if us.server.linktime = secondlinkts then if greaternames(us.name,tuser(us.server.parentserver.us).name) then begin
      greaternamelink := us;
    end;
    us := tuser(us.server.parentserver.us);
  end;
end;

procedure youngestlinkloop;
begin
  while us <> me do begin
    if us.server.linktime > youngestlink.server.linktime then youngestlink := us;
    us := tuser(us.server.parentserver.us);
  end;
end;

procedure secondlinkloop;
begin
  while us <> me do begin
    if (us <> youngestlink) and (us.server.linktime <= youngestlinkts) and (us.server.linktime > secondlinkts) then begin
      secondlinkts := us.server.linktime;
    end;
    us := tuser(us.server.parentserver.us);
  end;
end;

begin
  existingname := findname(newname);
  existingnum := findnumeric(p10inttostr(newnum,2));

  {no collision}
  if not (assigned(existingname) or assigned(existingnum)) then begin

    {search for outgoing connections with the name and cancel them}
    for a := 0 to highconnection do if connectionlist[a].open then if isinitiated(connectionlist[a].user) then begin
      if (a <> newfrom.socknum) then begin
        if strcompup(connectionlist[a].connectto_str,newname) then begin
          connectionlist[a].user.error := 'server got introduced from different direction';
          connectionlist[a].user.destroy;
        end;
      end;
    end;
    result := 0;
    exit;
  end;

  if (existingname = me) then begin
    resultstr := 'name collision with me';
    result := 1;
    goto finish;
  end;

  if (existingnum = me) then begin
    resultstr := 'numeric collision with me';
    result := 1;
    goto finish;
  end;

  if assigned(existingname) then if flag_isset(existingname.server.flags,servflag_ulined) then begin
    resultstr := 'name collision with services';
    result := 1;
    goto finish;
  end;

  if assigned(existingnum) then if flag_isset(existingnum.server.flags,servflag_ulined) then begin
    resultstr := 'numeric collision with services';
    result := 1;
    goto finish;
  end;

  if assigned(existingname) then if (newnum <> existingname.server.p10num) then begin
    resultstr := 'name collision, different numerics: '+inttostr(newnum)+' '+inttostr(existingname.server.p10num);
    result := 2;
    goto finish;
  end;

  if assigned(existingnum) then if not strcompup(newname,existingnum.name) then begin
    wallops('SERVER Numeric Collision: '+existingnum.name+' != '+newname);
    resultstr := 'NUMERIC collision between '+newname+' and '+existingnum.name+'. Is your server numeric correct ?';
    result := 2;
    goto finish;
  end;

  if existingname = nil then existingname := existingnum;
  {here, existingname is always the existing server}

  if isserver(newfrom) and (existingname.from = newfrom.from) then begin
    resultstr := 'collision, both servers from same direction. impossible.';
    result := 1;
    goto finish;
  end;

  {server collision: juped (2)}

  {!!can't search for existing unreg/handshake links this way, they dont exist in the namespace,
  so have to search for handshake (outgoing connect attempts) and break them,
  reason "collision: server got introduced from different direction"
  to prevent a collision later}

  if isunreg(newfrom) then begin
    if (newts <= existingname.server.linktime) then begin
      result := 1;
      resultstr := 'server already exists, link is '+inttostr(existingname.server.linktime-newts)+' seconds younger';
      goto finish;
    end;

    resultstr := 'Ghost';
    result := 4;
    goto finish;
  end;

  if flag_isset(newfrom.from.server.flags,servflag_ghost) then begin
    resultstr := 'Ghost loop';
    result := 3;
    goto finish;
  end;



  {second youngest link: path between existing-me-new -

  A-B-C-D
  |     |
  E-F-G-H

  the new server too is included in search
  }

  {find youngest link in loop}
  us := existingname;
  youngestlink := us;
  youngestlinkloop;
  if isserver(newfrom) then begin
    us := newfrom;
    youngestlinkloop;
  end;
  youngestlinkts := youngestlink.server.linktime;
  if newts > youngestlinkts then begin
    youngestlinkts := newts;
    youngestlink := nil;
  end;

  {find the TS of second link - not the server itself - second link can have the same TS as the youngest link}
  secondlinkts := 0;
  us := existingname;
  secondlinkloop;
  if isserver(newfrom) then begin
    us := newfrom;
    secondlinkloop;
  end;
  if (youngestlink <> nil) and (newts > secondlinkts) and (newts <= youngestlinkts) then begin
    secondlinkts := newts;
  end;

  {find the link with the greatest server name(s), and the TS equal to the second youngest link TS}
  greatername1 := '';
  greatername2 := '';
  greaternamelink := nil;
  us := existingname;
  greaternameloop;
  if isserver(newfrom) then begin
    us := newfrom;
    greaternameloop;
  end;
  if newts = secondlinkts then begin
    if isserver(newfrom) then begin
      if greaternames(newname,newfrom.name) then greaternamelink := nil; {new introduced server. must send SQ}
    end else begin
      if greaternames(newname,me.name) then greaternamelink := newfrom; {new direct connection. must break link}
    end;
  end;

  resultstr := 'loop: second youngest link';
  if greaternamelink = nil then begin
    result := 2;
    locnotice(SNO_NETWORK,'loop: '+newname+', second youngest link');
    sendto_one(newfrom,sprefix(me,TOK_SQUIT)+newname+' '+inttostr(newts)+' :'+resultstr);
  end else begin
    if greaternamelink.from = newfrom.from then result := 2 else result := 3;
    greaternamelink.error := resultstr;
    greaternamelink.destroy;
  end;
  exit;

finish:
  case result of
    1:begin
      newfrom.from.error := resultstr;
      newfrom.from.destroy;
    end;
    2:begin
      if isserver(newfrom.from) then begin
        {new server was existing server link introducing another server}
        sendto_one(newfrom.from,sprefix(me,TOK_SQUIT)+newname+' '+inttostr(newts)+' :'+resultstr);
      end else begin
        newfrom.from.error := resultstr;
        newfrom.from.destroy;
      end;
    end;
    3,4:begin
      existingname.error := resultstr;
      existingname.destroy;
    end;
  end;
end;


procedure gotbootts(i:integer);
begin
  if (i < bootts) and (i > oldest_ts) then begin
    locnotice(SNO_OLDSNO,'Boot timestamp changed from '+inttostr(bootts)+' to '+inttostr(i)+' ('+timestrshort(i)+')');
    bootts := i;
  end;
end;


{
SENDER name hops bootts linkts J10 SSCCC +hs :[0.0.0.0] description
  0      1    2    3       4    5   6    7   -1
parc
}
procedure mu_server(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  s:bytestring;
  a,b,hops,p10num,p10max,ts1,ts2,newlinkts,myts:integer;
  pcl,cl:tconfline;
  bool:boolean;
  p:tserver;
  us:tuser;
  l:listenobject;
  bm:tbanmask;
  idstr:bytestring;
  ghosted:boolean;
  namematches:boolean;
  maskmatches:boolean;
begin
  l := connectionlist[cptr.socknum].listener;
  if l <> nil then begin
    if not l.serveraccept then begin
      cptr.error := 'Use another port';
      cptr.destroy;
      exit
    end;
  end;

  {enough params}
  if parc < 8 then begin
    cptr.error := 'Not enough parameters';
    cptr.destroy;
    exit;
  end;

  if (parv[5] <> 'J10') and (parv[5] <> 'P10') then begin
    cptr.error := 'Bogus protocol ('+parv[5]+')';
    cptr.destroy;
    exit;
  end;
  parv[5,1] := 'J'; {server link must start as J}

  {valid servername}
  if not validservername(parv[1]) then begin
    cptr.error := 'Bogus servername ('+parv[1]+')';
    cptr.destroy;
    exit;
  end;

  {bogus hopcount}
  if parv[2] <> '1' then begin
    cptr.error := 'Bogus hopcount ('+parv[2]+')';
    cptr.destroy;
    exit;
  end;

  {bogus timestamps}
  ts1 := strtointdef(parv[3],0);
  ts2 := strtointdef(parv[4],0);
  if (ts1 < OLDEST_TS) or (ts2 < OLDEST_TS) then begin
    cptr.error := 'Bogus timestamps ('+parv[3]+' '+parv[4]+')';
    cptr.destroy;
    exit;
  end;

  {bogus numeric}
  idstr := convertidstrlong(parv[6]);
  if (length(idstr) <> 5) or (p10strtoint(idstr) = -1) then begin
    cptr.error := 'Bogus numeric ('+parv[6]+')';
    cptr.destroy;
    exit;
  end;

  {authorization, find a C-line}
  banmaskmake_oneuser(@bm,'',cptr.host,cptr.binip);
  namematches := false;
  maskmatches := false;
  pcl := conflinelist;
  cl := nil;
  while pcl <> nil do begin
    if pcl.c = 'C' then begin
      if banmaskmatch(@pcl.bm,@bm) then begin
        maskmatches := true;
        if maskmatchup(pcl.s3,parv[1]) or (pos('.',pcl.s3) = 0) then begin
          namematches := true;
          if pcl.s2 = cptr.password then begin
            cl := pcl;
            break;
          end;
        end;
      end;
    end;
    pcl:= tconfline(pcl.next);
  end;

  {no matching C:line found, fallthrough: find N:line}

  if cl = nil then begin
    pcl := conflinelist;
    while pcl <> nil do begin
      if pcl.c = 'N' then begin
        if banmaskmatch(@pcl.bm,@bm) then begin
          if maskmatchup(pcl.s3,parv[1]) or (pos('.',pcl.s3) = 0) then begin
            if pcl.s2 = cptr.password then begin
              cl := pcl;
              break;
            end;
          end;
        end;
      end;
      pcl:= tconfline(pcl.next);
    end;
  end;

  if cl = nil then begin
    if namematches and maskmatches then s := 'password incorrect'
    else if maskmatches then s := 'no server name match'
    else s := 'no mask match';
    locnotice(SNO_UNAUTH,'Received unauthorized connection from '+parv[1]+': '+s);
    cptr.error := 'No C-line';
    cptr.destroy;
    exit;
  end;

  if not opt.hub then begin
    b := 0;
    for a := 1 to maxserverlink do begin
      if serverlinklist[a] <> nil then b := 1;
    end;
    if b <> 0 then begin
      locnotice(SNO_NETWORK,'Failed connection from '+parv[1]+', this server is not hub.');
      cptr.error := 'I am not configured to be hub';
      cptr.destroy;
      exit;
    end;
  end;
  b := 0;
  for a := 0 to maxserverlink do begin
    if serverlinklist[a] = nil then b := 1;
  end;
  if b = 0 then begin
    locnotice(SNO_NETWORK,'Failed connection from '+parv[1]+', no more server links possible.');
    cptr.error := 'No more server links possible';
    cptr.destroy;
    exit;
  end;

  myts := getlinkts;
  if isinitiated(cptr) then newlinkts := ts2 else newlinkts := myts;


  p10num := p10strtoint(copy(idstr,1,SSlen)) and SSmask;
  p10max := p10strtoint(copy(idstr,1+SSlen,CCClen)) and CCCmask;

  {new link time is already known: its ts2 if handshake, irctime if accepting}
  b := cptr.socknum;
  a := servercollision(p10num,parv[1],cptr,newlinkts,s);

  if (a <> 0) then locnotice(SNO_NETWORK,'Incoming server connection '+parv[1]+' collision: '+s);

  ghosted := a = 4;
  if not connectionlist[b].open then exit;

  {here, all checks must be passed}

  {connection becomes server}
  if cptr.ipcheck <> nil then cptr.ipcheck.attempt := 0;
  ipcheck_connectfailed(cptr.ipcheck); {this is to not throttle server links}
  cptr.ipcheck := nil;
  setname(cptr,parv[1]);
  cptr.fullname := copy(parv[parc-1],1,maxgcoslength);
  addserver(cptr,p10num,p10max,me.server);
  setflag(cptr.flags,userflag_nopenalty);
  if ghosted then setflag(cptr.server.flags,servflag_ghost);
  dec(count.unknown);
  inc(count.localservers);
  updatehighestconnections;
  cptr.hops := 1;
  if parv[5,1] = 'J' then begin
    setflag(cptr.server.flags,servflag_joining);
    inc(receivingburst);
  end;
  cptr.server.linktime := ts2;
  clearflag(cptr.flags,userflag_pongneeded);

  if parc > 8 then if parv[7,1] = '+' then begin
    if pos('h',parv[7]) <> 0 then setflag(cptr.server.flags,servflag_hub);
    if pos('s',parv[7]) <> 0 then setflag(cptr.server.flags,servflag_services);
  end;

  if not isinitiated(cptr) then begin
    {send PASS and SERVER}
    sendto_one(cptr,'PASS :'+cl.s2);
    sendto_one(cptr,'SERVER '+me.name+' 1 '+inttostr(bootts)+' '+inttostr(myts)+' J10 '+convertidstr(me.idstr+p10inttostr(me.server.p10max,3))+{$ifndef noipv6}' +6'+{$endif}' :'+me.fullname);
    connectionlist[cptr.socknum].connectby_str := '*!*@'+cptr.name;
  end;

  {timestamp stuff}
  if opt.reliableclock then begin
    if ts1 < bootts then bootts := ts1;
  end else begin
    bool := false;
    if ts1 < bootts then begin
      gotbootts(ts1);
      bool := true;
    end else if (ts1 > bootts) then begin
      {}
    end else if myts <> ts2 then begin
      if isinitiated(cptr) then bool := true;
    end;
    if bool then begin
      locnotice(SNO_OLDSNO,'clock adjusted by adding '+inttostr(ts2-irctime));
      settime(ts2);
    end;
  end;
  cptr.server.linktime := newlinkts;

  for a := 0 to maxserverlink do begin
    if serverlinklist[a] = nil then begin
      if a > highserverlink then highserverlink := a;
      serverlinklist[a] := cptr.server;
      cptr.server.serverlinknum := a;
      break;
    end;
  end;

  locnotice(SNO_NETWORK,'Link with '+cptr.name+' established');
  locnotice(SNO_NETWORK,'Net junction: '+me.name+' '+cptr.name);


  sendto_serversbutone(cptr,propagateserverstr(cptr.server));

 {
  need to do Y:line stuff here
  }
  connectionlist[cptr.socknum].classnum := cl.i5;
  if (cl.i5 > 0) and (cl.i5 <= maxclass) then inc(classcount[cl.i5]);

  pcl := getyline(connectionlist[cptr.socknum].classnum);

  if pcl = nil then begin
    {no Y:line, use some defaults}
    connectionlist[cptr.socknum].pingfreq := 30;
    connectionlist[cptr.socknum].maxsendq := 3000000;
  end else begin
    connectionlist[cptr.socknum].pingfreq := strtointdef(pcl.s2,0);
    connectionlist[cptr.socknum].maxsendq := pcl.i5;
  end;
  connectionlist[cptr.socknum].pingtime := unixtime;

  if isulined(cptr.name) then
  setflag(cptr.server.flags,servflag_ulined);

  if opt.reliableclock then if abs(ts2-irctime) >= 30 then begin
    sendto_one(cptr,sprefix(me,TOK_SETTIME)+inttostr(irctime));
    locnotice(sno_oldsno,'Connected to a net with a TS difference of '+inttostr(ts2-irctime)+', sent SETTIME to correct this.');
  end;

  {send all servers except for me and new server, nearest first}
  hops := 1;
  repeat
    bool := false;
    p := tserver(globalserverlist);
    while p <> nil do begin
      if tuser(p.us).hops = hops then if tuser(p.us) <> cptr then begin
        sendto_one(cptr,propagateserverstr(p));
        bool := true;
      end;
      p := tserver(p.next);
    end;
    inc(hops);
  until not bool;

  {send all clients}
  us := tuser(globaluserlist);
  while us <> nil do begin
    if isclient(us) then sendto_one(cptr,propagateuserstr(us));
    us := tuser(us.next);
  end;

  burst_channels(cptr);
  glineburst(cptr);
  sendto_one(cptr,sprefix(me,TOK_END_OF_BURST));
end;

{SENDER name hops bootts linkts P10 SSCCC 0 :[0.0.0.0] description
  0      1    2    3       4    5   6     7  -1}

procedure ms_server(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  p10num,p10max:integer;
  us:tuser;
  a,b,ts1,ts2:integer;
  s:bytestring;
  p:tconfline;
  idstr:bytestring;
begin
  if (parc < 9) then begin
    cptr.error := 'Not enough parameters in SERVER message';
    cptr.destroy;
    exit;
  end;

  if not isserver(sptr) then begin
    cptr.error := 'received SERVER message, source is a user';
    cptr.destroy;
    exit;
  end;

  {hopcount}
  a := strtointdef(parv[2],0);
  if a <> sptr.hops+1 then begin
    cptr.error := 'Bogus hopcount: ('+sptr.name+' '+inttostr(sptr.hops)+' '+parv[2]+')';
    cptr.destroy;
    exit;
  end;

  {bogus timestamps}
  ts1 := strtointdef(parv[3],0);
  ts2 := strtointdef(parv[4],0);
  if (ts2 < oldest_ts) then begin
    cptr.error := 'Bogus timestamps ('+parv[3]+' '+parv[4]+')';
    cptr.destroy;
    exit;
  end;

  {valid servername}
  if not validservername(parv[1]) then begin
    cptr.error := 'Bogus servername ('+parv[1]+')';
    cptr.destroy;
    exit;
  end;

  idstr := convertidstrlong(parv[6]);
  if ((length(idstr) <> 3) and (length(idstr) <> 5)) or (p10strtoint(idstr) = -1) then begin
    cptr.error := 'Bogus numeric ('+parv[6]+')';
    cptr.destroy;
    exit;
  end;

  {H:lines}
  a := 0;
  p := conflinelist;
  while p <> nil do begin
    if maskmatchup(p.s3,cptr.name) then begin
      if maskmatchup(p.s1,parv[1]) then begin
        a := 1;
        break;
      end
    end;
    p := tconfline(p.next);
  end;
  if a = 0 then begin
    cptr.error := 'No H-line';
    cptr.destroy;
    exit
  end;

  {servercollision}
  p10num := p10strtoint(copy(idstr,1,SSlen)) and SSmask;
  p10max := p10strtoint(copy(idstr,1+SSlen,CCClen)) and CCCmask;

  b := cptr.socknum;
  a := servercollision(p10num,parv[1],sptr,ts2,s);
  if (a = 1) or (a = 2) then exit;
  if not connectionlist[b].open then exit;

  us := adduser;
  us.from := cptr;
  setname(us,parv[1]);
  us.hops := sptr.hops+1;
  us.fullname := copy(parv[parc-1],1,maxgcoslength);

  addserver(us,p10num,p10max,sptr.server);

  if parv[5,1] = 'J' then begin
    setflag(us.server.flags,servflag_joining);
    inc(receivingburst);
  end else setflag(us.server.flags,servflag_burstack);
  if flag_isset(us.server.flags,servflag_joining) then begin
    locnotice(SNO_NETWORK,'Net junction: '+sptr.name+' '+us.name);
  end;

  if opt.reliableclock then
  if flag_isset(us.server.flags,servflag_joining) then
  if abs(ts2-irctime) >= 30 then begin
    sendto_one(us,sprefix(me,TOK_SETTIME)+inttostr(irctime));
    locnotice(sno_oldsno,'Connected to a net with a TS difference of '+inttostr(ts2-irctime)+', sent SETTIME to correct this.');
  end;

  us.server.serverlinknum := sptr.server.serverlinknum;
  us.server.parentserver := sptr.server;
  us.server.linktime := strtointdef(parv[4],0);

  if parv[7,1] = '+' then begin
    if pos('h',parv[7]) <> 0 then setflag(us.server.flags,servflag_hub);
    if pos('s',parv[7]) <> 0 then setflag(us.server.flags,servflag_services);
    if pos('6',parv[7]) <> 0 then setflag(us.server.flags,servflag_ipv6aware);
  end;

  gotbootts(ts1);

  us.server.protoversion := strtointdef(copy(parv[5],2,2),0);

  sendto_serversbutone(cptr,propagateserverstr(us.server));

  if isulined(us.name) then
  setflag(us.server.flags,servflag_ulined);
end;

end.
