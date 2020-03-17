#!/bin/sh

ERRORS=`ssh $2@$1 "errpt -T PERM"`

if [ "$ERRORS" = "" ]; then
	echo OK : no errpt errors
	exit 0
else
	echo $ERRORS
	exit 2
fi
