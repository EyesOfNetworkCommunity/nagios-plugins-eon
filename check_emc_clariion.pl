#!/usr/bin/perl -w

# ------------------------------------------------------------------------------
# check_emc_clariion.pl - checks the EMC CLARIION SAN devices
# Copyright (C) 2005  NETWAYS GmbH, www.netways.de
# Original Author: Michael Streb <michael.streb@netways.de>
# Maintained by: Troy Lea <plugins@box293.com> Twitter: @Box293
# See all my Nagios Projects on the Nagios Exchange: 
#	http://exchange.nagios.org/directory/Owner/Box293/1
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
# To see the license type:
#		check_emc_clariion.pl --license | more
#
# ------------------------------------------------------------------------------
# 				Version Notes
# ------------------------------------------------------------------------------
# Version : 1.0 or 1315 2009-01-08 09:16:31Z
# Date    : January 8 2009
# Notes   : This is the original plugin 
#
#
# Version : 2011-03-24
# Date    : March 24 2011
# Notes   : Modified plugin to perform a Percentage Of Dirty Pages check that
#			returns performance data (cache_pdp)
#
# Version : 2011-03-28
# Date    : March 28 2011
# Notes   : Modified plugin to perform SP Busy and SP Idle checks that
#			returns performance data (sp_busy and sp_idle)
#
#
# Version : 2011-05-08
# Date    : May 5 2011
# Notes   : Modified plugin to peform an SP Busy check [that uses the controller
#			busy and idle ticks] and returns performance data (sp_cbt_busy).
#			This is more accurate than the (sp_busy and sp_idle) method.
#			Removed (sp_busy and sp_idle) checks from the help text, left them
#			in the plugin so can can still be used if desired.
#
#
# Version : 2011-06-29
# Date    : June 29th 2011
# Notes   : Modified sp_cbt_busy to check for negative numbers in the data
#			obtained from the SAN. If this occurs then abort. This happens 
#			randomnly so this will avoid incorrect data.
#
#
# Version : 2011-07-04
# Date    : July 4th 2011
# Notes   : Modified sp_cbt_busy to ensure calculated value does not exceed
#			100%. If this occurs then abort. This happens randomnly so this 
#			will avoid incorrect data.
#
#
# Version : 2012-03-06
# Date    : March 6th 2012
# Notes   : Modified check_disk to look for Removed drives, this was missing.
#			Also removed a double || symbol in the same section.
#			Modified check_portstate to include code supplied from Federspiel
#			Till. Problem occurred when all ports were checked, the error_count
#			was being incorrectly determined.
#
#
# Version : 2012-10-23
# Date    : October 23rd 2012
# Notes   : Corrected POD formatting to fix POD ERRRORS.
#			Added error checking to ensure we are getting expected results from
#			the Navisphere CLI app.
#			
#
# Version : 2012-12-05
# Date    : December 5th 2012
# Notes   : Updated plugin to check for navicli or naviseccli, it will use
#			naviseccli if present. Also makes sure that the username and password
#			arguments have been provided. This fixes a problem with newer
#			releases of Navisphere that only come with naviseccli (reported by
#			Charles Breite).
#			
#			
# Version : 2012-12-11
# Date    : December 11th 2012
# Notes   : Fixed bug in portstate check, it is now performing a regex that is 
#			not case sensative (reported by Charles Breite). Also added a check
#			to detect if the user did not provide any options, if not it will
#			display the help. 
#			
#			
# Version : 2012-12-19
# Date    : December 19th 2012
# Notes   : Updated code to prevent errors if required arguments are missing, if 
#			so it will display the help. Updated the help to include information
#			about Secure vs Non-Secure and also provided several examples.
#			
#			
# Version : 2013-01-25
# Date    : January 25th 2013
# Notes   : Added LUN check (requested by Nishith N. Vyas) to report the State,
#			ID, Name, Size, Free Space, RAID Group Type and Percentage Rebuilt. 
#			Added RAID Group check (requested by Nishith N. Vyas) to report the
#			State, ID, RAID Group Type, Logical Size, Free Space, Percentage 
#			Defragmentation Complete, Percentage Expansion Complete. 
#			Fixed bug in the disk check that was counting Empty disk slots as
#			disks, (reported by Nishith N. Vyas). Added SP Information check 
#			that will report information about the SP ID, Agent Revision, 
#			FLARE Revision, PROM Revision, Model/Type, Memory and Serial Number.
#			Added functionality that will pause for 7 seconds if an error occurs
#			before showing the help text, this gives you time to read the error
#			message. Added error checking for "Could not connect to the specified
#			host". Updated SP check to account for enclosures which return 
#			certain parts (Fans etc) with a status of N/A (as reported by 
#			davesykes on Nagios Exhcange). Added information to the Help about 
#			what states will be returned for each check. If warn or crit values
#			are incorrect or not present when the arguments are, only an error
#			is displayed, the help is not displayed. Fixed bug "Illegal division
#			by zero" error when running the sp_cbt_busy check (reported by
#			Charles Breite). Added full GNU license.
#			
# Version : 2013-01-28
# Date    : January 28th 2013
# Notes   : Fixed RAID Group type being identified as hot_spare instead of 'Hot
#			Spare'. 
#			
# Version : 2013-01-30
# Date    : January 30th 2013
# Notes   : Removed space from performance data string for LUN and RAID Group
#			checks as identified by Fernando Coelho.
#			
#
# Version : 2013-02-09
# Date    : February 9th 2013
# Notes   : Fixed bug in LUN and RAID Group checks, they were not triggering
#			correctly on the warning and critical thresholds. Updated the help
#			to explain how the warning and critical thresholds are triggered as
#			the existing help was not very clear.
#			
# Version : 2013-03-09
# Date    : March 9th 2013
# Notes   : Plugin updated to incorporate new functionality of using a credentials
#			file instead of supplying a username and password. This code was 
#			supplied by Uwe Kirbach. Fixed a bug that was caused by older versions
#			of perl and the use of switch statements. Changed these switch
#			statements to if elsif statements to allow plugin to run on older
#			versions of perl.
#
# Version : 2013-12-19
# Date    : December 19th 2013
# Notes   : Add an option to set min spare disk expected (--minspare <COUNT>).
#
# Version : 2014-05-06
# Date    : May 6th 2014
# Notes   : Added a check to get the inlet air temperature as a nagios perf
#			metric (Contributed by Max Vernimmen from www.comparegroup.eu).
#			Fixed duplicate port bug when checking just one port. Can now check
#			several specific ports at one time like --port 1,3. (Port fixes
#			contributed by Stanislav German-Evtushenko).
#			Added a check for reporting on Storage Pools (requested and tested by
#			Vitaly Burshteyn, tested by Stanislav German-Evtushenko).
#
#
# ------------------------------------------------------------------------------

# basic requirements
use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;
	
# predeclared subs
use subs qw/print_help print_license check_sp get_sp_info check_temp check_sp_busy check_sp_idle check_sp_cbt_busy check_disk check_portstate check_hbastate check_cache check_cache_pdp check_faults check_lun check_raid_group check_storage_pool check_test size_format raid_group_state/;

# predeclared vars
use vars qw (
	$PROGNAME
	$VERSION
	$NAVICLI
	$NAVISECCLI
	$NAVICLI_CMD
	%state_names
	$state
	$opt_host
	$opt_sp
	$opt_verbose
	$opt_help
	$opt_checktype
	$opt_warn
	$opt_crit
	$opt_pathcount
	$opt_node
	$opt_secfilepath
	$opt_user
	$opt_password
	$opt_lun_id
	$opt_temp_type
	$output
	$secure
	);

# I'm setting these variable with no values to prevent some coding errors.
my $opt_host = '';
my $opt_sp = '';
my $opt_verbose = '';
my $opt_help = '';
my $opt_license = '';
my $opt_checktype = '';
my $opt_pathcount = '';
my $opt_node = '';
my $opt_secfilepath = '';
my $opt_user = '';
my $opt_password = '';
my $opt_lun_id = '';
my $opt_raid_group_id = '';
my $opt_storage_pool_id = '';
my $opt_hot_spare_min_count = 1;
my $output = '';
my $secure = '';

### add some declaration in order to manage the --port option for check_portstate();
my $opt_port;
$opt_port=-1;

# Main values
$PROGNAME = basename($0);
$VERSION  = '2014-05-06';
$NAVICLI = '/opt/Navisphere/bin/navicli';
$NAVISECCLI = '/opt/Navisphere/bin/naviseccli';
$NAVICLI_CMD= '';

# Nagios exit states
our %states = (
	OK       => 0,
	WARNING  => 1,
	CRITICAL => 2,
	UNKNOWN  => 3
	);

# Nagios state names
%state_names = (
	0 => 'OK',
	1 => 'WARNING',
	2 => 'CRITICAL',
	3 => 'UNKNOWN'
	);


# Checking to see if options have been supplied.
if ( @ARGV == 0 ) {
	print_help('jh', 2);
	exit ($states{UNKNOWN});
	}


# Get the options from cl
Getopt::Long::Configure('bundling');
GetOptions(
	'h'       			=> \$opt_help,
	'help'    			=> \$opt_help,
	'license'  			=> \$opt_license,
	'H=s'     			=> \$opt_host,
	'node=s'  			=> \$opt_node,
	'sp=s'    			=> \$opt_sp,
	't=s'    			=> \$opt_checktype,
	'warn=i' 			=> \$opt_warn,
	'crit=i'  			=> \$opt_crit,
	'lun_id=i'			=> \$opt_lun_id,
	'raid_group_id=i'	=> \$opt_raid_group_id,
	'storage_pool_id=i'	=> \$opt_storage_pool_id,
	'secfilepath=s'		=> \$opt_secfilepath,
	'u=s'     			=> \$opt_user,
	'p=s'     			=> \$opt_password,
	'port=s'  			=> \$opt_port,
	'paths=s' 			=> \$opt_pathcount,
	'temp_type=s'  		=> \$opt_temp_type,
	'minspare=s'		=> \$opt_hot_spare_min_count,
	) || print_help('warn', 0);
 

# If somebody wants the help ...
if ($opt_help) {
	print_help('jh', 2);
	}

# If somebody wants the license ...
if ($opt_license) {
	print_license();
	}

if ($opt_user) {
	$secure = 'u';
	}
if ($opt_password) {
	$secure = $secure . 'p';
	}
if ($opt_secfilepath) {
	$secure = $secure . 's';
	}

# Check if NAVICLI exists
if (-e $NAVICLI) {
	$NAVICLI_CMD="$NAVICLI";
	$secure = 0;
	}
# Check if NAVISECCLI exists
elsif (-e $NAVISECCLI) {
	# Check if secfilepath or user and password for Naviseccli is given
	# If it is providen, then it passes in secure mode for the command to the array.
	# else we are staying in navicli mode
	if ($secure =~ /u/i || $secure =~ /p/i) {
		if (!defined($opt_user)) {
			# The user argument has not been supplied
			print "\nThe -u argument has not been supplied, aborting.\n";
			exit ($states{UNKNOWN});
			}
		elsif (!defined($opt_password)) {
			# The password argument was not supplied
			print "\nThe -p argument has not been supplied, aborting.\n";
			exit ($states{UNKNOWN});
			}
		else {
			$NAVICLI_CMD="$NAVISECCLI -User $opt_user -Password $opt_password -Scope 0";
			$secure = 1;
			}
		}
	elsif ($secure =~ /s/i) {
		if (!defined($opt_secfilepath)) {
			# The secfilepath argument has not been supplied
			print "\nThe --secfilepath argument has not been supplied, aborting.\n";
			exit($states{UNKNOWN});
			}
		else {
			if (-x $opt_secfilepath && -e "$opt_secfilepath/SecuredCLISecurityFile.xml" && -e "$opt_secfilepath/SecuredCLIXMLEncrypted.key") {
				$NAVICLI_CMD="$NAVISECCLI -secfilepath  $opt_secfilepath";
				$secure = 1;
				}
			else {
				print "\nThe secfilepath $opt_secfilepath does not exist or SecuredCLI files are not created, aborting.\n";
				print "\nYou can create the SecuredCLI files with the command:\n";
				print "\t\tmkdir <path to SecuredCLI files>\n";
				print "\t\t$NAVISECCLI -secfilepath <path to SecuredCLI files> -User <username> -Password <password> -Scope <0 = global 1 = local 2 = LDAP> -AddUserSecurity\n";
				exit($states{UNKNOWN});
				}
			}
		}
	}

