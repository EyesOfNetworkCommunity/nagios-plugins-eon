#!/usr/bin/perl

# author: Eric Schultz <eric.schultz@mentaljynx.com>
# adapted from: by Al Tobey
# what:    monitor various aspects of an IBM Bladecenter
# license: GPL - http://www.fsf.org/licenses/gpl.txt
#
# Todo:

use strict;
require 5.6.0;
use lib qw( /opt/nagios/libexec );
use utils qw(%ERRORS $TIMEOUT &print_revision &support &usage);
use Net::SNMP;
use Getopt::Long;
use vars qw/$exit $message $opt_version $opt_timeout $opt_help $opt_command $opt_host $opt_community $opt_verbose 
$opt_warning $opt_critical $opt_port $opt_mountpoint $snmp_session $PROGNAME $TIMEOUT $test_details $test_name $test_num/;

$PROGNAME      = "check_snmp_IBM_Bladecenter.pl";
$opt_verbose   = undef;
$opt_host      = undef;
$opt_community = 'public';
$opt_command   = undef;
$opt_warning   = undef;
$opt_critical  = undef;
$opt_port      = 161;
$message       = undef;
$exit          = 'OK';
$test_details  = undef;
$test_name     = undef;
$test_num      = 1;


# =========================================================================== #
# =====> MAIN
# =========================================================================== #
process_options();

alarm( $TIMEOUT ); # make sure we don't hang Nagios

my $snmp_error;
($snmp_session,$snmp_error) = Net::SNMP->session(
		-version => 'snmpv1',
		-hostname => $opt_host,
		-community => $opt_community,
		-port => $opt_port,
		);

my $oid;
my $oid_prefix = ".1.3.6.1.4.1."; #Enterprises
$oid_prefix .= "2.3.51.2."; #IBM Bladecenter

$|=1;

my ($data,$data_text)=('','');

if($test_name =~ m/^System-State$/i){
	$oid = "2.7.1.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data_text='UnKnown';
	$data_text='Normal' if $data eq 255;
	$data_text='Sytem Level Error' if $data eq 4;
	$data_text='Non-Critical Error' if $data eq 2;
	$data_text='Critical' if $data eq 0;
	}
elsif($test_name =~ m/^System-Temp-Ambient$/i){
	$oid = "2.1.5.1.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data_text=$data;
	$data_text =~ s/^\s*(.+?)\s*$/$1/;
	$data =~ s/^\s*(\d+)\.(\d+).*?$/$1$2/;
	}
elsif($test_name =~ m/^System-Temp-MM$/i){
	$oid = "2.1.1.2.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data_text=$data;
	$data_text =~ s/^\s*(.+?)\s*$/$1/;
	$data =~ s/^\s*(\d+)\.(\d+).*?$/$1$2/;
	}
elsif($test_name =~ m/^System-Ethernet-Backplane$/i){
	$oid = "2.5.2.18.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data_text='Check Fail';
	$data_text='OK' if $data eq 0;
	}
elsif($test_name =~ m/^System-Primary-Bus$/i){
	$oid = "2.5.2.17.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data_text='Check Fail';
	$data_text='OK' if $data eq 0;
	}
elsif($test_name =~ m/^Blowers-Count$/i){
	$oid = "2.5.2.73.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data =~ s/0//g;
	$data = length $data;
	$data_text=$data." Operational Blowers";
	}
elsif($test_name =~ m/^Blower-Speed$/i){
	$oid = "2.3.1.0";
	$oid = "2.3.2.0" if($test_num eq 2);
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data_text=$data;
	$data_text =~ s/^\s*(.+?)\s*$/$1/;
	$data =~ s/^\s*(\d+).*?$/$1/;
	}
elsif($test_name =~ m/^Switches-Count$/i){
	$oid = "2.5.2.113.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data =~ s/0//g;
	$data = length $data;
	$data_text=$data." Operational Switches";
	}
