###################################################################################################
# Script name:   	check_ms_exchange_2010_health.ps1
# Version:			0.8.1
# Created on:    	01/02/2014																			
# Author:        	D'Haese Willem / JDC
# Purpose:       	Checks Microsoft Exchange 2010 mailbox health, excluding recovery databases, and checking latest backup date
# History:       	
#	13/06/2014 => Add check for last backup date (JDC) and updated documentation
#	30/07/2014 => Added perfdata 
#	31/07/2014 => Added 2 hours to backup compare, and check if no mounted databases found
#	01/08/2014 => Updated documentation and upload
# How to:
#	1) Put the script in the NSCP scripts folder
#	2) In the nsclient.ini configuration file, define the script like this:
#		check_ms_exchange_2010_health=cmd /c echo scripts\check_ms_exchange_2010_health.ps1 $ARG1$; exit $LastExitCode | powershell.exe -command -
#	3) Make a command in Nagios like this:
#		check_ms_exchange_2010_health => $USER1$/check_nrpe -H $HOSTADDRESS$ -p 5666 -t 60 -c check_ms_exchange_2010_health -a $ARG1$
#	4) Configure your service in Nagios:
#		- Make use of the above created command
#		- Parameter 1 should be the hostname of the Exchange server
# Copyright:
#	This program is free software: you can redistribute it and/or modify it under the terms of the
# 	GNU General Public License as published by the Free Software Foundation, either version 3 of 
#   the License, or (at your option) any later version.
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#	without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
# 	See the GNU General Public License for more details.You should have received a copy of the GNU
#   General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
###################################################################################################

#param([string] $Server)

add-pssnapin Microsoft.Exchange.Management.PowerShell.SnapIn
 
# In order to prevent recovery databases to pollute the open service problems each time a backup is restored

$Server = $env:COMPUTERNAME
$ServerShort = (($Server).split('.'))[0]
#$Status = Get-MailboxDatabase -server 127.0.0.1 | ? {-not $_.Recovery} | Get-MailboxDatabaseCopyStatus | ? {$_.mailboxserver -match $ServerShort}
$Status = Get-MailboxDatabase | ? {-not $_.Recovery} | Get-MailboxDatabaseCopyStatus | ? {$_.mailboxserver -match $ServerShort}

# Check last backup
#$BackupStatus = Get-MailboxDatabase -server $Server -status | ? {-not $_.recovery -and $_.server -match $ServerShort} | select name, lastfullbackup 
$BackupStatus = Get-MailboxDatabase -status | ? {-not $_.recovery -and $_.server -match $ServerShort} | select name, lastfullbackup 
 
$WarningList = @()
$ErrorList = @()
$CountMounted = 0
$CountHealthy = 0
$CountUnhealthy = 0
$OutputString = ""
 
foreach($State in $Status){
 
	if($State.status -match '^Mounted'){
		$CountMounted = $CountMounted +1
	}
	elseif($State.status -match '^Healthy'){
		$CountHealthy = $CountHealthy +1
	}
	else{
		$ContentState = $($State.name)+": "+$($State.status)
		$ErrorList += $ContentState
		$CountUnhealthy = $CountUnhealthy +1
	} 
}
foreach($ContentIndexState in $Status){
 
	if(($ContentIndexState.status -match '^Healthy') -or ($ContentIndexState.status -match '^Mounted')){
	}else{
		$Content = $($ContentIndexState.name)+" Index: "+$($ContentIndexState.status)
		$WarningList += $Content
	}
}

# Compare last backup date with current date, only when $BackupStatus is not empty
if ($BackupStatus.count -gt 0) {
	$Now = get-date
	$BackupStatus | ? {$_.lastfullbackup -lt $Now.addhours(-26)} | % {
		if ($_.lastfullbackup -lt $Now.addhours(-50)){
			write-verbose 'error $($_.name)';
			$ErrorList+="DB $($_.name) hasn't been backed up for $([Math]::floor(($now -  $_.lastFullbackup).totalHours)) hours`n"
		} else {
			$WarningList+="DB $($_.name) hasn't been backed up for $([Math]::floor(($now -  $_.lastFullbackup).totalHours)) hours`n"
		};
	}
}
else {
	$WarningList += "No mailbox databases mounted on $Server!"
}

$TotalProblems = $WarningList.count + $ErrorList.count

if ($TotalProblems -eq 0) {
	$OutputString = "All databases, indexes and backups are ok!" 
	$OutputString += " | 'Total Mounted'=$CountMounted, 'Total Healthy'=$CountHealthy, 'Total Unhealthy'=$CountUnhealthy, 'Total Problems'=$TotalProblems"
	Write-Host "$OutputString"
	exit 0
} 
else {
	$OutputString = "$ErrorList" + "$WarningList"
	$OutputString += " | 'Total Mounted'=$CountMounted, 'Total Healthy'=$CountHealthy, 'Total Unhealthy'=$CountUnhealthy, 'Total Problems'=$TotalProblems"
#	write-host (($ErrorList + $WarningList) -join ' - ')
	if ($ErrorList.count -ne 0){		
		Write-Host "$OutputString"
		exit 2
	} else {
		Write-Host "$OutputString"
		exit 1
	}
}