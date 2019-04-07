#!/bin/bash

##
#
# receive statusinfo from Netgear ReadyNAS 312 for Nagios
#
# you can get all snmp-options with:
#   snmpwalk -m ALL -v 2c -c MYCOMMUNITY MYIPADDRESS  .1.3.6.1.4.1.4526
#
#
# Usage: 
#  ./check_readynas IP-ADDRESS SNMP-COMMUNITY STATUSCHECK
#
#
# 2017-08-18: initial Version     \\ Pit Wenkin
#
##

# temperature values for warning or critical / hdd (from datasheet)
MAXDISKTEMPCRIT="60"
MINDISKTEMPCRIT="5"
MAXDISKTEMPWARN="50"
MINDISKTEMPWARN="15"

# unused systemtemperature values for warning or critical / (from webinterface)
MAXSYSTEMPCRIT=65
MINSYSTEMPCRIT=0
MAXSYSTEMPWARN=55
MINSYSTEMPWARN=10

FREEPERCENT="0"

# nagios return values
export STATE_OK=0
export STATE_WARNING=1
export STATE_CRITICAL=2
export STATE_UNKNOWN=3  
export STATE_DEPENDENT=4
                                        

# check disk temperature for warning or critical values
function checkDiskTemperature () {

	true=$(echo "$1 >= $MAXDISKTEMPWARN" | bc)
		if [ $true = 1 ] ; then
			returnValue=$STATE_WARNING ;
		fi
		
	true=$(echo "$1 >= $MAXDISKTEMPCRIT" | bc)
		if [ $true = 1 ] ; then
			returnValue=$STATE_CRITICAL ;
		fi
		
	true=$(echo "$1 <= $MINDISKTEMPWARN" | bc)
		if [ $true = 1 ] ; then
			returnValue=$STATE_WARNING ;
		fi
		  
	true=$(echo "$1 <= $MINDISKTEMPCRIT" | bc)
		if [ $true = 1 ] ; then
			returnValue=$STATE_CRITICAL ;
		fi
	return $returnValue
}                                        

# check disk space for warning or critical values
function checkDiskSpace () {
	FULL=$1
	FREE=$2
	FREEPERCENT=$((100*FREE/FULL))

	true=$(echo "$FREEPERCENT <= 5" | bc)
		if [ $true = 1 ] ; then
			returnValue=$STATE_CRITICAL ;
		fi

	true=$(echo "$FREEPERCENT <= 10" | bc)
		if [ $true = 1 ] ; then
			returnValue=$STATE_WARNING ;
		fi
		  
	return $returnValue
}


# check third parameter and return the information
case "$3" in
	disk1status)
		DSK1STAT=`snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.3.1.9.1 | sed 's/.*ING: "//g' | sed 's/"//g'`

		if [ $DSK1STAT == "ONLINE" ]; then
		  intReturn=$STATE_OK
		else
		  intReturn=$STATE_WARNING
		fi

		outMessage="Disk1: $DSK1STAT"
	;;


	disk2status)
		DSK2STAT=`snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.3.1.9.2 | sed 's/.*ING: "//g' | sed 's/"//g'`

		if [ $DSK2STAT == "ONLINE" ]; then
		  intReturn=$STATE_OK
		else
		  intReturn=$STATE_WARNING
		fi	

		outMessage="Disk2: $DSK2STAT"
	;;


	disk1temp)
		DSK1TEMP=`snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.3.1.10.1 | awk '{print $4}'`
		
		checkDiskTemperature $DSK1TEMP
		intReturn=$?
		outMessage="Disk1: $DSK1TEMP Celsius" ;
	;;


	disk2temp)
		DSK2TEMP=`snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.3.1.10.2 | awk '{print $4}'`

                checkDiskTemperature $DSK2TEMP
		intReturn=$?
		outMessage="Disk2: $DSK2TEMP Celsius"
	;;


	fan1)
		FAN1=`snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.4.1.3.1 |  awk '{print $4}'`
		intReturn=$STATE_OK
		outMessage="Fan1: $FAN1"
	;;


        systemp)
		SYSCEL=`snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.5.1.2.2 | awk '{print $4}'`
		if [ "$SYSCEL" -gt "$MINSYSTEMPWARN" ] && [ "$SYSCEL" -lt "$MAXSYSTEMPWARN" ] ; then
		  intReturn=$STATE_OK
		else
	                if [ "$SYSCEL" -lt "$MINSYSTEMPCRIT" ] || [ "$SYSCEL" -gt "$MAXSYSTEMPCRIT" ] ; then
				intReturn=$STATE_CRITICAL
			else
			  intReturn=$STATE_WARNING
			fi
		fi
		outMessage="System Temperature: $SYSCEL°C"
	;;


	raidstatus)
		RAIDSTAT=`snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.7.1.4.1 | sed 's/.*ING: "//g' | sed 's/"//g'`

		if [ $RAIDSTAT == "REDUNDANT" ]; then
		  intReturn=$STATE_OK
		else
		  intReturn=$STATE_WARNING
		fi

		outMessage="RAID: $RAIDSTAT"
	;;

	freespace)
		SPACE=` snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.7.1.5.1 | awk '{print $4}'`
		FREESPACE=` snmpget $1 -v2c -c $2 .1.3.6.1.4.1.4526.22.7.1.6.1 | awk '{print $4}'`

                checkDiskSpace $SPACE $FREESPACE
		intReturn=$?
		MB=`echo "scale=2; $FREESPACE/1024" | bc`
		outMessage="Free Space: $MB MB"
	;;

	*)
		intReturn=$STATE_OK
		outMessage="  Usage: $0 IPADDRESS SNMPCOMMUNITY STATUS \n \n  Available statuses are: \n\n    disk1status|disk2status \n    disk1temp|disk2temp \n    fan1 \n    systemp \n    raidstatus \n    freespace"

	;;
esac


echo -e $outMessage
exit $intReturn
