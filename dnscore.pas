{ Copyright (C) 2005 Bas Steendijk and Peter Green
  For conditions of distribution and use, see copyright notice in zlib_license.txt
  which is included in the package
  ----------------------------------------------------------------------------- }

{

  code wanting to use this dns system should act as follows (note: app
  developers will probably want to use dnsasync or dnssync or write a similar
  wrapper unit of their own).

  for normal lookups call setstate_forward or setstate_reverse to set up the
  state, for more obscure lookups use setstate_request_init and fill in other
  relevant state manually.

  call state_process which will do processing on the information in the state
  and return an action
  action_ignore means that dnscore wants the code that calls it to go
  back to waiting for packets
  action_sendpacket means that dnscore wants the code that calls it to send
  the packet in sendpacket/sendpacketlen and then start (or go back to) listening
  for
  action_done means the request has completed (either succeeded or failed)

  callers should resend the last packet they tried to send if they have not
  been asked to send a new packet for more than some timeout value they choose.

  when a packet is received the application should put the packet in
  recvbuf/recvbuflen , set state.parsepacket and call state_process again

  once the app gets action_done it can determine success or failure in the
  following ways.

  on failure state.resultstr will be an empty string and state.resultbin will
  be zeroed out (easily detected by the fact that it will have a family of 0)

  on success for a A or AAAA lookup state.resultstr will be an empty string
  and state.resultbin will contain the result (note: AAAA lookups require IPv6
  enabled).

  if an A lookup fails and the code is built with IPv6 enabled then the code
  will return any AAAA records with the same name. The reverse does not apply
  so if an application prefers IPv6 but wants IPv4 results as well it must
  check them separately.

  on success for any other type of lookup state.resultstr will be an empty

  note the state contains ansistrings, setstate_init with a null name parameter
  can be used to clean these up if required.

  callers may use setstate_failure to mark the state as failed themselves
  before passing it on to other code, for example this may be done in the event
  of a timeout.
}
unit dnscore;

{$ifdef fpc}{$mode delphi}{$endif}

{$include lcoreconfig.inc}

interface

uses binipstuff,classes,pgtypes,lcorernd;

var usewindns : boolean = {$ifdef mswindows}true{$else}false{$endif};
{hint to users of this unit that they should use windows dns instead.
May be disabled by applications if desired. (e.g. if setting a custom
dnsserverlist).

note: this unit will not be able to self populate it's dns server list on
older versions of windows.}

const
  useaf_default=0;
  useaf_preferv4=1;
  useaf_preferv6=2;
  useaf_v4=3;
  useaf_v6=4;
{
hint to users of this unit to how to deal with connecting to hostnames regarding ipv4 or ipv6 usage
can be set by apps as desired
}
var useaf:integer = useaf_default;

{
(temporarily) use a different nameserver, regardless of the dnsserverlist
}
var overridednsserver:ansistring;

const
  maxnamelength=127;
  maxnamefieldlen=63;
  //note: when using action_ignore the dnscore code *must* preserve the contents of state.sendpacket to allow for retries
  //note: action_ignore must not be used in response to the original request but there is no valid reason for doing this anyway
  action_ignore=0;
  action_done=1;
  action_sendquery=2;
  querytype_a=1;
  querytype_cname=5;
  querytype_aaaa=28;
  querytype_a6=38;
  querytype_ptr=12;
  querytype_ns=2;
  querytype_soa=6;
  querytype_mx=15;
  querytype_txt=16;
  querytype_spf=99;
  maxrecursion=50;
  maxrrofakind=32;
  {the maximum number of RR of a kind of purely an extra sanity check and could be omitted.
  before, i set it to 20, but valid replies can have more. dnscore only does udp requests,
  and ordinary DNS, so up to 512 bytes. the maximum number of A records that fits seems to be 29}

  retryafter=300000; //microseconds must be less than one second;
  timeoutlag=1000000000; // penalty value to be treated as lag in the event of a timeout (microseconds)
