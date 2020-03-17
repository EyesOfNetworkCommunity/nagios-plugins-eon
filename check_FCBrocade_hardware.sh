#!/bin/sh

# ========================================================================================
# Brocade Fibre Channel Hardware monitor plugin for Nagios
# 
# Written by         	: Steve Bosek (steve.bosek@ephris.net)
# Release               : 1.1
# Creation date		: 25 January 2008
# Revision date         : 5 December 2008
# Package               : DTB Plugins
# Description           : Nagios plugin to monitor Brocade Fibre Channel hardware with SNMP. 
#                         You must have SW-MIB from Brocade Communications Systems.
#
#                         Status Results:
#                         1 unknown
#                         2 faulty
#                         3 below-min
#                         4 nominal
#                         5 above-max
#                         6 absent
#                         For Temperature, valid values include 3 (below-min), 4 (nominal), and 5 (above-max).
#                         For Fan, valid values include 3 (below-min), 4 (nominal), and 6 (absent).
#                         For Power Supply, valid values include 2 (faulty), 4 (nominal), and 6 (absent).
#						
# Usage                 : ./check_FCBrocade_hardware.sh [-H | --hostname HOSTNAME] [-c | --community COMMUNITY ] [-h | --help] | [-v | --version]
# Supported Type        : Test with SilkWorm200E
# -----------------------------------------------------------------------------------------
#
# TODO :  - Add blacklist parameter [-b | --blacklist ] if necessary
#         - Add SNMP v2 and 3 if necessary
#         - Add Perfdata 
#		  
# =========================================================================================
#
# HISTORY :
#     Release	|     Date	|    Authors	| 	Description
# --------------+---------------+---------------+------------------------------------------
# 1.0		|   25.01.2008 |  Steve Bosek	|	Creation
#	1.1	|	05.12.2008	|	Steve Bosek	| Add Script Header
# =========================================================================================


# Nagios return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Plugin variable description
PROGNAME=$(basename $0)
RELEASE="Revision 1.1"
AUTHOR="(c) 2008 Steve Bosek (steve.bosek@ephris.net)"

# Functions plugin usage
print_release() {
    echo "$RELEASE $AUTHOR"
}

print_usage() {
	echo ""
	echo "$PROGNAME $RELEASE - Brocade Hardware monitor"
	echo ""
	echo "Usage: $PROGNAME [-H | --hostname HOSTNAME] | [-c | --community COMMUNITY ] | [-h | --help] | [-v | --version]"
	echo ""
	echo "		-h  Show this page"
	echo "		-v  Plugin Version"
	echo "    -H  IP or Hostname of Brocade Fiber Channel"
	echo "    -c  SNMP Community"
  echo ""
}

print_help() {
		print_usage
        echo ""
        print_release $PROGNAME $RELEASE
        echo ""
        echo ""
		exit 0
}

# Make sure the correct number of command line arguments have been supplied
if [ $# -lt 2 ]; then
    print_usage
    exit $STATE_UNKNOWN
fi

# Grab the command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            print_help
            exit $STATE_OK
            ;;
        -v | --version)
                print_release
                exit $STATE_OK
                ;;
        -H | --hostname)
                shift
                HOSTNAME=$1
                ;;
        -c | --community)
               shift
               COMMUNITY=$1
               ;;
        *)  echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
        esac
shift
done

TYPE=$(snmpwalk -v 1 -c $COMMUNITY $HOSTNAME SNMPv2-SMI::mib-2.47.1.1.1.1.2.1 | sed "s/.*STRING:\(.*\)$/\1/")
if [ $? == 1 ]; then
    echo "UNKNOWN - Could not connect to SNMP server $hostname.";
    exit $STATE_UNKNOWN;
fi

NBR_INDEX=$(snmpwalk -v 1 -c $COMMUNITY $HOSTNAME .1.3.6.1.4.1.1588.2.1.1.1.1.22.1.1 | wc -l )
i=1

while [ $i -le $NBR_INDEX ]; do
        SENSOR_VALUE=$(snmpwalk -v 1 -c $COMMUNITY $HOSTNAME .1.3.6.1.4.1.1588.2.1.1.1.1.22.1.4.$i | sed "s/.*INTEGER:\(.*\)$/\1/"| sed "s/ //g")
        SENSOR_STATUS=$(snmpwalk -v 1 -c $COMMUNITY $HOSTNAME .1.3.6.1.4.1.1588.2.1.1.1.1.22.1.3.$i | sed "s/.*INTEGER:\(.*\)$/\1/")
        SENSOR_INFO=$(snmpwalk -v 1 -c $COMMUNITY $HOSTNAME .1.3.6.1.4.1.1588.2.1.1.1.1.22.1.5.$i | sed "s/.*STRING:\(.*\)$/\1/" | sed "s/\"/\:/g" | sed "s/\://g"| sed "s/ //g")
        SENSOR_TYPE=$(snmpwalk -v 1 -c $COMMUNITY $HOSTNAME .1.3.6.1.4.1.1588.2.1.1.1.1.22.1.2.$i | sed "s/.*INTEGER:\(.*\)$/\1/")
        
        if [ $SENSOR_TYPE -eq 1 ]; then 
                SENSOR_TYPE="C"
        elif [ $SENSOR_TYPE -eq 2 ]; then
                SENSOR_TYPE="RPM"
        else
                SENSOR_TYPE=""
        fi


        case `echo $SENSOR_STATUS` in
                1) array=( ${array[@]} ${SENSOR_INFO}=${SENSOR_VALUE}${SENSOR_TYPE}, )
                   perfdata=( ${perfdata[@]}${SENSOR_VALUE}";" )
                ;;
                2) fault_array=( ${array[@]} ${SENSOR_INFO}=${SENSOR_VALUE}${SENSOR_TYPE}, "status=faulty" )
                   perfdata=( ${perfdata[@]}${SENSOR_VALUE}";" )
                ;;
                3) warn_array=( ${array[@]} ${SENSOR_INFO}=${SENSOR_VALUE}${SENSOR_TYPE}, "status=below-min" )
                   perfdata=( ${perfdata[@]}${SENSOR_VALUE}";" )  
                ;;
                4) array=( ${array[@]} ${SENSOR_INFO}=${SENSOR_VALUE}${SENSOR_TYPE}, )
                   perfdata=( ${perfdata[@]}${SENSOR_VALUE}";" )  
                ;;
                5) warn_array=( ${array[@]} ${SENSOR_INFO}=${SENSOR_VALUE}${SENSOR_TYPE}, "status=above-max" )
                   perfdata=( ${perfdata[@]}${SENSOR_VALUE}";" )
                ;;
                6) fault_array=( ${array[@]} ${SENSOR_INFO}=${SENSOR_VALUE}${SENSOR_TYPE}, "status=absent"  )
                   perfdata=( ${perfdata[@]}${SENSOR_VALUE}";" )
                ;;
        esac
let $[ i += 1 ]
done



if [ ${#fault_array[@]} != 0 ] ; then
    echo "HARDWARE CRITICAL : "${fault_array[@]}"|"${perfdata[@]}
    exit $STATE_CRITICAL
elif [ ${#warn_array[@]} != 0 ] ; then
     echo "HARDWARE WARNING : "${warn_array[@]}"|"${perfdata[@]}  
     exit $STATE_CRITICAL
else
    echo "HARDWARE OK : "${array[@]}"|"${perfdata[@]}
    exit $STATE_OK
fi