# If neither file exists then we need to exit as Navisphere is not installed
if (! -e $NAVICLI) {
	if (! -e $NAVISECCLI) {
		print "\nNavisphere does not appear to be installed in /opt/Navisphere/bin/\n";
		exit ($states{UNKNOWN});
		}
	}

# Check if all needed options present
if ( $opt_host && $opt_checktype ) {
	# do the work
	if ($opt_checktype eq "sp" && $opt_sp ne "") {
		check_sp();
		}
	if ($opt_checktype eq "sp_info") {
		get_sp_info();
		}
	if ($opt_checktype eq "sp_busy") {
		check_sp_busy();
		}
	if ($opt_checktype eq "sp_idle") {
		check_sp_idle();
		}
	if ($opt_checktype eq "sp_cbt_busy" && $opt_sp ne "") {
		$opt_sp = uc $opt_sp;
		check_sp_cbt_busy();
		}
	if ($opt_checktype eq "disk") {
		check_disk();
		}
	if ($opt_checktype eq "cache") {
		check_cache();
		}
	if ($opt_checktype eq "cache_pdp") {
		check_cache_pdp();
		}
	if ($opt_checktype eq "faults") {
		check_faults();
		}
	if ($opt_checktype eq "portstate" && $opt_sp ne "") {
		check_portstate();
		}
	if ($opt_checktype eq "hbastate" && $opt_pathcount ne "" && $opt_node ne "") {
		check_hbastate();
		}
	if ($opt_checktype eq "lun" && $opt_lun_id ne "") {
		check_lun();
		}
	if ($opt_checktype eq "raid_group" && $opt_raid_group_id ne "") {
		check_raid_group();
		}
	if ($opt_checktype eq "storage_pool" && $opt_storage_pool_id ne "") {
		check_storage_pool();
		}
	if ($opt_checktype eq "test") {
		check_test();
		}
	if ($opt_checktype eq "temp") {
		# Define temperature type if not defined
		if (!defined($opt_temp_type)) {
			$opt_temp_type = 'c';
			get_temperature();
			}
		else {
			# Otherwise check if it's a valid value
			if ($opt_temp_type eq 'c' or $opt_temp_type eq 'f' ) {
				get_temperature();
				}
			else {
				print "\n--temp_type value \'$opt_temp_type\' is not valid!\n";
				}
			}
		}
	print_help('uhoh', 2, 'Wrong parameters specified!');
	}
else {
	print_help('jh', 2);
	}

# -------------------------
# THE SUBS:
# -------------------------

# check_sp();
# check state of the storage processors
sub check_sp {

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getcrus |");

	my $sp_line = 0;
	my $error_count = 0;
	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
				
		if ($_ =~ m/^DPE|^SPE/ ) {
			# got an DPE line
			$sp_line=1;
			}
		if ($sp_line == 1) {
			# check for SP lines
			if( $_ =~ m/^SP\s$opt_sp\s\w+:\s+(\w+)/) {
				if ($1 =~ m/(Present|Valid)/) {
					$output .= "SP $opt_sp $1,";
					}
				else {
					$output .= "SP $opt_sp failed,";
					$error_count++;
					}	
				}
			# check for Enclosure lines
			if( $_ =~ m/Enclosure\s(\d+|\w+)\s(\w+)\s$opt_sp\d?\s\w+:\s+(\w+)/) {
				my $check = $2;
				if ($3 =~ m/Present|Valid|N/) {
					$output .= "$check ok,";
					}
				else {
					$output .= "$check failed,";
					$error_count++;
					}	
				}
			# check for Cabling lines
			if( $_ =~ m/Enclosure\s(\d+|\w+)\s\w+\s$opt_sp\s(\w+)\s\w+:\s+(\w+)/) {
				my $check = $2;
				if ($3 =~ m/Present|Valid/) {
					$output .= "$check ok";
					}
				else {
					$output .= "$check failed";
					$error_count++;
					}	
				}
			# end of section
			if ( $_ =~ m/^\s*$/) {
				$sp_line=0;
				}
			}
		}
	close (NAVICLIOUT);
	if ($error_count == 0 && $output ne "") {
		$state = 'OK';
		} 
	elsif ($output eq "") {
		$output = "UNKNOWN: No output from $NAVICLI";
		$state = 'UNKNOWN';
		} 
	else {
		$state = 'CRITICAL';
		}
	print $output."\n";
	exit $states{$state};
	} # End sub check_sp {
	

# get_sp_info();
# gathers SP Information
sub get_sp_info {
	my $sp_id = '';
	my $sp_agent_rev = '';
	my $sp_flare_rev = '';
	my $sp_prom_rev = '';
	my $sp_model = '';
	my $sp_model_type = '';
	my $sp_memory_total = '';
	my $sp_serial_number = '';
	$state = 'OK';

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getagent -ver -rev -prom -model -type -mem -serial -spid |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		if ( $_ =~ m/^SP Identifier:\s+(.*)$/) {
			$sp_id = $1;
			}
		
		if ( $_ =~ m/^Agent Rev:\s+(.*)$/) {
			$sp_agent_rev = $1;
			}
		
		if ( $_ =~ m/^Revision:\s+(.*)$/) {
			$sp_flare_rev = $1;
			}
		
		if ( $_ =~ m/^Prom Rev:\s+(.*)$/) {
			$sp_prom_rev = $1;
			}
		
		if ( $_ =~ m/^Model:\s+(.*)$/) {
			$sp_model = $1;
			}
		
		if ( $_ =~ m/^Model Type:\s+(.*)$/) {
			$sp_model_type = $1;
			}
		
		if ( $_ =~ m/^SP Memory:\s+(.*)$/) {
			$sp_memory_total = size_format($1*1048576);
			}
		
		if ( $_ =~ m/^Serial No:\s+(.*)$/) {
			$sp_serial_number = $1;
			}
		}
	close (NAVICLIOUT);

	$output .= "{SP ID:".$sp_id."} {Agent Revision:".$sp_agent_rev."} {FLARE Revision:".$sp_flare_rev."} {PROM Revision:".$sp_prom_rev."} {Model:".$sp_model.", ".$sp_model_type."} {Memory:".$sp_memory_total."} {Serial Number:".$sp_serial_number."}";
	
	print $output."\n";
	exit $states{$state};
	} # End sub get_sp_info {


# get_temperature();
# gathers inlet air temperature per enclosure
# Contributed by Max Vernimmen from www.comparegroup.eu
sub get_temperature {
	my $perf = '';
	$state = 'OK';

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host environment -list -enclosure -intemp $opt_temp_type |");

	my $line_nr = 0;
	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);

		if ($_ =~ m/^(.+)\s+Bus\s+(.*)\s+Enclosure\s+([0-9]+)\s*$/) {
			$output .= "{enclosure: ".$1."} {number: ".$3."} ";
			$perf .= "$1-$3=";
			}
		if ($_ =~ m/^Present\(degree\):\s+([0-9]+)\s*$/) {
			$output .= "{inlet air temperature : ".$1." ".$opt_temp_type."}";
			$perf .= "$1;;;;";
			}
		}
	close (NAVICLIOUT);

	$output .= "|".$perf;

	print $output."\n";
	exit $states{$state};
	} # End sub get_temperature {


# check_sp_busy();
# Use of this should be avoided, check_sp_cbt_busy is more accurate
# returns the percentage of how busy the sp is
sub check_sp_busy {
	$state = 'OK';
	my $errorcheck = 1;

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getcontrol -busy -idle |");

	my $busy_value;
	my $idle_value;
	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		$errorcheck = 2;
		#print "\n$_\n\n";
		if ( $_ =~ /^Prct Busy:\s+(\d+)/) {
			#print "\n$_\n\n";
			my @sp_busy_values = split(/:/,$_);
			$busy_value = $sp_busy_values[1];
			$busy_value =~ s/\s//g;
			#print "\n$busy_value\n\n";
			}
		elsif ( $_ =~ /^Prct Idle:\s+(\d+)/) {
			#print "\n$_\n\n";
			my @sp_idle_values = split(/:/,$_);
			$idle_value = $sp_idle_values[1];
			$idle_value =~ s/\s//g;
			#print "\n$idle_value\n\n";
			}
		}
	# Check for warning value
	no warnings;
	if (defined($opt_warn)) {
		# Check for critical value
		if (defined($opt_crit)) {
			# Ensure warning is a smaller value than critical
			if ($opt_warn > $opt_crit) {
				print_help('uhoh', 2, 'The "warn" value must be smaller than the "crit" value');
				}
			# Check if critical value has been exceeded
			elsif ($busy_value >= $opt_crit) {
				$state = 'CRITICAL';
				}
			# Otherwise check if warning value has been exceeded
			elsif ($busy_value >= $opt_warn) {
				$state = 'WARNING';
				}
			}
		# If no critical value was defined check if warning value has been exceeded
		elsif ($busy_value >= $opt_warn) {
				$state = 'WARNING';
			}
		}
	# Check for critical value
	if (defined($opt_crit) && !defined($opt_warn)) {
		# Check if critical value has been exceeded
		if ($busy_value >= $opt_crit) {
			$state = 'CRITICAL';
			}
		}
	close (NAVICLIOUT);
	if ($errorcheck==1) {
		$state = 'UNKNOWN';
		exit $states{$state};
		}
	else {
		$output .= "SP is $busy_value% Busy|SP Busy=$busy_value%;$opt_warn;$opt_crit;; SP Idle=$idle_value%;;;;";
		print $state . ": " . $output."\n";
		}
	use warnings;
	exit $states{$state};
	} # End sub check_sp_busy {

	
# check_sp_idle();
# Use of this should be avoided, check_sp_cbt_busy is more accurate
# returns the percentage of how idle the sp is
sub check_sp_idle {
	$state = 'OK';
	my $errorcheck = 1;

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getcontrol -idle -busy |");

	my $idle_value;
	my $busy_value;
	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		$errorcheck = 2;
		#print "\n$_\n\n";
		if ( $_ =~ /^Prct Idle:\s+(\d+)/) {
			#print "\n$_\n\n";
			my @sp_idle_values = split(/:/,$_);
			$idle_value = $sp_idle_values[1];
			$idle_value =~ s/\s//g;
			#print "\n$idle_value\n\n";
			}
		elsif ( $_ =~ /^Prct Busy:\s+(\d+)/) {
			#print "\n$_\n\n";
			my @sp_busy_values = split(/:/,$_);
			$busy_value = $sp_busy_values[1];
			$busy_value =~ s/\s//g;
			#print "\n$busy_value\n\n";
			}
		}
	# Check for warning value
	no warnings;
	if (defined($opt_warn)) {
		# Check for critical value
		if (defined($opt_crit)) {
			# Ensure warning is a larger value than critical
			if ($opt_warn < $opt_crit) {
				print_help('uhoh', 2, 'The "warn" value must be larger than the "crit" value');
				}
			# Check if critical value has been exceeded
			elsif ($idle_value <= $opt_crit) {
				$state = 'CRITICAL';
				}
			# Otherwise check if warning value has been exceeded
			elsif ($idle_value <= $opt_warn) {
				$state = 'WARNING';
				}
			}
		# If no critical value was defined check if warning value has been exceeded
		elsif ($idle_value <= $opt_warn) {
				$state = 'WARNING';
			}
		}
	# Check for critical value
	if (defined($opt_crit) && !defined($opt_warn)) {
		# Check if critical value has been exceeded
		if ($idle_value <= $opt_crit) {
			$state = 'CRITICAL';
			}
		}
	close (NAVICLIOUT);
	
	if (!defined($opt_warn)) {
		my $opt_warn = "";
		}
	if (!defined($opt_crit)) {
		my $opt_crit = "";
		}
	
	if ($errorcheck==1) {
		$state = 'UNKNOWN';
		exit $states{$state};
		}
	else {
		$output .= "SP is $idle_value% Idle|SP Idle=$idle_value%;$opt_warn;$opt_crit;; SP Busy=$busy_value%;;;;";
		print $state . ": " . $output."\n";
		}
	use warnings;
	exit $states{$state};
	} # End sub check_sp_idle {


