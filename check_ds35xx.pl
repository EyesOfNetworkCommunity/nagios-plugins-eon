#!/usr/bin/perl -w

# author:  Rafał Frühling < rafamiga at gmail com >
# what:    monitor various aspects of an IBM ds35xx storage enclosure
# license: GPL - http://www.fsf.org/licenses/gpl.txt

# Based on a great 4x00 family check by Thomas S. Iversen <zensonic@zensonic.dk>
# Originally tested with SM 10.77 and DS3512 (Firmware version: 07.77.20.00)
# Patched for SM 10.83 and updated DS3500 series firmware

# Other "known good" compatible storage systems, user-confimed:
# DS 3400 (Firmware version: 07.35.53.00) SM version 10.84
# DS 3200
# [v1.5] "With this patch check_ds35xx also works on DS3200, DS4700 and
# DS4800 with the various (old) levels of firmware and StorageManager that
# we currently have installed. We are only using the out-of-band mode.

# REVISION HISTORY:

# v1.0a - bug-fix release
# v1.0b - fixed a bug with when using a hostname -- SMcli does not need "-H"
#       to contact the defined hostname.  Thanks to Oliver Hanesse for
#       pointing it out.
# v1.1 - make "Battery learning" system_status just a WARNING, not a CRITICAL
#       error; list tests run only in verbose mode [2012-01-12 rafamiga]
# v1.1a - get rid of curlies from plugin output as they confuse nagios.
#       Bug discovered by Asq [2012-01-13 rafamiga]
# v1.2 - make "Battery maintenance charging" system_status just a WARNING,
#       not a CRITICAL error [2012-01-25 rafamiga]
# v1.3 - added patches for 10.83 firmware and preffered path check, both by
#       Ian Clancy <ian.  clancy@ valeo dot com> THANKS!; made "SFPs
#       Detected" check optional -- for SAS-only enclosures (various error
#       reports); made "Host Interface Board" check optional ("Not Present"
#       reported); done some cleanup and error reporting [2013-01-03
#       rafamiga]
# v1.4 - added support for DS 3400 (it reports "Power-Fan Canisters" instead
#       of CRUs/FRUs); Steven Wood < steven at ikoro.  com > reported a typo
#       in known test list, corrected, thanks!; small additions to help text
#       [2013-02-14 rafamiga]
# v1.5 - a patch from Niklas Edmundsson < Niklas. Edmundsson at hpc2n. umu
#       .se > TACK SÅ MYCKET! BUGFIX: forgot to actually parse the "--binary"
#       command line argument; BUGFIX: don't misparse "Controller A link
#       status:" etc. as "Status:" in drive channel check; BUGFIX: fix
#       battery detection string to work with DS 3200; FEATURE: added stats
#       on what's detected, output as long text (ie. visible if you click on
#       the check to get to the "Service State Information" screen)
#       [2013-04-12 rafamiga]
# v1.6 - a patch from for 10.86 firmware by Ian Clancy <ian.  clancy@ valeo 
#       dot com> and Niklas Edmundsson < Niklas. Edmundsson at hpc2n. umu
#       # .se > and a patch for 07.84.44 firmware in the DS3500 with 
#       Enhanced FlashCopy features by Maciej Bogucki <macbogucki as gmail. 
#       com>. The script continue to work with DS3400 and Dell MD3660 
#       arrays running the 10.84 firmware. [2014-02-27 mbogucki]
# v1.6a - added non-standard (DSTEST_ALL) test category, mainly to
#       accomodate additional tests (consistency_groups_status,
#       consistency_groups_status,
#       consistency_groups_member_logical_drives_status and
#       repository_logical_drives_status) added by Maciej Bogucki in 1.6;
#       just add "-t all" to the command line. [2014-02-28 rafamiga]
  
# NOTES:

# [Debian] You need to install nagios-plugins-basic package to get it
# working, obviously!  Make sure SM debs are installed -- smclient and
# smruntime. Usually it's done by installing SM to some directory and then
# using "alien" utility to convert RPMs to DEBs. It worked for me without a
# glitch.

# TODO:

# * anonymise --raw output [for error reporting]
# * make optional checks really optional, now "Host Interface Board: Not
# Present" is not reported as an error because I made it optional check,
# but maybe it should be...
#

use strict;
require 5.6.0;
use lib '/usr/lib64/nagios/plugins';
use lib '/usr/lib/nagios/plugins';
use utils qw(%ERRORS $TIMEOUT &print_revision &support &usage);
use Getopt::Long;
use vars qw/$exit $opt_version $opt_timeout $opt_help $opt_command $opt_host $opt_verbose $res
$test_name $opt_sanname $opt_binary $PROGNAME $TIMEOUT $opt_enclosure_name $sudo/;

