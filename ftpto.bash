#!/bin/bash

if [ $# -eq 0 ] 
then
	echo "Usage: `basename $0` <machine> <remote dir> <file to be sent over ftp>"
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

exec 6>$TMP_FILE_NAME

if [ $# -eq 3 ] 
then
	FILENAME=$3
	if [ -d $FILENAME ]
	then
		FILENAME=${FILENAME%/}
		echo "$FILENAME is a directory"
		FILENAME="$FILENAME.tar.bz2"
		FILETOSEND="$TMP_DIR/$FILENAME"
		echo "Creating tar file: $FILETOSEND"
		tar -cjvf $FILETOSEND $3
		echo "bin" >& 6
		echo "lcd $TMP_DIR" >& 6
	fi

	echo "bin" >& 6
	echo "cd $REMOTEDIR" >& 6
	echo "put $FILENAME" >& 6
	echo "bye" >& 6

	cat $TMP_FILE_NAME | ftp -id $MACHINE 22
else
	ftp -id $MACHINE 
fi

exec 6>&-
