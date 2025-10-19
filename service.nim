# service.nim
# mkdir C:\t
# set TEMP=C:\t
# set TMP=C:\t
# Build: nim c -d:release --app:gui --nimcache:C:\n service.nim
import winim/lean
import httpclient
import os  # for sleep()

var
  hStatus: SERVICE_STATUS_HANDLE
  svcStatus: SERVICE_STATUS
  stopEvent: HANDLE

proc reportStatus(state: DWORD; win32Exit: DWORD; waitHint: DWORD) =
  svcStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS
  svcStatus.dwCurrentState = state
  svcStatus.dwWin32ExitCode = win32Exit
  svcStatus.dwWaitHint = waitHint
  if state == SERVICE_START_PENDING:
    svcStatus.dwControlsAccepted = 0
  else:
    svcStatus.dwControlsAccepted = SERVICE_ACCEPT_STOP or SERVICE_ACCEPT_SHUTDOWN
  discard SetServiceStatus(hStatus, addr svcStatus)

proc ctrlHandler(ctrl: DWORD; eventType: DWORD; eventData: LPVOID; context: LPVOID): DWORD {.stdcall.} =
  case ctrl
  of SERVICE_CONTROL_STOP, SERVICE_CONTROL_SHUTDOWN:
    reportStatus(SERVICE_STOP_PENDING, 0, 2000)
    discard SetEvent(stopEvent)
    return NO_ERROR
  else:
    return NO_ERROR

proc doYourDownloadOnce() =
  # TODO: your real work here
  sleep(3000)  # Nim's stdlib sleep, takes ms
  # replace the above with your real download

proc serviceWorker() =
  # Run once, then idle so SCM keeps the service alive.
  doYourDownloadOnce()
  while true:
    let s = WaitForSingleObject(stopEvent, 1000)
    if s == WAIT_OBJECT_0: break
    # optional: repeat work on an interval, check a queue, etc.

proc serviceMain(argc: DWORD; argv: ptr LPWSTR) {.stdcall.} =
  hStatus = RegisterServiceCtrlHandlerExW(newWideCString("DemoNimSvc"), ctrlHandler, nil)
  if hStatus == 0: return

  reportStatus(SERVICE_START_PENDING, 0, 3000)
  stopEvent = CreateEventW(nil, TRUE, FALSE, nil)
  if stopEvent == 0:
    reportStatus(SERVICE_STOPPED, GetLastError(), 0)
    return

  reportStatus(SERVICE_RUNNING, 0, 0)
  serviceWorker()
  reportStatus(SERVICE_STOPPED, 0, 0)

when isMainModule:
  var table: array[2, SERVICE_TABLE_ENTRYW]
  # Fill fields explicitly — no “constructor” call.
  table[0].lpServiceName = newWideCString("DemoNimSvc")
  table[0].lpServiceProc = serviceMain
  table[1].lpServiceName = nil
  table[1].lpServiceProc = nil

  if not StartServiceCtrlDispatcherW(addr table[0]):
    # If run outside SCM, fall back to a debug mode.
    stopEvent = CreateEventW(nil, TRUE, FALSE, nil)
    echo "Debug mode: simulating service run..."
    serviceWorker()