my @tests=();
my $PROGNAME      = "check_IBM_ds35xx.pl";
#$opt_binary    = '/opt/IBM_DS/client/SMcli';
my $ver           = '1.6a'; # *********** CHANGE ME! ***********
my $releaseyear	  = 2014;   # *********** CHECK! 8^) ***********
my $opt_binary    = '/usr/bin/SMcli'; # RPM SMcli location
my $sudo          = '/usr/bin/sudo';
my $opt_sanname   = undef;
my $opt_wwn       = undef;
my $opt_verbose   = undef;
my $opt_host      = undef;
my $opt_login     = undef;
my $opt_nosudo	  = undef;
my $opt_debug     = undef;
my $opt_raw       = undef;
my $opt_stdin     = undef;
my $TIMEOUT       = 100;
my $res           = "OK";
my %stats;

# NOTE: Sorry for the variables, use constant didn't work out with use
# strict...
my $DSTEST_ALL = 0;
my $DSTEST_STD = 1;

my $data;

# List of known tests that we can perform
my %known_tests = (
	"system_status" =>			[ \&system_status, $DSTEST_STD ],
	"controller_status" =>			[ \&controller_status, $DSTEST_STD ],
	"controller_asset_status" =>		[ \&ctrl_asset_status, $DSTEST_STD ],
	"array_status" =>			[ \&array_status, $DSTEST_STD ],
	"device_status" =>			[ \&device_status, $DSTEST_STD ],
	"logical_status" =>			[ \&logical_status, $DSTEST_STD ],
	"enhanced_flashcopy_status" =>		[ \&enhanced_flashcopy_status, $DSTEST_ALL ],
	"consistency_groups_status" =>		[ \&consistency_groups_status, $DSTEST_ALL ],
	"consistency_groups_member_logical_drives_status" => [ \&consistency_groups_member_logical_drives_status, $DSTEST_ALL ],
	"repository_logical_drives_status" =>	[ \&repository_logical_drives_status, $DSTEST_ALL ],
	"drivechannel_status" =>		[ \&dc_status, $DSTEST_STD ]
);
                                                                                        
sub update_res {
    my $res_ref=shift;
    my $data_ref=shift;
    my $r=shift;
    my $l=shift;

    # Trim line before we return status
    $l =~ s/^[\s]+//;
    $l =~ s/[\s]+$//;
    $l =~ s/[\s][\s]+/ /g;

    $$res_ref = $r if ($ERRORS{$r} > $ERRORS{$$res_ref});

    if(defined($$data_ref)) {
	$$data_ref .= ", $l" if(defined($l));
    } else {
	$$data_ref .= $l if(defined($l));
    }

#    print "data_ref='$$data_ref'\n" if ($opt_debug);
}

sub update_if_verbose {
    my $res_ref=shift;
    my $data_ref=shift;
    my $r=shift;
    my $l=shift;
    if(defined($opt_verbose)) {
	&update_res($res_ref, $data_ref, $r, $l);
    }
}

sub match_data {
    my $lines_ref=shift;
    my $match_start=shift;
    my $match_end=shift;
    my $skip=shift;
    my $optional=shift||0;
    my $collecting_data=0;
    
    my @m=();
    
  LINE: foreach (@$lines_ref) {
      unless($collecting_data) {
	  next LINE unless( m/$match_start/);
	  $collecting_data=1;
      } else {
	  last LINE if( m/$match_end/);
      }
      
      if(defined($skip)) {
	  next LINE if ( m/$skip/);
      }
      push(@m,$_);
#      print "m[]='$_'\n" if ($opt_debug);
     }
    return @m;
}

sub system_status_helper {
    my $input_ref=shift;
    my $test_name=shift;
    my $regexp=shift;
    my $gres_ref=shift;
    my $gres_data=shift;
    my $fline;
    my $n = 0;
    my $optional = 0;

    my $local_res="OK";
    my $local_data;

    if ($regexp =~ /^\*/) {
        print "find_item_is_optional=yes\n" if ($opt_debug);
        $optional = 1;
        $regexp = substr($regexp,1);
    }

    print "find_item='$regexp'\n" if ($opt_debug);

    my @m=&match_data($input_ref,$regexp, "Detected",undef);

#    print "m_items=".scalar(@m)."\n" if ($opt_debug);

    if (scalar(@m)) # item(s) found
        {
        $fline=$m[0];
        $n=$1 if ($fline =~ /\s*([0-9]*)\s*$regexp/i);
        }
        
    if ($n eq 0 && !$optional) {
	&update_res(\$local_res,\$local_data, "WARNING",
	  "Could not parse number of elements detected: $regexp");
        }

    foreach my $line (@m) {
	if ($line =~ /status:/i && !($line =~ /optimal/i)) {
	    my $rlevel = "CRITICAL";
	    if ($line =~ /status:\s+Battery learning/) { $rlevel = "WARNING"; }
	    if ($line =~ /status:\s+Battery maintenance charging/) { $rlevel = "WARNING"; }
	    &update_res(\$local_res, \$local_data, $rlevel, $line);
	}
    }

    if($local_res ne "OK") {
	&update_res($gres_ref, $gres_data, $local_res, $local_data);
    }
}

