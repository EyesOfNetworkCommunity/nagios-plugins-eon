#!/bin/sh
#------------------------------------------------------------------------------
#
#   PROJECT      :  EyesOfNetwork NAGIOS RRD Delta Plugin
#
#   AUTOR        :  JC Laplace - APX
#
#   DATE         :  April 2015
#
#   HELP         :  see "usage"
#
#   COMMENT      : this plugin calculate deltas between RRD written values. 
#
#------------------------------------------------------------------------------
#set -x 
RRADIR=/srv/eyesofnetwork/pnp4nagios/rra
DEBUG=$(echo $0|grep -c debug)

# NAGIOS return status
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

###############################################################################
# usage
###############################################################################
usage ()
{
  nom=`basename $0`
  echo ""
  echo "Usage : $nom -H <hostname> -R <resourcename> -T <valuetype> -P <Reference period> -r <RRD data resolution> -w <warning> -c <critical>"
  echo " "
  echo "     -H <hostname>"
  echo "     -R <resourcename>"
  echo "     -T <valuetype : AVERAGE/MIN/MAX>"
  echo "     -P <Reference period : 1d, 2h, 1w>"
  echo "     -r <RRD data resolution : 1m=60, 5m=300, 30m=1800, 6h=21600>"
  echo "     -w <warning>"
  echo "     -c <critical>"
  echo "     -a (absolute value) -> create warning/critical alert even for negative delta"
  echo " "
  echo "Example : $nom -H server -R partitions -T AVERAGE -P 2h -r 1800 -w 30 -c 50"
  echo " "
exit 1
}

###############################################################################
# GetValue
###############################################################################
GetValue()
{
	DATA=${1}
	RANK=${2}
	LOCALRESULT=`echo ${DATA}| cut -d" " -f${RANK}`
	printf "%s\n" ${LOCALRESULT}
}



###############################################################################
# MAIN PROGRAM
###############################################################################

# Check arguments
while getopts ":R:H:T:P:r:w:c:a:" OPTS
do
    case $OPTS in
        R) RESOURCE=$OPTARG ;;
        H) HOST=$OPTARG ;;
        T) TYPE=$OPTARG ;;
	P) REFTIMESTAMP=$OPTARG ;;
	r) RESOLUTION=$OPTARG ;;
	w) WARNING=$OPTARG ;;
	c) CRITICAL=$OPTARG ;;
	a) ABSOLUTE=$OPTARG ;;
        *) usage ;;
    esac
done

# HOST : nom du host disposant de la ressource
if [ "$DEBUG" == 1 ] ; then echo HOST : ${HOST} ; fi

# RESOURCE : nom de la ressource pour identifier le fichier rrd
if [ "$DEBUG" == 1 ] ; then echo RESOURCE : ${RESOURCE} ; fi

# Type de la donnee a recuperer : AVERAGE / MIN / MAX
if [ "$DEBUG" == 1 ] ; then echo TYPE : ${TYPE} ; fi

# REFTIMESTAMP : valeur temporelle de reference : 1d (1 jour), 2h (2 heures), 1w (1 semaine)
if [ "$DEBUG" == 1 ] ; then echo REFTIMESTAMP : ${REFTIMESTAMP} ; fi

# RESOLUTION : resolution de la donnee (1m=60, 5m=300, 30m=1800, 6h=21600)
if [ "$DEBUG" == 1 ] ; then echo RESOLUTION : ${RESOLUTION} ; fi

# WARNING : seuil pour emission du warning
if [ "$DEBUG" == 1 ] ; then echo WARNING : ${WARNING} ; fi

# CRITICAL : seuil pour emission du critical
if [ "$DEBUG" == 1 ] ; then echo CRITICAL : ${CRITICAL} ; fi

# ABSOLUTE : prend en compte les pourcentages de modification negatifs
if [ "$DEBUG" == 1 ] ; then echo ABSOLUTE : ${ABSOLUTE} ; fi

# Parametres indispensables
if ( [ -z "$RESOURCE" ] || [ -z "$HOST" ] || [ -z "$TYPE" ] || [ -z "$REFTIMESTAMP" ] || [ -z "$RESOLUTION" ] || [ -z "$WARNING" ] || [ -z "$CRITICAL" ] ) ; then usage ; fi


