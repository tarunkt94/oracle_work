#!/usr/bin/perl


use strict;
use warnings;
use Cwd;


my $cmd = "locate /bin/opmnctl | grep instances";
my $opmnloc = `$cmd`;
chomp $opmnloc;

my $opmnstartcmd = "$opmnloc startall";
system($opmnstartcmd);

my $opmnstatus = "$opmnloc status";
my $out = `$opmnstatus`;
print $out;

my $phrase = "Alive";

if($out =~ /$phrase/){
	print "\nopmn is up and running\n";
}
else{
        print "\nopmn is not running\nCheck manually\n";
        exit(1);
}

