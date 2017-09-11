#!/usr/bin/perl


use strict;
use warnings;
use Cwd;


my $cmd = "locate /bin/opmnctl | grep instances";
my $opmnloc = `$cmd`;
chomp $opmnloc;

my $opmnstatus = "$opmnloc status";
my $out = `$opmnstatus`;
print $out;

my $phrase = "Alive";
if(!($out =~ /$phrase/)){
	print "\nopmn is not running\n";
	exit(1);
}
else{
	print "\nopmn is running\n";
}