type
  dvar=array[0..0] of byte;
  pdvar=^dvar;
  tdnspacket=packed record
    id:word;
    flags:word;
    rrcount:array[0..3] of word;
    payload:array[0..511-12] of byte;
  end;



  tdnsstate=record
    id:word;
    recursioncount:integer;
    queryname:ansistring;
    requesttype:word;
    parsepacket:boolean;
    resultstr:ansistring;
    resultbin:tbinip;
    resultlist:tbiniplist;
    resultaction:integer;
    numrr1:array[0..3] of integer;
    numrr2:integer;
    rrdata:ansistring;
    sendpacketlen:integer;
    sendpacket:tdnspacket;
    recvpacketlen:integer;
    recvpacket:tdnspacket;
    forwardfamily:integer;
  end;

  trr=packed record
    requesttypehi:byte;
    requesttype:byte;
    clas:word;
    ttl:integer;
    datalen:word;
    data:array[0..511] of byte;
  end;

  trrpointer=packed record
    p:pointer;
    ofs:integer;
    len:integer;
    namelen:integer;
  end;

//commenting out functions from interface that do not have documented semantics
//and probably should not be called from outside this unit, reenable them
//if you must but please document them at the same time --plugwash

//function buildrequest(const name:string;var packet:tdnspacket;requesttype:word):integer;

//returns the DNS name used to reverse look up an IP, such as 4.3.2.1.in-addr.arpa for 1.2.3.4
function makereversename(const binip:tbinip):ansistring;

procedure setstate_request_init(const name:ansistring;var state:tdnsstate);

//set up state for a forward lookup. A family value of AF_INET6 will give only
//ipv6 results. Any other value will give only ipv4 results
procedure setstate_forward(const name:ansistring;var state:tdnsstate;family:integer);

procedure setstate_reverse(const binip:tbinip;var state:tdnsstate);
procedure setstate_failure(var state:tdnsstate);
//procedure setstate_return(const rrp:trrpointer;len:integer;var state:tdnsstate);

//for custom raw lookups such as TXT, as desired by the user
procedure setstate_custom(const name:ansistring; requesttype:integer; var state:tdnsstate);

procedure state_process(var state:tdnsstate);

//function decodename(const packet:tdnspacket;len,start,recursion:integer;var numread:integer):string;

procedure populatednsserverlist;
procedure cleardnsservercache;

var
  dnsserverlist : tbiniplist;
  dnsserverlag:tlist;
//  currentdnsserverno : integer;


//getcurrentsystemnameserver returns the nameserver the app should use and sets
//id to the id of that nameserver. id should later be used to report how laggy
//the servers response was and if it was timed out.
function getcurrentsystemnameserver(var id:integer) :ansistring;
function getcurrentsystemnameserverbin(var id:integer) :tbinip;
procedure reportlag(id:integer;lag:integer); //lag should be in microseconds and should be -1 to report a timeout

//var
//  unixnameservercache:string;
{ $endif}


{$ifdef ipv6}
procedure initpreferredmode;

var
  preferredmodeinited:boolean;

{$endif}

var
  failurereason:ansistring;

function getquerytype(s:ansistring):integer;

implementation

uses
  lcorelocalips,
  sysutils;



function getquerytype(s:ansistring):integer;
begin
  s := uppercase(s);
  result := 0;
  if (s = 'A') then result := querytype_a else
  if (s = 'CNAME') then result := querytype_cname else
  if (s = 'AAAA') then result := querytype_aaaa else
  if (s = 'PTR') then result := querytype_ptr else
  if (s = 'NS') then result := querytype_ns else
  if (s = 'MX') then result := querytype_mx else
  if (s = 'A6') then result := querytype_a6 else
  if (s = 'TXT') then result := querytype_txt else
  if (s = 'SOA') then result := querytype_soa else
  if (s = 'SPF') then result := querytype_spf;
end;

function buildrequest(const name:ansistring;var packet:tdnspacket;requesttype:word):integer;
var
  a,b:integer;
  s:ansistring;
  arr:array[0..sizeof(packet)-1] of byte absolute packet;