sub system_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

# this changed in 10.83 firmware, reported by Ian Clancy <ian .clancy@ valeo dot com>
#    my @m=&match_data($input_ref,"^ENCLOSURES-----", "--------",undef);
    my @m=&match_data($input_ref,"ENCLOSURES-----", "--------",undef);

    # Watch all these parameters -- NOTE: * indicated an optional item, SFPs are not found on SAS (3400) systems
    my @list=(	"(Batteries|Battery Packs) Detected",
                "*SFPs Detected",
                "Power-Fan (CRUs|CRUs/FRUs|Canisters) Detected",
                "Power Supplies Detected",
                "Fans Detected",
                "Temperature Sensors Detected",
    );

    foreach my $regexp (@list) {
	&system_status_helper(\@m, $test_name, $regexp, \$local_res, \$local_data);
    }

    if ($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }
}

sub array_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"^ARRAYS-----", "--------",undef);

    # Find number of arrays.
    my $n = 0;

    foreach my $line (@m) {
	$n = $1 if ( $line=~/Number of arrays:\s*([^\s]*)/i );
    }

    if ($n eq 0) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not find number of arrays in 'array_status'");
	return;
    } else {
      print "Found $n array(s)\n" if ($opt_debug);
      $stats{'arrays'} = $n;
    }

    my $seen = 0;
    my $array_status;
    my $array_name = "?";

    foreach my $line (@m) {
	$array_name = $1 if( $line =~ /Name:\s*([^\s]*)/i );

	if( $line =~ /Status:\s*([^\s]*)/i ) {
	    $array_status = $1;
	    $seen++;

            print "array_name='$array_name' array_status='$array_status'\n" if ($opt_debug);

	    if ( !($array_status=~/optimal/i) ) {
		&update_res(\$local_res, \$local_data,
		  "CRITICAL", "One or more array(s) are not online (last seen: '$array_name')");
                $array_name = "??";
	    }
	}
    }

    if($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n arrays");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }

}

sub device_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"^DRIVES-----", "--------",undef);

    # Find number of logical.
    my $n = 0;

    foreach my $line (@m) {
	$n=$1 if($line=~/Number of drives:\s*([0-9]+)/i);
    }

    if ($n eq 0) {
      &update_res(\$local_res, \$local_data, "CRITICAL", "No physical drives found");
    } else {
      print "Found $n physical drive(s).\n" if ($opt_debug);
      $stats{'physical drives'} = $n;
    }

    if ($n lt 4) {
        &update_res(\$local_res, \$local_data, "WARNING", "Found only $n physical drive(s)");
    }

    my $seen = 0;
    my $drive_status;
    my $path_status;
    my $drive_enc = -2;
    my $drive_slot = -2;

    foreach (@m) {
	$drive_enc = $1 if ( m/Drive at Enclosure\s*([0-9]+)\s*,/i );
	$drive_slot = $1 if ( m/Drive at Enclosure[^,]+,\s*Slot ([0-9]+)/i );

	if( $_ =~ /Status:\s*([^\s]*)/i ) {
	    $drive_status = $1;
	    $seen++;

            print "drive_enc=$drive_enc drive_slot=$drive_slot drive_status='$drive_status'\n" if ($opt_debug);

	    if (!( $drive_status =~ /optimal/i)) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		"Drive at Enclosure $drive_enc, Slot $drive_slot not in Optimal state");
                $drive_enc = -1;
                $drive_slot = -1;
	    }
	}

# Drive path redundancy status was added in 10.83 firmware,
# Reported and patched by Ian Clancy <ian .clancy@ valeo dot com>
	if ($_ =~ /^\s+Drive path redundancy:\s*([^\s]*)/i) {
	    $path_status = $1;
	    print "drive_enc=$drive_enc drive_slot=$drive_slot path_status='$path_status'\n" if ($opt_debug);

	    if (!($path_status =~ /OK/i)) {
		&update_res(\$local_res, \$local_data, "WARNING",
		"Drive at Enclosure $drive_enc, Slot $drive_slot path redundancy state is $path_status");
            }
        }
    }

    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n physical drives");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }
}

