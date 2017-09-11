#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;

my $scriptDir = dirname($0);
chdir($scriptDir);
$scriptDir = getcwd();




startoms();

sub startoms{

	my $emctlloc = "/scratch/aime/work/CLOUDTOP/Middleware/MIDDLEWARE/EM/oms/bin";
	chdir($emctlloc);
	my $pwd = getcwd();
	print "\n=====Currently at location $pwd\n";
	
	my $omsDown = "Oracle Management Server is Down";
	my $webTierDown = "WebTier is Down";
	
	my $cmd = "emctl start oms";
	system($cmd);

	$cmd = "emctl status oms";
	my $out = `$cmd`;
	print "\n$out\n";
	foreach my $line(split('\n',$out)){
		if( $line =~ /$omsDown/ || $line =~ /$webTierDown/){
			print "\nError in starting OMS.\n";
			exit(1);
		}
	}
}	


