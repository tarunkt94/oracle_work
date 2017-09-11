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

stopoms();

foreach my $line(@catoutarr){
	if(!($line eq "" || $line =~ /$regex/|| $line =~ /^#/ )){
		$ORACLE_SID = (split(':',$line))[0];
		$ORACLE_HOME = (split(':',$line))[1];
		my $cmd = "$scriptDir/stopdb.sh $ORACLE_HOME $ORACLE_SID";
		system($cmd);
	}
}



sub stopoms{

	chdir($emctlloc);
	my $pwd = getcwd();
	print "\n=====Currently at location $pwd\n";
	
	my $omsUp = "Oracle Management Server is Up";
	my $webTierUp = "WebTier is Up";
	
	my $cmd = "$emctlloc/emctl stop oms -all";
	system($cmd);

	$cmd = "$emctlloc/emctl status oms";
	my $out = `$cmd`;
	print "\n$out\n";
	foreach my $line(split('\n',$out)){
		if( $line =~ /$omsUp/ || $line =~ /$webTierUp/){
			print "\nError in stopping OMS.\n";
			exit(1);
		}
	}
}	


