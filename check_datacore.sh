#!/bin/bash 
#########################################################################
# Script:       check_datacore.sh                                       #
# Author:       Roland RIPOLL							                #
# Purpose:      Monitor Datacore sansynphony 9 with Nagios				#
# Description:  Checks Datacore sansynphony 9 via SNMP.					#
#               Can be used to query status and performance info        #
# Tested on:    Datacore sansynphony 9									#
# History:                                                              #
# 20130215 création														#
# 20130308 amélioration nombre de requettes SNMP						#
# 20130325 Ajout champ													#
# 20130405 Ajout condition attention warinng critique sur les volumes	#
# 20131226 refonte suite changement OID sur la PSP4						#
#    																	#
#########################################################################
# Usage: ./check_datacore.sh -H host -C community -t type				#
#########################################################################
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown
#PATH=/usr/local/bin:/usr/bin:/bin # Set path

# Get user-given variables
#########################################################################
while getopts "H:C:t:w:c:" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       C)      community=${OPTARG};;
       t)      type=${OPTARG};;
       \?)     echo "options -H for host, -C for SNMP-Community, -t for type (DiskPoolUse, Hosts, Vdisks, FCPorts, DiskPool, DC, LinkErrors, DiskPoolLatency)"
               exit 1
               ;;
       esac
done

case ${type} in
DiskPoolUse)
	state=0;
	texte=""
	
	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the disk pools available space percentage." | cut -b 27-124) );
	texte="$texte Utilisation des disks Pools : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done
 	if [ "$state" = "0" ];
        then
         echo -e "$texte";
                exit ${STATE_OK};
        else
        echo -e "Utilisation Importante des disk pools ! $texte";
                exit ${STATE_CRITICAL};
        fi
;;
Hosts)
        state=0;
        texte=""


	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the state of hosts." | cut -b 27-124) );
	texte="$texte Status des Hotes : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done	
	if [ "$state" = "0" ];
        then
         echo -e "$texte";
                exit ${STATE_OK};
        else
        echo -e "Erreur sur une ou plusieurs hotes ! $texte";
                exit ${STATE_CRITICAL};
        fi
;;		
Vdisks)
        state=0;
        texte=""

		
	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the status of virtual disks." | cut -b 27-124) );
	texte="$texte Status des Virtuals Disks : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done	
	if [ "$state" = "0" ];
        then
         echo -e "$texte";
                exit ${STATE_OK};
        else
        echo -e "Virtual Disks en erreur ! $texte";
                exit ${STATE_CRITICAL};
        fi
;;
FCPorts)
        state=0;
        texte=""


	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the state of server FC ports." | cut -b 27-124) );
	texte="$texte Status des ports FC des Datacores : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done	
	if [ "$state" = "0" ];
        then
         echo -e "$texte";
                exit ${STATE_OK};
        else
        echo -e "Erreur sur un ou plusieurs Port FC ! $texte";
                exit ${STATE_CRITICAL};
        fi
;;
DiskPool)
        state=0;
        texte=""


	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the state of disk pools." | cut -b 27-124) );
	texte="$texte Status des Disks Pools : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done
	if [ "$state" = "0" ];
        then
         echo -e "$texte";
                exit ${STATE_OK};
        else
        echo -e "Disk pools en echec ! $texte";
                exit ${STATE_CRITICAL};
        fi
;;
LinkErrors)
        state=0;
        texte=""


	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the link errors on server ports." | cut -b 27-124) );
	texte="$texte Status des link sur les ports serveurs : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done
	if [ "$state" = "0" ];
        then
         echo -e "$texte";
                exit ${STATE_OK};
        else
        echo -e "Liens en erreur ! $texte";
                exit ${STATE_CRITICAL};
        fi
;;
DC)
        state=0;
        texte=""

	
	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the state of DataCore Servers." | cut -b 27-124) );
	texte="$texte Status des Datacores : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done
	if [ "$state" = "0" ];
        then
         echo -e "$texte";
                exit ${STATE_OK};
        else
        echo -e "Datacore Server en erreur ! $texte";
                exit ${STATE_CRITICAL};
        fi
;;
DiskPoolLatency)
        state=0;
        texte=""

	
	SELECTcheck=( $(snmpwalk -v 2c -O n -c ${community} ${host} 1.3.6.1.4.1.7652.1.1.1 | grep "Monitors the disk pools latency." | cut -b 27-124) );
	texte="$texte Latence sur les Volumes : ";
	inc=-1;
	for index in "${!SELECTcheck[@]}"; 
		do
			inc=$( expr $inc + 1 );
			OIDState="1.3.6.1.4.1.7652.1.1.1.5.${SELECTcheck[$inc]}";
			OIDCaption="1.3.6.1.4.1.7652.1.1.1.4.${SELECTcheck[$inc]}";
			OIDStMessage="1.3.6.1.4.1.7652.1.1.1.6.${SELECTcheck[$inc]}";
			MState=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDState | cut -d\" -f 2);
			MCaption=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDCaption | cut -d\" -f 2);
			MStMessage=$(snmpget -v 2c -O vq -c ${community} ${host} $OIDStMessage | cut -d\" -f 2);
			if [ "$MState" = "Healthy" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
				state=$state; 
			fi
			if [ "$MState" = "Attention" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 0 ]; 
					then 
						state=$state;
					else	
						state=1;
					fi
			fi
			if [ "$MState" = "Warning" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 1 ]; 
					then 
						state=$state;
					else	
						state=2;
					fi
			fi
			if [ "$MState" = "Critical" ];
			then 
				texte="$texte $MCaption : $MStMessage, "; 
					if [ $state -gt 2 ]; 
					then 
						state=$state;
					else	
						state=3;
					fi 
			fi					
		done
		
	if [ "$state" = "0" ]; 
	then
       	echo -e "$texte";
		exit ${STATE_OK};
	fi
	if [ "$state" = "1" ]; 
	then
		echo -e "Latence elevee  $texte";
       	exit ${STATE_WARNING};
	fi
	if [ "$state" = "2" ]; 
	then
		echo -e "Warning ESPACE ! $texte" ;
       	exit ${STATE_WARNING};
	fi
	if [ "$state" = "3" ]; 
	then
		echo -e "Alerte ESPACE ! $texte";
       	exit ${STATE_CRITICAL};
	fi 
;;
esac	
echo "type non reconnu"
exit ${STATE_UNKNOWN}
