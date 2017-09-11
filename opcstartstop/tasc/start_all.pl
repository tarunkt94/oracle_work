#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;


my $scriptloc = dirname($0);
chdir($scriptloc);
$scriptloc = getcwd();
my $centraldomainLog = "$scriptloc/centraldomainAdmin.log";
my $myAccountLog = "$scriptloc/myAccountAdmin.log";
my $nmLog = "$scriptloc/NM.log";

#Starting the central_domain Admin Server
my $centraldomainScript = "/scratch/aime/work/CLOUDTOP/Middleware/user_projects/domains/central_domain/bin/startWebLogic.sh";
my $centraldomainAdminStart = "nohup $centraldomainScript >& $centraldomainLog &";
print "\nGoing to run the command $centraldomainAdminStart\n";
system($centraldomainAdminStart);

#Starting the MyAccount Admin Server
my $myAccountScript = "/scratch/aime/work/CLOUDTOP/Middleware/user_projects/domains/cpserver/MyAccount/bin/startWebLogic.sh";
my $myAccountAdminStart = "nohup $myAccountScript >& $myAccountLog &";
print "\nGoing to run the command $myAccountAdminStart\n";
system($myAccountAdminStart);


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
