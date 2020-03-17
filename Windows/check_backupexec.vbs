'
' Nagios Plugn for reading BackupExec's error log
' It is intended to use with NSClient++
'
' To reset the alerts, accnolage the alerts in BackupExec
'
' Author: Nils Cronstedt
' Email: nils.cronstedt[at]gmail[dot]com
' Created on: 2010-05-15


Dim rad,txt,dag,alert

Set cnn = CreateObject("ADODB.Connection")
Set Rs = CreateObject("ADODB.Recordset")

cnn.ConnectionString = "driver={SQL Server};server=localhost\bkupexec;Trusted_Connection=Yes;database=bedb"
cnn.Open
rs.ActiveConnection = cnn
exitcode = 0
allert()
rs.close
If txt > "" Then
	txt = "Error on backup job , " & txt
	
	Else 
	txt = "OK - No alerts found"
	End If


wscript.echo(txt)
wscript.quit exitcode

Function allert()
	Const ForReading = 1, ForWriting = 2, ForAppending = 8
	Const TristateUseDefault = -2, TristateTrue = -1, TristateFalse = 0
	strsql = "SELECT * FROM Alert where Type <= 48 and UserResponse = 0"
	rs.Open strsql , cnn,3,3
	Do While Not rs.EOF 
		alert = rs("AlertTitle")
		'If alert = "Job Failed" or alert = "Media Request" or alert = "Job Warning" Then
		dag = mid(rs("AlertDate"),1,10)
		nu = mid(now-2,1,10)
		If dag >= nu Then ' One new Error
		rad = rs("AlertDate") & " : " & rs("SourceMachine") & " : " & rs("AlertTitle") & " : " & rs("AlertMessage")

			Set fso = CreateObject("Scripting.FileSystemObject")
			txt = txt + rad
			exitcode = 2
			Exit Function	
		End if
		'End if
		rs.movenext
	Loop
End Function

	