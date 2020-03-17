#!/usr/bin/perl
#==========================================================================
# License: GPLv2
#==========================================================================
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
# GPL License: http://www.gnu.org/licenses/gpl.txt
#
#==========================================================================

#==========================================================================
# Version
#==========================================================================
my $VERSION = '0.4' ;
my $TEMPLATE_VERSION = '1.0.0' ;

#==========================================================================
# Modules
#==========================================================================
use strict ;
use lib '/srv/eyesofnetwork/nagios/plugins' ;
use utils qw /$TIMEOUT %ERRORS &print_revision &support/ ;
use Getopt::Long ;
&Getopt::Long::config('bundling') ;
use File::Basename qw/basename/ ;
use Carp ;
use POSIX qw/uname/ ;
use Data::Dumper ;

#==========================================================================
# Options
#==========================================================================
my $progname = basename($0) ;
my $help ;
my $version ;
my $verbose = 0 ;
my $oratab_file ;
my $oracle_sid ;
my $timeout = $TIMEOUT ;
my $regexp ;
my $eregexp ;
my $exclude ;

my $status = $ERRORS{'UNKNOWN'} ;

my ($oracle_home,$alert_log,$background_dump_dest) = undef ;

GetOptions(
	   'h'=> \$help,'help'=> \$help,
	   'V'=> \$version,'version'=> \$version,
	   'v+'=> \$verbose,'verbose+'=> \$verbose,
	   'F:s'=> \$oratab_file,'log_file:s'=> \$oratab_file,
	   'n:s'=> \$oracle_sid,'name:s'=> \$oracle_sid,
	   't:i'=> \$timeout,'timeout:i'=> \$timeout,
	   'r:s'=> \$regexp,'regexp:s'=> \$regexp,
	   'e:s'=> \$exclude,'exclude:s'=> \$exclude,
) ;

usage() if defined $help ;

version() if defined $version ;

unless ( defined $oracle_sid ) {
	print "$progname: ERROR no Oracle SID defined ! \n" ;
	exit $status;
}

unless ( defined $oratab_file ) {
	if ( -f "/etc/oratab" ) { $oratab_file = "/etc/oratab" } # En considérant que "/etc/oratab" prévaut sur tout autre
	elsif ( -f "/var/opt/oracle/oratab" ) { $oratab_file = "/var/opt/oracle/oratab" }
	else {
		print "$progname: ERROR no oratab found ! \n" ;
		exit $status;
	}
} elsif ( ! -f "$oratab_file" ) {
	print "$progname: ERROR no oratab found ! \n" ;
	exit $status;
}

$oracle_home = get_oracle_home($oracle_sid,$oratab_file) ;

if (-f "$oracle_home/dbs/spfile$oracle_sid.ora") {
	$background_dump_dest = get_background_dump_dest("$oracle_home/dbs/spfile$oracle_sid.ora") ;
} elsif (-f "$oracle_home/dbs/init$oracle_sid.ora") {
	$background_dump_dest = get_background_dump_dest("$oracle_home/dbs/init$oracle_sid.ora") ;
} else {
		print "$progname: ERROR no $oracle_home/dbs/spfile$oracle_sid.ora or $oracle_home/dbs/init$oracle_sid.ora found !\n" ;
		exit $status;
}

$alert_log = "$background_dump_dest/alert_$oracle_sid.log" ;

unless ( -f "$alert_log" ) {
	print "$progname: ERROR no $alert_log file found !\n" ;
	exit $status;
}

my @group = () ;
my $nombre_erreurs = 0 ;
my $derniere_erreur = undef ;

# get a date tag for today
my $today = localtime ;
$today =~ m/^(\S+\s+\S+\s+\d+)  # word (like Wed) followed by Mon and Day
		(\s+\d+:\d+:\d+\s+)   # the time - ignored
		(\d+)               # the year
	/x;
my $today_date_tag = $1 . ' ' .$3 ;

open (ALERT_LOG,"<$alert_log") ;

while (<ALERT_LOG>) {
	chomp($_);

	# make a date tag for the current line read
	my $log_date_tag ;
	if (m/^(\S+\s+\S+\s+\d+)  # word (like Wed) followed by Mon and Day
		(\s+\d+:\d+:\d+\s+)   # the time - ignored
		(\d+)               # the year
		/x) {

		$log_date_tag = $1 . ' ' . $3 if (defined $1 && defined $3) ;
		next if ($today_date_tag ne $log_date_tag);

		# Teste si les lignes enregistrées contiennent une erreur oracle
		unless ( 0 == scalar @group ) {
			unless ( 0 == scalar map /^ORA\-/, @group ) { # Remplace avantageusement la fonction check_group()
				$nombre_erreurs += 1 ;
				$derniere_erreur = join "\n", @group ; # Pour stockage du texte de la dernière erreur
			}
			@group = () ;
		}
		push @group, $_ ;
	} elsif ( 0 != scalar @group ) {
		push @group, $_ ;
	}
}

