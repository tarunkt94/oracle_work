#!/usr/bin/perl

use strict;
use warnings;

BEGIN{
        push(@INC, '/scratch/aime/hari_slc06xjl/sampath/DR_AUTO_HOME/scripts/Cloud9/generic');
}

use JSON;

my $json_file_loc = '/scratch/aime/tarun/create_order/rel13.json';
my $json_object= readJSON($json_file_loc);

print $json_object->{DATABASES}{"??slc11rme"}{CRS_HOME}, "\n";

sub readJSON{
	
	my $json_file_loc = shift;
	my $json_input;
	{
		local $/ = undef;
		open my $json_file,'<',$json_file_loc;
		$json_input=<$json_file>;
		close $json_file;
	}

	$json_object = decode_json($json_input);
	return $json_object;
}
