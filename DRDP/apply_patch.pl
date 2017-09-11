#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Cwd;


my ($oms_oracle_home,$version,$ARU,$drdp_zip,$oms_sysman_password,$unzip_loc,$help);

get_input();

validate_inputs();

get_ARU();

$ENV{ORACLE_HOME} = $oms_oracle_home;
$ENV{OPATCH} = "$oms_oracle_home/OPatch";
$ENV{EM_BIN} = "$oms_oracle_home/bin";

unzip_file();

apply_patch();

post_install();

sub get_input{
	GetOptions('oms_oracle_home=s' => \$oms_oracle_home,
		   'version=s' => \$version,
		   'drdp_zip=s' => \$drdp_zip,
		   'oms_sysman_password=s' => \$oms_sysman_password,
		   'unzip_loc=s' => \$unzip_loc,
		   'help' => \$help) or pod2usage(2);

}

sub validate_inputs{

	if(!($oms_oracle_home && $version  && $drdp_zip && $oms_sysman_password && $unzip_loc) || $help){
		pod2usage(2);
	}
	die "Give the version in 5 digit format, ex : 1.8.2.0.0 \n" if($version !~ /\d+\.\d+\.\d+\.\d+\.\d+/);
	die "No file exists at the given patch location $drdp_zip\n" unless(-f $drdp_zip);
	die "Location $oms_oracle_home does not exist\n" unless (-d $oms_oracle_home);
	system("mkdir -p $unzip_loc");
}

sub get_ARU{
	
	my $cmd = "unzip -l $drdp_zip";
	my $out = `$cmd`;

	my $line = (split("\n",$out))[3];
	my $dir = (split('\s+',$line))[4];
	$ARU = (split('/',$dir))[0];

}

sub unzip_file{

	chdir($unzip_loc) or die "Cannot go to $unzip_loc directory\n";

	my $cmd = "unzip $drdp_zip -d .";
	run_system_cmd($cmd,"Error in unzipping the file");
}

sub apply_patch{

	my $loc = "$unzip_loc/$ARU";

	chdir("$loc") or die "Could not go to $loc\n";

	my $cmd = "echo 'y' \| $ENV{OPATCH}/opatch apply -oh $ENV{ORACLE_HOME} -invPtrLoc $ENV{ORACLE_HOME}/oraInst.loc";

	my $out = `$cmd`;

	print "\n$out\n";

	if($out =~ /OPatch succeeded/i){
		print "OPatch has succeeded\n";
	}
	else{
		print "OPatch has failed\n Look into it\n";
		exit(1);
	}

}

sub post_install{

	my $cmd =  "$ENV{EM_BIN}/emctl register oms metadata -service swlib -core -file_list"
		." $ENV{ORACLE_HOME}/sysman/metadata/swlib/contentmgmt/$version/FILELIST_pbu_swlib_core_disasterrecovery";
	register_service($cmd);

	$cmd =  "$ENV{EM_BIN}/emctl register oms metadata -service  procedures -core -file_list"
		." $ENV{ORACLE_HOME}/sysman/metadata/procedures/contentmgmt/$version/FILELIST_pbu_procedures_core_disasterrecovery";
	register_service($cmd);

	$cmd =  "$ENV{EM_BIN}/emctl register oms metadata -service jobTypes -core -file_list"
		." $ENV{ORACLE_HOME}/sysman/metadata/jobs/contentmgmt/$version/FILELIST_pbu_jobs_core_disasterrecovery";
	register_service($cmd);

	print "Registered the services and applied the patch on EM, will stage fa_dr_genparams now\n";
}

sub register_service{

        my $cmd = shift;


        my $new_cmd = "echo '$oms_sysman_password' \| $cmd ";
        my $fail_regex = qr/unsuccessful|failed|invalid/i;

        my $out = `$new_cmd`;
        print "\n$new_cmd\n\n$out\n";
        if($out =~ /$fail_regex/){
                print "\nRegistration of service failed\n";
                exit(1);
        }

        print "\nRegistration of service successful\n";
}

sub run_system_cmd{
	my ($cmd,$fail_msg) = @_;
	my $ret_code = system($cmd);
	die "\n$fail_msg\n" unless $ret_code ==0;
}

__END__ 

=head1 NAME

apply_patch.pl

=head1 SYNOPSIS

The arguments oms_oracle_home, version of the DRDP patch, ARU number, patch location , unzip location and sysman password for EMGC are mandatory

The version should be given in 5 numbers format , ex : 1.8.2.0.0

Options :

oms_oracle_home : Location of OMS on the host
version : THE DRDP version to be installed , give it in 5 numbers format , ex : 1.8.2.0.0
ARU : Bug Number of the patch
drdp_zip : location of the DRDP patch 
oms_sysman_password : password for the sysman account
unzip_loc : Location where the DRDP patch should be applied 

Ex : apply_patch.pl -oms_oracle_home /scratch/aime/work/CLOUDTOP/Middleware/MIDDLEWARE/EM/oms -version 1.8.2.0.0 -ARU 25293218 -drdp_zip /ade_autofs/gd24_lcm/LCMSERVICE_MAIN_GENERIC.rdd/161222.0818/lcmservice/dist/zips/opatch/fadr_161222_25293218.zip -oms_sysman_password *** - unzip_loc /scratch/aime/LCMDRPatch/DRDP_1.6.3.4

=cut 
