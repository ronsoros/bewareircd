(*
 *  beware ircd, Internet Relay Chat server, bircd.dpr
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


program bircd;

{$include bircd.inc}

uses
  {$ifndef nowinnt}bwinnt,{$endif}
  {$ifndef mswindows}baseunix,bunixsignals,unitfork,{$endif}
  {$ifndef nosignal}bsignal,{$endif}
  bstuff,bircdunit,bparse,bconfig,btime,sysutils;

{$ifndef noicon}
  {$R *.RES}
{$endif}

begin
 {$ifndef fpc}
 {$IF CompilerVersion >= 26}formatsettings.{$ifend}
 {$endif}

 decimalseparator := '.';         {override local differences}

  getpath; {chdir to bircd.exe directory}

  getparams;

  bparse.init;
  bconfig.init;

  btime.init;

  {$ifndef nowinnt}
  if paramstr(1) = 'install' then begin
    installservice(paramstr(2) = 'auto');
    {$ifndef noini}
    {if you disable ini support and want to run as service,
    set the runasservice option manually in bconfig}
    opt.runasservice := true;
    writecfg;
    {$endif}
    halt;
  end;

  if paramstr(1) = 'uninstall' then begin
    uninstallservice;
    {$ifndef noini}
    opt.runasservice := false;
    writecfg;
    {$endif}
    halt;
  end;
  {$endif}

  {$ifndef nowinnt}
  if opt.runasservice then begin
    runservice;
    halt;
  end else bircdunit_lcoreinit;
  {$endif}

  {$ifndef nosignal}
  if paramstr(1) = 'signal' then begin
    sendsignal(paramstr(2));
    halt;
  end;
  {$endif}

  if paramstr(1) = 'writeini' then begin
    {must be after "init"}
    writecfg;
    halt;
  end;

  {$ifdef unix}
  {$ifndef bdebug}if not foregroundmode then dofork('bircd');{$endif}
  bunixsignals.init;
  {$endif}


  initapplication;
  runapplication;
  CleanupApplication;
end.

