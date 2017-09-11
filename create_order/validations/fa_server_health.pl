#!/usr/bin/perl

use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;

my ($test);

get_input();

validate_input();

remove_files();

my $status = get_server_status();

validate_server_status($status);

sub get_input{
	GetOptions("test=s" => \$test);
}

sub validate_input{
	die "\nThe test argument is mandatory\n" if(!$test);
}

sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}



sub get_server_status{
	my $cmd = '/u01/lcm/startstop_saas/fa_control.sh -c status -a all';
	my $output = `$cmd| tee /tmp/$test.log `;
	print "\n$output\n";
	return $output;
}

sub validate_server_status{
	my $status = shift;
	my $errstr = "exception|ASMCMD-|error|RESUMING|STARTING|SHUTDOWN";
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
	}
	else{
		system("touch /tmp/$test.suc");
	}
}