sub ctrl_asset_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"^CONTROLLERS-----", "--------",undef);

    # Watch these parameters; ^* indicates optional
    my @list = (  "Cache Backup Device",
                  "Host Interface Board",
    );

    my @val_list = (  "Status:",
    );

    my $ctrl_enc = -2;
    my $ctrl_slot = -2;
    my @ctrl_asset;
    my $seek_val = undef;
    my $is_ok = 0;
    my $v;
    my $optional = 0;

    foreach my $line (@m) {
      $ctrl_enc = $1 if ( $line =~ m/Controller in Enclosure\s*([0-9]+)\s*,/i );
      $ctrl_slot = $1 if ( $line =~ m/Controller in Enclosure[^,]+,\s*Slot ([A-D]+)/i );

#      print "ctrl_enc='$ctrl_enc' ctrl_slot='$ctrl_slot'\n" if ($opt_debug);

      foreach my $l (@list) {
          if ($l =~ /^\*/) {
              print "find_asset_is_optional=yes, asset='$l'\n" if ($opt_debug);
              $optional = 1;
              $l = substr($l,1);
              }
        
        if ($line =~ m/$l/i) { # found asset
          print "asset_found=$l ctrl_enc=$ctrl_enc ctrl_slot=$ctrl_slot\n" if ($opt_debug);

          if (defined($seek_val)) { # we didn't find previous asset's value
            print "previous asset=$seek_val not found\n" if ($opt_debug);
            &update_res(\$local_res, \$local_data, "WARNING",
              "Could not find status for controller asset '$seek_val'");
            }

          $seek_val = $l;
          print "seek_val=$l\n" if ($opt_debug);
        }

      if (defined($seek_val)) {
        foreach my $s (@val_list) { # find status
#          print "s='$s' line='$line'\n" if ($opt_debug);
          if ( $line =~ m/$s\s*([^\s]+(\s+[^\s]+)?)/i ) { # found status
#            print "v1='$1' v2='$2'\n" if ($opt_debug);
            $v = $1; $is_ok = 0;
            
            $is_ok = 1 if ($v =~ m/up/i);
            $is_ok = 1 if ($v =~ m/optimal/i);

            # TODO: make conditional
            if ($v =~ m/not present/i) {
                $is_ok = 1;
                }

            print "asset=$seek_val s=$s status=$v is_ok=$is_ok\n" if ($opt_debug);

            if ($is_ok eq 0) {
                if (!$optional) {
                    &update_res(\$local_res, \$local_data, "CRITICAL",
                        "Controller $ctrl_enc/$ctrl_slot asset '$seek_val' state is invalid or unrecognised [$v]");
                } else {
                print "asset=$seek_val optional, not found" if ($opt_debug);
                $optional = 0;
                }
            } else {
              &update_res(\$local_res, \$local_data, "OK",
                "Controller $ctrl_enc/$ctrl_slot asset '$seek_val' is OK [$v]");
            }
            undef $seek_val; # stop seeking for status

          }
        } # foreach my s list
      } # if defined seek_val
    } # foreac my l list
  } # foreach m

  if($local_res eq "OK") {
    &update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
  } else {
    &update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
  }
}

sub controller_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"^CONTROLLERS-----", "--------",undef);

    # Find number of logical stuff.
    my $n = 0;
    
    foreach my $line (@m) {
	$n= $1 if ( $line =~ /Number of controllers:\s*([0-9]+)/i );
    }

    if ($n eq 0) {
      &update_res(\$local_res, \$local_data, "CRITICAL", "No controllers found (WTF?!)");
    } else {
      print "Found $n controller(s).\n" if ($opt_debug);
      $stats{'controllers'} = $n;
    }

    my $seen = 0;
    my $ctrl_status;
    my $ctrl_enc = -2;
    my $ctrl_slot = -2;
    my $ignore = undef;

    foreach (@m) {
        if ( m/Controller in Enclosure\s*([0-9]+),\s*Slot ([A-D])/i ) {
          $ctrl_enc = $1;
          $ctrl_slot = $2;
          undef $ignore;
        }

 	if ( ($_ =~ /Status:\s*([^\s]*)/i ) && !defined $ignore ) {
	    $ctrl_status = $1;
	    $seen++;
            $ignore = 1;

            print "ctrl_enc=$ctrl_enc ctrl_slot=$ctrl_slot ctrl_status='$ctrl_status'\n" if ($opt_debug);

	    if ( !( $ctrl_status =~ /online/i ) ) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		"Controller in Enclosure $ctrl_enc, Slot $ctrl_slot is not Online [$ctrl_status]");
                $ctrl_enc = -1;
                $ctrl_slot = -1;
	    }
	}
    }

    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n controllers");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Online");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }
}

