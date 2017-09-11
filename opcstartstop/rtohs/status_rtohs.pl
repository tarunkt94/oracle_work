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

unless($out =~ /Alive/){
        open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
        print $fileh "opmn process not running in RT OHS\n";
        close $fileh;
}

