#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;

my $scriptDir = dirname($0);
chdir($scriptDir);
$scriptDir = getcwd();

die "Please provide the emctl location on the command line\n" if @ARGV < 1 ; 
my $emctlloc = $ARGV[0];

my $catoutput = `cat /etc/oratab`;
my @catoutarr  =split('\n',$catoutput);
my $listenerStopped  = "false";
my $regex  = qr/^[\s+]#/;
my $ORACLE_HOME;
my $ORACLE_SID;

foreach my $line(@catoutarr){
	if(!($line eq "" || $line =~ /$regex/|| $line =~ /^#/ )){
		$ORACLE_SID = (split(':',$line))[0];
		$ORACLE_HOME = (split(':',$line))[1];
		my $cmd = "$scriptDir/startdb.sh $ORACLE_HOME $ORACLE_SID";
		system($cmd);
	}
}


startoms();

sub startoms{

	chdir($emctlloc);
	my $pwd = getcwd();
	print "\n=====Currently at location $pwd\n";
	
	my $omsDown = "Oracle Management Server is Down";
	my $webTierDown = "WebTier is Down";
	
	my $cmd = "$emctlloc/emctl start oms";
	system($cmd);

	$cmd = "$emctlloc/emctl status oms";
	my $out = `$cmd`;
	print "\n$out\n";
	foreach my $line(split('\n',$out)){
		if( $line =~ /$omsDown/ || $line =~ /$webTierDown/){
			print "\nError in starting OMS.\n";
			exit(1);
		}
	}
}	


