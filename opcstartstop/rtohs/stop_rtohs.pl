#!/usr/bin/perl


use strict;
use warnings;
use Cwd;


my $cmd = "locate /bin/opmnctl | grep instances";
my $opmnloc = `$cmd`;
chomp $opmnloc;

my $opmnstopcmd = "$opmnloc stopall";
system($opmnstopcmd);


my $opmnstatus = "$opmnloc status";
my $out = `$opmnstatus`;
print $out;


my $phrase = "not running";
if($out =~ /$phrase/){
        print "\nopmn is down\n";
}
else{
	print "\nUnable to shutdown opmn. Check manually\n";
	exit(1);
}

