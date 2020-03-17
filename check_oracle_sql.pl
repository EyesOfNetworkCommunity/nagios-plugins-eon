#!/usr/bin/perl
#
#Ecrit par Pascal TROUVIN
#
#Historique
#date / auteur
#	commentaire
#
#12-JUL-2004/pascal TROUVIN
#	1st version
#17-MAR-2005/pascal TROUVIN
#	add --eval=perl_expression using function sql(sql_command)
#24-MAR-2005/pascal TROUVIN
#	reopen STDERR to STDOUT to let error message sent to stderr go back nagios
#19-APR-2005/pascal TROUVIN
#	set RC to 0 when pinging oracle server
#26-APR-2005/pascal TROUVIN
#	set RC to 0 when everything sounds good
#27-APR-2005/pascal TROUVIN
#	change ping timer from milli-seconds to seconds
#27-JUL-2005/pascal TROUVIN
#	add workaround of nagios '$' bug (add a trailing $ when found single $)
#25-OCt-2005/pascal TROUVIN
#	add error level control before dying (exit code)
#	let warning and critical thresholds be with decimal
#

use Getopt::Long;
use Pod::Usage;
use DBI;
use Time::HiRes qw(gettimeofday tv_interval );

$ENV{"ORACLE_HOME"} = "/usr/lib/oracle/10.1.0.2/client/lib/";
$ENV{"TNS_ADMIN"} = "/etc/oracle";

my $man = 0;
my $help = 0;
my $debug = 0;
my $USER='';
my $PASSWD='';
my $HOST='';
my $PORT=1521;
my $SID='';
my $WARNING,$CRITICAL;
my $PING=0;
my $EVAL='';

GetOptions(
	'help|?' => \$help, 
	man => \$man,
	'd|debug+' => \$debug,
	'U|user=s' => \$USER,
	'P|password=s' => \$PASSWD,
	'SID=s' => \$SID,
	'H|host=s' => \$HOST,
	'port=i' => \$PORT,
	'W|warning=s' => \$WARNING,
	'C|critical=s' => \$CRITICAL,
	'ping' => \$PING,
	'eval=s' => \$EVAL,
	) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# verif des arguments
#
$!=3;
die("Vous devez indiquer un HOST\n") if ! $HOST;
die("Vous devez indiquer un SID\n") if ! $SID;
die("Les arguments doivent être numériques\n") if ($WARNING && ! ($WARNING=~/^[0-9.]+$/)) || ($CRITICAL && ! ($CRITICAL=~/^[0-9.]+$/));
$retcode=-3; # 0=OK, 1=KO
$retmsg="";

open STDERR,">&STDOUT" || &stop("Unable to re-open stderr to stdout\n");

my $t0=[gettimeofday];

sub stop {
	my $msg=shift;
	my $errorlevel=shift;
	$errorlevel=3 if ! $errorlevel;

	$!=$errorlevel;
	die($msg);
}

$dbh=DBI->connect("dbi:Oracle:host=$HOST;sid=$SID;port=$PORT",$USER,$PASSWD) || &stop("Unable to open Oracle DB '$HOST:$PORT/$SID', $DBI::errstr\n",2);

if($PING){
	if($dbh->ping){
		$retmsg .= "ping OK";
		my $t=tv_interval($t0);
		#my $t=tv_interval($t0)*1000;
		$retcode=0;
		$retcode=2 if $CRITICAL && $retcode<2 && $t>$CRITICAL;
		$retcode=1 if $WARNING && $retcode<1 && $t>$WARNING;
	} else {
		$retmsg .= "$DBI::errmsg ";
		$retcode=3;
	}
} elsif($EVAL){
	my $ret;
	eval("\$ret=$EVAL");
	if($@){
		$retmsg .= "Invalid --eval($EVAL) : $@";
	} else {
		$retmsg .= $ret;
		if($CRITICAL || $WARNING){
			if($ret =~ /^[0-9\.,]+$/){
				$ret =~ s/,/./g;
				$retcode=2 if $CRITICAL && $retcode<2 && $ret>=$CRITICAL;
				$retcode=1 if $WARNING && $retcode<1 && $ret>=$WARNING;
			}
		}
		$retcode=0 if $retcode<0;
	}
} else {
	foreach $cmd (@ARGV){
		$cmd =~ s/\%24/\$/;
		$sth=$dbh->prepare($cmd);
		$sth->execute;
		while($rec=$sth->fetchrow_arrayref()){
			my $msg="";
			foreach $v (@$rec){
				print "$v " if $debug;
				$msg .= ($msg ? " ":"") . $v;
				if($CRITICAL || $WARNING){
					if($v =~ /^[0-9\.,]+$/){
						$v =~ s/,/./g;
						$retcode=2 if $CRITICAL && $retcode<2 && $v>$CRITICAL;
						$retcode=1 if $WARNING && $retcode<1 && $v>$WARNING;
					}
				}
			}
			print "\n" if $debug;
			$retmsg .= "[$msg] ";
		}
	}
	$retcode=0 if $retcode<0; # switch off unknown flag, everything seems ok
}

