set xlabel "Time"              # set the lower X-axis label to 'time'

set xtics rotate by -270       # have the time-marks on their side


set ylabel "BPM"    # set the left Y-axis label

set ytics nomirror             # tics only on left side

set yr [55:120]

set key box top left           # legend box
set key box linestyle 0 

set xdata time                 # the x-axis is time
set format x "%H:%M:%S"        # display as time
set timefmt "%s"               # but read in as 'unix timestamp'

plot "data/hrm.data" using 1:2 with lines title "30 sec avg", "data/hrm.data" using 1:3 with lines title "rolling avg"