sub check_test {
	$state = 'OK';
	my $opt_host_uc = uc $opt_host;
	print "\n$opt_host_uc\n";
	exit $states{$state};
	} # End sub check_test {


# check_sp_cbt_busy();
# returns the percentage of how busy the sp is
sub check_sp_cbt_busy {
	$state = 'OK';
	my $errorcheck = 1;
	my $opt_host_uc = uc $opt_host;
	my $cbtbusy_tmp_file = '/tmp/check_emc_clariion_cbtbusy_'.$opt_host_uc.'_'.$opt_sp.'_tmp.txt';
	my $cbtbusy_tmp_file_exists = 1;
	my $cbt_busy_value_old;
	my $cbt_idle_value_old;
	my $cbtbusy_tmp_file_line = 1;
	if (-e $cbtbusy_tmp_file) {
		open TEMPFILE_CONTENTS, '<', $cbtbusy_tmp_file;
		while (<TEMPFILE_CONTENTS>) {
			if ($cbtbusy_tmp_file_line == 1) {
				$cbt_busy_value_old = $_;
				#print "Busy OLD \n$cbt_busy_value_old\n";
				}
			if ($cbtbusy_tmp_file_line == 2) {
				$cbt_idle_value_old = $_;
				#print "Idle OLD \n$cbt_idle_value_old\n";
				}
			$cbtbusy_tmp_file_line++
			}
		close TEMPFILE_CONTENTS;
		$cbtbusy_tmp_file_exists = 2;
		}

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getcontrol -cbt |");

	my $cbt_busy_value_new;
	my $cbt_busy_value;
	my $cbt_idle_value_new;
	my $malform_check = 1;
	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		$errorcheck = 2;
		#print "\n$_\n\n";
		if ( $_ =~ /^Controller busy ticks:\s+(\d+)/) {
			#print "\n$_\n\n";
			my @sp_cbt_busy_values = split(/:/,$_);
			$cbt_busy_value_new = $sp_cbt_busy_values[1];
			$cbt_busy_value_new =~ s/\s//g;
			#print "\n$cbt_busy_value_new\n\n";
			#Checking to see if the returned value is a negative number
			if ($cbt_busy_value_new < 0) { 
				$malform_check = 2;
				}
			}
		elsif ( $_ =~ /^Controller idle ticks:\s+(\d+)/) {
			#print "\n$_\n\n";
			my @sp_cbt_idle_values = split(/:/,$_);
			$cbt_idle_value_new = $sp_cbt_idle_values[1];
			$cbt_idle_value_new =~ s/\s//g;
			#print "\n$cbt_idle_value_new\n\n";
			#Checking to see if the returned value is a negative number
			if ($cbt_idle_value_new < 0) { 
				$malform_check = 2;
				}
			}
		}
		
	close (NAVICLIOUT);
	
	#If any of the values are negative then abort
	if ($malform_check == 2) { 
		$output .= "Waiting for more data to be collected";
		print $state . ": " . $output."\n";
		exit $states{$state};
		}
	
	if ($cbtbusy_tmp_file_exists == 2) {
		my $cbt_busy_diff = $cbt_busy_value_new - $cbt_busy_value_old;
		my $cbt_idle_diff = $cbt_idle_value_new - $cbt_idle_value_old;
		my $cbt_total_diff = $cbt_busy_diff + $cbt_idle_diff;
		
		# Checking values to avoide divide by zero errors
		if ($cbt_busy_diff == 0 && $cbt_total_diff == 0) {
			$cbt_busy_value = 0;
			}
		else {
			$cbt_busy_value = sprintf("%.2f", ($cbt_busy_diff / $cbt_total_diff) * 100);	
			}
		
		#If the calculated percentage is over 100% then start data collection from scratch
		if ($cbt_busy_value > 100) { 
			unlink($cbtbusy_tmp_file); 
			$output .= "Waiting for more data to be collected";
			print $state . ": " . $output."\n";
			exit $states{$state};
			}
		}
				
	# Check for warning value
	no warnings;
	if ($cbtbusy_tmp_file_exists == 2) {
		if (defined($opt_warn)) {
			# Check for critical value
			if (defined($opt_crit)) {
				# Ensure warning is a smaller value than critical
				if ($opt_warn > $opt_crit) {
					print_help('warn', 2, 'The "warn" value must be smaller than the "crit" value');
					}
				# Check if critical value has been exceeded
				elsif ($cbt_busy_value >= $opt_crit) {
					$state = 'CRITICAL';
					}
				# Otherwise check if warning value has been exceeded
				elsif ($cbt_busy_value >= $opt_warn) {
					$state = 'WARNING';
					}
				}
			# If no critical value was defined check if warning value has been exceeded
			elsif ($cbt_busy_value >= $opt_warn) {
				$state = 'WARNING';
				}
			}
		# Check for critical value
		if (defined($opt_crit) && !defined($opt_warn)) {
			# Check if critical value has been exceeded
			if ($cbt_busy_value >= $opt_crit) {
				$state = 'CRITICAL';
				}
			}
		}
			
	
	if (!defined($opt_warn)) {
		my $opt_warn = "";
		}
	if (!defined($opt_crit)) {
		my $opt_crit = "";
		}
	
	if ($errorcheck!=1) {
		open TEMPFILE_CONTENTS, ">$cbtbusy_tmp_file";
		print TEMPFILE_CONTENTS "$cbt_busy_value_new\n";
		print TEMPFILE_CONTENTS "$cbt_idle_value_new\n";
		close TEMPFILE_CONTENTS;
		}
	if ($errorcheck==1) {
		$state = 'UNKNOWN';
		exit $states{$state};
		}
	elsif ($cbtbusy_tmp_file_exists == 1) {
		$output .= "Waiting for more data to be collected";
		print $state . ": " . $output."\n";
		}
	else {
		$output .= "SP".$opt_sp." % Busy is ".$cbt_busy_value."%|'SP".$opt_sp." % Busy'=".$cbt_busy_value."%;".$opt_warn.";".$opt_crit.";;";
		print $state . ": " . $output."\n";
		}
	use warnings;
	exit $states{$state};
	} # End sub check_sp_cbt_busy {


# check_disk();
# check state of the disks
sub check_disk {
	my $disk_line = 0;
	my $crit_count = 0;
	my $warn_count = 0;
	my $hotspare_count = 0;
	my $disk_ok_count = 0;
	my ($bus,$enclosure,$disk) = 0;
	$state = 'UNKNOWN';

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getdisk -state |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		# check for disk lines
		#if( $_ =~ m/^Bus\s(\d+)\s\w+\s(\d+)\s+\w+\s+(\d+)/) {
		if( $_ =~ m/^Bus\s(\d+)\s\w+\s(\d+)\s+\w+\s+/) {
			$bus = $1;
			$enclosure = $2;
			$disk = $3;
			$disk_line=1;
			}

		if ($disk_line == 1) {
			# check for States lines
			if( $_ =~ m/^State:\s+(.*)$/) {
				my $status = $1;
				if ($status =~ m/Hot Spare Ready/) {
					$hotspare_count++;
					$disk_ok_count++;
					}
				elsif ($status =~ m/Binding|Enabled|Expanding|Unbound|Powering Up|Ready/) {
					$disk_ok_count++;
					}
				elsif ($status =~ m/Empty/) {
					# Doing nothing, making sure it is not flagged as critical
					}
				elsif ($status =~ m/Equalizing|Rebuilding/) {
					$warn_count++;
					$output .= "Bus $bus, Enclosure $enclosure, Disk $disk is replaced or is being rebuilt, ";
					}
				elsif ($status =~ m/Removed/) {
					$warn_count++;
					$output .= "Bus $bus, Enclosure $enclosure, Disk $disk is removed, ";
					}
				else {
					$crit_count++;
					$output .= "Bus $bus, Enclosure $enclosure, Disk $disk is critical, ";
					}	
				}
			}

		# end of section
		if ( $_ =~ m/^\s*$/) {
			$disk_line=0;
			}
		}
	close (NAVICLIOUT);
	if ($disk_ok_count eq 0) {
		print "No disk were founded !\n";
		$state = 'UNKNOWN';
		}
	elsif ($crit_count > 0) {
		$state='CRITICAL';
		}
	elsif ($warn_count > 0 || $hotspare_count < $opt_hot_spare_min_count) {
		$state='WARNING';
		}
	else {
		$state='OK';
		}
	$output .= $disk_ok_count." physical disks are OK. ".$hotspare_count." Hotspares are ready.";
	print $output."\n";
	exit $states{$state};
	} # End sub check_disk {


# check_cache();
# check state of the read and write cache
sub check_cache {
	my $read_state = 0;
	my $write_state = 0;
	my $write_mirrored_state = 0;
	my $crit_count = 0;
	my $warn_count = 0;
	$state = 'UNKNOWN';

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getcache |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		# check for cache
		if( $_ =~ m/^SP Read Cache State\s+(\w+)/) {
			$read_state = $1;
			if ($read_state =~ m/Enabled/) {
				$output .= "Read cache is enable, ";
				}
			else {
				$output .= "Read cache is not enable ! ";
				$warn_count++;
				}
			}
		elsif ( $_ =~ m/^SP Write Cache State\s+(\w+)/) {
			$write_state = $1;
			if ($write_state =~ m/Enabled/) {
				$output .= "Write cache is enable, ";
				}
			else {
				$output .= "Write cache is not enable ! ";
				$crit_count++;
				}
			}
		elsif ( $_ =~ m/^Write Cache Mirrored\:\s+(\w+)/) {
			$write_mirrored_state = $1;
			if ($write_mirrored_state =~ m/YES/) {
				$output .= "Write cache mirroring is enable.";
				}
			else {
				$output .= "The Write cache mirroring is not enable !";
				$crit_count++;
				}
			}
		}
	close (NAVICLIOUT);
	if ( !defined($output) ) {
		print "No output from the command getcache !\n";
		$state = 'UNKNOWN';
		exit $states{$state};
		}
	elsif ($crit_count > 0) {
		$state='CRITICAL';
		}
	elsif ($warn_count > 0 ) {
		$state='WARNING';
		}
	else {
		$state='OK';
		}
	print $output."\n";
	exit $states{$state};
	} # End sub check_cache {


# check_cache_pdp();
# returns the percentage of dirty pages currently in cache
sub check_cache_pdp {
	$state = 'UNKNOWN';

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getcache -pdp |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		# check for cache
		if( $_ =~ /^Prct Dirty Cache Pages =\s+(\d+)/) {
			my @cache_pdp_values = split(/=/,$_);
			my $pdp_value = $cache_pdp_values[1];
			$pdp_value =~ s/\s//g;
			#print "\n$pdp_value\n\n";
			$output .= "Dirty Pages In Cache is $pdp_value%|Dirty Pages In Cache=$pdp_value%;;;;";
			} 
		}
	close (NAVICLIOUT);
	if ( !defined($output) ) {
		print "No output from the command getcache -pdp !\n";
		$state = 'UNKNOWN';
		exit $states{$state};
		}
	$state='OK';
	print $output."\n";
	exit $states{$state};
	} # End sub check_cache_pdp {

	