begin
 { writeln('buildrequest: name: ',name);}
  result := 0;
  fillchar(packet,sizeof(packet),0);
  packet.id := randominteger($10000);

  packet.flags := htons($0100);
  packet.rrcount[0] := htons($0001);


  s := copy(name,1,maxnamelength);
  if s = '' then exit;
  if s[length(s)] <> '.' then s := s + '.';
  b := 0;
  {encode name}
  if (s = '.') then begin
    packet.payload[0] := 0;
    result := 12+5;
  end else begin
    for a := 1 to length(s) do begin
      if s[a] = '.' then begin
        if b > maxnamefieldlen then exit;
        if (b = 0) then exit;
        packet.payload[a-b-1] := b;
        b := 0;
      end else begin
        packet.payload[a] := byte(s[a]);
        inc(b);
      end;
    end;
    if b > maxnamefieldlen then exit;
    packet.payload[length(s)-b] := b;
    result := length(s) + 12+5;
  end;

  arr[result-1] := 1;
  arr[result-3] := requesttype and $ff;
  arr[result-4] := requesttype shr 8;
end;

function makereversename(const binip:tbinip):ansistring;
var
  name:ansistring;
  a,b:integer;
begin
  name := '';
  if binip.family = AF_INET then begin
    b := htonl(binip.ip);
    for a := 0 to 3 do begin
      name := name + inttostr(b shr (a shl 3) and $ff)+'.';
    end;
    name := name + 'in-addr.arpa';
  end else
  {$ifdef ipv6}
  if binip.family = AF_INET6 then begin
    for a := 15 downto 0 do begin
      b := binip.ip6.u6_addr8[a];
      name := name + hexchars[b and $f]+'.'+hexchars[b shr 4]+'.';
    end;
    name := name + 'ip6.arpa';
  end else
  {$endif}
  begin
    {empty name}
  end;
  result := name;
end;

{
decodes DNS format name to a string. does not includes the root dot.
doesnt read beyond len.
empty result + non null failurereason: failure
empty result + null failurereason: internal use
}
function decodename(const packet:tdnspacket;len,start,recursion:integer;var numread:integer):ansistring;
var
  arr:array[0..sizeof(packet)-1] of byte absolute packet;
  s:ansistring;
  a,b:integer;
begin
  numread := 0;
  repeat
    if (start+numread < 0) or (start+numread >= len) then begin
      result := '';
      failurereason := 'decoding name: got out of range1';
      exit;
    end;
    b := arr[start+numread];
    if b >= $c0 then begin
      {recursive sub call}
      if recursion > 10 then begin
        result := '';
        failurereason := 'decoding name: max recursion';
        exit;
      end;
      if ((start+numread+1) >= len) then begin
        result := '';
        failurereason := 'decoding name: got out of range3';
        exit;
      end;
      a := ((b shl 8) or arr[start+numread+1]) and $3fff;
      s := decodename(packet,len,a,recursion+1,a);
      if (s = '') and (failurereason <> '') then begin
        result := '';
        exit;
      end;
      if result <> '' then result := result + '.';
      result := result + s;
      inc(numread,2);
      exit;
    end else if b < 64 then begin
      if (numread <> 0) and (b <> 0) then result := result + '.';
      for a := start+numread+1 to start+numread+b do begin
        if (a >= len) then begin
          result := '';
          failurereason := 'decoding name: got out of range2';
          exit;
        end;
        result := result + ansichar(arr[a]);
      end;
      inc(numread,b+1);

      if b = 0 then begin
        if (result = '') and (recursion = 0) then result := '.';
        exit; {reached end of name}
      end;
    end else begin
      failurereason := 'decoding name: read invalid char';
      result := '';
      exit; {invalid}
    end;
  until false;
end;

{==============================================================================}

function getrawfromrr(const rrp:trrpointer;len:integer):ansistring;
begin
  setlength(result,htons(trr(rrp.p^).datalen));
  uniquestring(result);
  move(trr(rrp.p^).data,result[1],length(result));
end;


function getipfromrr(const rrp:trrpointer;len:integer):tbinip;
begin
  fillchar(result,sizeof(result),0);
  case trr(rrp.p^).requesttype of
    querytype_a: begin
      if htons(trr(rrp.p^).datalen) <> 4 then exit;
      move(trr(rrp.p^).data,result.ip,4);
      result.family :=AF_INET;
    end;
    {$ifdef ipv6}
    querytype_aaaa: begin
      if htons(trr(rrp.p^).datalen) <> 16 then exit;
      result.family := AF_INET6;
      move(trr(rrp.p^).data,result.ip6,16);
    end;
    {$endif}
  else
    {}
  end;
