#!/usr/bin/perl -w
#
# check_mysql_threads.pl - nagios plugin
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

my $PROGNAME = "check_mysql_threads";
my $VERSION  = "v1.1";

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
               "Threads_created"     => "tot", 
			   "Threads_connected"   => "con",
               "Threads_running"     => "run",
             );

my %values = ();

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

open(CMD, "$cmd |")
  or die("Could not execute '$cmd': $!");

while (<CMD>) {
    my ($k, $v) = (m/(\w+).*?(\d+(?:\.\d+)?)/);
    next unless ($k);
    if (exists $wanted{$k} ) {
        $values{$k} = $v;
    }
}

close(CMD);

alarm(0);

$state = "OK";
if ($values{'Threads_running'} >= $opt_w) { $state = "WARNING"; }
if ($values{'Threads_running'} >= $opt_c) { $state = "CRITICAL"; }

my $perfdata = sprintf("tot=%d running=%d connected=%d",
                    $values{'Threads_created'},
                    $values{'Threads_running'},
                    $values{'Threads_connected'});

print sprintf("$state: %.d Threads Running.|$perfdata\n", $values{'Threads_running'});
exit $ERRORS{$state};

sub usage (){
        printf "\nMissing arguments!\n";
        printf "\n";
        printf "check_mysql_threads -H <HOSTNAME>\n";
        printf "Copyright (C) 2007 Marius Rieder <marius.rieder\@inf.ethz.ch>\n";
        printf "\n\n";
        support();
        exit $ERRORS{"UNKNOWN"};
}

sub print_help (){
	printf "$PROGNAME plugin for Nagios check if connecting to mysql is possible,\n";
	printf "check and check thread count.\n";
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