# check_faults();
# check state of the different faults
# only works with naviseccli
sub check_faults {
	$state = 'UNKNOWN';
	if ($secure == 0 ) {
		print "The check of the faults only works with Naviseccli. Please provide user and password with -u and -p options !\n";
		exit $states{$state};
		}
	if ($secure == 1 ) { 
		open( NAVICLIOUT, "$NAVICLI_CMD -h $opt_host Faults -list |" );
		}
	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		# check for faults on the array
		if( $_ =~ m/^The array is operating normally/) {
			$state='OK';
			$output .= $_ ;
			close (NAVICLIOUT);
			print $output."\n";			
			exit $states{$state};
			}
		else {
			$state='CRITICAL';
			$output .= $_ ;
			}
		}
	close (NAVICLIOUT);
	if ( !defined($output) ) {
		print "No output from the command Faults -list !\n";
		$state = 'UNKNOWN';
		exit $states{$state};
		}
	print $output."\n";
	exit $states{$state};
	} # End sub check_faults {

	
# check_portstate();
# check port state of the sp`s
sub check_portstate {
	my $sp_section = 0;
	my $sp_line = 0;
	my $portstate_line = 0;
	my $error_count = -1;
	my ($port_id,$enclosure,$disk) = 0;
	my @opt_ports=split(/,/ , $opt_port);
	$state = 'UNKNOWN';

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getall -hba |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		# check for port lines
		if ($_ =~ m/SP PORT/i ) {
			$sp_section = 1;
			}
		# check for requested SP
		if( $_ =~ m/^SP\sName:\s+SP\s$opt_sp/ ) {
			$sp_line = 1;
			}
		# check for requested port id
		if ($opt_port =~ /^\d+$/) {
			if( $_ =~ m/^SP\sPort\sID:\s+($opt_port)$/) {
				$port_id = $1;
				$portstate_line = 1;
				$error_count = 0;
				} 
			}
		else {
			if( $_ =~ m/^SP\sPort\sID:\s+(\d+)$/) {
				$port_id = $1;
				if ($opt_ports[0] >=0) {
					$portstate_line = 0;				
					for (my $i=0;$i<=$#opt_ports;$i++) {
						if ($opt_ports[$i] == $port_id) {
							$port_id = $1;
							$portstate_line = 1;
							if ($error_count < 0) { 
								$error_count = 0;
								}
							}
						}
					}
				else {
					$port_id = $1;
					$portstate_line = 1;
					if ($error_count < 0) { 
						$error_count = 0;
						}
					}
				} 
			}

		if ($sp_section == 1 && $sp_line == 1 && $portstate_line == 1) {
			# check for Link line
			if( $_ =~ m/^Link\sStatus:\s+(.*)$/) {
				my $status = $1; 
				if ($status =~ m/Up/) {
					$output .= "SP $opt_sp Port: $port_id, Link: $status, ";
					}
				else {
					$output .= "SP $opt_sp Port: $port_id, Link: $status, ";
					$error_count++;
					}	
				}
			# check for Link line
			### check for Port line
			if( $_ =~ m/^Port\sStatus:\s+(.*)$/) {
				my $status = $1;
				if ($status =~ m/Online/) {
					$output .= "State: $status, ";
					}
				else {
					$output .= "State: $status, ";
					$error_count++;
					}	
				}
			# check for Connection Type
			if( $_ =~ m/^Connection\sType:\s+(.*)$/) {
				my $type = $1;
				$output .= "Connection Type: $type. ";
				}
			# end of section
			if ( $_ =~ m/^\s*$/) {
				$portstate_line = 0;
				$sp_section = 0;
				$sp_line = 0;
				}
			}
		}
	close (NAVICLIOUT);
	if ($error_count == 0) {
		$state='OK';
		}
	elsif ($error_count == -1) {
		$state='UNKNOWN';
		$output = 'UNKNOWN: specified port not found '.$opt_port;
		}
	else {
		$state='CRITICAL';
		}
		
	print $output."\n";
	exit $states{$state};
	} # End sub check_portstate {

	
# check_hbastate();
# check hba and path states for specific client
sub check_hbastate {
	$state = 'UNKNOWN';
	my $hba_node;
	my $hba_node_line = 0;
	my $hba_section = 0;
	my $hba_port_section = 0;
	my $hba_port_count = 0;
	my $hba_uid = "";
	my $error_count = 0;
	my $output = "";

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getall -hba |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		if ($_ =~ m/Information\sabout\seach\sHBA/) {
			$hba_section = 1;
			$hba_port_section = 0;
			$hba_node_line = 0;
			}
		if ($hba_section == 1) {
			if ($_ =~ m/^HBA\sUID:\s+((\w+:?)+)/i) {
				$hba_uid=$1;
				}
			if ($_ =~ m/^Server\sName:\s+($opt_node)/i) {
				$hba_node = $1;
				$hba_node_line = 1;
				}
			if ($_ =~ m/Information\sabout\seach\sport\sof\sthis\sHBA/) {
				$hba_section = 0;
				$hba_port_section = 1;
				}
			}
		
		if ($hba_port_section && $hba_node_line) {
			if ($_ =~ m/SP\sName:\s+(\w+\s+\w+)/) {
				$output .= "$hba_uid connected to: $1, ";
				}
			if ($_ =~ m/SP\sPort\sID:\s+(\d+)/) {
				$output .= "port: $1, ";
				}
			if ($_ =~ m/Logged\sIn:\s+(YES)/) {
				$output .= "Logged in: $1; ";
				$hba_port_count++;
				}
			elsif ($_ =~ m/Logged\sIn:\s+(\w+)/) {
				$output .= "Logged in: $1; <br>";
				$error_count++;
				}
			}
		}
	close (NAVICLIOUT);
	

	if ($error_count == 0 && $hba_port_count == $opt_pathcount) {
		$state='OK';
		}
	elsif (lc($opt_node) ne lc($hba_node) ) {
		$state='UNKNOWN';
		$output = 'UNKNOWN: specified node not found '.$opt_node;
		}
	elsif ($hba_port_count != $opt_pathcount) {
		$output .= " error in pathcount from client to SAN: suggested $opt_pathcount detected $hba_port_count";
		$state='CRITICAL';
		}
	elsif ($error_count != 0 && $hba_port_count == $opt_pathcount) {
		$output .= " Error in Configuration, one path not connected !";
		$state='CRITICAL';
		}
		
	print $opt_node."<br>".$output."\n";
	exit $states{$state};
	} # End sub check_hbastate {
	

# check_lun();
# check specific LUN
sub check_lun {
	my $lun_name = '';
	my $lun_raid_type = '';
	my $lun_state = '';
	my $lun_capacity = '';
	my $lun_drive_type = '';
	my $lun_percentage_rebuilt = '';
	my $lun_percentage_bound = '';
	$state = 'UNKNOWN';

	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getlun $opt_lun_id -name -type -state -usage -capacity -drivetype -prb -bind |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		
		if ( $_ =~ m/^Name\s+(.*)$/) {
			$lun_name = $1;
			}
		
		if ( $_ =~ m/^RAID Type:\s+(.*)$/) {
			$lun_raid_type = $1;
			}
		
		if ( $_ =~ m/^State:\s+(.*)$/) {
			$lun_state = $1;
			}
		
		if ( $_ =~ m/^LUN Capacity\(Megabytes\):\s+(.*)$/) {
			$lun_capacity = $1;
			}
		
		if ( $_ =~ m/^Drive Type:\s+(.*)$/) {
			$lun_drive_type = $1;
			}
		
		if ( $_ =~ m/^Prct Rebuilt:\s+(.*)$/) {
			$lun_percentage_rebuilt = $1;
			}
		
		if ( $_ =~ m/^Prct Bound:\s+(.*)$/) {
			$lun_percentage_bound = $1;
			}
		
		}
	close (NAVICLIOUT);

	my $lun_free_space_percentage = 100 - $lun_percentage_bound;
	my $lun_free_space_size = $lun_capacity*$lun_free_space_percentage;
	
	$lun_capacity = size_format($lun_capacity*1048576);
	$lun_free_space_size = size_format($lun_free_space_size*1048576);
	
	if ($lun_state =~ /Expanding/i) {
		$state = 'OK';
		}
	elsif ($lun_state =~ /Defragmenting/i) {
		$state = 'OK';
		}
	elsif ($lun_state =~ /Faulted/i) {
		$state = 'CRITICAL';
		}
	elsif ($lun_state =~ /Transitional/i) {
		$state = 'WARNING';
		}
	elsif ($lun_state =~ /Bound/i) {
		$state = 'OK';
		}
	
		
	# Check for warning value
	no warnings;
	if (defined($opt_warn)) {
		# Check for critical value
		if (defined($opt_crit)) {
			# Ensure warning is a smaller value than critical
			if ($opt_warn < $opt_crit) {
				print_help('warn', 2, 'The "warn" value must be larger than the "crit" value');
				}
			# Check if critical value has been exceeded
			elsif ($lun_free_space_percentage <= $opt_crit) {
				$state = 'CRITICAL';
				$output = $state.":Free Space is less than supplied threshold";
				}
			# Otherwise check if warning value has been exceeded
			elsif ($lun_free_space_percentage <= $opt_warn) {
				$state = 'WARNING';
				$output = $state.":Free Space is less than supplied threshold";
				}
			}
		# If no critical value was defined check if warning value has been exceeded
		elsif ($lun_free_space_percentage <= $opt_warn) {
			$state = 'WARNING';
			$output = $state.":Free Space is less than supplied threshold";
			}
		}
	# Check for critical value
	if (defined($opt_crit) && !defined($opt_warn)) {
		# Check if critical value has been exceeded
		if ($lun_free_space_percentage <= $opt_crit) {
			$state = 'CRITICAL';
			$output = $state.":Free Space is less than supplied threshold";
			}
		}
	
	if (!defined($opt_warn)) {
		my $opt_warn = "";
		}
	if (!defined($opt_crit)) {
		my $opt_crit = "";
		}
	
	if ($output eq "") {
		$output = $state;
		}

	$output .= " {State:".$lun_state."} {ID:".$opt_lun_id."} {Name:".$lun_name."} {Size:".$lun_capacity."} {Free Space:".$lun_free_space_size." = ".$lun_free_space_percentage."%} {RAID Group Type:".$lun_raid_type.", ".$lun_drive_type."} {Percentage Rebuilt:".$lun_percentage_rebuilt."%}|'Size'=".$lun_capacity.";;;; 'Free Space'=".$lun_free_space_size.";;;; 'Free Space Percentage'=".$lun_free_space_percentage."%;".$opt_warn.";".$opt_crit.";;";
			
	print $output."\n";
	exit $states{$state};
	} # End sub check_lun {

	
