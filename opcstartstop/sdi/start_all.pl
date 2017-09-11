#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;

my $scriptloc = dirname($0);
chdir($scriptloc);
$scriptloc = getcwd();
my $dcdomainLog = "$scriptloc/dcdomainAdmin.log";
my $myServicesLog = "$scriptloc/myServicesAdmin.log";
my $nmLog = "$scriptloc/NM.log";

#Starting the dc_domain Admin Server
my $dcdomainScript = "/scratch/aime/work/CLOUDTOP/Middleware/user_projects/domains/dc_domain/bin/startWebLogic.sh";
my $dcdomainAdminStart = "nohup $dcdomainScript >& $dcdomainLog &";
print "\nGoing to run the command $dcdomainAdminStart\n";
system($dcdomainAdminStart);

#Starting the MyServices Admin Server
my $myServicesScript = "/scratch/aime/work/CLOUDTOP/Middleware/user_projects/domains/cpserver/MyServices/bin/startWebLogic.sh";
my $myServicesAdminStart = "nohup $myServicesScript >& $myServicesLog &";
print "\nGoing to run the command $myServicesAdminStart\n";
system($myServicesAdminStart);


print "\nSleeping for 120 seconds for the Admin Server to start\n";
sleep(240);

print "\nOut of sleep, will start the Node manager now and wait for 60 seconds\n";

#Starting the NodeManager
my $nmLoc = "/scratch/aime/work/CLOUDTOP/Middleware/wlserver_10.3/server/bin/startNodeManager.sh";
my $startNMcmd = "nohup $nmLoc >& $nmLog &";
print "\nGoing to run the command $startNMcmd\n";
system($startNMcmd);
sleep(60);

print "Out of sleep, will bring up the managed servers now \n";

#starting the Managed Servers
chdir($scriptloc);
my $startMScmd = './WLS_Script.sh start_managed.py';
my $retCode = system($startMScmd);
if($retCode !=0){
	exit(1);
}