close ALERT_LOG ;

# Test du dernier groupe de lignes
unless ( 0 == scalar @group ) {
	unless ( 0 == scalar map /^ORA\-/, @group ) { # Remplace avantageusement la fonction check_group()
		$nombre_erreurs += 1 ;
		$derniere_erreur = join "\n", @group ; # Pour stockage du texte de la dernière erreur
	}
}
utf8::encode($derniere_erreur);
unless ( 0 == $nombre_erreurs ) {
	print "Number of alert log errors for $oracle_sid: $nombre_erreurs\n$derniere_erreur | 'Number of alert log errors'=$nombre_erreurs;0;0;0;1000\n" ;
	$status = $ERRORS{'WARNING'} ;
} else {
	print "Number of alert log errors for $oracle_sid: no error found today | 'Number of alert log errors'=0;0;0;0;1000\n" ;
	$status = $ERRORS{'OK'} ;
}
exit $status ;

#
# get_oracle_home - get the location of the alert log from the RDBMS
#
sub get_oracle_home
{
	my ($sid,$oratab) = @_;
	my ($orasid,$orahome,$oravalid) = undef;
	
	open(ORATAB,"< $oratab");
	while(<ORATAB>) {
		($orasid,$orahome,$oravalid) = split(/:/);
		if ( "$orasid+" eq "$sid+" ) { last; }
	}
	close ORATAB;
	return $orahome;
}  # end of get_alert

#
# get_background_dump_dest - get the location of the alert log from the RDBMS
#
sub get_background_dump_dest
{
	my $oraini = shift ;
	my $bd_dest = undef ;

	open(ORAINI,"< $oraini");
	while(<ORAINI>) {
		if (/^IFILE="([A-Za-z0-9_\/.]+)"/) {
			open(IFILE,"< $1");
			while(<IFILE>) {
				if (/^background_dump_dest\s*=\s*([A-Za-z0-9_\/.\']+)/) {
					$bd_dest = $1;
					last ; # On a trouvé le chemin dans IFILE , donc c'est fini !
				}
			}
			close IFILE ;
			last ; # On a trouvé dans IFILE, on ne parcourt plus ORAINI
		} elsif (/^(?:\*\.)?background_dump_dest\s*=\s*'?([A-Za-z0-9_\/.]+)'?/) {
			$bd_dest = $1;
			last ; # On a trouvé dans ORAINI, c'est fini !
                } elsif (/^(?:\*\.)?BACKGROUND_DUMP_DEST\s*=\s*'?([A-Za-z0-9_\/.]+)'?/) {
                        $bd_dest = $1;
                        last ; # On a trouvé dans ORAINI, c'est fini !
		} elsif (/^(?:\*\.)?diagnostic_dest\s*=\s*'?([A-Za-z0-9_\/.]+)'?/) {
			$bd_dest = $1."/diag/rdbms/".lc($oracle_sid)."/".$oracle_sid."/trace/";
			last ;
		}
	}
	close ORAINI ;
	return $bd_dest ;
}  # end of get_background_dump_dest

sub usage {
	copyright() ;
	print "
This plugin will check for '^ORA-' error messages of an oracle database instance.

Usage: $progname -n <sid> [-F <oratab file>] [-t <number>] [-e <pattern>] [-r <pattern>]
       $progname [-V|--version]
       $progname [-h|--help]
";
	print "
 -h, --help
    display this help
 -V, --version
    display the plugin version
 -v, --verbose
    not implemented yet.
 -F, --oratab_file=STRING
    the oracle databases table configuration file known as 'oratab'. By default: /etc/oratab.
 -n, --oracle_sid=STRING
    the Oracle SID
 -t, --timeout=INTEGER
    not implemented yet.
 -r, --regexp=STRING
    not implemented yet.
 -e, --exclude=STRING
    not implemented yet.
";

	exit $ERRORS{'UNKNOWN'};
}

sub version {
   copyright();
   print "
$progname $VERSION
";
   exit $ERRORS{"UNKNOWN"};
}

sub copyright {
   print "The nagios plugins come with ABSOLUTELY NO WARRANTY. You may redistribute
copies of the plugins under the terms of the GNU General Public License.
For more information about these matters, see the file named COPYING.\n";
}