# check_raid_group();
# check specific RAID Group
sub check_raid_group {
	my $raid_group_raid_type = '';
	my $raid_group_logical_capacity_blocks = '';
	my $raid_group_logical_capacity = '';
	my $raid_group_free_space_blocks = '';
	my $raid_group_free_space = '';
	my $raid_group_defragmentation_percent = '';
	my $raid_group_expansion_percent = '';
	$state = 'UNKNOWN';
	
	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getrg $opt_raid_group_id -type -tcap -ucap -prcntdf -prcntex |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		if ( $_ =~ m/^RaidGroup Type:\s+(.*)$/) {
			$raid_group_raid_type = $1;
			}
		
		if ( $_ =~ m/^Logical Capacity \(Blocks\):\s+(.*)$/) {
			$raid_group_logical_capacity_blocks = $1;
			$raid_group_logical_capacity = size_format($1*512);
			}
		
		if ( $_ =~ m/^Free Capacity \(Blocks,non-contiguous\):\s+(.*)$/) {
			$raid_group_free_space_blocks = $1;
			$raid_group_free_space = size_format($1*512);
			}
		
		if ( $_ =~ m/^Percent defragmented:\s+(.*)$/) {
			$raid_group_defragmentation_percent = $1;
			}
		
		if ( $_ =~ m/^Percent expanded:\s+(.*)$/) {
			$raid_group_expansion_percent = $1;
			}
		
		}
	close (NAVICLIOUT);

	my $raid_group_state = '';
	
	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host getrg $opt_raid_group_id -state |");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);
		if ( $raid_group_state eq "") {
			if ( $_ =~ m/^RaidGroup State:\s+(.*)$/) {
				$raid_group_state = $1;
				$state = raid_group_state($1);
				}
			}
		else {
			if ( $_ =~ /\s+(.*)$/) {
				if ( $1 ne "") {
					$raid_group_state .= ", " .$1;
					$state = raid_group_state($1);
					}
				}
			}
		}
	close (NAVICLIOUT);
	
	if ($raid_group_raid_type =~ /r0/i) {
		$raid_group_raid_type = 'RAID 0';
		}
	elsif ($raid_group_raid_type =~ /r1/i) {
		$raid_group_raid_type = 'RAID 1';
		}
	elsif ($raid_group_raid_type =~ /r3/i) {
		$raid_group_raid_type = 'RAID 3';
		}
	elsif ($raid_group_raid_type =~ /r5/i) {
		$raid_group_raid_type = 'RAID 5';
		}
	elsif ($raid_group_raid_type =~ /r6/i) {
		$raid_group_raid_type = 'RAID 6';
		}
	elsif ($raid_group_raid_type =~ /r1_0/i) {
		$raid_group_raid_type = 'RAID 1/0';
		}
	elsif ($raid_group_raid_type =~ /id/i) {
		$raid_group_raid_type = 'Individual Disk';
		}
	elsif ($raid_group_raid_type =~ /hot_spare/i) {
		$raid_group_raid_type = 'Hot Spare';
		}
	
	my $raid_group_free_space_percentage = ($raid_group_free_space_blocks/$raid_group_logical_capacity_blocks)*100;
	$raid_group_free_space_percentage = sprintf("%.2f",$raid_group_free_space_percentage);
	
	# Check for warning value
	no warnings;
	if (defined($opt_warn)) {
		# Check for critical value
		if (defined($opt_crit)) {
			# Ensure warning is a smaller value than critical
			if ($opt_warn < $opt_crit) {
				print_help('warn', 0, 'The "warn" value must be larger than the "crit" value');
				}
			# Check if critical value has been exceeded
			elsif ($raid_group_free_space_percentage <= $opt_crit) {
				$state = 'CRITICAL';
				$output = $state.":Free Space is less than supplied threshold";
				}
			# Otherwise check if warning value has been exceeded
			elsif ($raid_group_free_space_percentage <= $opt_warn) {
				$state = 'WARNING';
				$output = $state.":Free Space is less than supplied threshold";
				}
			}
		# If no critical value was defined check if warning value has been exceeded
		elsif ($raid_group_free_space_percentage <= $opt_warn) {
			$state = 'WARNING';
			$output = $state.":Free Space is less than supplied threshold";
			}
		}
	# Check for critical value
	if (defined($opt_crit) && !defined($opt_warn)) {
		# Check if critical value has been exceeded
		if ($raid_group_free_space_percentage <= $opt_crit) {
			$state = 'CRITICAL';
			$output = $state.":Free Space is less than supplied threshold";
			}
		}
	
	if ($output eq "") {
		$output = $state;
		}
	
	if (!defined($opt_warn)) {
		my $opt_warn = "";
		}
	if (!defined($opt_crit)) {
		my $opt_crit = "";
		}
	
	$output .= " {State:".$raid_group_state."} {ID:".$opt_raid_group_id."} {RAID Group Type:".$raid_group_raid_type."} {Logical Size:".$raid_group_logical_capacity."} {Free Space:".$raid_group_free_space." = ".$raid_group_free_space_percentage."%} {Percentage Defragmentation Complete:".$raid_group_defragmentation_percent."%} {Percentage Expansion Complete:".$raid_group_expansion_percent."%}|'Logical Size'=".$raid_group_logical_capacity.";;;; 'Free Space'=".$raid_group_free_space.";;;; 'Free Space Percentage'=".$raid_group_free_space_percentage."%;".$opt_warn.";".$opt_crit.";;";
	
	print $output."\n";
	exit $states{$state};
	} # End sub check_raid_group {


# check_storage_pool();
# check specific Storage Pool
sub check_storage_pool {
	my $storage_pool_raid_type = '';
	my $storage_pool_available_capacity = '';
	my $storage_pool_consumed_capacity = '';
	my $storage_pool_subscribed_capacity = '';
	my $storage_pool_subscribed_percentage = '';
	my $storage_pool_percentage_used = '';
	my $storage_pool_percentage_free = '';
	my $storage_pool_state = '';
	$state = 'OK';
	
	open (NAVICLIOUT ,"$NAVICLI_CMD -h $opt_host storagepool -list -id $opt_storage_pool_id -availableCap -consumedCap -subscribedCap -prcntFull -state -rtype|");

	while (<NAVICLIOUT>) {
		# First lets check for errors before proceeding
		check_for_errors($_);

		if ( $_ =~ m/^Raid Type:\s+(.*)$/) {
			$storage_pool_raid_type = $1;
			}
		
		if ( $_ =~ m/^Available Capacity \(GBs\):\s+(.*)$/) {
			$storage_pool_available_capacity = $1;
			}
		
		if ( $_ =~ m/^Consumed Capacity \(GBs\):\s+(.*)$/) {
			$storage_pool_consumed_capacity = $1;
			}
		
		if ( $_ =~ m/^Total Subscribed Capacity \(GBs\):\s+(.*)$/) {
			$storage_pool_subscribed_capacity = $1;
			}

		if ( $_ =~ m/^Percent Subscribed:\s+(.*)$/) {
			$storage_pool_subscribed_percentage = $1;
			}
		
		if ( $_ =~ m/^Percent Full:\s+(.*)$/) {
			$storage_pool_percentage_used = $1;
			$storage_pool_percentage_free = 100 - $storage_pool_percentage_used;
			}

		if ( $_ =~ m/^State:\s+(.*)$/) {
			$storage_pool_state = $1;
			}
		
		}
	close (NAVICLIOUT);

	
	if ($storage_pool_raid_type =~ /r0/i) {
		$storage_pool_raid_type = 'RAID 0';
		}
	elsif ($storage_pool_raid_type =~ /r1/i) {
		$storage_pool_raid_type = 'RAID 1';
		}
	elsif ($storage_pool_raid_type =~ /r3/i) {
		$storage_pool_raid_type = 'RAID 3';
		}
	elsif ($storage_pool_raid_type =~ /r5/i) {
		$storage_pool_raid_type = 'RAID 5';
		}
	elsif ($storage_pool_raid_type =~ /r6/i) {
		$storage_pool_raid_type = 'RAID 6';
		}
	elsif ($storage_pool_raid_type =~ /r1_0/i) {
		$storage_pool_raid_type = 'RAID 1/0';
		}
	elsif ($storage_pool_raid_type =~ /Mixed/i) {
		$storage_pool_raid_type = 'Mixed';
		}
	
	
	# Check for warning value
	no warnings;
	if (defined($opt_warn)) {
		# Check for critical value
		if (defined($opt_crit)) {
			# Ensure warning is a smaller value than critical
			if ($opt_warn > $opt_crit) {
				print_help('warn', 0, 'The "warn" value must be smaller than the "crit" value');
				}
			# Check if critical value has been exceeded
			elsif ($storage_pool_percentage_used >= $opt_crit) {
				$state = 'CRITICAL';
				$output = $state.":Used space exceeds supplied threshold";
				}
			# Otherwise check if warning value has been exceeded
			elsif ($storage_pool_percentage_used >= $opt_warn) {
				$state = 'WARNING';
				$output = $state.":Used space exceeds supplied threshold";
				}
			}
		# If no critical value was defined check if warning value has been exceeded
		elsif ($storage_pool_percentage_used >= $opt_warn) {
			$state = 'WARNING';
			$output = $state.":Used space exceeds supplied threshold";
			}
		}
	# Check for critical value
	if (defined($opt_crit) && !defined($opt_warn)) {
		# Check if critical value has been exceeded
		if ($storage_pool_percentage_used >= $opt_crit) {
			$state = 'CRITICAL';
			$output = $state.":Used space exceeds supplied threshold";
			}
		}
	
	if ($output eq "") {
		$output = $state;
		}
	
	if (!defined($opt_warn)) {
		my $opt_warn = "";
		}
	if (!defined($opt_crit)) {
		my $opt_crit = "";
		}
	
	$output .= " {State:".$storage_pool_state."} {ID:".$opt_storage_pool_id."} {RAID Type:".$storage_pool_raid_type."} {Available Capacity:".$storage_pool_available_capacity." GB} {Consumed Capacity :".$storage_pool_consumed_capacity." GB} {Subscribed Capacity:".$storage_pool_subscribed_capacity." GB / ".$storage_pool_subscribed_percentage."%} {Percentage Used:".$storage_pool_percentage_used."%} {Percentage Free:".$storage_pool_percentage_free."%}|'Available Capacity'=".$storage_pool_available_capacity."GB;;;; 'Consumed Capacity'=".$storage_pool_consumed_capacity."GB;;;; 'Subscribed Capacity GB'=".$storage_pool_subscribed_capacity."GB;;;; 'Subscribed Capacity Percentage'=".$storage_pool_subscribed_percentage."%;;;; 'Percentage Used'=".$storage_pool_percentage_used."%;".$opt_warn.";".$opt_crit.";; 'Percentage Free'=".$storage_pool_percentage_free."%;;;;";
	
	print $output."\n";
	exit $states{$state};
	} # End sub check_storage_pool {


sub check_for_errors {
	# General checks to see if we had issues connecting
	if  ($_[0] =~ /^(A network error)/) {
		print "\n$_[0]";
		exit ($states{UNKNOWN});
		}
	
	if  ($_[0] =~ /^(Error)/) {
		print "\n$_[0]";
		exit ($states{UNKNOWN});
		}
		
	if  ($_[0] =~ /^(Exception)/) {
		print "\n$_[0]";
		exit ($states{UNKNOWN});
		}
	
	if  ($_[0] =~ /^(Could not connect to the specified host)/) {
		print "\n$_[0]";
		exit ($states{UNKNOWN});
		}
	} # End sub check_for_errors {


sub size_format {
	my $size = shift(@_);
	if ($size < (1024)) {
		return sprintf("%.2fB",$size);
		}
	if ($size < (1024*1024)) {
		return sprintf("%.2fKB",$size / (1024));
		}
	if ($size < (1024*1024*1024)) {
		return sprintf("%.2fMB",$size / (1024*1024));
		}
	if ($size < (1024*1024*1024*1024)) {
		return sprintf("%.2fGB",$size / (1024*1024*1024));
		}
	if ($size < (1024*1024*1024*1024*1024)) {
		return sprintf("%.2fTB",$size / (1024*1024*1024*1024));
		}
	if ($size < (1024*1024*1024*1024*1024*1024)) {
		return sprintf("%.2fPB",$size / (1024*1024*1024*1024*1024));
		}
	if ($size < (1024*1024*1024*1024*1024*1024*1024)) {
		return sprintf("%.2fEB",$size / (1024*1024*1024*1024*1024*1024));
		}
	} # End sub size_format {

	
sub raid_group_state {
	if ($_ =~ /Invalid/i) {
		return 'CRITICAL';
		}
	elsif ($_ =~ /Explicit_Remove/i) {
		return 'OK';
		}
	elsif ($_ =~ /Valid_luns/i) {
		return 'OK';
		}
	elsif ($_ =~ /Expanding/i) {
		return 'OK';
		}
	elsif ($_ =~ /Defragmenting/i) {
		return 'OK';
		}
	elsif ($_ =~ /Halted/i) {
		return 'CRITICAL';
		}
	elsif ($_ =~ /Busy/i) {
		return 'WARNING';
		}
	} # End sub raid_group_state {
	
	
