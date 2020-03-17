#!/usr/bin/perl
#
# Josh Yost
# written: 07.14.06
# updated: 06.05.07
#
# 	Use the output of snmpget hrSystemDate.0 to create warning/critical
# signals to Nagios w/ the help of Time::Local and localtime().
#
# LICENSE
#   Distributed freely w/ no license &  w/ absolutely no warranty of any kind =)
#
# BUGS & PATCHES
# 	mailto: joshyost@gmail.com
# 
# VERSIONS
# 1.0.5 
# 	- switched to Getopt::Long
# 	- all non-zero snmpget exits are UNKNOWN, bad usage is UNKNOWN
# 	- added SNMPv3 options
# 	- expanded help a bit, expanded debug output
# 1.0.4
# 	- using utils.pm (took a while...); re-directing STDERR to STDOUT on syscalls
# 1.0.3
# 	- re-wrote some code for cleanliness & (hopefully) efficiency
# 	- changed usage handling

use warnings;
use strict;
use File::Basename;
use Getopt::Long;
use Time::Local;
use lib "/usr/lib64/nagios/plugins";
use utils qw ( %ERRORS $TIMEOUT );

our $snmpget = '/usr/bin/snmpget';
our $exe     = basename $0;
our $vers    = '1.0.5';

#########################88### Functions ###################################
sub usage{
  print "Usage: $exe [-dhV] -H <host> -C <community> | -u <user>\n",
  ' ' x length("Usage: $exe "), "[-n <secs>][-v 1|2c|3][-a MD5|SHA]\n",
  ' ' x length("Usage: $exe "), "[-A <authpass>][-x DES|AES][-X <privpass>]\n",
  ' ' x length("Usage: $exe "), "[-e <secengine>][-E <conengine][-N <context>]\n";
  print "Try '--help' for more information.\n";
  exit $ERRORS{'UNKNOWN'};
}

sub HELP{
  print "$exe\t\t$vers\n",
        "\n\tCheck the system time on a host against the localhost's time using\n",
	"net-snmp's snmpget.\n",
        "\n\tThis plugin returns a critical state if the target has drifted\n",
        "more than 10 times your allowed number of drift seconds, and it returns \n",
	"a warning state for anything in between (for example, if you allow 60\n",
	"seconds of deviation, a warning will be returned if the target differs\n",
	"by 61 - 600 seconds and critical if more than 600).\n",
	"\nOPTIONS\n",
        "  -a,--authproto MD5|SHA\n",       "     Set the SNMPv3 auth protocol (defaults to MD5)\n",
        "  -A,--authpass <arg>\n",          "     Set the SNMPv3 auth passphrase\n",
        "  -C,--community <arg>\n",         "     Set the SNMP v1|v2c community string\n",
        "  -d,--debug\n",                   "     Show debugging output\n",
        "  -e,--secengine <arg>\n",         "     Set the SNMPv3 security engine ID\n",
        "  -E,--conengine <arg>\n",         "     Set the SNMPv3 context engine ID\n",
        "  -h,--help\n",                    "     Show this help information\n",
        "  -H,--host <host[:port]>\n",      "     Set the target host (& port optionally)\n",
        "  -n,--num <secs>\n",              "     The amount of drift allowed in seconds (defaults to 120)\n",
        "  -N,--context <arg>\n",           "     Set the SNMP context name\n",
        "  -t,--timeout <arg>\n",           "     Set the timeout value in seconds\n",
        "  -v,--snmpversion 1|2c|3\n",      "     Set the SNMP version (defaults to 1)\n",
        "  -V,--version\n",                 "     Show version information\n",
        "  -u,--username <arg>\n",          "     Set the SNMPv3 username\n",
        "  -x,--privproto DES|AES\n",       "     Set the SNMPv3 priv protocol (defaults to DES)\n",
        "  -X,--privpass <arg>\n",          "     Set the SNMPv3 privacy passphrase\n",
        "\nCAVEATS\n",
        " - This script depends on having net-snmp's snmpget installed.\n",
        " - The executable path is hard-coded to '/usr/bin/snmpget.' Please edit the\n",
        "    '\$snmpget' variable near the top of the script for your environment.\n",
        " - You may also need to change the 'use lib' path to utils.pm for your system\n",
	"    (make sure you use an absolute path!!)\n",
	"\nEXAMPLES\n",
	"  \$ $exe -H host1 -C public\n",
	"  \$ $exe -H host2 -n 30 -u MD5User -A \"My Passphrase\"\n";

  exit $ERRORS{'OK'};
}

sub VERS{
  print "$exe\t\t$vers\n";
  exit $ERRORS{'OK'};
}

$SIG{ALRM} = sub { print "ERROR - Global timeout exceeded\n"; exit $ERRORS{'UNKNOWN'} };

###### Variables
Getopt::Long::Configure("bundling");
my %opts;
GetOptions(\%opts, 'authproto|a=s','authpass|A=s',   'community|C=s','debug|d',
                   'secengine|e=s','conengine|E=s',  'help|h',       'host|H=s',
		   'num|n=i',      'context|N=s',    'snmpversion|v=s', 'timeout|t=i',
		   'version|V',    'username|u=s',   'privproto|x=s','privpass|X=s') || &usage();

&HELP()  if defined($opts{help});
&VERS()  if defined($opts{version});