sub logical_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"STANDARD LOGICAL DRIVES-----", "--------",undef);

    # Find number of logical stuff.
    my $n = 0;

    # it was "logical drives" but it matched "access logical drives" also
    foreach my $line (@m) {
	$n = $1 if($line=~/standard logical drives:\s*([0-9]+)/i);
    }

    if ($n eq 0) {
        &update_res(\$local_res, \$local_data, "WARNING", "No logical drives found");
    } else {
      print "Found $n standard logical drive(s).\n" if ($opt_debug);
      $stats{'logical drives'} = $n;
    }

    my $seen = 0;
    my $ldrive_status;
    my $ldrive_name = "?";
    my $ldrive_pref_owner;
    my $ldrive_current_owner;

    foreach (@m) {
	$ldrive_name = $1 if ( m/Logical Drive name:\s*([^\s]*)/i );

	if ($_ =~ /Logical Drive status:\s*([^\s]*)/i) {
	    $ldrive_status = $1;
	    $seen++;

            print "ldrive_name=$ldrive_name ldrive_status='$ldrive_status'\n" if ($opt_debug);

	    if ( !( $ldrive_status =~ /optimal/i ) ) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		  "Logical Drive '$ldrive_name' is not in Optimal state [$ldrive_status]");
                $ldrive_name = "??";
	    }
	}

	# Preferred owner checks added by Ian Clancy <ian. clancy@ valeo dot com>
	if ($_ =~ /Preferred owner:\s*(\S.+)$/i) {
	        $ldrive_pref_owner = $1;
	        print "ldrive_name=$ldrive_name ldrive_pref_owner='$ldrive_pref_owner'\n" if ($opt_debug);
        }

        if ($_ =~ /Current owner:\s*(\S.+)$/i) {
                $ldrive_current_owner = $1;
                print "ldrive_name=$ldrive_name ldrive_current_owner='$ldrive_current_owner'\n" if ($opt_debug);

                if (!($ldrive_pref_owner =~ /$ldrive_current_owner/i)) {
                    &update_res(\$local_res, \$local_data, "WARNING",
                    "Logical Drive '$ldrive_name' is not on it's preferred path: $ldrive_pref_owner");
            }
        }
    }

    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n logical drives");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }

}

sub enhanced_flashcopy_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"ENHANCED FLASHCOPY IMAGES-----", "--------",undef);

    # Find number of logical stuff.
    my $n = 0;

    foreach my $line (@m) {
        $n= $1 if ( $line =~ /Total Enhanced FlashCopy Images:\s*([0-9]+)/i );
    }

    if ($n eq 0) {
        &update_res(\$local_res, \$local_data, "WARNING", "No enhanced flashcopy images found");
    } else {
      print "Found $n enhanced flashcopy image(s).\n" if ($opt_debug);
      $stats{'enhanced flashcopy images'} = $n;
    }

    my $seen = 0;
    my $enhfc_status;
    my $enhfc_name = "?";

    foreach (@m) {
	$enhfc_name = $1 if ( m/Enhanced FlashCopy Image\s*([^\s]*)/i );

	if ($_ =~ /Status:\ \ \s*([^\s]*)/i) {
	    $enhfc_status = $1;
	    $seen++;

            print "enhfc_name=$enhfc_name enhfc_status='$enhfc_status'\n" if ($opt_debug);

	    if ( !( $enhfc_status =~ /optimal/i ) ) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		  "Enhanced FlashCopy Image '$enhfc_name' is not in Optimal state [$enhfc_status]");
                $enhfc_name = "??";
	    }
	}

    }

    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n enhanced flashcopy images");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }

}

sub consistency_groups_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"CONSISTENCY GROUPS-----", "--------",undef);

    # Find number of logical stuff.
    my $n = 0;

    foreach my $line (@m) {
        $n= $1 if ( $line =~ /Total Consistency Groups:\s*([0-9]+)/i );
    }

    if ($n eq 0) {
        &update_res(\$local_res, \$local_data, "WARNING", "No consistency groups found");
    } else {
      print "Found $n consistency group(s).\n" if ($opt_debug);
      $stats{'consistency groups'} = $n;
    }

    my $seen = 0;
    my $cg_status;
    my $cg_name = "?";

    foreach (@m) {
	$cg_name = $1 if ( m/Consistency Group\s*([^\s]*)/i );

	if ($_ =~ /Status:\ \ \s*([^\s]*)/i) {
	    $cg_status = $1;
	    $seen++;

            print "cg_name=$cg_name cg_status='$cg_status'\n" if ($opt_debug);

	    if ( !( $cg_status =~ /optimal/i ) ) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		  "Consistency Group '$cg_name' is not in Optimal state [$cg_status]");
                $cg_name = "??";
	    }
	}

    }

    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n consistency groups");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }

}

