#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

my($test,$project_name,$drmode);

get_input();

validate_input();

remove_files();

my $fs_tab_info = get_fstab_info();

validate_fs_tab_info($fs_tab_info);

my $mount_info = get_mount_info();

validate_mount_info($mount_info);



sub get_input{
         GetOptions('project_name=s' =>\$project_name,
                    'test=s' => \$test,
		    'drmode=s' => \$drmode);	
}

sub validate_input{
	if(!($test && $project_name)){
		die "\nThe arguments test and project name are mandatory\n";
	}
}

sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub get_fstab_info{
	my $cmd = "cat /etc/fstab";
	if($test =~ /osn/){
		$cmd .= '|grep -E "u01|osn_scratch"';
	}
	else{
		$cmd .= '|grep -E "u01"';
	}
	$cmd .= "| grep $project_name ";
	my $fs_tab_info = `$cmd | tee /tmp/$test.log `;
	print "\n$fs_tab_info\n";
	return $fs_tab_info;
}

sub validate_fs_tab_info{
	my $fs_tab_info = shift;
	
	my $errstr = "exception|error";
	if($fs_tab_info =~ /$errstr/i){
		system("touch /tmp/$test.dif");
		exit;
	}
	my $expected_num = 1;
	$expected_num = 2 if($test =~ /osn/);

	my $num = () = $fs_tab_info =~ /u01/g;
	if($num != $expected_num){
		my $cmd = "echo -e '\nfstab entries are incorrect\n' |  tee -a /tmp/$test.log ";
		system($cmd);
		system("touch /tmp/$test.dif");
		exit 1;
	}
}

sub get_mount_info{
	my $cmd = 'df -h| grep u01 -B 1';
	my $status = `$cmd | tee -a /tmp/$test.log `;
	print "\n$status\n";
	return $status;
}

sub validate_mount_info{
	my $mount_info = shift;

	my $num = () = $mount_info =~ /u01/g ;
	my $expected_num = 1;
	$expected_num = 0 if(lc($drmode) =~ /passive/);
	if( $num == $expected_num ){
		 system("touch /tmp/$test.suc");
	}
	else{
                my $cmd = "echo -e '\nThere is a discrepancy with mount points\n' | tee -a /tmp/$test.log ";
                system($cmd);
		
		system("touch /tmp/$test.dif");
	}
}
