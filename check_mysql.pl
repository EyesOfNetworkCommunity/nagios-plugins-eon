#!/usr/bin/perl -w
#
#  __ __ _______ ___ ___ _______ 
# |__|__|    ___|   |   |    ___|
# |  |  |    ___|\     /|    ___|
# |__|__|_______| |___| |_______|
#
# $Id: check_mysql.pl 45 2007-10-04 13:51:14Z mariusr@D.ETHZ.CH $
# $Date: 2007-10-04 15:51:14 +0200 (Thu, 04 Oct 2007) $
# $Author: mariusr@D.ETHZ.CH $
# $URL: https://svn.isg.inf.ethz.ch/svn/nagios-plugins/trunk/MySQL/check_mysql.pl $
#
#
# check_mysql.pl - nagios plugin
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
use lib "/usr/lib/nagios/plugins" ;
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use DBI;

use Getopt::Long;
Getopt::Long::Configure('bundling');

my $PROGNAME = "check_mysql";
my $VERSION  = "v1.1";

sub print_help ();
sub usage ();
sub process_arguments ();

my $status;

my $state = "UNKNOWN";
my $out  = "";
my $perfdata = "";
my $crit = "";
my $warn = "";

my $hostname; 
my $username;
my $password;
my $port;
my $database;

my $opt_s ;
my $opt_w ;
my $opt_c ;
my $opt_d ;

my $opt_o ;

my $timeout;
my $opt_V ;
my $opt_h ;

my %values;

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
     print ("ERROR: No response from mysql (alarm timeout)\n");
     exit $ERRORS{"UNKNOWN"};
};

#Option checking
$status = process_arguments();
if ($status != 0)
{
	print_help() ;
	exit $ERRORS{'OK'};
}

#Start Check
alarm($timeout);

my $dsn = "DBI:mysql:hostname=$hostname;";
if ( $port ) { $dsn .= "port=$port;"; }
if ( $database ) { $dsn .= "database=$database;"; }

my $dbh = DBI->connect($dsn,$username,$password, { PrintError => 0 } );
if (!$dbh) {
    print "CRITICAL - Unable to connect to mysql://$username\@$hostname/$database - $DBI::errstr\n"; 
    exit $ERRORS{"CRITICAL"};   
}

# Fetch Version
my $sth=$dbh->prepare("SELECT VERSION()");
if (!$sth->execute()) {
    print "CRITICAL - Unable to execute 'SELECT VERSION()' on mysql://$username\@$hostname/$database - $DBI::errstr\n";
    exit $ERRORS{"CRITICAL"};
}            
my ($mysql_version)=$sth->fetchrow_array();
$sth->finish();

# Get Status
if ( $opt_o ) {
    $sth=$dbh->prepare("SHOW STATUS");
} else {
    $sth=$dbh->prepare("SHOW GLOBAL STATUS");
}
if (!$sth->execute()) {
    print "CRITICAL - Unable to execute 'SHOW STATUS' on on mysql://$username\@$hostname/$database - $DBI::errstr\n";
    exit $ERRORS{"CRITICAL"};
}
while (my ($key,$value)=$sth->fetchrow_array()) {
    $key =~ tr/[A-Z]/[a-z]/ ;
    $values{$key} = $value; 
}
$sth->finish();

# Disconnect from the database.
$dbh->disconnect();

#End Check
alarm(0);

$state = "OK";

