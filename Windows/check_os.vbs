' Copyright (c) 1997-1999 Microsoft Corporation 
'************************************************************************** * 
' 
' WMI Sample Script - Information about the OS (VBScript) 
' 
' This script demonstrates how to retrieve the info about the OS on the local machine from instances of 
' Win32_OperatingSystem. 
' 
'************************************************************************** * 
Set SystemSet = GetObject("winmgmts:").InstancesOf ("Win32_OperatingSystem") 
for each System in SystemSet 
 WScript.Echo System.Caption & " SP " & System.ServicePackMajorVersion
next 