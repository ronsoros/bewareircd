(*
 *  beware ircd, Internet Relay Chat server, b_silence.pas
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

unit b_silence;

interface

uses buser,bcmds,bstuff,bconsts,pgtypes;

procedure m_silence(cptr,sptr:tuser;parc:integer;parv:pparams);
procedure ms_silence(cptr,sptr:tuser;parc:integer;parv:pparams);

function add_silence(us:tuser;s:bytestring):boolean;
function del_silence(us:tuser;s:bytestring):boolean;

implementation

uses bserver,breplies,bsend,bconfig,blinklist,unitbanmask,bparse;

function add_silence(us:tuser;s:bytestring):boolean;
var
  sl,sl2:tsilence;
  bm:tbanmask;
begin
  result := false;
  s := cookmask(s);
  banmaskmake(@bm,s);


  {find out if the same or an overlapping mask already exists}
  sl := us.silence;
  while sl <> nil do begin
    if banmaskmatch(@sl.bm,@bm) then exit;
    sl := tsilence(sl.next);
  end;

  {remove any overlapped masks}
  sl := us.silence;
  while sl <> nil do begin
    sl2 := tsilence(sl.next);
    if banmaskmatch(@bm,@sl.bm) then begin
      linklistdel(tlinklist(us.silence),tlinklist(sl));
      sl.destroy;
    end;
    sl := sl2;
  end;

  sl := tsilence.create;
  linklistadd(tlinklist(us.silence),tlinklist(sl));
  sl.s := s;
  banmaskmake(@sl.bm,s);
  result := true;
end;

function del_silence(us:tuser;s:bytestring):boolean;
var
  sl,sl2:tsilence;
  bm:tbanmask;
begin
  result := false;
  s := cookmask(s);
  banmaskmake(@bm,s);

  {remove any overlapped masks}
  sl := us.silence;
  while sl <> nil do begin
    sl2 := tsilence(sl.next);
    if banmaskmatch(@bm,@sl.bm) then begin
      result := true;
      linklistdel(tlinklist(us.silence),tlinklist(sl));
      sl.destroy;
    end;
    sl := sl2;
  end;
end;


{
client only handler

silence +mask
silence -mask
silence mask
silence nick
silence

}

procedure m_silence(cptr,sptr:tuser;parc:integer;parv:pparams);
const maxlength=63;
var
  mask:bytestring;
  action,a:integer;
  sl:tsilence;
  showuser:tuser;
begin
  showuser := nil;
  if (parc < 2) or (parv[1] = '') then begin
    showuser := sptr;
    action := 0; {show}
  end else begin
    if parv[1,1] = '+' then begin
      action := 1; {add}
      mask := copy(parv[1],2,maxlength);
    end else if parv[1,1] = '-' then begin
      action := 2; {delete}
      mask := copy(parv[1],2,maxlength);
    end else begin
      if (pos('*',parv[1]) <> 0) or (pos('?',parv[1]) <> 0) or (pos('.',parv[1]) <> 0) or (pos('@',parv[1]) <> 0) or (pos('!',parv[1]) <> 0) then begin
        action := 1;
        mask := copy(parv[1],1,maxlength);
      end else begin
        action := 0;
        showuser := findnick(parv[1]);
      end;
    end;
  end;

  if action = 0 then begin
    if showuser = nil then begin
      sendreply(sptr,ERR_NOSUCHNICK,parv[1]+' '+getrpl0(ERR_NOSUCHNICK));
    end else begin
      sl := showuser.silence;
      while sl <> nil do begin
        sendreply(sptr,RPL_SILELIST,showuser.name+' '+sl.s);
        sl := tsilence(sl.next);
      end;
      sendreply(sptr,RPL_ENDOFSILELIST,showuser.name+' '+getrpl0(RPL_ENDOFSILELIST));
    end;
    exit;
  end else if action = 1 then begin
    if mask = '' then exit;
    {count items in list, check maximum}
    a := 0;
    sl := sptr.silence;
    while sl <> nil do begin
      inc(a);
      sl := tsilence(sl.next);
    end;
    mask := cookmask(mask);
    if (a >= maxsilence) then begin
      sendreply(sptr,ERR_SILELISTFULL,mask+' '+getrpl0(ERR_SILELISTFULL));
      exit;
    end;
    if add_silence(sptr,mask) then
    sendto_one(sptr,cprefix(sptr,MSG_SILENCE)+'+'+mask);
  end else if action = 2 then begin
    if mask = '' then exit;
    mask := cookmask(mask);
    if del_silence(sptr,mask) then begin
      sendto_serversbutone(me,sprefix(sptr,TOK_SILENCE)+'* :-'+mask);
      sendto_one(sptr,cprefix(sptr,MSG_SILENCE)+'-'+mask);
    end;
  end;
end;

{
server handler

sender U target :mask
sender U * :-mask
}
procedure ms_silence(cptr,sptr:tuser;parc:integer;parv:pparams);
var
  us:tuser;
begin
  if checkneedmoreparams(cptr,cmdnum,2,parc,parv) then exit;
  if parv[2,1] = '-' then begin
    del_silence(sptr,copy(parv[2],2,500));
    sendto_serversbutone(cptr,sprefix(sptr,TOK_SILENCE)+'* :'+parv[2]);
  end else begin
    add_silence(sptr,parv[2]);
    us := findnumeric(parv[1]);
    if us <> nil then begin
      if us <> us.from then
      sendto_one(us.from,sprefix(sptr,TOK_SILENCE)+us.idstr+' :'+parv[2]);
    end else begin
      sendto_serversbutone(cptr,sprefix(sptr,TOK_SILENCE)+'* :'+parv[2]);
    end;
  end;
end;

end.