elsif($test_name =~ m/^Power-Count$/i){
	$oid = "2.5.2.89.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data =~ s/0//g;
	$data = length $data;
	$data_text=$data." Operational Power Modules";
	}
elsif($test_name =~ m/^Blades-Count$/i){
	$oid = "2.5.2.33.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$data =~ s/0//g;
	$data = length $data;
	$data_text=$data." Operational Blades";
	}
elsif($test_name =~ m/^Blades-Comm$/i){
	$oid = "2.5.2.33.0";
	$data = SNMP_getvalue($snmp_session,$oid_prefix.$oid);
	$oid = "2.5.2.49.0";
	if($data eq SNMP_getvalue($snmp_session,$oid_prefix.$oid)){ $data = 0; }
	else{ $data = 1; }
	$data_text='Check Fail';
	$data_text='OK' if $data eq 0;
	}

$snmp_session->close;
alarm( 0 ); # we're not going to hang after this.

# Parse our the thresholds. and set the result
my ($ow_low,$ow_high,$oc_low,$oc_high) = parse_thres($opt_warning,$opt_critical);
my $res = "OK";
$res = "WARNING" if( ($ow_low ne '' and $data < $ow_low )
			or ($ow_high ne '' and $data > $ow_high) );
$res = "CRITICAL" if( ($oc_low ne '' and $data < $oc_low )
			or ($oc_high ne '' and $data > $oc_high) );

#print "$ow_low:$ow_high $oc_low:$oc_high\n";
print "$res $test_name ($data) $data_text\n";
exit $ERRORS{$res};


# =========================================================================== #
# =====> Sub-Routines
# =========================================================================== #

sub parse_thres{
	my ($opt_warning,$opt_critical)=@_;
	my ($ow_low,$ow_high) = ('','');
	if($opt_warning){
		if($opt_warning =~ m/^(\d*?):(\d*?)$/){ ($ow_low,$ow_high) = ($1,$2); }
		elsif($opt_warning =~ m/^\d+$/){ ($ow_low,$ow_high)=(-1,$opt_warning); }
		}
	my ($oc_low,$oc_high) = ('','');
	if($opt_critical){
		if($opt_critical =~ m/^(\d*?):(\d*?)$/){ ($oc_low,$oc_high) = ($1,$2); }
		elsif($opt_critical =~ m/^\d+$/){ ($oc_low,$oc_high)=(-1,$opt_critical); }
		}
	return($ow_low,$ow_high,$oc_low,$oc_high);
	}

sub process_options {
	Getopt::Long::Configure( 'bundling' );
	GetOptions(
			'V'     => \$opt_version,       'version'     => \$opt_version,
			'v'     => \$opt_verbose,       'verbose'     => \$opt_verbose,
			'h'     => \$opt_help,          'help'        => \$opt_help,
			'H:s'   => \$opt_host,          'hostname:s'  => \$opt_host,
			'p:i'   => \$opt_port,          'port:i'      => \$opt_port,
			'C:s'   => \$opt_community,     'community:s' => \$opt_community,
			'c:s'   => \$opt_critical,          'critical:s'  => \$opt_critical,
			'w:s'   => \$opt_warning,          'warning:s'   => \$opt_warning,
			'o:i'   => \$TIMEOUT,           'timeout:i'   => \$TIMEOUT,
			'T:s'	=> \$test_details,	'test-help:s' => \$test_details,
			't:s'	=> \$test_name,		'test:s'      => \$test_name,
			'n:i'	=> \$test_num,		'ele-number:i'      => \$test_num
		  );
	if ( defined($opt_version) ) { local_print_revision(); }
	if ( defined($opt_verbose) ) { $SNMP::debugging = 1; }
	if ( !defined($opt_host) || defined($opt_help) 
		|| defined($test_details) || !defined($test_name) ) {
		
		print_help();
		if(defined($test_details)) { print_test_details($test_details); }
		exit $ERRORS{UNKNOWN};
		}
	}