sub consistency_groups_member_logical_drives_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"CONSISTENCY GROUP MEMBER LOGICAL DRIVES-----", "--------",undef);

    # Find number of logical stuff.
    my $n = 0;

    foreach my $line (@m) {
        $n= $1 if ( $line =~ /Total Member Logical Drives:\s*([0-9]+)/i );
    }

    if ($n eq 0) {
        &update_res(\$local_res, \$local_data, "WARNING", "No consistency groups logical member drives found");
    } else {
      print "Found $n consistency groups logical member drive(s).\n" if ($opt_debug);
      $stats{'consistency groups member logical drives'} = $n;
    }

    my $seen = 0;
    my $cgmld_status;
    my $cgmld_name = "?";

    foreach (@m) {
	$cgmld_name = $1 if ( m/Member Logical Drive \"\s*([^\s]*)\"/i );
        

	if ($_ =~ /Status:\ \ \s*([^\s]*)/) {
	    $cgmld_status = $1;
	    $seen++;

            print "cgmld_name=$cgmld_name cgmld_status='$cgmld_status'\n" if ($opt_debug);

	    if ( !( $cgmld_status =~ /optimal/i ) ) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		  "Consistency Groups Member Logical Drive '$cgmld_name' is not in Optimal state [$cgmld_status]");
                $cgmld_name = "??";
	    }
	}

    }

    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n consistency groups member logical drive");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }

}

sub repository_logical_drives_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;

    my @m=&match_data($input_ref,"REPOSITORY LOGICAL DRIVES-----", "MAPPINGS",undef);

    # Find number of logical stuff.
    my $n = 0;

    foreach my $line (@m) {
        $n= $1 if ( $line =~ /Total Number of Repositories:\s*([0-9]+)/i );
    }

    if ($n eq 0) {
        &update_res(\$local_res, \$local_data, "WARNING", "No repository logical drives found");
    } else {
      print "Found $n repository logical drive(s).\n" if ($opt_debug);
      $stats{'repository logical drive'} = $n;
    }

    my $seen = 0;
    my $rld_status;
    my $rld_name = "?";

    foreach (@m) {
	$rld_name = $1 if ( m/Repository Logical Drive \"\s*([^\s]*)\"/i );
        

	if ($_ =~ /Status:\ \ \s*([^\s]*)/) {
	    $rld_status = $1;
	    $seen++;

            print "rld_name=$rld_name rld_status='$rld_status'\n" if ($opt_debug);

	    if ( !( $rld_status =~ /optimal/i ) ) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		  "Repository Logical Drive '$rld_name' is not in Optimal state [$rld_status]");
                $rld_name = "??";
	    }
	}

    }

    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n repository logical drives");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }

}

sub dc_status {
    my $input_ref=shift;
    my $test_name=shift;
    my $local_res="OK";
    my $local_data;
    my @dcs;
    my @m=&match_data($input_ref,"DRIVE CHANNELS-----", "--------",undef);

    # Find how many...
    my $n = 0;

    foreach my $line (@m) {
	if($line=~/DRIVE CHANNEL\s+([0-9]+)/i) {
	$n = $1;
	push(@dcs,$n);
	}
    }

    if ($n eq 0) {
        &update_res(\$local_res, \$local_data, "WARNING", "No drive channels found");
    } else {
      print "Found $n drive channel(s).\n" if ($opt_debug);
      $stats{'drive channels'} = $n;
    }

    my $seen = 0;
    my $dc_status;

    # Older DS's has a Status: line.
    foreach (@m) {
	if( $_ =~ /^\s*Status:\s*([^\s]*)/i ) {
	    $dc_status = $1;
            print "dc=$dcs[$seen] dc_status='$dc_status'\n" if ($opt_debug);

	    if ( !( $dc_status =~ /optimal/i ) ) {
		&update_res(\$local_res, \$local_data, "CRITICAL",
		  "Drive Channel $dcs[$seen] is not in Optimal state [$dc_status]");
	    }

            $seen++;
	}
    }

    # The Drive channels format is different in version 10.86. Looks for Link Status for the controller to be up
    if($seen == 0) {
       foreach (@m) {
           if(/^\sDETAILS\s$/i) {
               last;
           }
           if(/^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$/) {
               my $chn = $1;
               my $type = $2;
               my $astat = $3;
               my $bstat = $4;

               if($opt_debug) {
                   print "dc=$chn type=$type A=$astat B=$bstat\n";
               }

               $dc_status="$astat $bstat";
               if ( !( $dc_status =~ /up up/i ) ) {
                   &update_res(\$local_res, \$local_data, "CRITICAL",
                     "Drive Channel $dcs[$seen] is not in Optimal state [$dc_status]");
               }
               $seen++;

           }
       }
    }




    if ($seen ne $n) {
	&update_res(\$local_res, \$local_data, "WARNING", "Could not account for all $n drive channels");
    }

    if($local_res eq "OK") {
	&update_if_verbose(\$res, \$data, "OK", "$test_name: Optimal");
    } else {
	&update_res(\$res, \$data, $local_res, "$test_name: $local_res ($local_data)");
    }

}

