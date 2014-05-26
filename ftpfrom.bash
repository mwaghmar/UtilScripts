#!/bin/bash

if [ $# -eq 0 ] 
then
	echo "Usage: `basename $0` <machine> <remote dir> <file to get from ftp server>"
	exit 
fi

MACHINE=$1

if [ $# -eq 1 ] 
then
	REMOTEDIR="."
else
	REMOTEDIR=$2
fi

TMP_DIR=/tmp
TMP_FILE_NAME="$TMP_DIR/ftpcmds"

if [ $# -eq 3 ] 
then
	FILETOGET=$3

	exec 6>$TMP_FILE_NAME
	echo "bin" >& 6
	echo "cd $REMOTEDIR" >& 6
	echo "get $FILETOGET" >& 6
	echo "bye" >& 6
	exec 6>&-

	cat $TMP_FILE_NAME | ftp -id $MACHINE
else
	ftp -id $MACHINE 
fi

