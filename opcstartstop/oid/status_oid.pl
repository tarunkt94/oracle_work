#!/usr/bin/perl

use strict;
use warnings;

my $cmd = "/u01/IDMTOP/config/instances/oid1/bin/opmnctl status | grep oidmon";
my $out = `$cmd`;

my $status = (split('\|',$out))[3];
chomp $status;

unless($status =~ /Alive/){
        open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
        print $fileh "oidmon not running in SIM OID\n";
        close $fileh;

}

$cmd = "/u01/IDMTOP/config/instances/oid1/bin/opmnctl status | grep OVD";
$out = `$cmd`;

$status = (split('\|',$out))[3];
chomp $status;

unless($status =~ /Alive/){
        open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
        print $fileh "OVD not running in SIM OID\n";
        close $fileh;

}


