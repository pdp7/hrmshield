#!/usr/bin/perl

# Title: Arduino hrmshield heart rate file parser
# Author: Drew Fustini
# Version: 0.1 [2012-04-12]
# Blog: http://www.element14.com/community/blogs/pdp7
# Repo: https://github.com/pdp7/hrmshield
# STDIN: 
#     The hrmshield writes heart rate bpm readings to file on SD card.
#     File format is as follows:
#         <epoch-timestamp>\t<bpm-1>,<bpm-2>,<bpm-2>,[..],<bpm-n>\n
# STDOUT:
#     To simplify plotting a graph, this script writes a tab-delimited file
#     with one line per bpm reading preceeded by it's calculated timestamp:
#         <epoch-timestamp>\t<bpm>\n

use Math::Round;

while(my $ln = <STDIN>) {

	# remove trailing \n
	chomp $ln;

        # extract timestamp and bpm packet
	my ($ts,$data) = split(/\t/, $ln);

	print STDERR "ts=$ts\tdata=$data\n";

	# split bpm packet into an array of bpm readings
	my @bpm_packet = split(/,/, $data);

	my $sum = 0;
	my $n = 0;
	# write each bpm reading to a seperate line
	foreach my $bpm (@bpm_packet) {
		$sum += $bpm;	
	}
	my $avg = round( $sum / scalar @bpm_packet );
	#print STDERR round($ts) . "\t$avg\n";
	print round($ts) . "\t$avg\n";

}
