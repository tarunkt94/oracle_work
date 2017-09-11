#!/usr/bin/perl

use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;

my ($db_uniq_name,$test);

get_input();

validate_input();

remove_files();

my $status = get_listener_status();

validate_status($status);

sub get_input{
        GetOptions('test=s' => \$test,
		   'db_uniq_name=s' => \$db_uniq_name);
}

sub validate_input{
	if(!($test and $db_uniq_name)){
		print "\nThe arguments test and db_uniq_name are mandatory\n";
	}
}

sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub get_listener_status{
	my $db_uniq_name = uc($db_uniq_name);
	my $cmd = "srvctl status listener -l LISTENER_$db_uniq_name";
	my $status = `$cmd | tee /tmp/$test.log `;
	print "\n$status\n";
	return $status;
}

sub validate_status{
	my $status = shift;
	my $errstr = "exception|ORA-|error";
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
		exit;
	}
	else{
		if($status =~ /enabled/i and $status =~ /running/i ){
			system("touch /tmp/$test.suc");
		}
		else{
			system("touch /tmp/$test.dif");
		}	
	}
	
}
