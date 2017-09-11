#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Cwd;
use File::Basename;

my ($em_hostname,$em_username,$em_passwd,$oms_oracle_home,$patch_loc,$prev_drdp_id,$current_drdp_version,$drdp_zip,$sdi_hostname,$sdi_username,$sdi_passwd,
    $take_bcackup,$sdi_unzip_loc,$utils_zip,$scriptDir,$emremoteObj,$sdiremoteObj,$oms_sysman_password,$drdp_unzip_loc,$rollback_prev_drdp,$apply_drdp,$stage_gen_param,
    $logDir,$take_backup);
BEGIN{
        my $originalDir = getcwd();
        $scriptDir = dirname($0);
        chdir($scriptDir);
        $scriptDir = getcwd();
        chdir($originalDir);
        push(@INC , "$scriptDir/../pm");
}
use RemoteCmd;

get_input();

build_object();

rollback() if( $rollback_prev_drdp =~ /true|y/i);

apply_drdp() if ($apply_drdp =~ /true|y/i);


sub get_input{
	GetOptions('em_hostname=s' => \$em_hostname,
		   'em_username=s' => \$em_username,
		   'em_passwd=s' => \$em_passwd,
		   'oms_oracle_home=s' => \$oms_oracle_home,
		   'patch_loc=s' => \$patch_loc,
		   'prev_drdp_id=s' => \$prev_drdp_id,
		   'current_drdp_version=s' => \$current_drdp_version,
		   'drdp_zip=s' => \$drdp_zip,
		   'utils_zip=s' => \$utils_zip,
		   'drdp_unzip_loc=s' => \$drdp_unzip_loc,
		   'oms_sysman_password=s' => \$oms_sysman_password,
		   'rollback_prev_drdp=s' => \$rollback_prev_drdp,
		   'apply_drdp=s' => \$apply_drdp,
		   'logDir=s' => \$logDir);
}

sub build_object{
	
        my $logObj = Logger->new(
                      {'loggerLogFile' => "$logDir/drdp.log",
                      'maxLogLevel' => 4}
                      );

	$emremoteObj = new RemoteCmd(user => $em_username,
					passwd => $em_passwd,
					logObj => $logObj);

	$sdiremoteObj = new RemoteCmd(user => $sdi_username,
					 passwd => $sdi_passwd,
					 logObj => $logObj);

}

sub rollback{
	my $file = "$scriptDir/rollback_drdp.pl";
	
	$emremoteObj->copyFileToHost(file => $file,host => $em_hostname, dest => '/tmp');

	my $cmd = "/tmp/rollback_drdp.pl -patch_loc $patch_loc -id $prev_drdp_id -oms_oracle_home $oms_oracle_home";

	my $out = $emremoteObj->executeCommandsonRemote(cmd => $cmd , host => $em_hostname);

	if (grep(/error|no such|failed|fail/i, @$out)){
		print "\nRollback has failed\n";
		exit(1);
    	} 
}

sub apply_drdp{
	my $file = "$scriptDir/apply_patch.pl";
	
	$emremoteObj->copyFileToHost(file => $file,host => $em_hostname, dest => '/tmp');

	my $cmd = "/tmp/apply_patch.pl -oms_oracle_home $oms_oracle_home -version $current_drdp_version -drdp_zip $drdp_zip";
	$cmd .= " -oms_sysman_password $oms_sysman_password -unzip_loc $drdp_unzip_loc";

	my $out = $emremoteObj->executeCommandsonRemote(cmd => $cmd , host => $em_hostname);

        if (grep(/\berror\b|no such|failed|fail/i, @$out)){
                print "\nApplying DRDP patch  has failed\n";
                exit(1);
        }

}

sub stage_gen_param{

	my $file = "$scriptDir/stage_dr_gen.pl"	;

	$sdiremoteObj->copyFileToHost(file => $file,host => $sdi_hostname, dest => '/tmp');

	my $cmd = "/tmp/stage_dr_gen.pl -unzip_loc $sdi_unzip_loc -utils_zip $utils_zip -take_backup $take_backup";

	my $out = $sdiremoteObj->executeCommandsonRemote(cmd => $cmd , host => $sdi_hostname);

        if (grep(/error|no such|failed|fail/i, @$out)){
                print "\nUnzipping utils zip  has failed\n";
                exit(1);
        }

}
