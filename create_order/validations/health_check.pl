#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my($ORACLE_HOME,$APPS_BASE,$OHS_INSTANCE_ID,$OHS_HOST_NAME,$test);

get_input();


remove_files();

my $status = get_health_status();

validate_status($status);

sub get_input{
	GetOptions('ORACLE_HOME=s' => \$ORACLE_HOME,
		   'APPLICATIONS_BASE=s' => \$APPS_BASE,
		   'OHS_INSTANCE_ID=s' => \$OHS_INSTANCE_ID,
		   'OHS_HOST_NAME=s' => \$OHS_HOST_NAME,
		   'test=s' => \$test);
}

sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}

sub get_health_status{
	my $cmd = "export ORACLE_HOME=$ORACLE_HOME;";
	$cmd .= "export APPLICATIONS_BASE=$APPS_BASE;";
	$cmd .= "export OHS_INSTANCE_ID=$OHS_INSTANCE_ID;";
	$cmd .= "export OHS_HOST_NAME=$OHS_HOST_NAME;";
	$cmd .= '/u01/APPLTOP/fusionapps/applications/lcm/hc/bin/hcplug.sh';
	$cmd .= ' -manifest /u01/APPLTOP/fusionapps/applications/lcm/hc/config/SaaS/GeneralSystemHealthChecks.xml';
	$cmd .= ' -DlogLevel=FINEST';
	$cmd .= " | tee /tmp/$test.log";

	my $status = `$cmd`;
	print "\n$status\n";
	return $status;
}

sub validate_status{
	my $status = shift;
	my $errstr = 'error|failed|exception';
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
	}
	else{
		system("touch /tmp/$test.suc");
	}
}