############## MAIN LOOP ################

&process_options();

if (! -e $opt_binary && ! defined($opt_stdin)) {
    $res="CRITICAL";
    $data="Binary file $opt_binary not found.";
    &error_exit;
}

alarm( $TIMEOUT ); # make sure we don't hang Nagios

$|=1 if (defined($opt_verbose) || ($opt_debug));

my @input;
my $command;
my $username;
my $password;


if (defined($opt_nosudo)) {
    $command="$opt_binary";
} else {
    $command="$sudo $opt_binary";
}

# try read the username and password from the file
if (defined($opt_login)) {
    open(my $fh, '<:encoding(UTF-8)', $opt_login) or die "Could not open login file '$opt_login' $!";
    my @login_info =  <$fh>;  # Reads lines into array
    chomp @login_info;
    unless (scalar @login_info == 2) { die "Login file should only contain 2 lines "; }
    $username = $login_info[0];
    $password = $login_info[1];
}

$command .= " -n $opt_sanname" if(defined($opt_sanname));
$command .= " -w $opt_wwn" if(defined($opt_wwn));
$command .= " $opt_host" if(defined($opt_host));
$command .= " -p $password -R $username" if(defined($opt_login));
$command .= " -c \"show storagesubsystem profile;\"";

print "Execute: '$command'\n" if ($opt_debug);

if ($opt_stdin) {
    print "STDIN mode -- reading from <STDIN> instead of '$command'\n";
    open (DATA,"-") || die "ERROR: Could not read from STDIN -- no file piped?\n";
    } else {
    open(DATA,$command."|") || die "ERROR: Could not execute '$command'!\n";
    }

while(<DATA>) {
    chomp;
    push(@input,$_);
    print "$_\n" if ($opt_raw);
}

close(DATA);

my $rc=$? >> 8;
$|=1;

if($rc > 0) {
    $res="WARNING";
    $data="Could not execute $command. Maybe you lack sudo permissions in the sudoers file. Ie append 'nagios      ALL=NOPASSWD: $command' to the sudoers file";
    &error_exit;
}


alarm( 0 ); # we're not going to hang after this.

if(scalar(@input) <= 0) {
    $res = "CRITICAL";
    $data = "No input data from $opt_binary";
    &error_exit;
}

# Run the tests
my $test_name = '';

#print join("\n->",@tests);

foreach my $tn (@tests) {
#    print "tn='$tn' sub='$known_tests{$tn}[0]'\n";
    &{$known_tests{$tn}[0]}(\@input, $tn);
    $test_name .= ", $tn" if(!($test_name=~/all/i));
}

$test_name =~ s/^, //;

&error_exit;

# From http://nagios.sourceforge.net/docs/3_0/pluginapi.html:
# Plugin Output Spec
#
# At a minimum, plugins should return at least one of text output. Beginning
# with Nagios 3, plugins can optionally return multiple lines of output.
# Plugins may also return optional performance data that can be processed by
# external applications. The basic format for plugin output is shown below:
#
# TEXT OUTPUT | OPTIONAL PERFDATA
# LONG TEXT LINE 1
# LONG TEXT LINE 2
# ...
# LONG TEXT LINE N | PERFDATA LINE 2
# PERFDATA LINE 3
# ...
# PERFDATA LINE N 
#
sub error_exit {
    $data="" if(!defined($data));
    $test_name="" if(!defined($test_name));

    if(defined($opt_verbose)) {
      print "$res $test_name ($data)|\n";
    } else {
    # just the facts, ma'am
      print "$res $data|\n";
    }
 
    foreach (sort keys %stats) {
    	print "$_: $stats{$_}\n";
    }

    # Return total grand status.
    exit $ERRORS{$res};
}

