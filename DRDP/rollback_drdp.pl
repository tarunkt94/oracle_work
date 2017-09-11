#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

my($patch_loc,$id,$oms_oracle_home,$help);

get_input();

validate_inputs();

$ENV{oms_oracle_home} = $oms_oracle_home;

rollback();

sub get_input{

	GetOptions('patch_loc=s' => \$patch_loc,
		   'id=i' => \$id,
		   'oms_oracle_home=s' => \$oms_oracle_home,
		   'help' => \$help) or pod2usage(2);
}

sub validate_inputs{

	if (!($patch_loc && $id && $oms_oracle_home) || $help){
		pod2usage(2);
	}
	die "Patch location $patch_loc does not exist\n" unless (-d $patch_loc);
	die "oms_oracle_home does not exist at $oms_oracle_home\n" unless (-d $oms_oracle_home);
}

sub rollback{

	chdir($patch_loc) or die "Could not go to $patch_loc\n";
	my $cmd = "$ENV{oms_oracle_home}/OPatch/opatch rollback -id $id -invPtrLoc $ENV{oms_oracle_home}/oraInst.loc";
	my $out = `$cmd`;
	print "\n$out\n";
	my $regex = 'OPatch succeeded';
	if($out =~ /$regex/){
		print "Rollback has succeeded\n";
		exit(0);
	}
	else{
		print "Rollback has failed\n";
		exit(1);
	}

}

__END__

=head1 NAME

rollback_drdp.pl

=head1 SYNOPSIS

The arguments patch_loc, id and oms_oracle_home are mandatory

Options :

patch_loc : Location of the patch that you want to rollback

id : Patch id

oms_oracle_home : Location of OMS Oracle Home

=cut