# print_help($type, $level, $msg);
# prints some message and the POD DOC
sub print_help {
	#sleep_message();
	my ( $type, $level, $msg ) = @_;
	if ($type eq 'uhoh') {
			print "\nuh oh something happened that shouldn't ... sleeping for 7 seconds so you can read any error message before lots of help text appears ... sometimes they appear after this line\n\n";
			sleep(7);
		}
	elsif ($type eq 'warn') {
		}
	$level = 0 unless ($level);
	pod2usage({
			-message => $msg,
			-verbose => $level,
			-noperldoc => 1
		});

	exit( $states{UNKNOWN} );
	} # End sub print_help {


sub print_license {
	print "\n";
	print "============================ PROGRAM LICENSE ==================================\n";
	print "    This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n";
	print "\n";
	print "    This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.\n";
	print "\n";
	print "    You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.\n";
	print "\n";
	print "\n";
	print "                    GNU GENERAL PUBLIC LICENSE\n";
	print "                       Version 3, 29 June 2007\n";
	print "\n";
	print " Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>\n";
	print " Everyone is permitted to copy and distribute verbatim copies of this license document, but changing it is not allowed.\n";
	print "\n";
	print "                            Preamble\n";
	print "\n";
	print "  The GNU General Public License is a free, copyleft license for software and other kinds of works.\n";
	print "\n";
	print "  The licenses for most software and other practical works are designed to take away your freedom to share and change the works.  By contrast, the GNU General Public License is intended to guarantee your freedom to share and change all versions of a program--to make sure it remains free software for all its users.  We, the Free Software Foundation, use the GNU General Public License for most of our software; it applies also to any other work released this way by its authors.  You can apply it to your programs, too.\n";
	print "\n";
	print "  When we speak of free software, we are referring to freedom, not price.  Our General Public Licenses are designed to make sure that you have the freedom to distribute copies of free software (and charge for them if you wish), that you receive source code or can get it if you want it, that you can change the software or use pieces of it in new free programs, and that you know you can do these things.\n";
	print "\n";
	print "  To protect your rights, we need to prevent others from denying you these rights or asking you to surrender the rights.  Therefore, you have certain responsibilities if you distribute copies of the software, or if you modify it: responsibilities to respect the freedom of others.\n";
	print "\n";
	print "   For example, if you distribute copies of such a program, whether gratis or for a fee, you must pass on to the recipients the same freedoms that you received.  You must make sure that they, too, receive or can get the source code.  And you must show them these terms so they know their rights.\n";
	print "\n";
	print "   Developers that use the GNU GPL protect your rights with two steps:\n";
	print " (1) assert copyright on the software, and (2) offer you this License giving you legal permission to copy, distribute and/or modify it.\n";
	print "\n";
	print "   For the developers\' and authors\' protection, the GPL clearly explains that there is no warranty for this free software.  For both users\' and authors\' sake, the GPL requires that modified versions be marked as changed, so that their problems will not be attributed erroneously to authors of previous versions.\n";
	print "\n";
	print "   Some devices are designed to deny users access to install or run modified versions of the software inside them, although the manufacturer can do so.  This is fundamentally incompatible with the aim of protecting users\' freedom to change the software.  The systematic pattern of such abuse occurs in the area of products for individuals to use, which is precisely where it is most unacceptable.  Therefore, we have designed this version of the GPL to prohibit the practice for those products.  If such problems arise substantially in other domains, we stand ready to extend this provision to those domains in future versions of the GPL, as needed to protect the freedom of users.\n";
	print "\n";
	print "   Finally, every program is threatened constantly by software patents. States should not allow patents to restrict development and use of  software on general-purpose computers, but in those that do, we wish to avoid the special danger that patents applied to a free program could make it effectively proprietary.  To prevent this, the GPL assures that patents cannot be used to render the program non-free.\n";
	print "\n";
	print "   The precise terms and conditions for copying, distribution and modification follow.\n";
	print "\n";
	print "                        TERMS AND CONDITIONS\n";
	print "\n";
	print "   0. Definitions.\n";
	print " \n";
	print "   \"This License\" refers to version 3 of the GNU General Public License.\n";
	print " \n";
	print "   \"Copyright\" also means copyright-like laws that apply to other kinds of works, such as semiconductor masks.\n";
	print "\n";
	print "   \"The Program\" refers to any copyrightable work licensed under this License.  Each licensee is addressed as \"you\".  \"Licensees\" and \"recipients\" may be individuals or organizations.\n";
	print "\n";
	print "   To \"modify\" a work means to copy from or adapt all or part of the work in a fashion requiring copyright permission, other than the making of an exact copy.  The resulting work is called a \"modified version\" of the earlier work or a work \"based on\" the earlier work.\n";
	print "\n";
	print "   A \"covered work\" means either the unmodified Program or a work based on the Program.\n";
	print "\n";
	print "   To \"propagate\" a work means to do anything with it that, without permission, would make you directly or secondarily liable for infringement under applicable copyright law, except executing it on a computer or modifying a private copy.  Propagation includes copying, distribution (with or without modification), making available to the public, and in some countries other activities as well.\n";
	print "\n";
	print "   To \"convey\" a work means any kind of propagation that enables other parties to make or receive copies.  Mere interaction with a user through a computer network, with no transfer of a copy, is not conveying.\n";
	print "\n";
	print "   An interactive user interface displays \"Appropriate Legal Notices\" to the extent that it includes a convenient and prominently visible feature that (1) displays an appropriate copyright notice, and (2) tells the user that there is no warranty for the work (except to the extent that warranties are provided), that licensees may convey the work under this License, and how to view a copy of this License.  If the interface presents a list of user commands or options, such as a menu, a prominent item in the list meets this criterion.\n";
	print "\n";
	print "   1. Source Code.\n";
	print "\n";
	print "   The \"source code\" for a work means the preferred form of the work for making modifications to it.  \"Object code\" means any non-source form of a work.\n";
	print "\n";
	print "   A \"Standard Interface\" means an interface that either is an official standard defined by a recognized standards body, or, in the case of interfaces specified for a particular programming language, one that is widely used among developers working in that language.\n";
	print "\n";
	print "   The \"System Libraries\" of an executable work include anything, other than the work as a whole, that (a) is included in the normal form of packaging a Major Component, but which is not part of that Major Component, and (b) serves only to enable use of the work with that Major Component, or to implement a Standard Interface for which an implementation is available to the public in source code form.  A \"Major Component\", in this context, means a major essential component (kernel, window system, and so on) of the specific operating system (if any) on which the executable work runs, or a compiler used to produce the work, or an object code interpreter used to run it.\n";
	print "\n";
	print "   The \"Corresponding Source\" for a work in object code form means all the source code needed to generate, install, and (for an executable work) run the object code and to modify the work, including scripts to control those activities.  However, it does not include the work\'s System Libraries, or general-purpose tools or generally available free programs which are used unmodified in performing those activities but which are not part of the work.  For example, Corresponding Source includes interface definition files associated with source files for the work, and the source code for shared libraries and dynamically linked subprograms that the work is specifically designed to require, such as by intimate data communication or control flow between those subprograms and other parts of the work.\n";
	print "\n";
	print "   The Corresponding Source need not include anything that users can regenerate automatically from other parts of the Corresponding Source.\n";
	print "\n";
	print "   The Corresponding Source for a work in source code form is that same work.\n";
	print "\n";
	print "   2. Basic Permissions.\n";
	print "\n";
	print "   All rights granted under this License are granted for the term of copyright on the Program, and are irrevocable provided the stated conditions are met.  This License explicitly affirms your unlimited permission to run the unmodified Program.  The output from running a covered work is covered by this License only if the output, given its content, constitutes a covered work.  This License acknowledges your rights of fair use or other equivalent, as provided by copyright law.\n";
	print "\n";
	print "   You may make, run and propagate covered works that you do not convey, without conditions so long as your license otherwise remains in force.  You may convey covered works to others for the sole purpose of having them make modifications exclusively for you, or provide you with facilities for running those works, provided that you comply with the terms of this License in conveying all material for which you do not control copyright.  Those thus making or running the covered works for you must do so exclusively on your behalf, under your direction and control, on terms that prohibit them from making any copies of your copyrighted material outside their relationship with you.\n";
	print "\n";
	print "   Conveying under any other circumstances is permitted solely under the conditions stated below.  Sublicensing is not allowed; section 10 makes it unnecessary.\n";
	print "\n";
	print "   3. Protecting Users\' Legal Rights From Anti-Circumvention Law.\n";
	print "\n";
	print "   No covered work shall be deemed part of an effective technological measure under any applicable law fulfilling obligations under article 11 of the WIPO copyright treaty adopted on 20 December 1996, or similar laws prohibiting or restricting circumvention of such measures.\n";
	print "\n";
	print "   When you convey a covered work, you waive any legal power to forbid circumvention of technological measures to the extent such circumvention is effected by exercising rights under this License with respect to the covered work, and you disclaim any intention to limit operation or modification of the work as a means of enforcing, against the work\'s users, your or third parties\' legal rights to forbid circumvention of technological measures.\n";
	print "\n";
	print "   4. Conveying Verbatim Copies.\n";
	print "\n";
	print "   You may convey verbatim copies of the Program\'s source code as you receive it, in any medium, provided that you conspicuously and appropriately publish on each copy an appropriate copyright notice; keep intact all notices stating that this License and any non-permissive terms added in accord with section 7 apply to the code; keep intact all notices of the absence of any warranty; and give all recipients a copy of this License along with the Program.\n";
	print "\n";
	print "   You may charge any price or no price for each copy that you convey, and you may offer support or warranty protection for a fee.\n";
	print "\n";
	print "   5. Conveying Modified Source Versions.\n";
	print "\n";
	print "   You may convey a work based on the Program, or the modifications to produce it from the Program, in the form of source code under the terms of section 4, provided that you also meet all of these conditions:\n";
	print "\n";
	print "     a) The work must carry prominent notices stating that you modified it, and giving a relevant date.\n";
	print "\n";
	print "     b) The work must carry prominent notices stating that it is released under this License and any conditions added under section 7.  This requirement modifies the requirement in section 4 to \"keep intact all notices\".\n";
	print "\n";
	print "     c) You must license the entire work, as a whole, under this License to anyone who comes into possession of a copy.  This License will therefore apply, along with any applicable section 7 additional terms, to the whole of the work, and all its parts, regardless of how they are packaged.  This License gives no permission to license the work in any other way, but it does not invalidate such permission if you have separately received it.\n";
	print "\n";
	print "     d) If the work has interactive user interfaces, each must display Appropriate Legal Notices; however, if the Program has interactive interfaces that do not display Appropriate Legal Notices, your work need not make them do so.\n";
	print "\n";
	print "   A compilation of a covered work with other separate and independent works, which are not by their nature extensions of the covered work, and which are not combined with it such as to form a larger program, in or on a volume of a storage or distribution medium, is called an \"aggregate\" if the compilation and its resulting copyright are not used to limit the access or legal rights of the compilation\'s users beyond what the individual works permit.  Inclusion of a covered work in an aggregate does not cause this License to apply to the other parts of the aggregate.\n";
	print "\n";
	print "   6. Conveying Non-Source Forms.\n";
	print "\n";
	print "   You may convey a covered work in object code form under the terms of sections 4 and 5, provided that you also convey the machine-readable Corresponding Source under the terms of this License, in one of these ways:\n";
	print "\n";
	print "     a) Convey the object code in, or embodied in, a physical product (including a physical distribution medium), accompanied by the Corresponding Source fixed on a durable physical medium customarily used for software interchange.\n";
	print "\n";
	print "     b) Convey the object code in, or embodied in, a physical product (including a physical distribution medium), accompanied by a written offer, valid for at least three years and valid for as long as you offer spare parts or customer support for that product model, to give anyone who possesses the object code either (1) a copy of the Corresponding Source for all the software in the product that is covered by this License, on a durable physical medium customarily used for software interchange, for a price no more than your reasonable cost of physically performing this conveying of source, or (2) access to copy the Corresponding Source from a network server at no charge.\n";
	print "\n";
	print "     c) Convey individual copies of the object code with a copy of the written offer to provide the Corresponding Source.  This alternative is allowed only occasionally and noncommercially, and only if you received the object code with such an offer, in accord with subsection 6b.\n";
	print "\n";
	print "     d) Convey the object code by offering access from a designated place (gratis or for a charge), and offer equivalent access to the Corresponding Source in the same way through the same place at no further charge.  You need not require recipients to copy the Corresponding Source along with the object code.  If the place to copy the object code is a network server, the Corresponding Source may be on a different server (operated by you or a third party) that supports equivalent copying facilities, provided you maintain clear directions next to the object code saying where to find the Corresponding Source.  Regardless of what server hosts the Corresponding Source, you remain obligated to ensure that it is available for as long as needed to satisfy these requirements.\n";
	print "\n";
	print "     e) Convey the object code using peer-to-peer transmission, provided you inform other peers where the object code and Corresponding Source of the work are being offered to the general public at no charge under subsection 6d.\n";
	print "\n";
	print "   A separable portion of the object code, whose source code is excluded from the Corresponding Source as a System Library, need not beincluded in conveying the object code work.\n";
	print "\n";
	print "   A \"User Product\" is either (1) a \"consumer product\", which means any tangible personal property which is normally used for personal, family, or household purposes, or (2) anything designed or sold for incorporation into a dwelling.  In determining whether a product is a consumer product, doubtful cases shall be resolved in favor of coverage.  For a particular product received by a particular user, \"normally used\" refers to a typical or common use of that class of product, regardless of the status of the particular user or of the way in which the particular user actually uses, or expects or is expected to use, the product.  A product is a consumer product regardless of whether the product has substantial commercial, industrial or non-consumer uses, unless such uses represent the only significant mode of use of the product.\n";
	print "\n";
	print "   \"Installation Information\" for a User Product means any methods, procedures, authorization keys, or other information required to install and execute modified versions of a covered work in that User Product from a modified version of its Corresponding Source.  The information must suffice to ensure that the continued functioning of the modified object code is in no case prevented or interfered with solely because modification has been made.\n";
	print "\n";
	print "   If you convey an object code work under this section in, or with, or specifically for use in, a User Product, and the conveying occurs as part of a transaction in which the right of possession and use of the User Product is transferred to the recipient in perpetuity or for a fixed term (regardless of how the transaction is characterized), the Corresponding Source conveyed under this section must be accompanied by the Installation Information.  But this requirement does not apply if neither you nor any third party retains the ability to install modified object code on the User Product (for example, the work hasbeen installed in ROM).\n";
	print "\n";
	print "   The requirement to provide Installation Information does not include a requirement to continue to provide support service, warranty, or updates for a work that has been modified or installed by the recipient, or for the User Product in which it has been modified or installed.  Access to a network may be denied when the modification itself materially and adversely affects the operation of the network or violates the rules and protocols for communication across the network.\n";
	print "\n";
	print "   Corresponding Source conveyed, and Installation Information provided, in accord with this section must be in a format that is publicly documented (and with an implementation available to the public in source code form), and must require no special password or key for unpacking, reading or copying.\n";
	print "\n";
	print "   7. Additional Terms.\n";
	print "\n";
	print "   \"Additional permissions\" are terms that supplement the terms of this License by making exceptions from one or more of its conditions.\n";
	print " Additional permissions that are applicable to the entire Program shall be treated as though they were included in this License, to the extent that they are valid under applicable law.  If additional permissions apply only to part of the Program, that part may be used separately under those permissions, but the entire Program remains governed by this License without regard to the additional permissions.\n";
	print "\n";
	print "   When you convey a copy of a covered work, you may at your option remove any additional permissions from that copy, or from any part of it.  (Additional permissions may be written to require their own removal in certain cases when you modify the work.)  You may place additional permissions on material, added by you to a covered work, for which you have or can give appropriate copyright permission.\n";
	print "\n";
	print "   Notwithstanding any other provision of this License, for material you add to a covered work, you may (if authorized by the copyright holders of that material) supplement the terms of this License with terms:\n";
	print "\n";
	print "     a) isclaiming warranty or limiting liability differently from the terms of sections 15 and 16 of this License; or\n";
	print "\n";
	print "     b) Requiring preservation of specified reasonable legal notices or author attributions in that material or in the Appropriate Legal Notices displayed by works containing it; or\n";
	print "\n";
	print "     c) Prohibiting misrepresentation of the origin of that material, or requiring that modified versions of such material be marked in reasonable ways as different from the original version; or\n";
	print "\n";
	print "     d) Limiting the use for publicity purposes of names of licensors or authors of the material; or\n";
	print "\n";
	print "     e) Declining to grant rights under trademark law for use of some trade names, trademarks, or service marks; or\n";
	print "\n";
	print "     f) Requiring indemnification of licensors and authors of that material by anyone who conveys the material (or modified versions of it) with contractual assumptions of liability to the recipient, for any liability that these contractual assumptions directly impose on those licensors and authors.\n";
	print "\n";
	print "   All other non-permissive additional terms are considered \"further restrictions\" within the meaning of section 10.  If the Program as you received it, or any part of it, contains a notice stating that it is governed by this License along with a term that is a further restriction, you may remove that term.  If a license document contains a further restriction but permits relicensing or conveying under this License, you may add to a covered work material governed by the terms of that license document, provided that the further restriction does not survive such relicensing or conveying.\n";
	print "\n";
	print "   If you add terms to a covered work in accord with this section, you must place, in the relevant source files, a statement of the additional terms that apply to those files, or a notice indicating where to find the applicable terms.\n";
	print "\n";
	print "   Additional terms, permissive or non-permissive, may be stated in the form of a separately written license, or stated as exceptions; the above requirements apply either way.\n";
	print "\n";
	print "   8. Termination.\n";
	print "\n";
	print "   You may not propagate or modify a covered work except as expressly provided under this License.  Any attempt otherwise to propagate or modify it is void, and will automatically terminate your rights under this License (including any patent licenses granted under the third paragraph of section 11).\n";
	print "\n";
	print "   However, if you cease all violation of this License, then your license from a particular copyright holder is reinstated (a) provisionally, unless and until the copyright holder explicitly and finally terminates your license, and (b) permanently, if the copyright holder fails to notify you of the violation by some reasonable means prior to 60 days after the cessation.\n";
	print "\n";
	print "   Moreover, your license from a particular copyright holder is reinstated permanently if the copyright holder notifies you of the violation by some reasonable means, this is the first time you have received notice of violation of this License (for any work) from that copyright holder, and you cure the violation prior to 30 days after your receipt of the notice.\n";
	print "\n";
	print "   Termination of your rights under this section does not terminate the licenses of parties who have received copies or rights from you under this License.  If your rights have been terminated and not permanently reinstated, you do not qualify to receive new licenses for the same material under section 10.\n";
	print "\n";
	print "   9. Acceptance Not Required for Having Copies.\n";
	print "\n";
	print "   You are not required to accept this License in order to receive or run a copy of the Program.  Ancillary propagation of a covered work occurring solely as a consequence of using peer-to-peer transmission to receive a copy likewise does not require acceptance.  However, nothing other than this License grants you permission to propagate or modify any covered work.  These actions infringe copyright if you do not accept this License.  Therefore, by modifying or propagating a covered work, you indicate your acceptance of this License to do so.\n";
	print "\n";
	print "   10. Automatic Licensing of Downstream Recipients.\n";
	print "\n";
	print "   Each time you convey a covered work, the recipient automatically receives a license from the original licensors, to run, modify and propagate that work, subject to this License.  You are not responsible for enforcing compliance by third parties with this License.\n";
	print "\n";
	print "   An \"entity transaction\" is a transaction transferring control of an organization, or substantially all assets of one, or subdividing an organization, or merging organizations.  If propagation of a covered work results from an entity transaction, each party to that transaction who receives a copy of the work also receives whatever licenses to the work the party\'s predecessor in interest had or could give under the previous paragraph, plus a right to possession of the Corresponding Source of the work from the predecessor in interest, if the predecessor has it or can get it with reasonable efforts.\n";
	print "\n";
	print "   You may not impose any further restrictions on the exercise of the rights granted or affirmed under this License.  For example, you may not impose a license fee, royalty, or other charge for exercise of rights granted under this License, and you may not initiate litigation (including a cross-claim or counterclaim in a lawsuit) alleging that any patent claim is infringed by making, using, selling, offering for sale, or importing the Program or any portion of it.\n";
	print "\n";
	print "   11. Patents.\n";
	print "\n";
	print "   A \"contributor\" is a copyright holder who authorizes use under this License of the Program or a work on which the Program is based.  The work thus licensed is called the contributor\'s \"contributor version\".\n";
	print "\n";
	print "   A contributor\'s \"essential patent claims\" are all patent claims owned or controlled by the contributor, whether already acquired or hereafter acquired, that would be infringed by some manner, permitted by this License, of making, using, or selling its contributor version, but do not include claims that would be infringed only as a consequence of further modification of the contributor version.  For purposes of this definition, \"control\" includes the right to grant patent sublicenses in a manner consistent with the requirements of this License.\n";
	print "\n";
	print "   Each contributor grants you a non-exclusive, worldwide, royalty-free patent license under the contributor\'s essential patent claims, to make, use, sell, offer for sale, import and otherwise run, modify and propagate the contents of its contributor version.\n";
	print "\n";
	print "   In the following three paragraphs, a \"patent license\" is any express agreement or commitment, however denominated, not to enforce a patent (such as an express permission to practice a patent or covenant not to sue for patent infringement).  To \"grant\" such a patent license to a party means to make such an agreement or commitment not to enforce a patent against the party.\n";
	print "\n";
	print "   If you convey a covered work, knowingly relying on a patent license, and the Corresponding Source of the work is not available for anyone to copy, free of charge and under the terms of this License, through a publicly available network server or other readily accessible means, then you must either (1) cause the Corresponding Source to be so available, or (2) arrange to deprive yourself of the benefit of the patent license for this particular work, or (3) arrange, in a manner consistent with the requirements of this License, to extend the patent license to downstream recipients.  \"Knowingly relying\" means you have actual knowledge that, but for the patent license, your conveying the covered work in a country, or your recipient\'s use of the covered work in a country, would infringe one or more identifiable patents in that country that you have reason to believe are valid.\n";
	print "\n";
	print "   If, pursuant to or in connection with a single transaction or arrangement, you convey, or propagate by procuring conveyance of, a covered work, and grant a patent license to some of the parties receiving the covered work authorizing them to use, propagate, modify or convey a specific copy of the covered work, then the patent license you grant is automatically extended to all recipients of the covered work and works based on it.\n";
	print "\n";
	print "   A patent license is \"discriminatory\" if it does not include within the scope of its coverage, prohibits the exercise of, or is conditioned on the non-exercise of one or more of the rights that are specifically granted under this License.  You may not convey a covered work if you are a party to an arrangement with a third party that is in the business of distributing software, under which you make payment to the third party based on the extent of your activity of conveying the work, and under which the third party grants, to any of the parties who would receive the covered work from you, a discriminatory patent license (a) in connection with copies of the covered work conveyed by you (or copies made from those copies), or (b) primarily for and in connection with specific products or compilations that contain the covered work, unless you entered into that arrangement, or that patent license was granted, prior to 28 March 2007.\n";
	print "\n";
	print "   Nothing in this License shall be construed as excluding or limiting any implied license or other defenses to infringement that may otherwise be available to you under applicable patent law.\n";
	print "\n";
	print "   12. No Surrender of Others\' Freedom.\n";
	print "\n";
	print "   If conditions are imposed on you (whether by court order, agreement or otherwise) that contradict the conditions of this License, they do not excuse you from the conditions of this License.  If you cannot convey a covered work so as to satisfy simultaneously your obligations under this License and any other pertinent obligations, then as a consequence you may not convey it at all.  For example, if you agree to terms that obligate you to collect a royalty for further conveying from those to whom you convey the Program, the only way you could satisfy both those terms and this License would be to refrain entirely from conveying the Program.\n";
	print "\n";
	print "   13. Use with the GNU Affero General Public License.\n";
	print "\n";
	print "   Notwithstanding any other provision of this License, you have permission to link or combine any covered work with a work licensed under version 3 of the GNU Affero General Public License into a single combined work, and to convey the resulting work.  The terms of this License will continue to apply to the part which is the covered work, but the special requirements of the GNU Affero General Public License, section 13, concerning interaction through a network will apply to the combination as such.\n";
	print "\n";
	print "   14. Revised Versions of this License.\n";
	print "\n";
	print "   The Free Software Foundation may publish revised and/or new versions of the GNU General Public License from time to time.  Such new versions will be similar in spirit to the present version, but may differ in detail to address new problems or concerns.\n";
	print "\n";
	print "   Each version is given a distinguishing version number.  If the Program specifies that a certain numbered version of the GNU General Public License \"or any later version\" applies to it, you have the option of following the terms and conditions either of that numbered version or of any later version published by the Free Software Foundation.  If the Program does not specify a version number of the GNU General Public License, you may choose any version ever published by the Free Software Foundation.\n";
	print "\n";
	print "   If the Program specifies that a proxy can decide which future versions of the GNU General Public License can be used, that proxy\'s public statement of acceptance of a version permanently authorizes you to choose that version for the Program.\n";
	print "\n";
	print "   Later license versions may give you additional or different permissions.  However, no additional obligations are imposed on any author or copyright holder as a result of your choosing to follow a later version.\n";
	print "\n";
	print "   15. Disclaimer of Warranty.\n";
	print "\n";
	print "   THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM \"AS IS\" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.\n";
	print "\n";
	print "   16. Limitation of Liability.\n";
	print "\n";
	print "   IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.\n";
	print "\n";
	print "   17. Interpretation of Sections 15 and 16.\n";
	print "\n";
	print "   If the disclaimer of warranty and limitation of liability provided above cannot be given local legal effect according to their terms, reviewing courts shall apply local law that most closely approximates an absolute waiver of all civil liability in connection with the Program, unless a warranty or assumption of liability accompanies a copy of the Program in return for a fee.\n";
	print "\n";
	print "====================== END OF TERMS AND CONDITIONS ============================\n";
	print "\n";
	print "\n";
	print "To see the license type:\n";
	print "check_emc_clariion.pl --license | more\n";
	print "\n";
	exit( $states{UNKNOWN} );
	} # End sub print_license {

	
