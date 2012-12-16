#!/usr/bin/env bash

# disktest
# by Aaron Kondziela <aaron@aaronkondziela.com>
# Copyright (c) 2012 Aaron Kondziela; all rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

CHUNKSIZE=65535
BLOCKSIZE=512
POSITION=0
THRESHOLD=2
STATUS=0
VERBOSE=0

DEVICE="$1" ; shift
while [ ! -z "$1" ] ; do
	if [ "$1" == "-v" ] ; then VERBOSE=1 ; echo Verbose On ; shift ; fi
	if [ "$1" == "-t" ] ; then shift ; THRESHOLD="$1" ; echo Threshold $THRESHOLD ; shift ; fi
	if [ "$1" == "-c" ] ; then shift ; CHUNKS="$1" ; echo Chunks $CHUNKS ; shift ; fi
done

if [ -z "$DEVICE" ] ; then
	echo "Usage: $0 <devicename> [-v] [-t threshold] [-c chunk_count]"
	echo
	echo "  -v              Verbose output, otherwise only suspicious times printed"
	echo "  -t <threshold>  Sets threshold multiplier, default 2.0"
	echo "  -c <count>      Read <count> number of chunks, default entire disk"
	echo
	echo "  Reads entire device and times each read. If the hard drive is going bad,"
	echo "  it may take significantly longer to read certain sectors, even though"
	echo "  it succeeds and SMART reports no problems. This may indicated impending"
	echo "  failure. Additionally, reading the entire disk can trigger the drive\'s"
	echo "  automatic sector replacement for weak sectors, refreshing the data."
	echo "  You may want to tee the output to a file for later review, there"
	echo "  may be a lot fo lines for large disks. Run on an idle system, other"
	echo "  activity will skew the drive read times."
	echo
	echo "  Author and Copyright: Aaron Kondziela <aaron@aaronkondziela.com>"
	echo "  This software is released under the 2-clause FreeBSD license."
	echo
	exit 1
fi

# Check if device is readable, may need sudo
dd if="$DEVICE" of=/dev/null count=1 2>/dev/null 1>/dev/null
RETVAL=$?
if [ $RETVAL -gt 0 ] ; then
	echo "Device not readable, try sudo maybe"
	exit 2
fi

# Get first chunktime
PREVCHUNKTIME=`dd if="$DEVICE" of=/dev/null bs="$BLOCKSIZE" count="$CHUNKSIZE" skip=0 2>&1 | egrep -o 'in .\.[0-9]+ secs' | cut -d ' ' -f 2`

echo "Testing $CHUNKSIZE blocks of $BLOCKSIZE bytes for each chunk..."
if [ "$VERBOSE" -eq 0 ] ; then echo "Printing only suspicious times..." ; fi

STARTTIME=`date +%s`
CHUNK=0
while [ $STATUS -eq 0 ] ; do
	BLOCK=$((POSITION / CHUNKSIZE))
	CHUNKTIME=`dd if="$DEVICE" of=/dev/null bs="$BLOCKSIZE" count="$CHUNKSIZE" skip="$POSITION" 2>&1 | egrep -o 'in .\.[0-9]+ secs' | cut -d ' ' -f 2`
	STATUS=$?	
	RANGE_HI=`echo $PREVCHUNKTIME '*' $THRESHOLD | bc`
	if [[ $CHUNKTIME > $RANGE_HI ]] ; then
		echo -ne "$BLOCK:\t"
		echo -n $CHUNKTIME
		echo -e "\t< ERROR long read time at offset $POSITION, previous time was $PREVCHUNKTIME"
	else
		if [ "$VERBOSE" -eq 1 ] ; then echo -e "$BLOCK:\t$CHUNKTIME" ; fi
	fi
	PREVCHUNKTIME="$CHUNKTIME"
	POSITION=$((POSITION + CHUNKSIZE))
	CHUNK=$((CHUNK + 1))
	if [ $CHUNK -ge $CHUNKS ] ; then STATUS=1 ; fi
done
ENDTIME=`date +%s`

echo Finished run in $((ENDTIME - STARTTIME)) seconds

# If we are on Mac OSX print SMART status
if which diskutil > /dev/null ; then
	diskutil info /dev/disk0 | grep SMART
fi