end;

procedure setstate_return(const rrp:trrpointer;len:integer;var state:tdnsstate);
var
  a:integer;
begin
  state.resultaction := action_done;
  state.resultstr := '';
  case trr(rrp.p^).requesttype of
    querytype_a{$ifdef ipv6},querytype_aaaa{$endif}: begin
      state.resultbin := getipfromrr(rrp,len);
    end;
    querytype_txt:begin
      {TXT returns a raw string}
      state.resultstr := copy(getrawfromrr(rrp,len),2,9999);
      fillchar(state.resultbin,sizeof(state.resultbin),0);
    end;
    querytype_mx:begin
      {MX is a name after a 16 bits word}
      state.resultstr := decodename(state.recvpacket,state.recvpacketlen,taddrint(rrp.p)-taddrint(@state.recvpacket)+12,0,a);
      fillchar(state.resultbin,sizeof(state.resultbin),0);
    end;
  else
    {other reply types (PTR, MX) return a hostname}
    state.resultstr := decodename(state.recvpacket,state.recvpacketlen,taddrint(rrp.p)-taddrint(@state.recvpacket)+10,0,a);
    fillchar(state.resultbin,sizeof(state.resultbin),0);
  end;
end;

procedure setstate_request_init(const name:ansistring;var state:tdnsstate);
begin
  {destroy things properly}
  state.resultstr := '';
  state.queryname := '';
  state.rrdata := '';
  fillchar(state,sizeof(state),0);
  state.queryname := name;
  state.parsepacket := false;
end;

procedure setstate_forward(const name:ansistring;var state:tdnsstate;family:integer);
begin
  setstate_request_init(name,state);
  state.forwardfamily := family;
  {$ifdef ipv6}
  if family = AF_INET6 then state.requesttype := querytype_aaaa else
  {$endif}
  state.requesttype := querytype_a;
end;

procedure setstate_reverse(const binip:tbinip;var state:tdnsstate);
begin
  setstate_request_init(makereversename(binip),state);
  state.requesttype := querytype_ptr;
end;

procedure setstate_custom(const name:ansistring; requesttype:integer; var state:tdnsstate);
begin
  setstate_request_init(name,state);
  state.requesttype := requesttype;
end;


procedure setstate_failure(var state:tdnsstate);
begin
  state.resultstr := '';
  fillchar(state.resultbin,sizeof(state.resultbin),0);
  state.resultaction := action_done;
end;

procedure state_process(var state:tdnsstate);
label recursed;
label failure;
var
  a,b,ofs:integer;
  rrtemp:^trr;
  rrptemp:^trrpointer;
