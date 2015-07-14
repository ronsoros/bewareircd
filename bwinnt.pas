(*
 *  beware ircd, Internet Relay Chat server, bwinnt.pas
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
code for NT system service
}

unit bwinnt;

interface

uses
  {$ifdef fpc}bmessages,{$else}messages,winsvc,{$endif}
  windows,sysutils;

Const { from WINNT.H }
  Service_Win32_Own_Process   = $10;
  Service_Win32_Share_Process = $20;
  runasservice:boolean = false;
  {servicename='BewareIRCD';}

  SERVICE_AUTO_START=  $00000002;
  SERVICE_DEMAND_START=$00000003;
  SERVICE_ERROR_NORMAL=$00000001;
  EVENTLOG_ERROR_TYPE=$0001;

Var
  StatusHandle : Service_Status_Handle;

procedure InstallService(auto:boolean);
procedure unInstallService;
function runservice:boolean;

procedure reportstopped;
procedure reportstopping;

implementation

uses btime,bircdunit,bconfig;

procedure bSetServiceStatus(StatusHandle:Service_Status_Handle;var Status:Tservicestatus);
begin
  SetServiceStatus(StatusHandle,{$ifdef fpc}@{$endif}Status);
end;

procedure reportstopping;
Var
  Status : TServiceStatus;
begin
  if not runasservice then exit;
  With Status do Begin
    FillChar(Status,SizeOf(Status),0);
    dwServiceType := Service_Win32_Own_Process;
    dwCurrentState := Service_Stop_pending;
    dwControlsAccepted := Service_Accept_Stop;
  End;
  bSetServiceStatus(StatusHandle,Status);
end;

procedure reportstopped;
Var
  Status : TServiceStatus;
begin
  if not runasservice then exit;
  With Status do Begin
    FillChar(Status,SizeOf(Status),0);
    dwServiceType := Service_Win32_Own_Process;
    dwCurrentState := Service_Stopped;
    dwControlsAccepted := Service_Accept_Stop;
  End;
  bSetServiceStatus(StatusHandle,Status);
end;

Procedure MyCtrlHandler(OpCode : Integer); StdCall;
Var
  Status : TServiceStatus;
Begin
  Case OpCode of
    Service_Control_Stop        : Begin
                                    triggershutdown('Received Service_Control_Stop',false);
                                  End;
    Service_Control_Interrogate : Begin { report our current status }
                                    With Status do Begin
                                      FillChar(Status,SizeOf(Status),0);
                                      dwServiceType := Service_Win32_Own_Process;
                                      dwCurrentState := Service_Running;
                                      dwControlsAccepted := Service_Accept_Stop;
                                    End;
                                    bSetServiceStatus(StatusHandle,Status);
                                  End;

    End;
End;


procedure servicemain(ArgCount : Integer; Args : Pointer); StdCall;
var
  Status : TServiceStatus;
begin
  StatusHandle := RegisterServiceCtrlHandler(@opt.servicename[1],@MyCtrlHandler);
  if statushandle = 0 then exit;
  runasservice := true;
  { Report status to Service Control Manager (SCM) }
  With Status do Begin
    FillChar(Status,SizeOf(Status),0);
    dwServiceType := Service_Win32_Own_Process;
    dwCurrentState := Service_Running;
    dwControlsAccepted := Service_Accept_Stop;
  End;
  bSetServiceStatus(StatusHandle,Status);

  initapplication;
  runapplication;
  CleanupApplication;

end;


procedure InstallService(auto:boolean);
var
   schService:SC_HANDLE;
   schSCManager:SC_HANDLE;
   lpszPath:array[0..511] of char;
   howtostart:integer;
begin
     if auto then howtostart := SERVICE_AUTO_START
     else howtostart := SERVICE_DEMAND_START;

     if GetModuleFileName(0,@lpszPath,sizeof(lpszPath))=0 then exit;

     schSCManager:=OpenSCManager(nil,nil,SC_MANAGER_ALL_ACCESS);
     if (schSCManager>0) then
     begin
          schService:=CreateService(schSCManager,@opt.ServiceName[1],@opt.ServiceName[1],
          SERVICE_ALL_ACCESS,SERVICE_WIN32_OWN_PROCESS,howtostart,
          SERVICE_ERROR_NORMAL,@lpszPath,nil,nil,nil,nil,nil);
          if (schService>0) then
          begin
               conwrite('Install Ok.');
               CloseServiceHandle(schService);
          end
          else
               conwrite('Unable to install '+opt.ServiceName+', CreateService Fail. (service is already installed)');
     end
     else
         conwrite('Unable to install '+opt.ServiceName+', OpenSCManager Fail.');
end;

procedure UnInstallService;
var
  ServiceControlHandle: SC_HANDLE;
  SCManagerHandle: SC_HANDLE;
  s:ansistring;
  Status : TServiceStatus;
begin
  s := opt.servicename;

  SCManagerHandle := OpenSCManager(nil, nil, SC_MANAGER_ALL_ACCESS);
  if (SCManagerHandle > 0) then begin
    ServiceControlHandle := OpenService(SCManagerHandle, @s[1], SERVICE_ALL_ACCESS);
    if (ServiceControlHandle > 0) then begin
      if ControlService(ServiceControlHandle, SERVICE_CONTROL_STOP, {$ifdef fpc}@{$endif}Status) then begin
        conwrite('Stopping Service');
        Sleep(1000);
        while (QueryServiceStatus(ServiceControlHandle, {$ifdef fpc}@{$endif}Status)) do begin
          if Status.dwCurrentState = SERVICE_STOP_PENDING then begin
            conwrite('pending..');
            Sleep(1000);
          end else
            break;
        end;

        if Status.dwCurrentState = SERVICE_STOPPED then
          conwrite('Service Stop succeeded')
        else begin
          CloseServiceHandle(ServiceControlHandle);
          CloseServiceHandle(SCManagerHandle);

          conwrite('Service Stop Failed');
          exit;
        end;
      end;
      if (DeleteService(ServiceControlHandle)) then
        conwrite('Service Uninstall succeeded.')
      else
        conwrite('DeleteService failed');
      CloseServiceHandle(ServiceControlHandle);
    end else
      conwrite('OpenService fail (service is not installed)');
    CloseServiceHandle(SCManagerHandle);
  end else
    conwrite('OpenSCManager fail');
end;

Var
  STEs : Array[0..1] of TServiceTableEntry;

function runservice:boolean;
begin
  With STEs[0] do Begin
    lpServiceName := @opt.servicename[1];
    lpServiceProc := @servicemain;
  End;
  With STEs[1] do Begin
    lpServiceName := nil;
    lpServiceProc := nil;
  End;
  runasservice := false;
  StartServiceCtrlDispatcher({$ifdef fpc}@{$endif}STEs[0]);
  result := runasservice;
end;


end.
