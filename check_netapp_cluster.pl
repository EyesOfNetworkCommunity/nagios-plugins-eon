#!/usr/bin/perl -w
use strict;
use Net::SNMP;
use Getopt::Long;

# Script Version
my $Version='0.1';

# Nagios Specific
my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $oid_netapp_cf                        = ".1.3.6.1.4.1.789.1.2.3";
my $oid_netapp_cfSettings                = $oid_netapp_cf . ".1.0";
my $oid_netapp_cfState                   = $oid_netapp_cf . ".2.0";
my $oid_netapp_cfCannotTakeoverCause     = $oid_netapp_cf . ".3.0";
my $oid_netapp_cfPartnerStatus           = $oid_netapp_cf . ".4.0";
my $oid_netapp_cfPartnerLastStatusUpdate = $oid_netapp_cf . ".5.0";
my $oid_netapp_cfPartnerName             = $oid_netapp_cf . ".6.0";
my $oid_netapp_cfPartnerSysid            = $oid_netapp_cf . ".7.0";
my $oid_netapp_cfInterconnectStatus      = $oid_netapp_cf . ".8.0";

my $o_host      = undef;
my $o_community = undef;
my $o_port      = 161;
my $o_verb      = undef;
my $o_help      = undef;
my $o_version   = undef;
my $o_timeout   = undef;

sub print_usage {
    print "Usage: $0 -H <host> -C <snmp_community> -t <timeout>] \n";
}

sub help {
    print "\nSNMP NetApp Metrocluster state for Nagios version ",$Version,"\n";
    print "GPL licence, (c)2013 Guillaume ONA\n\n";
    print_usage();
    print <<EOT;
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-t, --timeout=timeout
   SNMP Timeout
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub p_version { print "$0 version : $Version\n"; }

sub check_options {
    Getopt::Long::Configure ("bundling");
        GetOptions(
            'v'     => \$o_verb,            'verbose'       => \$o_verb,
            'h'     => \$o_help,            'help'          => \$o_help,
            'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
            'p:i'   => \$o_port,            'port:i'        => \$o_port,
            'C:s'   => \$o_community,       'community:s'   => \$o_community,
            'V'     => \$o_version,         'version'       => \$o_version,
            't:i'   => \$o_timeout,         'timeout'       => \$o_timeout
        );
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined ($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
}

###########
check_options();

# Check gobal timeout if snmp screws up
if ( ! defined ($o_timeout) ) {
  $o_timeout = 5;
  verb("Default timeout 5");
} else {
  verb("Timeout : $o_timeout");
}

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# SNMPv2c Login
verb("SNMP v2c login");
my ($session, $error) = Net::SNMP->session(
    -hostname  => $o_host,
    -version   => 2,
    -community => $o_community,
    -port      => $o_port,
    -timeout   => $o_timeout
);

if (!defined($session)) {
    printf("ERROR opening session: %s.\n", $error);
    exit $ERRORS{"UNKNOWN"};
}

my $resultat = $session->get_table(
    Baseoid => $oid_netapp_cf
);

$session->close;

if (!defined($resultat)) {
   printf("ERROR: Description table : %s.\n", $session->error);
   #$session->close;
   exit $ERRORS{"UNKNOWN"};
}

foreach my $key ( keys %$resultat) {
    verb("OID : $key, Desc : $$resultat{$key}");
}

my $cfSettings                = $$resultat{$oid_netapp_cfSettings};
my $cfState                   = $$resultat{$oid_netapp_cfState};
my $cfCannotTakeoverCause     = $$resultat{$oid_netapp_cfCannotTakeoverCause};
my $cfPartnerStatus           = $$resultat{$oid_netapp_cfPartnerStatus};
my $cfPartnerLastStatusUpdate = $$resultat{$oid_netapp_cfPartnerLastStatusUpdate};
my $cfPartnerName             = $$resultat{$oid_netapp_cfPartnerName};
my $cfPartnerSysid            = $$resultat{$oid_netapp_cfPartnerSysid};
my $cfInterconnectStatus      = $$resultat{$oid_netapp_cfInterconnectStatus};

verb("$cfSettings - $cfState - $cfCannotTakeoverCause - $cfPartnerStatus - $cfPartnerLastStatusUpdate - $cfPartnerName - $cfPartnerSysid - $cfInterconnectStatus");

if ( $cfSettings eq 1 ) {
    print "Cluster is not configured\n";
    exit $ERRORS{"UNKNOWN"};
} elsif ( $cfState eq 1 or $cfSettings eq 5 ) {
    print "Node is declared dead by cluster.\n";
    exit $ERRORS{"CRITICAL"};
} elsif ( $cfPartnerStatus eq 1 or $cfPartnerStatus eq 3 ) {
    print "Partner Status is dead or maybeDown.\n";
    exit $ERRORS{"CRITICAL"};
} elsif ( $cfInterconnectStatus eq 1 ) {
    print "Interconnection isn't present.\n";
    exit $ERRORS{"CRITICAL"};
} elsif ( $cfInterconnectStatus eq 2 ) {
    print "Interconnection is down.\n";
    exit $ERRORS{"CRITICAL"};
} elsif ( $cfSettings eq 3 or $cfState eq 3 ) {
    print "Cluster cannot takeover\n";
    exit $ERRORS{"WARNING"};
} elsif ( $cfInterconnectStatus eq 3 ) {
    print "Cluster interconnect partially failed.\n";
    exit $ERRORS{"WARNING"};
} elsif ( $cfSettings eq 2 and $cfState eq 2 and $cfCannotTakeoverCause eq 1 and $cfPartnerStatus eq 2 and $cfInterconnectStatus eq 4) {
    print "Cluster status is OK\n";
    exit $ERRORS{"OK"};
}

print "Unknown output";
exit $ERRORS{"UNKNOWN"};
