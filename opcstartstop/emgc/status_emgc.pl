#!/usr/bin/perl


use Cwd;
use strict;
use warnings;

my $status="";

my $cmd = "ps -ef | grep pmon | grep emdb";
my $out = `$cmd`;
my @outarr = split("\n",$out);
if( scalar @outarr < 2 ){
	$status .= "emdb is down in EMGC\n";
}


$cmd = " ps -ef | grep tnsl | grep dbhome";
$out = `$cmd`;
@outarr = split("\n",$out);
if(scalar @outarr  < 2 ){
	$status .= "Listener is down in EMGC\n";
}

$cmd = " /scratch/aime/work/CLOUDTOP/Middleware/MIDDLEWARE/EM/oms/bin/emctl status oms";
$out = `$cmd`;
if($out =~ /WebTier is Down/){
	$status .= "Webtier is down in EMGC\n";
}

if($out =~ /Oracle Management Server is Down/){
        $status .= "Oracle Management Server is down in EMGC\n";
}


if($status ne ""){
	open(my $fileh,">>","/net/slc03wlx/scratch/aime/tarun/status.txt");
	print $fileh $status;
	close $fileh;
} 

