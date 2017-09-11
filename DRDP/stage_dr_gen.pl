#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Cwd;

my ($cmd,$utils_zip,$unzip_loc,$take_backup,$help);

get_input();

validate_inputs();

take_dir_backup();

stage_genparams();

sub get_input{

	GetOptions('unzip_loc=s' => \$unzip_loc,
		   'utils_zip=s' => \$utils_zip,
		   'take_backup=s' => \$take_backup,
		   'help' => \$help) or pod2usage(2);

}

sub validate_inputs{

	if(!( $utils_zip && $unzip_loc && $take_backup) || $help){
		pod2usage(2);
	}
	die "No file exists at the given utils zip location $utils_zip\n" unless (-f $utils_zip);
	
	die "The location $unzip_loc does not exist\n" unless (-d $unzip_loc);
	
	take_dir_backup() if( lc($take_backup) eq 'yes' or lc($take_backup) eq 'y' );
}

sub take_dir_backup{

	my $backup_loc = $unzip_loc . '.bak';
	$cmd = "mv $unzip_loc $backup_loc";
	run_system_cmd($cmd,"Could not take backup with the command $cmd\n");
}

sub stage_genparams{
	
	$cmd = "unzip $utils_zip -d $unzip_loc";
	run_system_cmd($cmd,"Could not unzip the utils zip at $unzip_loc\n");

}


sub run_system_cmd{
	my ($cmd,$fail_msg) = @_;
	my $ret_code = system($cmd);
	die "\n$fail_msg\n" unless $ret_code ==0;
}

__END__ 

=head1 NAME

stage_dr_gen.pl

=head1 SYNOPSIS

The arguments release , utils_zip , and pillar  are mandatory
Default location of fsnadmin is taken to be /fsnadmin

Options:

release : Specify the release and stage number combined, as it would be present under fsnadmin
utils_zip :  Utils zip location
fsnadmin :  Default value taken to be fansadmin, provide this option if fsnadmin is present under a different location
pillar : Give the pillar

=cut 
