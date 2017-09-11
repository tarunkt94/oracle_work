#!/usr/bin/perl


use Cwd;
use strict;
use warnings;

my @sids = ("IDMDB","OIMDB","OIDPDB","OIDIDDB");
my $status="";
foreach my $sid(@sids){
	my $cmd = "ps -ef | grep pmon | grep $sid";
	my $out = `$cmd`;
	my @outarr = split("\n",$out);
	if( scalar @outarr < 2 ){
		$status .= "$sid is down in SIM DB\n";
	}
}

my $cmd = " ps -ef | grep tnsl | grep idmdb";
my $out = `$cmd`;
my @outarr = split("\n",$out);
if(scalar @outarr  < 2 ){
	$status .= "idmdb listener is down in SIM DB\n";
}

$cmd = " ps -ef | grep tnsl | grep oiddb";
$out = `$cmd`;
@outarr = split("\n",$out);
if(scalar @outarr  < 2 ){
        $status .= "oiddb listener is down in SIM DB\n";
}


if($out ne ""){
	open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
	print $fileh $status;
	close $fileh;
} 

