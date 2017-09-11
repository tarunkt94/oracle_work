#!/usr/bin/perl

use strict;
use warnings;
use Cwd;


my $cmd = '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/nscd start\'';
my $phrase = "is running";

my $retCode = system($cmd);

$cmd = '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/nscd status\'';
my $out = `$cmd`;
print "$out";

if($out =~ /$phrase/){
	print "\nServices are up and running\n";
}
else{
	print "\nCould not bring up services\nCheck manually\n";
        exit(1);
}

