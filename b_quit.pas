(*
 *  beware ircd, Internet Relay Chat server, b_quit.pas
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


unit b_quit;

interface

uses bcmds,buser,bstuff,bconsts;

procedure m_quit(cptr,sptr:tuser;parc:integer;parv:pparams);

implementation

uses bchannel,bconfig;

procedure m_quit(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  p:tuserchan;
  bool:boolean;
begin
  setflag(sptr.flags,userflag_noerror);
  sptr.error := parv[parc-1];
  if (parc >= 2) then if (cptr.error <> '') then begin
    {user gives a quit reason}

    if sptr = cptr then begin
      {permission to send}
      bool := false;
      p := tuserchan(sptr.channel);
      while p <> nil do begin
        if not cansendtochannel(cptr,p.ch,p) then begin
          bool := true;
          break;
        end;

        {$ifndef noqnet}
          {no colors?}
        if flag_isset(p.ch.modeflag,chanmode_noquitreason) then begin
          bool := true;
          break;
        end;

        if flag_isset(p.ch.modeflag,chanmode_nocolors) then
        if pos(#3,sptr.error) <> 0 then begin
          bool := true;
          break;
        end;

        {$endif}

        p := tuserchan(p.next);
      end;

      if not opt.quitprefix then begin
        {no quitprefix; check for disallowed quit reason}
        if (pos('Killed',sptr.error) = 1) or (pos('Local kill',sptr.error) = 1) then bool := true;
      end;
      if bool then begin
        sptr.error := 'Signed off'
      end else begin
        if opt.quitprefix then sptr.error := 'Quit: '+sptr.error;
      end;
      sptr.error := copy(sptr.error,1,opt.topiclen);
    end;
  end;
  sptr.destroy;
end;

end.