if($retcode<0){
	$retcode=3;
	$retmsg="Impossible d'exécuter la commande" if ! $retmsg;
}
print "OK - " if $retcode==0;
print "WARNING - " if $retcode==1;
print "CRITICAL - " if $retcode==2;
print "UNKNOWN - " if $retcode==3;
print "$retmsg Exec(".tv_interval($t0)."s)\n";

undef $sth;
$dbh->disconnect;
exit $retcode;

sub sql {
	my $sql_str=shift;
	my $sth=$dbh->prepare($sql_str);
	$sth->execute;
	my $ret=$sth->fetchrow_array();
	print "SQL($sql_str)->(",$sth->rows,") $ret\n" if $debug;
	return $ret;
}

__END__

=head1 NAME

check_oracle_sql.pl - Plugin Nagios - 

=head1 SYNOPSIS

check_oracle_sql.pl [options] arguments

Options:
--help
--man 
--debug
--user=username
--password=mot_de_passe
--host=nom_machine
--port=1521
--sid=SID_oracle
--ping
--eval=perl_command

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--debug>

Incrémente le mode de deboggage.

=item B<--user=utilisateur> B<-U utilisateur>

Indique le nom de l'utilisateur à utiliser.

=item B<--password=mot_de_passe>

Indique le mot de passe à utiliser

=item B<--host=machine> B<-H machine>

Indique la machine serveuse de base de données, on peut utiliser soit le nom soit son adresse IP.

=item B<--sid=SID>

Indique le SID de la base.

=item B<--port=1521>

Indique le port de connexion à utiliser.

=item B<--critical=seuil_critique> B<-C seuil_critique>

Indique le niveau du seuil critique en secondes.

=item B<--warning=seuil_warning> B<-W seuil_warning>

Indique le niveau du seuil warning en secondes.

=item B<--ping>

Va ouvrir le canal de communication avec la base Oracle puis passera seulement un ping (requete nulle).

Dans ce cas, les options --critique et --warning portent sur le temps d'exécution en milli-secondes.

=item B<--eval=perl_command>

Cette fonction évalue la commande 'perl_command'. Les requetes SQL sont faites via l'appel de fonction:  sql('sql...')

Ceci permet de tester des retours sql:

sql('select count(*) from fichier where code=1')>1

retournera CRITICAL si critical est positionné à 1.

=head1 ARGUMENTS

On indique en arguments les commandes SQL à passer aux serveurs.

Si vous avez indiqué un seuil, il sera tester sur les arguments numériques de vos requêtes.

=back

=head1 DESCRIPTION

B<check_oracle_sql.pl> va exécuter les requêtes SQL données en arguments de la ligne de commande.

exemple 1- Taux de remplissage de la base:


	./check_oracle_sql.pl -C 10 -H 172.20.1.193 --sid=TDEV -U system --password=manager "select a.TABLESPACE_NAME,round(((a.BYTES-b.BYTES)/a.BYTES)*100,2) percent_used from (select TABLESPACE_NAME,sum(BYTES) BYTES from dba_data_files group by TABLESPACE_NAME) a, (select TABLESPACE_NAME,sum(BYTES) BYTES from dba_free_space group by TABLESPACE_NAME) b where  a.TABLESPACE_NAME=b.TABLESPACE_NAME order by ((a.BYTES-b.BYTES)/a.BYTES) desc"


se qui donnera quelque chose comme:
	
	CRITICAL - TS_INDXTDEV 66,01, TS_DATATDEV 42,43, SYSTEM 29,7, TS_ANNULTDEV 1,36, TS_TOOLTDEV ,05, TS_TEMPTDEV 0,


exemple 2- temps de réponse ping:

	./check_oracle_sql.pl -C 1000 -H 172.20.1.193 --sid=TDEV -U system --password=manager --ping

se qui donnera quelque chose comme:

	OK - ping OK Exec(0.315825s)

ou

	CRITICAL - ping OK Exec(1.309584s)
	
=over 16

=cut

