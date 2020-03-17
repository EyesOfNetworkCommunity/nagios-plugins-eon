'Script to check the status of a DOMAIN controller and report to Nagios
'requires DCDIAG.EXE 
'Author: Felipe Ferreira
'Version: 3.2
'Updated by: Guillaume ONA : Add detection of code page and French support
'
'Mauled over by John Jore, j-o-h-n-a-t-j-o-r-e-d-o-t-n-o 16/11/2010 to work on W2K8, x32
'as well as remove some, eh... un-needed lines of code, general optimization as well as adding command parameter support
'This is where i found the original script, http://felipeferreira.net/?p=315&cpage=1#comments
'Tested by JJ on W2K8 SP2, x86
'		 W2K3 R2 SP2, x64
'Version 3.0-JJ-V0.2
'Todo: Proper error handling
'      Add support for the two tests which require additional input (dcpromo is one such test)

'Force all variables to be declared before usage
option explicit

'Array for name and status (Ugly, but redim only works on last dimension, and can't set initial size if redim 
dim name(), status()
redim preserve name(0)
redim preserve status(0)

'Debug switch
dim verbose : verbose = 0

'Return variables for NAGIOS
const intOK = 0
const intWarning = 1 'Not used. What dcdiag test would be warning instead of critical?
const intCritical = 2
const intUnknown = 3

'Lang dependend
dim strOK : strOK = "passed"
dim strNotOK : strNotOk = "failed"

'Call dcdiag and grab relevant output
exec(cmd)

'Generate NAGIOS compatible output from dcdiag
printout()

'call dcdiag and parse the output
sub exec(strCmd)
	'Declare variables
	dim objShell : Set objShell = WScript.CreateObject("WScript.Shell")
	dim oExec1 : Set oExec1=objShell.Exec("cmd /c chcp")
	dim conv : Set conv=CreateObject("OlePrn.OleCvt")
	dim objExecObject, lineout, tmpline, mess, ssaccent
	dim page_code
	lineout = ""
	'Command line options we're using
	pt strCmd
    mess=oExec1.StdOut.ReadAll
	page_code = Split(mess,":",-1,1)
	Set objExecObject = objShell.Exec(strCmd)
	'Loop until end of output from dcdiag
	do While not objExecObject.StdOut.AtEndOfStream
        ssaccent = conv.ToUnicode(objExecObject.StdOut.ReadLine(),trim(page_code(1)))
		tmpline = lcase(ssaccent)
		call parselang(tmpline)
		lineout = lineout + tmpline
		if (instr(tmpline, ".....")) then 
			'testresults start with a couple of dots, so lets reset the lineout buffer
			lineout= tmpline
		end if
		if instr(lineout, lcase(strOK)) then
			'we have a strOK String which means we have reached the end of a result output (maybe on newline)
			call parse(lineout)
			lineout = ""
		end if 
	loop
	call parse(lineout)
end sub

sub parselang(txtp)
        txtp = Replace(txtp,chr(10),"") ' Newline
	txtp = Replace(txtp,chr(13),"") ' CR
	txtp = Replace(txtp,chr(9),"")  ' Tab
	do while instr(txtp, "  ")
		txtp = Replace(txtp,"  "," ") ' Some tidy up
	loop
	
	if (instr(lcase(txtp), lcase("Domain Controller Diagnosis"))) then ' English
		strOK = "passed"
		strNotOk = "failed"
	end if
	if (instr(lcase(txtp), lcase("Verzeichnisserverdiagnose"))) then ' German
		strOK = "bestanden"
		strNotOk = "nicht bestanden"
	end if	
	if (instr(lcase(txtp), lcase("Diagnostic du serveur d'annuaire"))) then ' French
		strOK = "réussi"
		strNotOk = "échoué"
	end if	
end sub

