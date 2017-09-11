#!/usr/bin/perl

use strict;
use warnings;

my $hostname = `hostname`;

$hostname = (split('\.',$hostname))[0];

my $cmd = "/usr/local/packages/aime/ias/run_as_root \"/scratch/sftp_stage/cloudsftp_install.sh install -u ldap://$hostname:3060 -d 'dc=us,dc=oracle,dc=com' -b 'cn=orcladmin' -p 'Fusionapps1'\" >& /tmp/install_sftp.log";

my $ret_code = system($cmd);

if($ret_code >>8 !=0){
	print "\nSomething happened while installing sftp. Look at the log file /tmp/install_sftp.log\n";
	exit 1;
}

