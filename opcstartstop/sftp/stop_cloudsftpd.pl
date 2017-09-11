#!/usr/bin/perl

use warnings;
use Cwd;


my $cmd = '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/sshd stop\'';
my $phrase = "is stopped";

system($cmd);

$cmd = '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/sshd status\'';
my $out = `$cmd`;
print "$out";

if($out =~ /$phrase/){
	print "\nServices are down\n";
}
else{
	print "\nCould not bring down services\nCheck manually\n";
	exit(1);
}

