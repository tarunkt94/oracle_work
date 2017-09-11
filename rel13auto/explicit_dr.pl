#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

my($tasctl_loc,$service_name,$subs_id,$system_name);

get_input();

validate_input();

get_subs_id();

add_explicit_dr();

sub get_input{
	GetOptions('tasctl_loc=s' => \$tasctl_loc,
		   'service_name=s' => \$service_name)or usage();
}

sub validate_input{
	
	usage()  unless (defined($tasctl_loc) and defined($service_name));
	die "\nNo executable in the tasctl location $tasctl_loc. No such file\n" unless (-x "$tasctl_loc/tasctl");
}

sub get_subs_id{

	my $cmd = "$tasctl_loc/tasctl list_subscriptions --service_name $service_name --status ACTIVE";

	my $out = `$cmd`;

	my $subs_out = (split('\|',$out))[23];
	$subs_id =(split('\n',$subs_out))[4];

	$subs_id =~ s/^\s+//;
	$subs_id =~ s/\s+$//;

        die "No orders with the service name $service_name. Script failed with errors\n"  if ($subs_id eq '');
	
	print "\nSubs id is $subs_id\n";
}

sub add_explicit_dr{
	
	my $cmd = "$tasctl_loc/tasctl add_explicit_dr --subscription_id $subs_id";
	
	my $out = `$cmd`;
	print "\n$out\n";

	if($out =~ /error|no such|failed|fail|Command not found|Name or service not known/i){
		print "\nadd_explicit_dr failed with errors. Look into it\n";
		exit(1);
	}

}


sub usage{

	
print  <<"EOF";
The options tasctl and service_name are mandatory

tasctl_loc ->  location of the tasctl executable
service_name -> service name of the pod provisioned

Script failed with errors.
EOF
exit(1);
	
}

