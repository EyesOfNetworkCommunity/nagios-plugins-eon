#!/bin/bash

LANG="en"

CURTIME="`date +%H:%M`"
CURDAY="`date +%a`"

CURHOUR="`echo $CURTIME | cut -d':' -f1`"
CURMINUTE="`echo $CURTIME | cut -d':' -f2`"

SERVICE=""
HOST=""

cd /srv/eyesofnetwork/nagios/plugins/Downtime

for i in `cat ./downtime_list.txt | grep -v "^#" | sed -e 's: ::g'`; do
	
	DAY="`echo $i | cut -d';' -f3`"
	TIME="`echo $i | cut -d';' -f4`"
	DURATION="`echo $i | cut -d';' -f5`"
	HOST="`echo $i | cut -d';' -f6`"
	SERVICE="`echo $i | cut -d';' -f7`"
	AUTHOR="`cat ./downtime_list.txt | grep -v "^#"  | grep "${HOST}"  | grep "${SERVICE}" | grep "${DAY}" | grep "${TIME}" | grep "${DURATION}" | cut -d';' -f1`"
	COMMENT="`cat ./downtime_list.txt | grep -v "^#"  | grep "${HOST}"  | grep "${SERVICE}" | grep "${DAY}" | grep "${TIME}" | grep "${DURATION}" | cut -d';' -f2`"

	if [ "${DAY}" = "*" ]; then
		DAY="Mon,Tue,Wed,Thu,Fri,Sat,Sun"
	fi

	if [ "${TIME}" = "*" ]; then
		HOUR="`echo $CURHOUR`"
		MINUTE="`echo $CURMINUTE`"
		HOUR_DURATION="00"
		MINUTE_DURATION="01"
	else
		HOUR="`echo ${TIME} | cut -d':' -f1`"	
		MINUTE="`echo ${TIME} | cut -d':' -f2`"	
	fi


	if [ "${DURATION}" = "*" ]; then
		HOUR="`echo $CURHOUR`"
		MINUTE="`echo $CURMINUTE`"
		DURATION="60"
	else
		HOUR_DURATION="`echo ${DURATION}  | cut -d':' -f1`"
		MINUTE_DURATION="`echo ${DURATION}  | cut -d':' -f2`"
		IN_MINUTE="`expr $HOUR_DURATION \* 3600`"
		IN_SEC="`expr $MINUTE_DURATION \* 60`"
		DURATION="`expr $IN_SEC + $IN_MINUTE`"
	fi

	if [ ! -n "$SERVICE" ]; then
		downtime_type="downtime_host"
	else
		downtime_type="downtime_service"
	fi

	if [ ! -n "$HOST" ]; then
		echo "Error in configuration file. Host unspecified"
	fi

	for day in `echo $DAY | sed -e 's/,/ /g'`; do
		if [ "$day" = "$CURDAY" ]; then
			if [ "$HOUR" = "$CURHOUR" ]; then
				if [ "$MINUTE" = "$CURMINUTE" ]; then
					if [ "$1" = "-d" ]; then
						echo "./downtime_manual.sh $downtime_type $HOST $DURATION \"$AUTHOR\" \"$COMMENT\" $SERVICE"
						./downtime_manual.sh $downtime_type $HOST $DURATION `echo $AUTHOR | sed 's: :_:g'` `echo $COMMENT | sed 's: :_:g'` $SERVICE
					else
						./downtime_manual.sh $downtime_type $HOST $DURATION `echo $AUTHOR | sed 's: :_:g'` `echo $COMMENT | sed 's: :_:g'` $SERVICE
					fi
				fi
			fi
		fi
	done		
done
