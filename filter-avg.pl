#!/usr/bin/perl

# Title: Arduino hrmshield heart rate data rolling average filter
# Author: Drew Fustini
# Version: 0.1 [2012-04-09]
# Blog: http://www.element14.com/community/blogs/pdp7
# Repo: https://github.com/pdp7/hrmshield
#
# Desc: This script calculates a rolling average for heart rate
#
# STDIN: file format is as follows:
#         <epoch-timestamp>\t<bpm>\n
#
# STDOUT: file format is as follows:
#         <epoch-timestamp>\t<bpm>\n


use Math::Round;

my $MIN_BPM = 50;
my $MAX_BPM = 120;

my %data = undef;

my @time;
my @bpm;
my @plot;

my $rollingaverage = 70;

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

# process each bpm sample for rolling average
for(my $i=0; $i < scalar @bpm; $i++) {
	next if($bpm[$i]>$MAX_BPM or $bpm[$i]<$MIN_BPM);
        $rollingaverage = ($rollingaverage*0.90) + (0.10*$bpm[$i]);
	print STDERR "$time[$i]\t$bpm[$i]\t" . round($rollingaverage) . "\t". '*' x round($rollingaverage) . "\n";
	print "$time[$i]\t" . round($rollingaverage) . "\n";
}
