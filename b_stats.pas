(*
 *  beware ircd, Internet Relay Chat server, b_stats.pas
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

unit b_stats;

interface

{$include bircd.inc}

uses buser,bstuff,bcmds,blargenum;

procedure m_stats(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  {$ifndef nowinnt}
  bwinnt,
  {$endif}
  bconfig,breplies,bsend,btime,bserver,bparse,b_gline,blinklist,bsock,bipcheck,
  sysutils,bprivs,bwelcome,pgtypes;


{$ifdef fpc} 
  {$ifdef ver1_0} 
    {$define fpcbefore195} 
  {$endif} 
  {$ifdef ver1_9_4} 
    {$define fpcbefore195} 
  {$endif} 
{$endif}

procedure heapstats(sptr:tuser);
var
  {$ifndef fpcbefore195}
  hs:theapstatus;
  {$else}
  hs:tmemorymanager;
  {$endif}
begin
  {$ifndef fpcbefore195}
        hs := getheapstatus;
        sendreply(sptr,1200,':TotalAddrSpace '+inttostr(hs.TotalAddrSpace));
        sendreply(sptr,1200,':TotalUncommitted '+inttostr(hs.TotalUncommitted));
        sendreply(sptr,1200,':TotalCommitted '+inttostr(hs.TotalCommitted));
        sendreply(sptr,1200,':TotalAllocated '+inttostr(hs.TotalAllocated));
        sendreply(sptr,1200,':TotalFree '+inttostr(hs.TotalFree));
        sendreply(sptr,1200,':FreeSmall '+inttostr(hs.FreeSmall));
        sendreply(sptr,1200,':FreeBig '+inttostr(hs.FreeBig));
        sendreply(sptr,1200,':Unused '+inttostr(hs.Unused));
        sendreply(sptr,1200,':Overhead '+inttostr(hs.Overhead));
        sendreply(sptr,1200,':linklist items: '+inttostr(linklistdebug));
        sendreply(sptr,1200,':IPcheck items: '+inttostr(ipcheckdebugcount));
        {$ifndef nowinnt}
        sendreply(sptr,1200,':runasservice: '+inttostr(ord(runasservice)));
        {$endif}
  {$else}
  getmemorymanager(hs);
  sendreply(sptr,1200,':TotalAllocated '+inttostr(hs.heapsize()-memavail));
  {$endif}
  sendreply(sptr,1200,':total sendQ size: '+inttostr(totalsendq)+' peak '+inttostr(totalsendqpeak));
end;

procedure m_stats(cptr,sptr:tuser;parc:integer;parv:pparams);
label skip;
var
  c:bytechar;
  p:tconfline;
  s:bytestring;
  a,b:integer;
  srv:tuser;
  srv2:tserver;
begin
  if checkneedmoreparams(cptr,cmdnum,1,parc,parv) then exit;
  c := parv[1,1];
  p := conflinelist;

  if (parv[2] <> '') and (parc >= 3) then begin
    {$ifndef nohis}
    if opt.headinsand and not hasprivs(cptr,privs_his) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    {$endif}
    srv := getremoteserver(parv[2],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[2]);
      exit;
    end;
    if srv <> me then begin
      sendto_one(srv,sprefix(sptr,TOK_STATS)+parv[1]+' '+srv.idstr);
      exit;
    end;
  end;

  if length(parv[1]) > 1 then goto skip;

  if not hasprivs(sptr,privs_his) then if pos(parv[1],opt.secretstats) <> 0 then begin
    sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
    exit;
  end;

  case c of
    'C','c','N','n':begin
      while p <> nil do begin
        if (p.c = 'C') or (p.c = 'N') then begin
          sendreply(sptr,RPL_STATSCLINE,p.c+' * * '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5));
        end;
        p := tconfline(p.next);
      end;
    end;

    'd':begin
      if hasprivs(sptr,privs_his) then begin
        heapstats(sptr);
      end;
    end;
    'D':begin
      begin
        {ip check table status}
        {$ifdef bdebug}
        if isanoper(sptr) then ipcheckdebug(sptr);
        {$endif}
      end;
    end;
    'H','h':begin
      while p <> nil do begin
        if p.c = 'H' then begin
          if p.s1 = '' then s := '*' else s := p.s1;
          sendreply(sptr,RPL_STATSHLINE,'H '+s+' * '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5));
        end;
        p := tconfline(p.next);
      end;
    end;


    'I','i':begin
      while p <> nil do begin
        if p.c = 'I' then begin
          if passwordislimit(p.s2,a,b) then s := p.s2 else s := '*';
          if s = '' then s := '0';
          sendreply(sptr,RPL_STATSILINE,'I '+p.s1+' '+s+' '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5));
        end;
        p := tconfline(p.next);
      end;
    end;
    'O','o':begin
      while p <> nil do begin
        if (p.c = 'O') or (p.c = 'o') then begin
          s := p.s1;
          if pos('@',s) = 0 then s := '*@'+s;
          sendreply(sptr,RPL_STATSOLINE,p.c+' '+s+' * '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5));
        end;
        p := tconfline(p.next);
      end;
    end;
    'K','k':begin
      p := klist;
      begin

        if (parv[3] = '') or (parc < 4) then parv[3] := '*';
        if parv[3] = '*' then begin
          while p <> nil do begin
            if p.c = 'K' then begin
              if p.s2 = '' then s := '*' else s := p.s2;
              for a := 1 to length(s) do if s[a] = ' ' then s[a] := '_';
              sendreply(sptr,RPL_STATSKLINE,'K '+p.s1+' '+s+' '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5));
            end;
            p := tconfline(p.next);
          end;
        end else begin
          while p <> nil do begin
            if p.c = 'K' then begin
              if maskmatchup(parv[3],p.s3+'@'+p.s1) then begin
                if p.s2 = '' then s := '*' else s := p.s2;
                for a := 1 to length(s) do if s[a] = ' ' then s[a] := '_';
                sendreply(sptr,RPL_STATSKLINE,'K '+p.s1+' '+s+' '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5));
              end;
            end;
            p := tconfline(p.next);
          end;
        end;
      end;
    end;
    'Y','y':begin
      while p <> nil do begin
        if p.c = 'Y' then begin
          a := strtointdef(p.s1,0);
          if (a >= 0) and (a <= maxclass) then
          a := classcount[a] {show how many connections on the class}
          else
          a := 0;
          sendreply(sptr,RPL_STATSYLINE,'Y '+p.s1+' '+p.s2+' '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5)+' '+inttostr(a));
        end;
        p := tconfline(p.next);
      end;
    end;
    'u':begin
      a := unixtime-starttime;
      sendreply(sptr,RPL_STATSUPTIME,getrpl2(RPL_STATSUPTIME,inttostr(a div 86400),inttostr(a div 3600 mod 24)+':'+inttostr(a div 600 mod 6)+
        inttostr(a div 60 mod 10)+':'+inttostr(a div 10 mod 6)+inttostr(a mod 10)));
      sendreply(sptr,RPL_STATSCONN,getrpl2(RPL_STATSCONN,inttostr(count.highestconnections),inttostr(count.highestlocalclients)));
    end;
    'U':begin
      while p <> nil do begin
        if p.c = 'U' then begin
          if p.s2 = '' then s := '<NULL>' else s := p.s2;

          sendreply(sptr,RPL_STATSULINE,'U '+p.s1+' '+s+' '+p.s3+' '+inttostr(p.i4)+' '+inttostr(p.i5));
        end;
        p := tconfline(p.next);
      end;
    end;

    'M','m':begin
      for a := 0 to numcmds do if statsm[a,0] <> 0 then if not flag_isset(cmdtable[a].flags,MFLG_DISABLED) then begin
        sendreply(sptr,RPL_STATSCOMMANDS,':'+cmdtable[a].cmd+' '+inttostr(statsm[a,0])+' '+inttostr(statsm[a,1]));
      end;
    end;

    'G','g':begin
      begin
        if (parv[3] = '') or (parc < 4) then parv[3] := '*';
        list_glines(sptr,parv[3]);
      end;
    end;
    't':begin
      begin
        sendreply(sptr,1200,':Sent:     '+largenumstr(count.sendc)+' K  ('+formatfloat('0.0#',largenumfloat(count.sendc)/(unixtime-starttime))+' K/s)');
        sendreply(sptr,1200,':Received: '+largenumstr(count.recvc)+' K  ('+formatfloat('0.0#',largenumfloat(count.recvc)/(unixtime-starttime))+' K/s)');
      end;
    end;
    'T':begin
      while p <> nil do begin
        if p.c = 'T' then begin
          sendreply(sptr,RPL_STATSTLINE,'T '+p.s1+' '+p.s2);
        end;
        p := tconfline(p.next);
      end;
    end;
    'P','p':begin
      while p <> nil do begin
        if p.c = 'P' then begin
          if isprivileged(sptr) or (pos('H',p.s3) = 0) then begin

            {search for listener}
            a := -1;
            for b := 0 to maxlistener do if listenlist[b] <> nil then begin
              if listenlist[b].port = p.i4 then if listenlist[b].localaddr = makelocaladdr(p.s2)
              then a := b;
            end;
            if (a >= 0) then a := listenlist[a].count;

            s := p.s2;
            if s = '' then s := '*';

            sendreply(sptr,RPL_STATSPLINE,'P '+inttostr(p.i4)+' '+s+' '+inttostr(a)+' :'+p.s3);
          end;
        end;
        p := tconfline(p.next);
      end;
    end;
    'j','J':begin
      begin
        sendreply(sptr,1249,':Histogram of message lengths ('+inttostr(histogram[0])+' messages)');
        for a := 0 to 31 do begin
          s := inttostr(a shl 4+1)+':';
          while length(s) < 4 do s := ' '+s;
          for b := 1 to 16 do s := s + ' '+inttostr(histogram[a shl 4+b]);
          sendreply(sptr,1249,':'+s);
        end;
      end;
    end;
    'l','L':begin
      begin
        sendreply(sptr,1211,':name class sendQ MaxSendQ Pingfreq');
        for a := 0 to highconnection do if connectionlist[a].open then begin
          sendreply(sptr,1211,':'+connectionlist[a].user.name+' '+inttostr(connectionlist[a].classnum)+' '+inttostr(connectionlist[a].sendqsize)+' '+inttostr(connectionlist[a].maxsendQ)+' '+inttostr(connectionlist[a].pingfreq));
        end;
      end;
    end;
    's','S':begin
      begin
        {only opers can see stats S because S:lines (atleast the real IP's) are secret}
        while p <> nil do begin
          if p.c = 'S' then begin
            sendreply(sptr,RPL_STATSSLINE,'S '+p.s1);
          end;
          p := tconfline(p.next);
        end;
      end;
    end;
    'v','V':begin
      srv2 := tserver(globalserverlist);
      me.server.linktime := bootts;
      sendreply(sptr,1326,'Servername           Uplink               Flags Hops Numeric   Lag  RTT   Up Down Clients/Max Proto LinkTS     :Info');
      while srv2 <> nil do begin
        s := tuser(srv2.us).name+' '+tuser(srv2.parentserver.us).name+' ';
        if flag_isset(srv2.flags,servflag_joining) then s := s + 'B' else s := s + '-';
        if (not flag_isset(srv2.flags,servflag_joining)) and (not flag_isset(srv2.flags,servflag_burstack)) then s := s + 'A' else s := s + '-';
        if flag_isset(srv2.flags,servflag_hub) then s := s + 'H' else s := s + '-';
        if flag_isset(srv2.flags,servflag_services) then s := s + 'S' else s := s + '-';

        s := s + ' '+inttostr(tuser(srv2.us).hops)+' '+tuser(srv2.us).idstr+' '+inttostr(srv2.p10num)+' * * * * '+inttostr(srv2.usercount)+' '+inttostr(srv2.p10max)+' ';
        if flag_isset(srv2.flags,servflag_joining) then s := s + 'J' else s := s + 'P';
        s := s + inttostr(srv2.protoversion)+' '+inttostr(srv2.linktime)+' :'+tuser(srv2.us).fullname;
        sendreply(sptr,1326,s);

        srv2 := tserver(srv2.next);
      end;

    end;
  end;
skip:
  sendreply(sptr,RPL_ENDOFSTATS,parv[1]+' '+getrpl0(RPL_ENDOFSTATS))
end;

end.
