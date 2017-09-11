#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my($user,$pswd,$storage,$sunprj,$test,$logDir);

get_input();

validate_input();

remove_files();

my $status = project_existence_status();

validate_project_existence($status);

sub get_input{
	GetOptions('storage=s' => \$storage,
		   'sunprj=s' => \$sunprj,
		   'user=s' => \$user,
		   'pswd=s' => \$pswd,
		   'test=s' => \$test,
		   'logDir=s' => \$logDir);
}

sub validate_input{
	if(!($storage and $sunprj and $user and $pswd )){
		system("touch $logDir/$test.dif");
		die "\nArguments storage and sunprj  and username and password are mandatory\n";
	}
}

sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub project_existence_status{
	my $cmd = "./sunStorageVerifyProjectExists.sh $user $pswd $storage $sunprj";
	print "\n$cmd\n";
	my $status = `$cmd`;
	print "\n$status\n";
	return $status;
}

sub validate_project_existence{
	my $status = shift;
	my $successStr = "$sunprj Present";
	if($status =~ /$successStr/i){
		system("touch $logDir/$test.suc");
	}
	else{
		system("touch $logDir/$test.dif");
	}
}
