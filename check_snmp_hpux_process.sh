#!/bin/bash

usage() {
echo "Usage :check_snmp_hpuxi_process.sh
        -H Hostname to check
	-C Community SNMP
	-p process to check
        -w Warning (means maximun number of running process) 
        -c Critical (means minimum number of running process)"
exit 2
}

if [ "${10}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-p"`" ]; then PROCESS="`echo ${i} | cut -c 3-`"; if [ ! -n ${PROCESS} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done

if [ ! -d /tmp/tmp-internal ]; then mkdir -p /tmp/tmp-internal; fi
TMPDIR="`mktemp -d /tmp/tmp-internal/hpux-internal.XXXXXXXX`"


snmpwalk -v 1 -c $COMMUNITY $HOSTTARGET -O 0qv .1.3.6.1.4.1.11.2.3.1.4.2.1.22 | sed -e 's: "$:":g' > $TMPDIR/snmp_process.txt

if [ "`cat $TMPDIR/snmp_process.txt | head -1`" = "" ]; then 
	echo "CRITICAL: Interogation HPUX impossible."
	rm -rf ${TMPDIR}
	exit 2
fi

LOAD="`cat $TMPDIR/snmp_process.txt | grep "${PROCESS}" | wc -l`"
LIST="`cat $TMPDIR/snmp_process.txt | grep "${PROCESS}" | sed -e 's:"::g' | tr '\n' ';'`"

if [ $LOAD -lt $CRITICAL ]; then
	echo "CRITICAL: less than $CRITICAL process running:$LOAD  :$LIST"
	rm -rf ${TMPDIR}	
	exit 2
fi
if [ $LOAD -gt $WARNING ]; then
	echo "WARNING: More then $WARNING process are currently running: $LOAD   :$LIST"
	rm -rf ${TMPDIR}
	exit 1
fi
echo "OK: $LOAD number of $PROCESS running.  :$LIST"
rm -rf ${TMPDIR}
exit 0
