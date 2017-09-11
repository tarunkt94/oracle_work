#!/usr/bin/perl

use strict;
use warnings;

my $cmd = "/u01/IDMTOP/config/instances/ohs1/bin/opmnctl status";
my $out = `$cmd`;

unless($out =~ /Alive/){
        open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
        print $fileh "Services not running in SIM OHS\n";
        close $fileh;
}

