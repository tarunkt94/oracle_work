#!/usr/bin/perl


use Cwd;
use strict;
use warnings;

my @sids = ("centraldb","myaccountdb","sdidb","poddb","myservicedb");
my $status="";
foreach my $sid(@sids){
	my $cmd = "ps -ef | grep pmon | grep $sid";
	my $out = `$cmd`;
	my @outarr = split("\n",$out);
	if( scalar @outarr < 2 ){
		$status .= "$sid is down in Infra DB\n";
	}
}

my $cmd = " ps -ef | grep tnsl | grep dbhome";
my $out = `$cmd`;
my @outarr = split("\n",$out);
if(scalar @outarr  < 2 ){
	$status .= "Listener is down in Infra DB\n";
}


if($out ne ""){
	open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
	print $fileh $status;
	close $fileh;
} 

