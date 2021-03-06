#!/usr/bin/perl -w
#
# check_mysql_queries.pl - nagios plugin
#
#
# Copyright (C) 2007 Marius Rieder <marius.rieder@inf.ethz.ch>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

use POSIX;
use strict;
use lib "nagios/plugins" ;
use utils qw($TIMEOUT %ERRORS &print_revision &support);

use Getopt::Long;
Getopt::Long::Configure('bundling');

my $PROGNAME = "check_mysql_queries";
my $VERSION  = "v1.1";

my $tmp = "/tmp/mysql_queries";

sub print_help ();
sub usage ();
sub process_arguments ();
sub snmp_connect();

my $status;

my $timeout ;
my $state = "UNKNOWN";
my $answer = "";

my $hostname = ''; 
my $username;
my $password;

my $opt_h ;
my $opt_V ;
my $opt_c ;
my $opt_w ;

my %wanted = (
               "Com_delete"     => "delete", 
			   "Com_insert"     => "insert",
               "Com_select"     => "select", 
               "Com_update"     => "update",
               "Com_replace"    => "replace",
               "Qcache_hits"    => "cache_hits",
               "Uptime"         => "uptime",
               "Coms"           => "coms",
             );

my %delta = ();
my %ovalues = ();
my $coms = 0;

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
     print ("ERROR: No response from mysqladmin (alarm timeout)\n");
     exit $ERRORS{"UNKNOWN"};
};

#Option checking
$status = process_arguments();

if ($status != 0)
{
	print_help() ;
	exit $ERRORS{'OK'};
}

my $cmd = "/usr/bin/mysqladmin ";
if ($hostname) {
    $cmd .= "-h $hostname ";
}
if ($username) {
    $cmd .= "-u $username ";
}
if ($password) {
    $cmd .= "-p$password ";
}
$cmd .= "extended-status";

alarm($timeout);

if (open(TMP, "$tmp-$hostname")) {
    while (<TMP>) {
        my ($k, $v) = (m/(\w+).*?(\d+(?:\.\d+)?)/);
        next unless ($k);
        if (exists $wanted{$k} ) {
	       $ovalues{$k} = $v;
        }
    }
}

close(TMP);

open(CMD, "$cmd |")
  or die("Could not execute '$cmd': $!");

open(TMP, "> $tmp-$hostname")
  or die("Could write '$tmp-$hostname': $!");

while (<CMD>) {
    my ($k, $v) = (m/(\w+).*?(\d+(?:\.\d+)?)/);
    next unless ($k);
    if (exists $wanted{$k} ) {
        if (exists $ovalues{$k} ) {
            $delta{$k} = $v - $ovalues{$k};
        }
	    print TMP "$k:$v\n";
    }
    if ($k =~ /^Com_/) {
        $coms += $v;
    }
}

print TMP "Coms:$coms\n";

if (exists $ovalues{'Coms'} ) {
    $delta{'Coms'} = $coms - $ovalues{'Coms'};
}

close(CMD);
close(TMP);

alarm(0);

if (!exists $delta{'Uptime'} ) {
    $state = "UNKNOWN";
    print ("$state:Init value cache $tmp-$hostname\n");
    exit $ERRORS{$state};
}

if ($delta{'Uptime'} < 0) {
    $state = "UNKNOWN";
    print ("$state: MySQL restarted\n");
    exit $ERRORS{$state};
}

my $qps = $delta{'Coms'} / $delta{'Uptime'};

$state = "OK";
if ($qps >= $opt_w) { $state = "WARNING"; }
if ($qps >= $opt_c) { $state = "CRITICAL"; }

my $perfdata = sprintf("querys=%.1f", $qps);
while(my ($key, $value) = each(%delta)) {
    if ($key =~ /^Com_(.*)/) {
        $perfdata .= sprintf(" %s=%.1f", $1, ($value / $delta{'Uptime'}));
    }
}

print sprintf("$state: %.1f Queries per Secound.|$perfdata\n", $qps);
exit $ERRORS{$state};

sub usage (){
        printf "\nMissing arguments!\n";
        printf "\n";
        printf "check_mysql_queries -H <HOSTNAME>\n";
        printf "Copyright (C) 2007 Marius Rieder <marius.rieder\@inf.ethz.ch>\n";
        printf "\n\n";
        support();
        exit $ERRORS{"UNKNOWN"};
}

sub print_help (){
	printf "$PROGNAME plugin for Nagios check if connecting to mysql is possible,\n";
	printf "check and check querys.\n";
	printf "\nUsage:\n";
	printf "   -u (--username)   Username\n";
	printf "   -p (--password)   Password\n";
	printf "   -H (--hostname)   Hostname\n";
	printf "   -w (--warning)    Warning threshold\n";
	printf "   -c (--critical)   Critical threshold\n";
	printf "   -t (--timeout)    seconds before the plugin times out (default=$TIMEOUT)\n";
	printf "   -V (--version)    Plugin version\n";
	printf "   -h (--help)       usage help \n\n";
	print_revision($PROGNAME, $VERSION);
}

sub process_arguments() {
	$status = GetOptions(
	"V"   => \$opt_V, "version"    => \$opt_V,
	"h"   => \$opt_h, "help"       => \$opt_h,
	"u=s" => \$username, "username=s" => \$username,
	"p=s" => \$password, "password=s" => \$password,
	"H=s" => \$hostname, "hostname=s" => \$hostname,
	"w=i" => \$opt_w, "warning=i" => \$opt_w,
	"c=i" => \$opt_c, "critical=i" => \$opt_c,
	"t=i" => \$timeout,    "timeout=i" => \$timeout,
	);

	if ($status == 0){
		print_help() ;
		exit $ERRORS{'OK'};
	}

	if ($opt_V) {
		print_revision($PROGNAME, $VERSION);
		exit $ERRORS{'OK'};
	}

	if ($opt_h) {
		print_help();
		exit $ERRORS{'OK'};
	}

	unless (defined $timeout) {
	   $timeout = $TIMEOUT;
	}

	unless ( defined $username ) {
	   $username = 'root';
	}
	
	return 0;
}