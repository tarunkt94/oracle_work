#!/usr/bin/perl


use strict;
use warnings;
use Cwd;

my $phrase = "is running";

my $cmd =  '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/sendmail status\'';
my $out = `$cmd`;
print "$out";

unless($out =~ /$phrase/){
        open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
        print $fileh "sendmail is down in IMAP\n";
        close $fileh;
}