begin
  if state.parsepacket then begin
    if state.recvpacketlen < 12 then begin
      failurereason := 'Undersized packet';
      state.resultaction := action_ignore;
      exit;
    end;
    if state.id <> state.recvpacket.id then begin
      failurereason := 'ID mismatch';
      state.resultaction := action_ignore;
      exit;
    end;
    state.numrr2 := 0;
    for a := 0 to 3 do begin
      state.numrr1[a] := htons(state.recvpacket.rrcount[a]);
      if state.numrr1[a] > maxrrofakind then begin
        failurereason := 'exceeded maximum RR of a kind';
        goto failure;
      end;
      inc(state.numrr2,state.numrr1[a]);
    end;

    setlength(state.rrdata,state.numrr2*sizeof(trrpointer));

    {- put all replies into a list}

    ofs := 12;
    {get all queries}
    for a := 0 to state.numrr1[0]-1 do begin
      if (ofs < 12) or (ofs > state.recvpacketlen-4) then goto failure;
      rrptemp := @state.rrdata[1+a*sizeof(trrpointer)];
      rrptemp.p := @state.recvpacket.payload[ofs-12];
      rrptemp.ofs := ofs;
      decodename(state.recvpacket,state.recvpacketlen,ofs,0,b);
      rrptemp.len := b + 4;
      inc(ofs,rrptemp.len);
    end;

    for a := state.numrr1[0] to state.numrr2-1 do begin
      if (ofs < 12) or (ofs > state.recvpacketlen-12) then goto failure;
      rrptemp := @state.rrdata[1+a*sizeof(trrpointer)];
      if decodename(state.recvpacket,state.recvpacketlen,ofs,0,b) = '' then goto failure;
      rrtemp := @state.recvpacket.payload[ofs-12+b]; {rrtemp points to values and result, after initial name}
      rrptemp.p := rrtemp;
      rrptemp.ofs := ofs; {ofs is start of RR before initial name from start of packet}
      rrptemp.namelen := b;
      b := htons(rrtemp.datalen);
      rrptemp.len := b + 10 + rrptemp.namelen;
      inc(ofs,rrptemp.len);
    end;
    if (ofs <> state.recvpacketlen) then begin
      failurereason := 'ofs <> state.packetlen';
      goto failure;
    end;

    {if we requested A or AAAA build a list of all replies}
    if (state.requesttype = querytype_a) or (state.requesttype = querytype_aaaa) then begin
      state.resultlist := biniplist_new;
      for a := state.numrr1[0] to (state.numrr1[0]+state.numrr1[1]-1) do begin
        rrptemp := @state.rrdata[1+a*sizeof(trrpointer)];
        rrtemp := rrptemp.p;
        b := rrptemp.len;
        if rrtemp.requesttype = state.requesttype then begin
          biniplist_add(state.resultlist,getipfromrr(rrptemp^,b));
        end;
      end;
    end;

    {- check for items of the requested type in answer section, if so return success first}
    for a := state.numrr1[0] to (state.numrr1[0]+state.numrr1[1]-1) do begin
      rrptemp := @state.rrdata[1+a*sizeof(trrpointer)];
      rrtemp := rrptemp.p;
      b := rrptemp.len;
      if rrtemp.requesttype = state.requesttype then begin
        setstate_return(rrptemp^,b,state);
        exit;
      end;
    end;

    {if no items of correct type found, follow first cname in answer section}
    for a := state.numrr1[0] to (state.numrr1[0]+state.numrr1[1]-1) do begin
      rrptemp := @state.rrdata[1+a*sizeof(trrpointer)];
      rrtemp := rrptemp.p;
      b := rrptemp.len;
      if rrtemp.requesttype = querytype_cname then begin
        state.queryname := decodename(state.recvpacket,state.recvpacketlen,rrptemp.ofs+12,0,b);
        goto recursed;
      end;
    end;

    {no cnames found, no items of correct type found}
    if state.forwardfamily <> 0 then goto failure;

    goto failure;
recursed:
    {here it needs recursed lookup}
    {if needing to follow a cname, change state to do so}
    inc(state.recursioncount);
    if state.recursioncount > maxrecursion then goto failure;
  end;

  {here, a name needs to be resolved}
  if state.queryname = '' then begin
    failurereason := 'empty query name';
    goto failure;
  end;

  {do /etc/hosts lookup here}
  state.sendpacketlen := buildrequest(state.queryname,state.sendpacket,state.requesttype);
  if state.sendpacketlen = 0 then begin
    failurereason := 'building request packet failed';
    goto failure;
  end;
  state.id := state.sendpacket.id;
  state.resultaction := action_sendquery;

  exit;
failure:
  setstate_failure(state);
end;


procedure populatednsserverlist;
var
  a:integer;
begin
  if assigned(dnsserverlag) then begin
    dnsserverlag.clear;
  end else begin
    dnsserverlag := tlist.Create;
  end;

  dnsserverlist := getsystemdnsservers;
  for a := biniplist_getcount(dnsserverlist)-1 downto 0 do dnsserverlag.Add(nil);
end;

procedure cleardnsservercache;
begin
  if assigned(dnsserverlag) then begin
    dnsserverlag.destroy;
    dnsserverlag := nil;
    dnsserverlist := '';
  end;
end;

function getcurrentsystemnameserverbin(var id:integer):tbinip;
var
  counter : integer;