1;

__END__

=head1 NAME

check_emc_clariion.pl - Checks EMC SAN devices for NAGIOS.


=head1 USAGE:

=head2 Help:

check_emc_clariion.pl --help | more

=head2 Non-Secure:

check_emc_clariion.pl -H <host> -t <checktype>

=head2 Secure:

check_emc_clariion.pl -H <host> -u <user> -p <password> -t <checktype>

check_emc_clariion.pl -H <host> --secfilepath <secfilepath> -t <checktype>

=head2 Non-Secure vs Secure:

The newer versions of Navisphere Cli do NOT come with the Navicli command (Non-Secure) and hence you will need to provide -u and -p options so the Naviseccli can be used (Secure). Alternatively the --secfilepath option allows you to use a directory that has the security credentials encrypted in some files.

=head1 DESCRIPTION

B<check_emc_clariion.pl> receives the data from the emc devices via Navicli or Naviseccli if user and password are provided.


=head1 OPTIONS

=over 8

=item B<-h>

Display this helpmessage.

=item B<-H>

The hostname or ipaddress of the emc storage processor device.

=item B<-u>

The user used to connect to the emc storage processor device with Naviseccli.
You must use this option with -password !

=item B<-p>

The password of the user used to connect to the emc storage processor device with Naviseccli.