sub print_test_details{
	my ($t_name) = @_;
	print "\n\nDETAILS FOR: $t_name\n";
	my %test_help;
	$test_help{'System-State'}=<<__END;
Returns the System State Code, Values are:
	255	ok
	4	soft-warning
	2	hard-warning
	0	ERROR
__END
	
	$test_help{'System-Temp-Ambient'}=<<__END;;
Returns the System Ambient Temperature as measured at the faceplate in degrees C x100.
	ex. 35.00 C = 3500
__END
        $test_help{'System-Temp-MM'}=<<__END;
Returns the System Management Module Temperature in degrees C x100.
	ex. 35.00 C = 3500
__END
        $test_help{'System-Ethernet-Backplane'}=<<__END;
Returns state of Ethernet Backplane.
	0	Ok
	1	Fail
__END
        $test_help{'System-Primary-Bus'}=<<__END;
Returns state of System Primary Bus.
	0	Ok
	1	Fail
__END
        $test_help{'Blowers-Count'}=<<__END;
Returns number of opperational Blowers as int.
	(generally 2)
__END
        $test_help{'Blower-Speed'}=<<__END;
Return the Percentage of max speed Blower is running at.
	(ex. 73 = 73% of Max)
__END
        $test_help{'Switches-Count'}=<<__END;
Return the Number of Active Switches.
	This is normally 2 or 4
__END
        $test_help{'Power-Count'}=<<__END;
Return the Number of Active Power Modules
	This is normally 2 or 4
__END
        $test_help{'Blades-Count'}=<<__END;
Return the Number of Blades Currently Plugged in.
__END
        $test_help{'Blades-Comm'}=<<__END;
Return the state of Blade Communication.
	(this basically enumerates the blades and compares it against the blades Communicating)
	0	Ok
	1	One or more Blades not communicating.
__END

	print $test_help{$t_name};
	}

sub local_print_revision { print_revision( $PROGNAME, '$Revision: 1.0 $ ' ); }

sub print_usage { print "Usage: $PROGNAME -H <host> -C <snmp_community> -t <test_name> [-n <ele-num>] [-w <low>,<high>] [-c <low>,<high>] [-o <timeout>] \n"; }

sub SNMP_getvalue{
	my ($snmp_session,$oid) = @_;

	my $res = $snmp_session->get_request(
			-varbindlist => [$oid]);
	
	if(!defined($res)){
		print "ERROR: ".$snmp_session->error."\n";
		exit 3;
		}
	
	return($res->{$oid});
	}

sub print_help {
	local_print_revision();
	print "Copyright (c) 2006 Eric Schultz <eric.schultz\@mentaljynx.com>\n\n",
	      "SNMP IBM Bladecenter plugin for Nagios\n\n";
	print_usage();
print <<EOT;
	-v, --verbose
		print extra debugging information
	-h, --help
		print this help message
	-H, --hostname=HOST
		name or IP address of host to check
	-C, --community=COMMUNITY NAME
		community name for the host's SNMP agent
	-w, --warning=INTEGER
		percent of disk used to generate WARNING state (Default: 99)
	-c, --critical=INTEGER
		percent of disk used to generate CRITICAL state (Default: 100)
	-T, --test-help=TEST NAME
		print Test Specific help for A Specific Test
	-t, --test=TEST NAME
		test to run
	-n, --ele-number=ELEMEMNT NUM
		Number of blade/blower/power module

POSSIBLE TESTS:
	System-State
	System-Temp-Ambient
	System-Temp-MM
	System-Ethernet-Backplane
	System-Primary-Bus	

	Blowers-Count
	Blower-Speed <1|2>

	Switches-Count

	Power-Count
	
	Blades-Count
	Blades-Comm

EOT

	}

sub verbose (@) {
	return if ( !defined($opt_verbose) );
	print @_;
	}
