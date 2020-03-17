#!/bin/bash

plugins="`dirname \"$0\"`"
yum -y install autoconf automake
cd $plugins

function get_plugin_wget {
	rm -rf $1	
	wget $2
	cp $1 $plugins
}

function get_plugin_consol {
	git clone https://github.com/lausser/$1 "$1-git"
	cd "$1-git"
	git submodule update --init
	autoreconf
	./configure
	make
	cp plugins-scripts/$1 $plugins
	cd ..
	rm -rf "$1-git"
}

# DELL
get_plugin_wget check_openmanage "https://raw.githubusercontent.com/trondham/check_openmanage/master/check_openmanage"

# HP 
get_plugin_wget check_ilo2_health.pl "https://gist.githubusercontent.com/mbirth/11207953/raw/3a6c0154a9c0c9705d6568cf40a4c7bb453728ac/check_ilo2_health.pl"

# SNMP
git clone https://github.com/dnsmichi/manubulon-snmp
cp manubulon-snmp/plugins/check* $plugins
rm -rf manubulon-snmp

# CONSOL LABS
get_plugin_consol check_nwc_health
get_plugin_consol check_mssql_health
get_plugin_consol check_mysql_health
get_plugin_consol check_sap_health
get_plugin_consol check_db2_health
get_plugin_consol check_oracle_health
get_plugin_consol check_hpasm


chmod u+x *
chown nagios:eyesofnetwork *
cd .