=item B<--secfilepath>

The path to the security files used to connect to the emc storage processor device with Naviseccli. You will need to make a directory first to store the files, and then run a command to create the security files in this directory.

The following example will create the directory /usr/local/nagios/libexec/check_emc_clariion_security_files for storing the security files.

You will need to change the username and password to match the credentials you use to connect to the emc storage processor.

Run these commands to create the security files:

  mkdir /usr/local/nagios/libexec/check_emc_clariion_security_files

  /opt/Navisphere/bin/naviseccli -secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -User readonly -Password AStrongPassword -Scope 0 -AddUserSecurity

=item B<-t>

The check type to execute:

=back

=head1 TYPES 

The following checks are currently available:

=head2 sp - check the status of the storage processors

=over 4

Returns an OK state if it gets Present, Valid or N/A from the SP, otherwise it will return a CRITICAL state

=back

=head2 sp_info - gets information on the storage processor

=over 4

This is an information gathering check so it will always return an OK state

=back

=head2 sp_cbt_busy - report the how busy the storage processor is and returns performance data for graphing purposes

=over 4

Returns WARNING or CRITICAL states based on how busy the SP is, if you supply these options

=back

=head2 disk - check the status of the physical disks attached in the DAE`s

=over 4

Returns a CRITICAL state if a Removed drive is detected, a WARNING state if it gets Equalizing, Rebuilding or less than one spare disk, otherwise it will return an OK state

=back

=head2 cache - check the status of the read and write cache

=over 4

Returns a CRITICAL state if Write cache or Write cache mirroring is not enabled, a WARNING state Read cache is not enabled, otherwise it will return an OK state

=back

=head2 cache_pdp - report the % of dirty pages in cache and returns performance data for graphing purposes

=over 4

This is an information gathering check so it will always return an OK state

=back

=head2 faults - Report the differents faults on the array

=over 4

Returns a CRITICAL state if it does not receive "The array is operating normally", otherwise it will return an OK state

=back

=head2 portstate - check the status of the FC ports on an SP

=over 4

Returns an OK state if the ports are UP and Online, otherwise it will return a CRITICAL state

=back

=head2 hbastate - check the connection state of the specified node

=over 4

Returns a CRITICAL state if the HBA is not logged in, otherwise it will return an OK state

=back

=head2 lun - check the status of a specific LUN 

=over 4

Returns a CRITICAL state if LUN is Faulted, a WARNING state if LUN is Transitional, otherwise it will return an OK state, also returns WARNING or CRITICAL states based on how much free space there is, if you supply these options

=back

=head2 raid_group - check the status of a specific RAID Group

=over 4

Returns a CRITICAL state if RAID Group is Invalid or Halted, a WARNING state if RAID Group is Busy, otherwise it will return an OK state, also returns WARNING or CRITICAL states based on how much free space there is, if you supply these options

=back

=head2 storage_pool - check the status of a specific Storage Pool

=over 4

Returns capacity usage information of the Storage Pool, also returns WARNING or CRITICAL states based on how much space is used, if you supply these options

=back

=head2 temp - Retrieves the inlet air temperature (Celcius by default) and returns performance data.

=over 4

Always returns an OK state, no warning or critical tested.

=back

=cut

=head3 TYPE OPTIONS

=head4 sp

=over 8

=item B<--sp>

The storageprocessor to check e.g. A or B 

=back

=head4 portstate

=over 8

=item B<--sp>

The storageprocessor to check e.g. A or B 

=item B<--port>
 
The port ID(s) to check e.g. 0 or 1 or 1,3,4

- if not specified, all ports are checked

- individual ports can be checked

- multiple ports can be checked by separating them with a comma

=back

=head4 hbastate

=over 8

=item B<--node>

The node name to check out of navisphere 

=item B<--paths>

The number of available FC Paths from the client to the SAN Infrastructure e.g. 2

=back

=head4 sp_cbt_busy

=over 8

=item B<--sp>

The storageprocessor to check e.g. A or B 

=item B<--warn>

The warning % value, this triggers if the SPs % Busy is greater than the warning value, this is a number only [don't include % symbol] (optional)

=item B<--crit>

The critical % value, this triggers if the SPs % Busy is greater than the critical value, this is a number only [don't include % symbol] (optional)

=back

=head4 lun

=over 8

=item B<--lun_id>

The LUN ID to check e.g. 1 or 36 (it is not possible to use the name of a LUN)

=item B<--warn>

The warning % value, this triggers if the LUNs % free space is less than the warning value, this is a number only [don't include % symbol] (optional)

=item B<--crit>

The critical % value, this triggers if the LUNs % free space is less than the critical value, this is a number only [don't include % symbol] (optional)

=back

=head4 raid_group

=over 8

=item B<--raid_group_id>

The RAID Group ID to check e.g. 0 or 13

=item B<--warn>

The warning % value, this triggers if the RAID Groups % free space is less than the warning value, this is a number only [don't include % symbol] (optional)

=item B<--crit>

The critical % value, this triggers if the RAID Groups % free space is less than the critical value, this is a number only [don't include % symbol] (optional)

=back

=head4 storage_pool

=over 8

=item B<--storage_pool_id>

The Storage Pool ID to check e.g. 0 or 13

=item B<--warn>

The warning % value, this triggers if the Storage Pools % used space exceeds the warning value, this is a number only [don't include % symbol] (optional)

=item B<--crit>

The critical % value, this triggers if the Storage Pools % used space exceeds the critical value, this is a number only [don't include % symbol] (optional)

=back

=head4 temp

=over 8

=item B<--temp_type>

The temperatere type returned can be (c)elcius or (f)ahrenheit.

=back

=cut

=head1 EXAMPLES

=head2 check the status of the storage processor SPA

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t sp --sp A

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t sp --sp A

=head2 get information on the storage processor SPA

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t sp_info

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t sp_info

=head2 get temperature

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t temp

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t temp

=head2 report the how busy the storage processor SPA is 

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t sp_cbt_busy --sp A

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t sp_cbt_busy --sp A

=head2 check the status of the physical disks

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t disk

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t disk

=head2 check the status of the physical disks with 2 disks as a minimum of spare disk

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t disk --minspare 2

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t disk --minspare 2

=head2 check the status of the cache

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t cache

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t cache

=head2 report the % of dirty pages in cache 

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t cache_pdp

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t cache_pdp

=head2 Report the differents faults on the array

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t faults

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t faults

=head2 check the status of all the FC ports on SPB 

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t portstate --sp B

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t portstate --sp B

=head2 check the status of the FC port 1 on SPB 

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t portstate --sp B --port 1

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t portstate --sp B --port 1

=head2 check the connection state of the specified node Windows Server 192.168.1.90

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t hbastate --node 192.168.1.90 --paths 4

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t hbastate --node 192.168.1.90 --paths 4

=head2 check the LUN with the ID 65

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t lun --lun_id 25

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t lun --lun_id 25

=head2 check the RAID Group with the ID 33, warning when free space is 30% of RAID Group and critical when free space is 10% of RAID Group

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t raid_group --raid_group_id 33 --warn 30 --crit 10

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t raid_group --raid_group_id 33 --warn 30 --crit 10

=head2 check the Storage Pool with the ID 33, warning when used space is 80% of Storage Pool and critical when used space is 90% of Storage Pool

check_emc_clariion.pl -H 192.168.1.88 -u readonly -p AStrongPassword -t storage_pool --storage_pool_id 33 --warn 80 --crit 90

check_emc_clariion.pl -H 192.168.1.88 --secfilepath /usr/local/nagios/libexec/check_emc_clariion_security_files -t storage_pool --storage_pool_id 33 --warn 80 --crit 90

=head1 VERSION

2014-05-06

=head1 AUTHOR

Originally written by Michael Streb (NETWAYS GmbH, 2008, http://www.netways.de).

Currently maintained by: Troy Lea <plugins@box293.com> Twitter: @Box293

Currently only updated when user submissions have been received, as I no longer have access to an EMC SAN!

See all my Nagios Projects on the Nagios Exchange: http://exchange.nagios.org/directory/Owner/Box293/1

Please report bugs to plugins@box293.com

=head2 To see the help type:

check_emc_clariion.pl --help | more

=head2 To see the license type:

check_emc_clariion.pl --license | more
