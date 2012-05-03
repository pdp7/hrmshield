#!/bin/bash

FILENAME="$1"
echo $FILENAME

if [ ! -f "$FILENAME" ]
then
	echo "error: no filename specified or filename doesn't exist"
	exit 1
fi

# run parse and filter seperately
cat $FILENAME | ./parse.pl | sort -n > $FILENAME.parsed
cat $FILENAME.parsed | ./filter.pl | sort -n > $FILENAME.filtered
# removing avg for now:
# cat $FILENAME.parsed | ./avg.pl | sort -n > $FILENAME.avg

# merge together the data output from the different scripts
join $FILENAME.parsed $FILENAME.filtered > $FILENAME.data
# removing avg for now:
# join $FILENAME.parsed $FILENAME.filtered > $FILENAME.tmp
# join $FILENAME.tmp $FILENAME.avg > data/hrm.data

# generate graph with pre-defined settings
gnuplot hrmshield-png.plot

# open graph in image viewer
eog graph/hrm.png