if ( $opt_s ) {
    my @arr_s = split( /,/ , lc $opt_s );
    my @arr_w = split( /,/ , lc $opt_w );
    my @arr_c = split( /,/ , lc $opt_c );
    
    for (my $i=0; $i < @arr_s; $i++) {
        if ($arr_w[$i] < $arr_c[$i] ) {
            if ($values{$arr_s[$i]} > $arr_c[$i]) {
                $crit .= " " . $arr_s[$i] . ": " . $values{$arr_s[$i]};
                $state = "CRITICAL";
            } elsif ($values{$arr_s[$i]} > $arr_w[$i]) {
                $warn .= " " . $arr_s[$i] . ": " . $values{$arr_s[$i]};
                $state = "WARNING" if ($state ne "CRITICAL")
            }
        } else {
            if ($values{$arr_s[$i]} < $arr_c[$i]) {
                $crit .= " " . $arr_s[$i] . ": " . $values{$arr_s[$i]};
                $state = "CRITICAL";
            } elsif ($values{$arr_s[$i]} < $arr_w[$i]) {
                $warn .= " " . $arr_s[$i] . ": " . $values{$arr_s[$i]};
                $state = "WARNING" if ($state ne "CRITICAL");
            }
        }
        print "$i:" . $arr_s[$i] .": " . $values{$arr_s[$i]} . " (" . $arr_w[$i] ."/" . $arr_c[$i] .")\n";
    }
}

$out  = "$state - $mysql_version";
$out .= " Critical:$crit" if $crit;
$out .= " Warning:$warn" if $warn;

foreach (split( /,/ , lc $opt_d )) {
    $perfdata .= " $_=" . $values{$_};
}

print "$out|$perfdata\n";
exit $ERRORS{$state};


sub usage (){
        printf "\nMissing arguments!\n";
        printf "\n";
        printf "$PROGNAME [-H <hostname>]\n";
        printf "Copyright (C) 2007 Marius Rieder <marius.rieder\@inf.ethz.ch>\n";
        printf "\n\n";
        support();
        exit $ERRORS{"UNKNOWN"};
}

sub print_help (){
	printf "$PROGNAME plugin for Nagios check if connecting to mysql is possible,\n";
	printf "check SHOW STATUS values and print perdata.\n";
	printf "\nUsage:\n";
	printf "   -H (--hostname)   Hostname, Default: localhost\n";
	printf "   -u (--username)   Username, Default: mysql\n";
	printf "   -p (--password)   Password, Default: none\n";
	printf "   -P (--port)       Port, Default: 3306\n";
	printf "   -D (--database)   Database, Default: none\n";
	
	printf "   -s (--status)     Status values to check\n";
	printf "   -w (--warning)    Warning threshold\n";
	printf "   -c (--critical)   Critical threshold\n";
	printf "   -d (--perfdata)   Status values to print as perfdata\n";
	
	printf "   -o (--old)        Use MySQL pre 5.0 Syntax.\n";
	
	printf "   -t (--timeout)    seconds before the plugin times out (default=$TIMEOUT)\n";
	printf "   -V (--version)    Plugin version\n";
	printf "   -h (--help)       usage help \n\n";
	print_revision($PROGNAME, $VERSION);
}

sub process_arguments() {
	$status = GetOptions(
	   "H=s" => \$hostname, "hostname=s" => \$hostname,
	   "u=s" => \$username, "username=s" => \$username,
	   "p=s" => \$password, "password=s" => \$password,
	   "P=i" => \$port,     "port=i"     => \$port,
	   "D=s" => \$database, "database=s" => \$database,
	   
	   "s=s" => \$opt_s,    "status=s"   => \$opt_s,
	   "w=s" => \$opt_w,    "warning=s"  => \$opt_w,
	   "c=s" => \$opt_c,    "critical=s" => \$opt_c,
	   "d=s" => \$opt_d,    "perfdata=s" => \$opt_d,
	   
	   "o"   => \$opt_o,    "old"        => \$opt_o,
	   
	   "t=i" => \$timeout,  "timeout=i"  => \$timeout,
	   "V"   => \$opt_V,    "version"    => \$opt_V,
	   "h"   => \$opt_h,    "help"       => \$opt_h,
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

	unless ( defined $hostname ) {
	   $hostname = 'localhost';
	}

	unless ( defined $username ) {
	   $username = 'mysql';
	}

	unless ( defined $password ) {
	   $password = '';
	}

	unless ( defined $port ) {
	   $port = 3306;
	}

	unless ( defined $database ) {
	   $database = '';
	}
	
	return 0;
}