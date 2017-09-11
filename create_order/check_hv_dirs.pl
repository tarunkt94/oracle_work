#!/usr/bin/perl

use strict;
use warnings;
BEGIN{
	push(@INC,'/scratch/aime/tarun/create_order/validations/pm');
}

use SDI;
use RemoteCmd;
use Logger;

my ($seed_pool,$relname,$pillar,$sdiuser,$sdipasswd,$sdihost);
my($sys_img_loc,$sys_img_bi_loc,$remoteObj,$template_name);

$pillar = 'GSI';

get_input();

create_object();

get_template_details();

create_dirs();

check_img_exists();

copy_sys_img();

untar_imgs();

sub get_input{
	GetOptions('seed_pool=s' => \$seed_pool,
		   'template_name=s' => \$template_name,
		   'sdiusername=s' => \$sdiuser,
		   'sdipasswd=s' => \$sdipasswd,
		   'sdihost=s' => \$sdihost,
		   'template_relname' => \$relname);
}

sub create_object{
        my $logObj = Logger->new(
                      {'loggerLogFile' => "/tmp/test.log",
                      'maxLogLevel' => 4}
                      );

	$remoteObj =  new RemoteCmd(user  => $sdiuser,
				       passwd => $sdipasswd,
				       logObj => $logObj);
}


sub create_dirs{

	
	$sys_img_loc = "$seed_pool/$template_name";
	$sys_img_bi_loc = $sys_img_loc . '_bi';

	
	my $cmd = "mkdir -p $sys_img_loc";

	run_system_cmd($cmd , "Could not create directory structure $cmd");	


	$cmd = "mkdir -p $sys_img_bi_loc";
	
        run_system_cmd($cmd , "Could not create directory structure $cmd");

}

sub check_img_exists{
	
	my $sys_img_file = $sys_img_loc . "/SystemImg.tar.gz";

	if( ! (-f $sys_img_file) ){
		print "\nSystem images do not exist in $sys_img_loc .  Copying them from SDI host\n";
		copy_sys_img();
	}
	else{
		print "\nSystem images already exist in the hypervisor\n";
	}
}

sub copy_sys_img{
	
	my $img_loc_sdi = "/fa_template/$relname/DedicatedIdm/paid/".uc($pillar)."/OVAB_HOME/vm";

	my $img_file_sdi = "$img_loc_sdi/SystemImg.tar.gz";

	my $destdir = $sys_img_loc;
	

	$remoteObj->copyFileToDir(host => $sdihost,
				  file => $img_file_sdi,
				  destdir => $destdir);

	my $bi_img_loc_sdi .= $img_loc_sdi . '/bi';

	$img_file_sdi = "$bi_img_loc_sdi/SystemImg.tar.gz";
	
	$destdir = $sys_img_bi_loc;
	
        $remoteObj->copyFileToDir(host => $sdihost,
                                  file => $img_file_sdi,
                                  destdir => $destdir);

}

sub untar_imgs{
	my $cmd = "tar -xvf $sys_img_loc/SystemImg.tar.gz -C $sys_img_loc";

	run_system_cmd($cmd , "Could not untar system image at $sys_img_loc\n");

	$cmd = "tar -xvf $sys_img_bi_loc/SystemImg.tar.gz -C $sys_img_bi_loc";

	run_system_cmd($cmd , "Could not untar system image at $sys_img_loc\n");
}


sub run_system_cmd{
        my ($cmd,$fail_msg) = @_;
        my $ret_code = system($cmd);
        die "\n$fail_msg\n" unless $ret_code ==0;
}