my $aproto   = ($opts{authproto} || 'MD5');
my $aphrase  =  $opts{authpass}  if defined ($opts{authpass});
my $pass     =  $opts{community} if defined ($opts{community});
my $DEBUG    = defined ($opts{debug});
my $dev      =  $opts{device}    if defined ($opts{device});
my $sengine  =  $opts{secengine} if defined ($opts{secengine});
my $cengine  =  $opts{conengine} if defined ($opts{conengine});
my $host     =  $opts{host}      if defined ($opts{host});
my $diff     = ($opts{num} || 120);			# number of seconds
my $context  =  $opts{context}   if defined ($opts{context});
my $snmpvers = ($opts{snmpversion} || '1');
my $timeout  = ($opts{timeout} || $TIMEOUT);
my $user     =  $opts{username}  if defined ($opts{username});
my $pproto   = ($opts{privproto} || 'DES');
my $pphrase  =  $opts{privpass}  if defined ($opts{privpass});

#### sanity checksy
if (!(defined($host) && (defined($pass) || defined($user)))){
  print "ERROR - At least -H and either -C or -u must be defined.\n";
  &usage();
}
if (! -x $snmpget){
  print "ERROR - $snmpget not found. Please edit the script for your environment.\n";
  exit $ERRORS{'UNKNOWN'};
}
if ($diff < 0 || $timeout < 0){
  print "ERROR - are you serious? The argument to -n and -t must be greater than 0 ...\n";
  exit $ERRORS{'UNKNOWN'};
}
&usage() if !(($aproto eq 'MD5' || $aproto eq 'SHA') && ($pproto eq 'DES' || $pproto eq 'AES'));
&usage() if !($snmpvers eq '1' || $snmpvers eq '2c' || $snmpvers eq '3');
&usage() if (@ARGV);

if (defined($user)) { $snmpvers = '3' }

#### Prepare System Call
my $syscall;
if ($snmpvers eq '3' && defined($user)){
  if (defined($pphrase)){
    if (!defined($aphrase)){
      print "ERROR - auth passphrase is not defined.\n";
      exit $ERRORS{'UNKNOWN'};
    }
    print "debug >> using SNMPv3 authPriv\n" if $DEBUG;
    $syscall = "$snmpget -v${snmpvers} -u $user -a $aproto -A \"$aphrase\" -x $pproto -X \"$pphrase\" -l authPriv";
  }
  elsif (defined($aphrase)){
    print "debug >> using SNMPv3 authNoPriv\n" if $DEBUG;
    $syscall = "$snmpget -v${snmpvers} -u $user -a $aproto -A \"$aphrase\" -l authNoPriv";
  }
  else{
    print "debug >> using SNMPv3 noAuthNoPriv\n" if $DEBUG;
    $syscall = "$snmpget -v${snmpvers} -u $user -l noAuthNoPriv";
  }
  $syscall .= " -n \"$context\"" if defined($context);
  $syscall .= " -e $sengine" if defined($sengine);
  $syscall .= " -E $cengine" if defined($cengine);
}
elsif ($snmpvers eq '1' || $snmpvers eq '2c'){
  print "debug >> using SNMPv$snmpvers\n" if $DEBUG;
  $syscall = "$snmpget -v${snmpvers} -c \"$pass\"";
}
else{
  print "ERROR - SNMPv3 requires at least the '-u' option.\n";
  &usage();
}

#### Actual syscall
# .1.3.6.1.2.1.25.1.2.0 = hrSystemDate.0
alarm $timeout;
my $oid    = '.1.3.6.1.2.1.25.1.2.0'; 

print "debug >> syscall - $syscall $host $oid 2>&1\n" if $DEBUG;

my $output = `$syscall $host $oid 2>&1`;
my $state  = $?;

print "debug >> output - |$output|","debug >> state : $state\n" if $DEBUG;

alarm 0;
if ($state != 0){
	print $output;
	exit $ERRORS{'UNKNOWN'};
}
else{
  # STRING: 2006-7-19,18:16:28.0,-5:0 
  if ($output =~ /STRING\s*:\s*(\d\d\d\d)-(\d+)-(\d+),(\d+):(\d+):(\d{1,2})/){
    my $ctime = localtime();
    my ($t_epoch, $l_epoch) = (timelocal($6,$5,$4,$3,$2-1,$1-1900),time);
    my $t_ctime = sprintf "%02d-%02d-%d, %02d:%02d:%02d",$2,$3,$1,$4,$5,$6;
    my $abs_time  = abs($l_epoch - $t_epoch);
	  
    if ($DEBUG){
      print "debug >>\n",
            "  sec:\t$6\n  min:\t$5\n  hr:\t$4\n  day:\t$3\n  mon:\t",$2-1," ($2)\n  yr:\t",$1-1900, " ($1)\n",
            "debug >> localhost time     : $ctime\n",
            "debug >> localhost epoch    : $l_epoch\n",
	    "debug >> target epoch       : $t_epoch\n",
            "debug >> allowed difference : $diff sec\tactual diff: $abs_time sec\n",
            "--\n";
    } 
	
    # Test epoch times
    if ($abs_time > ($diff*10)){
      print "CRITICAL - System time is off by $abs_time sec ($t_ctime).\n";
      exit $ERRORS{'CRITICAL'};
    }
    elsif ($abs_time > $diff){
      print "WARNING - System time is off by $abs_time sec ($t_ctime).\n";
      exit $ERRORS{'WARNING'};
    }
    else{
      print "System Time OK - $t_ctime\n";
      exit $ERRORS{'OK'};
    }
  }
  # No match on the RE
  else{
    print "UNKNOWN - snmpget returned unknown output: $output\n";
    exit $ERRORS{'UNKNOWN'};
  }
}