sub process_options {
    Getopt::Long::Configure('bundling');
      GetOptions(
		 'V'     => \$opt_version,       'version'     => \$opt_version,
		 'v'     => \$opt_verbose,       'verbose'     => \$opt_verbose,
		 'h'     => \$opt_help,          'help'        => \$opt_help,
		 'H:s'   => \$opt_host,          'hostname:s'  => \$opt_host,
                 'L:s'   => \$opt_login,         'login:s'     => \$opt_login,
		 'n:s'   => \$opt_sanname,       'sanname:s'   => \$opt_sanname,
		 'w:s'   => \$opt_wwn,           'wwn:s'       => \$opt_wwn,
		                                 'no-sudo|nosudo' => \$opt_nosudo,
		 'o:i'   => \$TIMEOUT,           'timeout:i'   => \$TIMEOUT,
		 't:s'	 => \@tests,             'test:s'      => \@tests,
		                                 'debug'       => \$opt_debug,
		                                 'raw'         => \$opt_raw,
		                                 'stdin'       => \$opt_stdin,
                                                 'binary:s'	=> \$opt_binary,
		 );
      
      if (defined($opt_version)) { local_print_revision(); exit(255); }
      if (defined($opt_help)) { &print_help(); exit(255); }

      # no name nor WWN nor hostname given
      if (!defined($opt_sanname) && !defined($opt_wwn) && !defined($opt_host) ) {
          &print_help("ERROR: You need to supply either SAN name, eclosure WWN or hostname to run this check.");
          exit(255);
          }

      # name and WWN given
      if (defined($opt_sanname) && defined($opt_wwn)) {
          &print_help("ERROR: You need to supply either SAN name or eclosure WWN to run this check.");
          exit(255);
          }

      # check that the login file exists 
      if (defined($opt_login)) {
          unless (-e $opt_login) {
          &print_help("ERROR: Supplied login file does not exist or is not readable.");
          exit(255);
          }
      }

      if ((scalar(@tests) == 1) && ($tests[0] eq "all")) {
          @tests = ();
          foreach (sort keys %known_tests) { push (@tests,$_); }
	  $test_name = "all_known_tests";
      } elsif (scalar(@tests) > 0) {
	  my $wrong;

	  foreach my $test (@tests) {
	      $wrong .= ", $test" if(!defined($known_tests{$test}));
	  }

	  if (defined($wrong)) {
	      $wrong=~s/^, //;
	      &print_help("Error: unrecognised tests: '$wrong'.");
	      exit 1;
	  }
      }

      # If no tests are requested on the command line, run all tests
      if (scalar(@tests) <= 0) {
          foreach (sort keys %known_tests) {
            push (@tests,$_) if ($known_tests{$_}[1] == $DSTEST_STD);
          }
	  $test_name = "all_standard_tests";
      }
  }

sub local_print_revision { print_revision($PROGNAME, $ver); }

sub print_usage {
  print "Usage: $PROGNAME [-b <path_to_smcli>] [-H <host>] [-t <test_name>] [-n <san_name>|-w <wwn>] [-o <timeout>] [-v] [-h] [--no-sudo]\n";
}

sub print_help {
  my $help_msg = shift || "";

  if (length($help_msg)) { print $help_msg . "\n\n"; }
  local_print_revision();

  print "Copyright (c) $releaseyear Rafał Frühling < rafamiga at gmail com >.\n",
        "Based on DS4x00 plugin by Thomas S. Iversen.\n\n",
        "IBM DS35xx storage enclosure plugin for Nagios (known to work on 3400 and 3200 series enclosures).\n\n";
  print_usage();

  print <<EOT;
	-v, --verbose
		print extra debugging information
        -b, --binary=PATH
                path to SMCli binary. 
	-h, --help
		print this help message
        -o, --timeout=TIMEOUT
                timout value in seconds to let SMcli command finish.
	-n, --sanname=SANNAME
	        name of the san controller (check using "$opt_binary -d"; in-band monitoring)
	-w, --wwn=WWN
	        WWN of the storage subsystem (for in-band monitoring)
	-H, --hostname=HOST
		name or IP address of enclosure to check if doing out-of-band monitoring
        -L, --login=PATH
                path to the login file to access the array      
	-t, --test=TEST_NAME
		test to run, can be applied multiple times to run multiple tests
		NOTE: -t all runs _ALL_ the tests, including non-standard tests
        --no-sudo
                do not use sudo (for testing purposes only)
        --debug
                helps me develop, useless for others
        --raw
                display $opt_binary output, for debugging
        --stdin
                instead of running SM parse <STDIN> -- used for testing user-reported issues

NOTES:
        Switches -n and -w are mutually exclusive.
        If doing out-of-band monitoring, you may use switch -H only.        

        Requires IBM DS Storage Manager CLI ($opt_binary) version 10.77 or newer.
        
AVAILABLE TESTS:

EOT

  foreach my $test (sort keys %known_tests) {
    print "\t$test" . ($known_tests{$test}[1] != $DSTEST_STD ? " (*)" : "") . "\n";
  }

  print <<ENDNOTE

NOTE: (*) indicates non-standard test, run only on demand or when \"-t all\"
modifier is used. Default behaviour (when no "-t" switch is used) is to run
all the *standard* tests.

ENDNOTE

}

