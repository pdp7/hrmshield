#!/usr/bin/perl

# Title: Arduino hrmshield heart rate data filter
# Author: Drew Fustini
# Version: 0.1 [2012-04-09]
# Blog: http://www.element14.com/community/blogs/pdp7
# Repo: https://github.com/pdp7/hrmshield
#
# Desc: This script applies filtering to the heart rate bpm samples 
#       and is adapted from the HeartSpark asymptote script:
#       http://github.com/mrericboyd/Heart-Plot
#
# STDIN: file format is as follows:
#         <epoch-timestamp>\t<bpm>\n
#
# STDOUT: file format is as follows:
#         <epoch-timestamp>\t<bpm>\n


use Math::Round;

my %data = undef;

my @time;
my @bpm;
my @plot;

my $rollingaverage = 75;
my $LowerBound = 0.60;
my $UpperBound = 1.30;

# read in all stdin and split each line into timestamp & bpm sample
# push each of these values into the respective array
while(my $ln = <STDIN>) {
	chomp $ln;
	my ($t,$b) = split(/\t/, $ln);
	push(@time, $t);
	push(@bpm, $b);
}

print STDERR "time: " . scalar @time . "\n";
print STDERR " bpm: " . scalar @bpm . "\n";

# process each bpm sample with the filter
for(my $i=0; $i < scalar @bpm; $i++) {
	print STDERR "main> BEFORE: $i: "  . $time[$i] . "\t" . $bpm[$i] . "\n";
	my $r = filter($i);
	print STDERR "main> plot? " . $r . "\n";
	push(@plot, $r);
	print STDERR "main> AFTER: $i: "  . $time[$i] . "\t" . $bpm[$i] . "\n\n";
}

# output each filtered bpm sample to stdout which should be redirected to a file
for(my $i=0; $i < scalar @bpm; $i++) {
	print "$time[$i]\t$bpm[$i]\n" if $plot[$i];
}

# determines if each bpm sample is plottable and may modify the value per filtering rules
sub filter {
	my $i = shift; # the only argument is the index to the bpm array of the sample to filter

	print STDERR "filter> $i: "  . $time[$i] . "\t" . $bpm[$i] . "\n";
  
	# filter sample unless it's the first two or last two samples
	if ($i > 2 && $i < ((scalar @bpm)-2)) {

		print STDERR $bpm[$i] . " < " . $LowerBound*$bpm[$i-1] . "\n";
		
		if ($bpm[$i] < $LowerBound*$bpm[$i-1]) {
			print STDERR "!!!!!!!!!!!!!!!!!!!!! TO LOW !!!!!!!!!!!!!!!!!!!!\n";
			# our data is "probably" a false negative, i.e.	we missed a point
       			if ($bpm[$i]*2 < 1.15*$rollingaverage) {
				print STDERR "#we could also plot a SECOND point for the one we missed\n";
				print STDERR ">>>>> " . $bpm[$i] . "\n";
	         		$bpm[$i] = $bpm[$i]*2;
				print STDERR ">>>>> " . $bpm[$i] . "\n";
				# we could also plot a SECOND point for the one we missed
				# but I am content to just plot this one at the "average" of the
				# two beats that would be here..
	       		} else {
        	 		print STDERR "# hmm, it shouldn't be so high like that, maybe it's not a false\n";
        	 		# hmm, it shouldn't be so high like that, maybe it's not a false
         			# negative, let's just plot it normally
	       		}
		} elsif ($bpm[$i] > $UpperBound*$bpm[$i-1] && $bpm[$i] > 0.8*$rollingaverage) {
			# we've got a potential false positive.  But let's check
			# carefully, because sometimes heartrate really does jump up quickly
			# check: if the total time of i and i+1 beats is similar to time
			# of i-1th beat, i is probably a false postive, we shouldn't plot it
			# and we should modify it and i+1 so that i+1 will plot "correctly"
			if (abs(($time[$i+1]-$time[$i-1])/($time[$i-1]-$self[$i-2])-1)<0.15) {
				# it has passed the test, both beats are with 15% of the time of
				# the previous beat, so it's likely a false positive
				my $backup = $bpm[$i+1];
				$bpm[$i+1] = (1.0/($minutes[$i+1]-$minutes[$i-1]));
				if ($bpm[$i+1] > 1.15*$rollingaverage || $bpm[$i+1] < 0.85*$rollingaverage) {
					# then bail or something, hell if I know!
				} 
				$bpm[$i] = $bpm[$i-1];  # ensure filtering doesn't trigger
				# and DO NOT PLOT point i: point i+1 will be plotted soon. 
				return 0;
			}
		} else {
      			#just plot as normal
		}

	}

	$rollingaverage = ($rollingaverage*0.90) + (0.10*$bpm[$i]);

	return 1;

}
