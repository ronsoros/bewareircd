(*
 *  beware ircd, Internet Relay Chat server, bunixsignals.pas
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

unit bunixsignals;

interface

uses
  {$ifdef VER1_0}
    linux,
  {$else}
    baseunix,
    unix,
  {$endif}
  lcore,lsignal,
  sysutils;

procedure init;

implementation

uses bircdunit,bsend,bconfig;

type
  tsigc=class(tobject)
    procedure signalhandler(sender:tobject;signal:integer);
    procedure rehashhandler(wparam:integer;lparam:integer);
  end;

var
  sigc:tsigc;

procedure tsigc.rehashhandler;
begin
  locnotice(SNO_OLDSNO,'Received signal SIGHUP, rehashing');
  bconfig.init;
end;

procedure tsigc.signalhandler;
begin
  if signal = sighup then begin
   
    lcore.addtask(self.rehashhandler,tobject(nil),0,0);
    exit;
  end;
  case signal of
    sigterm: triggershutdown('received signal SIGTERM',false);
    sigint: triggershutdown('received signal SIGINT',true);
  end;
end;

procedure init;
begin
  with tlsignal.create(nil) do onsignal := sigc.signalhandler;
  starthandlesignal(sigterm);
  starthandlesignal(sigint);
  starthandlesignal(sighup);
end;

end.