RESOURCEDIR=$RRADIR/${HOST}
RESOURCEFILE=${RESOURCEDIR}/${RESOURCE}.rrd

# Gets the last RRD update value for active resource and host
LAST=`/usr/bin/rrdtool lastupdate ${RESOURCEFILE} | /usr/bin/tail -1 | /bin/cut -d':' -f2`

# Gets the reference value at timestamp to calculate the delta
REFDATA=`/usr/bin/rrdtool fetch ${RESOURCEFILE} ${TYPE} -r ${RESOLUTION} -s -${REFTIMESTAMP} -e -${REFTIMESTAMP} | /usr/bin/tail -1 | /bin/cut -d':' -f2`

if [ "$DEBUG" == 1 ] ; then echo RRD FILE : ${RESOURCEFILE} ; fi
if [ "$DEBUG" == 1 ] ; then echo LAST COLLECT : ${LAST} ; fi
if [ "$DEBUG" == 1 ] ; then echo REFDATA : ${REFDATA} ; fi

#printf "Analyzed_datas|value=1;30;50;0;100"
printf "Last collected value : %d |" ${LAST}
if [ "$DEBUG" == 1 ] ; then printf "\n" ; fi

i=1
for LASTVALUE in ${LAST}
do
	if [ "$DEBUG" == 1 ] ; then echo "   LASTVALUE(Resource(${i})) : ${LASTVALUE}" ; fi
	# Get the value for the resource in resources tab
	REFVALUE=`GetValue "${REFDATA}" ${i}`
	# Convert the value to be used by bc
	REFBCVALUE=`/bin/echo ${REFVALUE} | /bin/sed -e 's/,/./g' -e 's/[eE]+*/\\*10\\^/'`
	if [ "$DEBUG" == 1 ] ; then echo "   REFBCVALUE(Resource(${i})) : ${REFBCVALUE}" ; fi

	if [ $(echo "${REFBCVALUE} == ${LASTVALUE}" | /usr/bin/bc) -eq 1 ]
	then
		RESULT=0
	else
		# Calculate the delta percentage : (newvalue - refvalue)/refvalue
		#RESULT="$(echo "scale=4;100-(${LASTVALUE} * 100 / (${REFBCVALUE}))" | /usr/bin/bc)"
		#RESULT="$(echo "scale=4;(${LASTVALUE} * 100 / (${REFBCVALUE}))" | /usr/bin/bc)"
		RESULT="$(echo "scale=2;(((${LASTVALUE}-(${REFBCVALUE})) / (${REFBCVALUE})) * 100)" | /usr/bin/bc)"
	fi
	if [ "$DEBUG" == 1 ] ; then echo "   RESULT(Ressource(${i})) : ${RESULT}" ; fi
	#printf "${RESOURCE}=${RESULT}%;${WARNING};${CRITICAL};0;100 "
	# Print the perfdatas
	printf "%s(%s)=%s;%s;%s;0;100" ${RESOURCE} ${i} ${RESULT} ${WARNING} ${CRITICAL}
	if [ "$DEBUG" == 1 ] ; then printf "\n" ; fi

	let i++
done
echo ""


# Conversion du pourcentage negative en positif si le flag ABSOLUTE est positionne
if [ $(echo "${ABSOLUTE} == 1" | bc) -eq 1 ]
then
	#printf "ABS(RESULT) =%s\n" `echo ${RESULT} | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
	RESULT=`echo ${RESULT} | awk '{ print ($1 >= 0) ? $1 : 0 - $1}'`
fi

if [ $(echo "${RESULT} < ${WARNING}" | bc) -eq 1 ]
then
		SORTIE=${STATE_OK}
fi

if [ $(echo "(${RESULT} >= ${WARNING})&&(${RESULT} < ${CRITICAL})" | bc) -eq 1 ]
then
	SORTIE=${STATE_WARNING}
fi

if [ $(echo "(${RESULT} >= ${CRITICAL})" | bc) -eq 1 ]
then
	SORTIE=${STATE_CRITICAL}
fi

 if [ "$DEBUG" == 1 ] ; then echo SORTIE : ${SORTIE} ; fi
exit ${SORTIE}
