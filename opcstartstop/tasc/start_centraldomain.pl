#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;


my $scriptloc = dirname($0);
chdir($scriptloc);
$scriptloc = getcwd();
my $centraldomainLog = "/tmp/centraldomain_$$.log";
my $nmLog = "$scriptloc/NM.log";

#Starting the central_domain Admin Server
my $centraldomainScript = "/scratch/aime/work/CLOUDTOP/Middleware/user_projects/domains/central_domain/bin/startWebLogic.sh";
die "\nthe script $centraldomainScript does not exist\n" unless (-f $centraldomainScript);
my $centraldomainAdminStart = "nohup $centraldomainScript >& $centraldomainLog &";
print "\nGoing to run the command $centraldomainAdminStart\n";
system($centraldomainAdminStart);

#print "\nSleeping for 300 seconds for the Admin Server to start\n";
#sleep(300);

my $i=20;
my $sucstr = "Server started in RUNNING mode";
my $failstr = "Server started in ADMIN mode";
while($i!=0){
        my $output = `cat $centraldomainLog`;

        last if($output =~ /$sucstr/i);
        if($output =~ /$failstr/i){
                die "\nAdmin server failed to start, is in Admin state , log file is $centraldomainLog\n";
        }
        print"\nAdmin server has not yet started\n";
        sleep(30);
        $i--;
}

die "\nWaited for 10 mins for admin server to start, did not start \n" if($i==0);


print "\nOut of sleep, will start the Node manager now and wait for 60 seconds\n";

#Starting the NodeManager
my $nmLoc = "/scratch/aime/work/CLOUDTOP/Middleware/wlserver_10.3/server/bin/startNodeManager.sh";
die "\nNode manager script $nmLoc does not exist\n" unless (-f $nmLoc);
my $startNMcmd = "nohup $nmLoc >& $nmLog &";
print "\nGoing to run the command $startNMcmd\n";
system($startNMcmd);
sleep(60);

print "Out of sleep, will bring up the managed servers now \n";

#starting the Managed Servers
chdir($scriptloc);
my $startMScmd = './WLS_Script.sh start_centraldomain_managed.py';
my $retCode = system($startMScmd);
if($retCode !=0){
	exit(1);
}
