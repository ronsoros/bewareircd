(*
 *  beware ircd, Internet Relay Chat server, b_motd.pas
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

unit b_motd;

interface

uses buser,bcmds,bstuff,sysutils,classes,pgtypes;

const
  motdfile='ircd.motd';

procedure m_motd(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_shortmotd(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure m_motdsignon(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses
  bsend,breplies,bserver,bconfig,unitmotdcache,unitbanmask,bprivs;

function getmotdfilename(us:tuser):bytestring;
var
  cl:tconfline;
  bm:tbanmask;
begin
  result := motdfile;
  banmaskmake_oneuser(@bm,'',us.host,us.binip);
  cl := conflinelist;
  while cl <> nil do begin
    if cl.c = 'T' then begin
      if banmaskmatch(@cl.bm,@bm) then begin
        result := cl.s2;
       { if pos('\',result) = 0 then result := result;}
        exit;
      end;
    end;
    cl := tconfline(cl.next);
  end;
end;

procedure m_motd(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a:integer;
  srv:tuser;
  sl:tstringlist;
begin
  if (parc >= 2) and (parv[1] <> '') then begin
    {$ifndef nohis}
    if opt.headinsand then if not hasprivs(cptr,privs_his) then begin
      sendreply(sptr,ERR_NOPRIVILEGES,getrpl0(ERR_NOPRIVILEGES));
      exit;
    end;
    {$endif}
    srv := getremoteserver(parv[1],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[1]);
      exit;
    end;
    if srv <> me then begin
      sendmsgto_one(sptr,srv,cmdmotd,'');
      exit;
    end;
  end;

  sl := getmotdcache(getmotdfilename(sptr));
  if sl.count = 0 then begin
    sendreply(sptr,ERR_NOMOTD,getrpl0(ERR_NOMOTD));
  end else begin
    sendreply(sptr,RPL_MOTDSTART,getrpl1(RPL_MOTDSTART,me.name));
    for a := 0 to sl.count-1 do begin
      sendreply(sptr,RPL_MOTD,sl[a]);
    end;
    sendreply(sptr,RPL_ENDOFMOTD,getrpl0(RPL_ENDOFMOTD));
  end;
end;

procedure m_shortmotd(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  sl:tstringlist;
begin
  sl := getmotdcache(getmotdfilename(sptr));
  if sl.count = 0 then begin
    sendreply(sptr,ERR_NOMOTD,getrpl0(ERR_NOMOTD));
  end else begin
    sendreply(sptr,RPL_MOTDSTART,getrpl1(RPL_MOTDSTART,me.name));
    if opt.shortmotdstr <> '' then sendreply(sptr,RPL_MOTD,':'+opt.shortmotdstr);
    sendreply(sptr,RPL_MOTD,':'#2'Type /MOTD to read the AUP before continuing using this service.');
    sendreply(sptr,RPL_MOTD,':The message of the day was last changed: '+copy(sl[0],4,length(sl[0])));
    sendreply(sptr,RPL_ENDOFMOTD,getrpl0(RPL_ENDOFMOTD));
  end;
end;

procedure m_motdsignon(cptr,sptr:tuser;parc:integer;parv:pparams);
begin
  if opt.shortmotd then
  m_shortmotd(cptr,sptr,0,nil)
  else
  m_motd(cptr,sptr,0,nil);
end;

end.