begin
  {override the name server choice here, instead of overriding it wherever it's called
  setting ID to -1 causes it to be ignored in reportlag}
  if (overridednsserver <> '') then begin
    result := ipstrtobinf(overridednsserver);
    if result.family <> 0 then begin
      id := -1;
      exit;
    end;
  end;

  if not assigned(dnsserverlag) then populatednsserverlist;
  if dnsserverlag.count=0 then raise exception.create('no dns servers available');
  id := 0;
  if dnsserverlag.count >1 then begin
    for counter := dnsserverlag.count-1 downto 1 do begin
      if taddrint(dnsserverlag[counter]) < taddrint(dnsserverlag[id]) then id := counter;
    end;
  end;
  result := biniplist_get(dnsserverlist,id);
end;

function getcurrentsystemnameserver(var id:integer):ansistring;
begin
  result := ipbintostr(getcurrentsystemnameserverbin(id));
end;

procedure reportlag(id:integer;lag:integer); //lag should be in microseconds and should be -1 to report a timeout
var
  counter : integer;
  temp : integer;
begin
  if (id < 0) or (id >= dnsserverlag.count) then exit;
  if lag = -1 then lag := timeoutlag;
  for counter := 0 to dnsserverlag.count-1 do begin
    temp := taddrint(dnsserverlag[counter]) *15;
    if counter=id then temp := temp + lag;
    dnsserverlag[counter] := tobject(temp div 16);
  end;

end;


{$ifdef ipv6}

procedure initpreferredmode;
var
  l:tbiniplist;
  a:integer;
  ip:tbinip;
  ipmask_global,ipmask_6to4,ipmask_teredo:tbinip;

begin
  if preferredmodeinited then exit;
  if useaf <> useaf_default then exit;
  l := getv6localips;
  if biniplist_getcount(l) = 0 then exit;
  useaf := useaf_preferv4;
  ipstrtobin('2000::',ipmask_global);
  ipstrtobin('2001::',ipmask_teredo);
  ipstrtobin('2002::',ipmask_6to4);
  {if there is any v6 IP which is globally routable and not 6to4 and not teredo, prefer v6}
  for a := biniplist_getcount(l)-1 downto 0 do begin
    ip := biniplist_get(l,a);
    if not comparebinipmask(ip,ipmask_global,3) then continue;
    if comparebinipmask(ip,ipmask_teredo,32) then continue;
    if comparebinipmask(ip,ipmask_6to4,16) then continue;
    useaf := useaf_preferv6;
    preferredmodeinited := true;
    exit;
  end;
end;

{$endif}


{  quick and dirty description of dns packet structure to aid writing and
   understanding of parser code, refer to appropriate RFCs for proper specs
- all words are network order

www.google.com A request:

0, 2: random transaction ID
2, 2: flags: only the "recursion desired" bit set. (bit 8 of word)
4, 2: questions: 1
6, 2: answer RR's: 0.
8, 2: authority RR's: 0.
10, 2: additional RR's: 0.
12, n: payload:
  query:
    #03 "www" #06 "google" #03 "com" #00
    size-4, 2: type: host address (1)
    size-2, 2: class: inet (1)

reply:

0,2: random transaction ID
2,2: flags: set: response (bit 15), recursion desired (8), recursion available (7)
4,4: questions: 1
6,4: answer RR's: 2
8,4: authority RR's: 9
10,4: additional RR's: 9
12: payload:
  query:
    ....
  answer: CNAME
    0,2 "c0 0c" "name: www.google.com"
    2,2 "00 05" "type: cname for an alias"
    4,2 "00 01" "class: inet"
    6,4: TTL
    10,2: data length "00 17" (23)
    12: the cname name (www.google.akadns.net)
  answer: A
    0,2 ..
    2,2 "00 01" host address
    4,2 ...
    6,4 ...
    10,2: data length (4)
    12,4: binary IP
  authority - 9 records
  additional - 9 records


  ipv6 AAAA reply:
    0,2: ...
    2,2: type: 001c
    4,2: class: inet (0001)
    6,2: TTL
    10,2: data size (16)
    12,16: binary IP

  ptr request: query type 000c

name compression: word "cxxx" in the name, xxx points to offset in the packet}

end.
