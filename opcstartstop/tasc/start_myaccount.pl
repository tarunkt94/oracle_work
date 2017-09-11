#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;


my $scriptloc = dirname($0);
chdir($scriptloc);
$scriptloc = getcwd();
my $myAccountLog = "/tmp/myaccount_$$.log";

#Starting the MyAccount Admin Server
my $myAccountScript = "/scratch/aime/work/CLOUDTOP/Middleware/user_projects/domains/cpserver/MyAccount/bin/startWebLogic.sh";
die "\nThe script $myAccountScript does not exist\n" unless (-f $myAccountScript);
my $myAccountAdminStart = "nohup $myAccountScript >& $myAccountLog &";
print "\nGoing to run the command $myAccountAdminStart\n";
system($myAccountAdminStart);


#print "\nSleeping for 300 seconds for the Admin Server to start\n";
#leep(300);

my $i=20;
my $sucstr = "Server started in RUNNING mode";
my $failstr = "Server started in ADMIN mode";
while($i!=0){
        my $output = `cat $myAccountLog`;

        last if($output =~ /$sucstr/i);
        if($output =~ /$failstr/i){
                die "\nAdmin server failed to start, is in Admin state , log file is $myAccountLog\n";
        }
        print"\nAdmin server has not yet started\n";
        sleep(30);
        $i--;
}

die "\nWaited for 10 mins for admin server to start, did not start \n" if($i==0);


print "Out of sleep, will bring up the managed servers now \n";

#starting the Managed Servers
chdir($scriptloc);
my $startMScmd = './WLS_Script.sh start_myaccount_managed.py';
my $retCode = system($startMScmd);
if($retCode !=0){
	exit(1);
}
