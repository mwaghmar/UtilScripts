#!/bin/bash
##
# @file - limitbw.sh
# @brief - Limits the outgoing traffic bandwidth [destined for specified port] to the specified value.
# @author Manojkumar M Waghmare
# @version 1.0
# @date 2013-06-03
##
# 	limitbw.sh -p 22 -b 10kbps -m 12kbps
#

USAGE=$" 
		Limits outgoing traffic on the given port to the specified value.\n\n
		Usage:\n\n
		limitbw.sh [-p <destination port>] [-b <bandwidth>] [-m <burst-bandwidth>] [-h] [-f]\n\n
		-p: [Optional. Default 22] Port number. Traffic destined for this port is shaped.\n
		-b: [Optional. Default 512kbps] Allowed Bandwidth Limit in kbps, mbps, kbit, mbit, bps.\n
		-m: [Optional. Default 640kbps if -b not provided. If -b provided then 'allowed bw+2'] \n
		\tBurst Bandwidth Limit in kbps, mbps, kbit, mbit, bps. Must be >= allowed bandwidth.\n
		-f: [Optional] Flushes Existing IPTABLES Mangle Rules.\n
		-h: [Optional] See usage.\n\n
		Example:\n\n 	
		limitbw.sh -p 22 -b 10kbps -m 12kbps \n\n
		"

function isNumber()
{
	expr "$1" : '[0-9]\+$' >/dev/null
	if [ $? -eq 0 ]; then
		return 1
	fi

	return 0
}

function isValidBandwidthUnit()
{
	shopt -s nocasematch

	RETVAL=0
	if [ "$1" == "kbps" -o "$1" == "mbps" -o "$1" == "kbit" -o "$1" == "mbit" -o "$1" == "bps" ]; then
		RETVAL=1
	fi

	shopt -u nocasematch
	return $RETVAL
}

RETBPS=0
function getBytesPerSecond()
{
	RATE=$1
	UNIT=$2
	BPS=0
	
	case $UNIT in
		"kbps")
			BPS=$(($RATE*1000))
		;;
			
		"mbps")
			BPS=$(($RATE*1000*1000))
		;;
		
		"kbit")
			BPS=$(($RATE*1000))
			BPS=$(($BPS/8))
		;;
		
		"mbit")
			BPS=$(($RATE*1000*1000))
			BPS=$(($BPS/8))
		;;

		"bps")
			BPS=$RATE
		;;
		
		*)
			echo "Invalid bandwidth unit: $UNIT"
			BPS=0
		;;
	esac

	RETBPS=$BPS
	return $BPS
}

TC=`which tc`
IPTABLES=`which iptables`

if [ -z "$TC" -o -z $IPTABLES ]; then
    echo "[FATAL ERROR!!!] Could not find either 'tc' or 'iptables' executbles in path."
    exit 1
fi

FLUSHMANGLE=0
OUTPORT=22
DEF_BW="512kbps"
DEF_BURST_BW="640kbps"

while getopts ":p:b:m:hf" opt; do
	case $opt in
		p)
			OUTPORT=$OPTARG
			isNumber $OUTPORT 
			if [ $? -eq 0 ]; then
				echo "Invalid Port Number: $OUTPORT"
				exit 1
			fi
			;;

		b)
			BW=$OPTARG
			BWNUMERAL=`expr match "$BW" '\([0-9]*\)'`
			BWUNIT=${BW/$BWNUMERAL/}
		
			isNumber $BWNUMERAL
			if [ $? -eq 0 ]; then
				echo "Invalid Bandwidth Specification: $BWNUMERAL"
				echo "Bandwidth must be a number without +/- sign."
				exit 1
			fi

			isValidBandwidthUnit $BWUNIT	
			if [ $? -eq 0 ]; then
				echo "Invalid Bandwidth Unit: $BWUNIT"
				echo "Valid Bandwidth units are: kbps mbps kbit mbit bps"
				exit 1
			fi
			DEF_BW=$BW
			DEF_BURST_BW=$(($BWNUMERAL+2))
			DEF_BURST_BW=$DEF_BURST_BW$BWUNIT
			;;

		m)
			BBW=$OPTARG
			BBWNUMERAL=`expr match "$BBW" '\([0-9]*\)'`
			BBWUNIT=${BBW/$BBWNUMERAL/}
		
			isNumber $BBWNUMERAL
			if [ $? -eq 0 ]; then
				echo "Invalid Burst/Max Bandwidth Specification: $BBWNUMERAL"
				echo "Burst Bandwidth must be a number without +/- sign."
				exit 1
			fi

			isValidBandwidthUnit $BBWUNIT	
			if [ $? -eq 0 ]; then
				echo "Invalid Bandwidth Unit: $BBWUNIT"
				echo "Valid Bandwidth units are: kbps mbps kbit mbit bps"
				exit 1
			fi
				
			DEF_BURST_BW=$BBW
			;;

		h)
			echo -e $USAGE
			exit 0
			;;

		f)
			FLUSHMANGLE=1
			;;

		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;

		:  ) 
			echo "Missing option argument for -$OPTARG" >&2 
			exit 1
			;;
	esac
