#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;

my $scriptloc = dirname($0);
chdir($scriptloc);
$scriptloc = getcwd();
my $myServicesLog = "/tmp/myservices_$$.log";


#Starting the MyServices Admin Server
my $myServicesScript = "/scratch/aime/work/CLOUDTOP/Middleware/user_projects/domains/cpserver/MyServices/bin/startWebLogic.sh";
die "\nThe script $myServicesScript does not exist\n" unless (-f $myServicesScript);
my $myServicesAdminStart = "nohup $myServicesScript >& $myServicesLog &";
print "\nGoing to run the command $myServicesAdminStart\n";
system($myServicesAdminStart);


#print "\nSleeping for 300 seconds for the Admin Server to start\n";
#sleep(300);

my $i=20;
my $sucstr = "Server started in RUNNING mode";
my $failstr = "Server started in ADMIN mode";
while($i!=0){
	my $output = `cat $myServicesLog`;
	
	last if($output =~ /$sucstr/i);
	if($output =~ /$failstr/i){
		die "\nAdmin server failed to start, is in Admin state , log file is $myServicesLog\n";
	}
	print"\nAdmin server has not yet started\n";
	sleep(30);
	$i--;
}

die "\nWaited for 10 mins for admin server to start, did not start \n" if($i==0);


print "Out of sleep, will bring up the managed servers now \n";

#starting the Managed Servers
chdir($scriptloc);
my $startMScmd = './WLS_Script.sh start_myservices_managed.py';
my $retCode = system($startMScmd);
if($retCode !=0){
	exit(1);
}

