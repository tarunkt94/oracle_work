#!/usr/bin/perl

use strict;
use warnings;
use Pod::Usage;

die "\nPlease provide system name as an argument\n" if(@ARGV < 1);
my $system_name = $ARGV[0];

my $cmd = "sdictl.sh list_fa_pods -system_name_criteria $system_name";

my $output = `$cmd`;

my $service_name = (split('\|',$output))[21];

print "\nService name for system name $system_name is $service_name\n";
