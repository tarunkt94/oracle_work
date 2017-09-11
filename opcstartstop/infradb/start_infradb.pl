#!/usr/bin/perl


use strict;
use warnings;
use Cwd;
use File::Basename;

my $catoutput = `cat /etc/oratab`;
my @catoutarr  =split('\n',$catoutput);
my $listenerStopped  = "false";
my $regex  = qr/^[\s+]#/;
my $ORACLE_HOME;
my $ORACLE_SID;

my $scriptDir = dirname($0);
chdir($scriptDir);
$scriptDir = getcwd();
print "\n==Currently in the directory $scriptDir\n";

my $cmd = 'startup';
foreach my $line(@catoutarr){
	if(!($line eq "" || $line =~ /$regex/|| $line =~ /^#/ )){
		$ORACLE_SID = (split(':',$line))[0];
		$ORACLE_HOME = (split(':',$line))[1];
		my $cmd = "$scriptDir/startdb.sh $ORACLE_HOME $ORACLE_SID";
		system($cmd);
	}
}



