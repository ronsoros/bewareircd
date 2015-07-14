(*
 *  beware ircd, Internet Relay Chat server, b_get.pas
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


unit b_get;

interface

uses buser,bstuff,pgtypes;

procedure m_get(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bsend,bcmds,bserver,breplies,bconfig,bparse;

{
get setting
get setting remoteserver
}

procedure m_get(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  a,b:integer;
  srv:tuser;
  searchmask:bytestring;
begin
  if checkneedmoreparams(sptr,cmdnum,1,parc,parv) then exit;
  if (parc > 2) and (parv[2] <> '') then begin
    srv := getremoteserver(parv[1],not isserver(cptr));
    if srv = nil then begin
      sendnosuchserver(sptr,parv[1]);
      exit;
    end;
    if srv <> me then begin
      sendmsgto_one(sptr,srv,cmdget,parv[parc-1]);
      exit;
    end;
  end;
  if parv[parc-1] = '0' then searchmask := '*' else searchmask := ircupper(parv[parc-1]);
  b := 0;
  for a := 0 to maxoptiontable do begin
    if maskmatchup(searchmask,optiontable[a].name) then begin
      sendreply(sptr,cmdnotice,':GET: '+optiontable[a].name+'='+optionstr(a));
      b := 1;
    end;
  end;
  if b = 0 then sendreply(sptr,cmdnotice,':option not found. use GET * to see all.');
end;

end.
