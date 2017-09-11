#!/usr/bin/perl


use strict;
use warnings;
use Cwd;

my $StartScriptsDir = "/u01/IDMTOP/config/scripts";
chdir($StartScriptsDir) or die "\nDirectory $StartScriptsDir is not present\n";

my $cmd = './startall.sh Fusionapps1 Fusionapps1';
my $checkPhrase = "Error while";


my $output =  `$cmd`;
my @outarr = split('\n',$output);

print "\n$output\n";
if(!($outarr[@outarr - 1] =~ /$checkPhrase/)){
        print "\nRan the scripts to start services on the host\nCheck manually to confirm services are up\n";
}
else{
        print "\nSeems like the scripts didn't run correctly\nCheck manually\n";
	exit 1;
}