done

shift $(($OPTIND - 1))

if [ ! -z $BW ] && [ ! -z $BBW ]; then

	getBytesPerSecond $BWNUMERAL $BWUNIT
	BWBPS=$RETBPS

	getBytesPerSecond $BBWNUMERAL $BBWUNIT
	BBWBPS=$RETBPS

	if [ "$BWBPS" -gt "$BBWBPS" ]; then
		echo "Burst/Max Bandwidth must be greater than Bandwidth."
		echo "Burst BW $BBW is less than allowed BW $BW. It must be >= $BW."
		exit 1
	fi
fi

echo "#############################################"
echo "Liming Outgoing B/W on Port $OUTPORT to $DEF_BW / $DEF_BURST_BW"
echo "#############################################"

STEPNUM=1
#Clear existing queue discipline rules.
echo "[STEP - $STEPNUM]: Deletig existing Queuing Discipline Rules .."
$TC qdisc del dev eth0 root
if [ $? -ne 0 ]; then
	echo "[WARNING!!!] FAILED to delete existing Queuing Discipline Rules."
fi

if [ $FLUSHMANGLE -eq 1 ]; then 
	#Flush all Mangle rules
	STEPNUM=$(($STEPNUM+1))
	echo "[STEP - $STEPNUM]: Deletig existing IPTABLES Mangling Rules .."

	$IPTABLES -t mangle  -F OUTPUT
	if [ $? -ne 0 ]; then
		echo "[WARNING!!!] FAILED to delete existing IPTABLES Mangling Rules."
	fi
fi

#Add Hierarchical Token Buffer [hbt] qdisc to interface eth0
STEPNUM=$(($STEPNUM+1))
echo "[STEP - $STEPNUM]: Adding HTB qdisc as root queue to the inteface eth0."
$TC qdisc add dev eth0 root handle 1: htb
if [ $? -ne 0 ]
then
	echo "[FATAL ERROR!!!] FAILED to add HTB qdisc to interface eth0. Quitting .."
	exit 1
fi

#Add Child class to root qdisc with given BW
$TC class add dev eth0 parent 1: classid 1:1 htb rate $DEF_BW ceil $DEF_BURST_BW prio 0
if [ $? -ne 0 ]
then
	echo "[FATAL ERROR!!!] FAILED to add child class to root HTB. Quitting .."
	exit 1
fi

STEPNUM=$(($STEPNUM+1))
echo "[STEP - $STEPNUM]: Add Filters for packet classification."
$TC filter add dev eth0 parent 1:0 prio 0 protocol ip handle 1 fw flowid 1:1
if [ $? -ne 0 ]
then
	echo "[FATAL ERROR!!!] FAILED to add filter. Quitting .."
	exit 1
fi

STEPNUM=$(($STEPNUM+1))
echo "[STEP - $STEPNUM]: Create iptables Mangling rule to mark packets."
$IPTABLES -A OUTPUT -t mangle -p tcp  --dport $OUTPORT -j MARK --set-mark 1
if [ $? -ne 0 ]
then
	echo "[FATAL ERROR!!!] FAILED to create iptables mangling rule. Quitting .."
	exit 1
fi

/sbin/service iptables save

echo -e "\n\nCurrent Queueing Discipline Rules are ..."
$TC -s qdisc ls dev eth0

echo -e "\n\nCurrent IPTABLE Rules are ..."
$IPTABLES -t mangle -n -v -L
