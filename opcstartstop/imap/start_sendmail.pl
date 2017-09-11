#!/usr/bin/perl


use strict;
use warnings;
use Cwd;


my $cmd = '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/sendmail start\'';
my $checkPhrase = "is running";

my $retCode = system($cmd);
die("Error while running the command $cmd.\n") if $retCode !=0 ;

$cmd =  '/usr/local/packages/aime/ias/run_as_root \'/etc/init.d/sendmail status\'';
my $out = `$cmd`;
print "$out";

if($out =~ /$checkPhrase/){
	print "Services started successfully\n";
}
else{
	print "Error while starting the services\nCheck manually\n";
	exit(1);
}


