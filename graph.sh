#!/bin/bash

FILENAME="$1"
echo $FILENAME

if [ ! -f "$FILENAME" ]
then
	echo "usage error"
	exit 1
fi

cat $FILENAME | ./parse.pl | sort -n > $FILENAME.parsed
cat $FILENAME.parsed | ./filter.pl | sort -n > $FILENAME.filtered
cat $FILENAME.parsed | ./avg.pl | sort -n > $FILENAME.avg
join $FILENAME.parsed $FILENAME.filtered > $FILENAME.tmp
join $FILENAME.tmp $FILENAME.avg > data/hrm.data

gnuplot hrmshield.plot

eog data/hrm.png

