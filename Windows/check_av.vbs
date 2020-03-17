' Script: check_av.vbs
' Author: Matt White
' Version: 1.1
' Date: 01-03-2010
' Details: Check the current definitions for Symantec AntiVirus are within acceptable bounds
' Usage: cscript /nologo check_av.vbs -w:<days> -c:<days>

' Define Constants for the script exiting
Const intOK = 0
Const intWarning = 1
Const intCritical = 2
Const intUnknown = 3

' Create required objects
Set ObjShell = CreateObject("WScript.Shell")
Set ObjProcess = ObjShell.Environment("Process")

const HKEY_CURRENT_USER = &H80000001
const HKEY_LOCAL_MACHINE = &H80000002

Dim strKeyPath, strSymantecVer
Dim intWarnLevel, intCritLevel, intYear, intMonth , intDay, intVer_Major, intDateDifference
Dim year, Month , Day, Ver_Major
Dim arrValue

' Parse Arguments to find Warning and Critical Levels
If Wscript.Arguments.Named.Exists("w") Then
  intWarnLevel = Cint(Wscript.Arguments.Named("w"))
Else
  intWarnLevel = 2
End If

If Wscript.Arguments.Named.Exists("c") Then
  intCritLevel = Cint(Wscript.Arguments.Named("c"))
Else
  intCritLevel = 4
End If

' Determine CPU architecture for correct location of the registry key
strCPUArch = objProcess("PROCESSOR_ARCHITECTURE")
If InStr(1, strCPUArch, "x86") > 0 Then
  strKeyPath = "SOFTWARE\Symantec\SharedDefs\DefWatch"
ElseIf InStr(1, strCPUArch, "64") > 0 Then
  strKeyPath = "SOFTWARE\Wow6432Node\Symantec\SharedDefs\DefWatch"
End If

' Query Registry using WMI to obtain the definition value
Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
oReg.GetBinaryValue HKEY_LOCAL_MACHINE,strKeyPath,"DefVersion",arrValue

' If the query doesnt return an array Quit - Unknown
If isArray(arrValue) = vbFalse Then
  Wscript.Echo "UNKNOWN - Unable to read Definitions from the Registry"
  Wscript.Quit(intUnknown)
End If

' Generate output from the registry value
intYear = CLng("&H" & hex(arrValue(1)) & hex(arrValue(0)))
intMonth = CLng("&H" & hex(arrValue(3)) & hex(arrValue(2)))
intDay = CLng("&H" & hex(arrValue(7)) & hex(arrValue(6)))
intVer_Major = CLng("&H" & hex(arrValue(17)) & hex(arrValue(16)))
strSymantecVer= intYear & "-" & intMonth & "-" & intDay & " rev. " & intVer_Major
intDateDifference = DateDiff("d", intYear & "/" & intMonth & "/" & intDay, Date)

' Output current version and definition age as Performance data
Wscript.Echo("Current Definitions: " & strSymantecVer & " Which are " & intDateDifference & " days old" & "|age=" & intDateDifference)

If intDateDifference > intCritLevel Then
  Wscript.Quit(intCritical)
ElseIf intDateDifference > intWarnLevel Then
  Wscript.Quit(intWarning)
ElseIf intDateDifference <= intWarnLevel Then
  Wscript.Quit(intOK)
End If
Wscript.Quit(intUnknown)
