#!/usr/bin/perl


use strict;
use warnings;
use Cwd;


my $cmd = '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/sendmail stop\'';
my $checkPhrase = "is stopped";

system($cmd);

$cmd =  '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/sendmail status\'';
my $out = `$cmd`;
print "$out";

if($out =~ /$checkPhrase/){
	print "Services stopped successfully\n";
}
else{
	print "Error while stopping the services\nCheck manually\n";
	exit(1);
}


