(*
 *  beware ircd, Internet Relay Chat server, unitmotdcache.pas
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

{
this unit stores the MOTD in ram when its needed the first time,
so its not read from disk everytime it is needed
}

unit Unitmotdcache;

interface

uses classes,pgtypes;

function getmotdcache(const name:bytestring):tstringlist;
procedure clearmotdcache;

implementation

uses blinklist,b_motd,sysutils,bsend,readtxt2;

var
  cachelist:tlist;
  namelist:tstringlist;

procedure clearmotdcache;
var
  a:integer;
begin
  for a := 0 to cachelist.count-1 do begin
    tstringlist(cachelist[a]).destroy;
  end;
  cachelist.clear;
  namelist.clear;
  {invalidate motd cache}
end;

{yyyy-mm-dd hh:mm}
function dosdate(i:integer):bytestring;
var
  dt:tdatetime;
  y,m,d,h,min,sec,ms:word;
  a:integer;
begin
  dt := FileDateToDateTime(i);
  a := trunc(frac(dt)*1440);
  decodedate(dt,y,m,d);
  decodetime(dt,h,min,sec,ms);
  result := inttostr(y)+'-'+inttostr(m div 10)+inttostr(m mod 10)+'-'+
  inttostr(d div 10)+inttostr(d mod 10)+' '+inttostr(h div 10)+
  inttostr(h mod 10)+':'+inttostr(min div 10)+inttostr(min mod 10)+':'+
  inttostr(sec div 10)+inttostr(sec mod 10);
end;

{
TWin32FindData
fileage
TFileTime
FileTimeToLocalFileTime
FileTimeToDosDateTime

type
TWin32FindData = record
  dwFileAttributes: DWORD;
  ftCreationTime: TFileTime;
  ftLastAccessTime: TFileTime;
  ftLastWriteTime: TFileTime;
  nFileSizeHigh: DWORD;
  nFileSizeLow: DWORD;
  dwReserved0: DWORD;
  dwReserved1: DWORD;
  cFileName: array[0..MAX_PATH - 1] of AnsiChar;
  cAlternateFileName: array[0..13] of AnsiChar;
end;
}


function getmotdcache(const name:bytestring):tstringlist;
var
  a:integer;
  pt:treadtxt;
begin
  {find if already in cache}
  for a := 0 to namelist.count-1 do begin
    if namelist[a] = name then begin
      result := tstringlist(cachelist[a]);
      exit;
    end;
  end;

  {create}
  namelist.add(name);
  result := tstringlist.create;
  cachelist.add(result);

  try
    pt := treadtxt.createf(name);
  except
    exit;
  end;

  if pt.eof then begin

    {empty file, return empty list}
    pt.destroy;
    exit;
  end;

  result.Add(':- '+dosdate(fileage(name)));
  while not pt.eof do begin
    result.add(':- '+pt.readline);
  end;
  pt.destroy;
end;

initialization begin
  cachelist := tlist.create;
  namelist := tstringlist.create;
end;

end.
