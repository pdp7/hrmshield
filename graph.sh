#!/bin/bash

FILENAME="$1"
echo $FILENAME

if [ ! -f "$FILENAME" ]
then
	echo "error: no filename specified or filename doesn't exist"
	exit 1
fi

# run parse and filter seperately
cat $FILENAME | ./parse-avg.pl | sort -n > $FILENAME.parsed
cat $FILENAME.parsed | ./filter-avg.pl | sort -n > $FILENAME.filtered

# merge together the data output from the different scripts
join $FILENAME.parsed $FILENAME.filtered > data/hrm.data

# generate graph with pre-defined settings
gnuplot hrmshield-parse-avg-png.plot
gnuplot hrmshield-filter-avg-png.plot
gnuplot hrmshield-combined-png.plot

# open graph in image viewer
eog graph/bpm-parse-avg.png 
eog graph/bpm-filter-avg.png
eog graph/bpm-combined.png 
