#!/usr/bin/perl -w 

#use Getopt::Mixed;

#Getopt::Mixed::init('j=s l:s p=i s=s t=s logfile>l d>p date>p period>p project> j type>t');

#http://www.perlmonks.org/?node_id=88222
use strict;
use Getopt::Std;

#getopts('g:', \%args);
#my %CmdLineArgs;
#my $thing = shift || 'world';
#print $args{g} ? 'Goodbye' : 'Hello', ", $thing\n";

my $Usage = "\n$0 -d <Directory Containing nfcapd Binary Flow Files> -a <Rotation Interval> -s <Start Time> -e <End Time> \n";
my %CmdLineArgs;

my %CmdLineArgsDesc = ( 
	a => "Rotation Interval",
	d => "Directory Containing nfcapd Binary Flow Files",
	s => "Start Time",
	e => "End Time"
);

getopts('hd:a:s:e:', \%CmdLineArgs);

if( $CmdLineArgs{h} ) {
	print $Usage;
	exit 0;
}

if(keys %CmdLineArgs < 4) {
	print STDERR "\nOne or more required options are missing.\n";
	print STDERR $Usage;
	exit 0;
}

print "\nCommand line arguments  - \n";
foreach my $switch (sort keys(%CmdLineArgs)) {
	print "\n$CmdLineArgsDesc{$switch}: $CmdLineArgs{$switch}";
}
print "\n";