sub parse(txtp)
	'Parse output of dcdiag command and change state of checks
	dim loop1
	txtp = Replace(txtp,chr(10),"") ' Newline
	txtp = Replace(txtp,chr(13),"") ' CR
	txtp = Replace(txtp,chr(9),"")  ' Tab
	do while instr(txtp, "  ")
		txtp = Replace(txtp,"  "," ") ' Some tidy up
	loop
	
	' We have to test twice because some localized (e.g. German) outputs simply use not as a prefix
	if instr(lcase(txtp), lcase(strOK)) then
		'What are we testing for now?
		pt txtp
		'What services are ok? 'By using instr we don't need to strip down text, remove vbCr, VbLf, or get the hostname
		for loop1 = 0 to Ubound(name)-1
			if (instr(lcase(txtp), lcase(name(loop1)))) then status(loop1)="OK"
		next
		' if we found the strNotOK string then reset to CRITICAL
		if instr(lcase(txtp), lcase(strNotOK)) then
			'What are we testing for now?
			pt txtp
			for loop1 = 0 to Ubound(name)-1
				if (instr(lcase(txtp), lcase(name(loop1)))) then status(loop1)="CRITICAL"
			next
		end if
	end if
end sub

'outputs result for NAGIOS
sub printout()
	dim loop1, msg : msg = ""
	for loop1 = 0 to ubound(name)-1
		msg = msg & name(loop1) & ": " & status(loop1) & ". "
	next
	'What state are we in? Show and then quit with NAGIOS compatible exit code
	if instr(msg,"CRITICAL") then
		wscript.echo "CRITICAL - " & msg
		wscript.quit(intCritical)
	else
		wscript.echo "OK - " & msg
		wscript.quit(intOK)
	end if
end sub

'Print messages to screen for debug purposes
sub pt(msgTxt)
	if verbose then
		wscript.echo msgTXT
	end if
end sub

'What tests do we run?
function cmd()
	dim loop1, test, tests
	cmd = "dcdiag " 'Start with this
	'If no command line parameters, then go with these defaults
	if Wscript.Arguments.Count = 0 Then
		redim preserve name(6)
		redim preserve status(6)
		'Test name
		name(0) = "services"
		name(1) = "replications"
		name(2) = "advertising"
		name(3) = "fsmocheck"
		name(4) = "ridmanager"
		name(5) = "machineaccount"
		'Status
		for loop1 = 0 to (ubound(name)-1)
			status(loop1) = "CRITICAL"
			cmd = cmd & "/test:" & name(loop1) & " "
		next
	else
		for loop1 = 0 to wscript.arguments.count - 1
		        if lcase(wscript.Arguments(loop1)) = "/help" then
			    wscript.echo "Usage : (with or without //nologo)" & VbCrLf & _
			        "        This script require dcdiag.exe " & VbCrLf & _
			        "        cscript.exe check_ad.vbs //nologo" & VbCrLf & _
			        "        cscript.exe check_ad.vbs //nologo /test:services" & VbCrLf & _
			        "        cscript.exe check_ad.vbs /test:services,fsmocheck,machineaccount" & VbCrLf & VbCrLf & _
				" ..::: For valid check, execute the script without arguments :::.."

			    wscript.quit(intUnknown)
			end if
			if (instr(lcase(wscript.Arguments(loop1)), lcase("/test"))) then
			
			'If parameter is wrong, give some hints
			if len(wscript.arguments(loop1)) < 6 then
				wscript.echo "UNKNOWN ? Parameter wrong specify test like /test:advertising,dfsevent"
				wscript.quit(intUnknown)
			end if
			
			'Strip down the test to individual items
			tests = right(wscript.arguments(loop1), len(wscript.arguments(loop1))-6)
			pt "Tests: '" & tests & "'"

			tests = split(tests,",")
			for each test in tests
				cmd = cmd  & " /test:" & test

				'Expand the array to make room for one more test
				redim preserve name(ubound(name)+1)
				redim preserve status(ubound(status)+1)

				'Store name of test and status
				name(Ubound(name)-1) = test
				status(Ubound(status)-1) = "CRITICAL" 'Default status. Change to OK if test is ok

				'pt "Contents: " & name(Ubound(name)-1) & " " & status(Ubound(status)-1)
			next
			else
			    wscript.echo "UNKNOWN - Invalid arguments :" & wscript.Arguments(loop1) & " , use /help for list of valid arguments"
			    wscript.quit(intUnknown)
			end if
		next
	end if
	'We end up with this to test:
	pt "Command to run: " & cmd
end function
