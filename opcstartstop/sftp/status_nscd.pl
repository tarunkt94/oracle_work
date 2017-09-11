#!/usr/bin/perl


use strict;
use warnings;
use Cwd;

my $phrase = "is running";

my $cmd =  '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/nscd status\'';
my $out = `$cmd`;
print "$out";

unless($out =~ /$phrase/){
        open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
        print $fileh "nscd is down in SFTP\n";
        close $fileh;
}


