#!/bin/ksh
# @(#) #=====================================================================#
# @(#) #
# @(#) # Script : emc_trespass.sh
# @(#) #
# @(#) # Auteur : ONA Guillaume (APX)
# @(#) # Version: 1.0
# @(#) # Date   : 28/06/2013
# @(#) #
# @(#) # Syntaxe: /srv/eyesofnetwork/nagios/plugins/emc_trespass.sh
# @(#) #
# @(#) # Check EMC Lun Trespass
# @(#) #
# @(#) #=====================================================================#

# Variables
HOST=""
OUT=""

# Nagios Exit Code
RESULT_OK=0
RESULT_WARNING=1
RESULT_ERROR=2
RESULT_UNKNOWN=3

# Default Exit Code
RETVAL=${RESULT_UNKNOWN}

# Usage
function help {
    echo "You must install Naviseccli first and add a user security
    emc_trespass.sh -h <hostname ou IP>"
    exit ${RESULT_UNKNOWN}
}

function check_connection {
    /opt/Navisphere/bin/naviseccli -h ${1} -secfilepath /home/nagios -Timeout 10 getagent >/dev/null 2>&1
    return ${?}
}

function check_all_luns_owner {
    CPT=$(/opt/Navisphere/bin/naviseccli -h ${1} -secfilepath /home/nagios getlun -owner | grep Current | sort -u | wc -l)
    if [[ ${CPT} -eq 1 ]] ; then
        return 2
    else
        return 1
    fi
}

# Check arguments
if [[ $# -ne 2 ]] ; then
    help
fi

# Parse arguments
while getopts h: arg; do
    case $arg in
        h)
            # Hostname ou IP
            HOST=${OPTARG}
        ;;
        *)
            help
        ;;
     esac
done

# Check connection
check_connection ${HOST}
if [[ ${?} -ne 0 ]] ; then
    echo "Check the connectivity with ${HOST}"
    exit ${RESULT_UNKNOWN}
fi

# Run
OUT=$(/opt/Navisphere/bin/naviseccli -h ${HOST} -secfilepath /home/nagios getlun -trespass -private -name | awk  ' /LOGICAL UNIT NUMBER/ { i=$4 } /Default Owner:/ { d=$4 } /Current owner:/ { c=$4 } /Name/ { n=$2 } /Is Private:/ { p=$3 ; if ( p = "NO" ) { if ( c != d) { print n " ("i") trespass (Default Owner: "d" - Current Owner: "c") /" } } }' )

# Check Output
if [[ -z ${OUT} ]] ; then
    echo "No Tresspass Lun"
    RETVAL=${RESULT_OK}
else
    check_all_luns_owner ${HOST}
    if [[ ${?} -eq 1 ]] ; then
        RETVAL=${RESULT_WARNING}
    else
        RETVAL=${RESULT_ERROR}
        OUT="All luns are on same controller"
    fi
    # Print result and remove last separator "/"
    echo ${OUT} | sed 's/\s\/$//g'
fi

exit ${RETVAL}