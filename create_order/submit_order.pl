#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my ($tag,$version,$email,$bundle_scripts_loc,$pillar,$HA,$scriptDir,$help);
BEGIN
{
    use File::Basename;
    use Cwd;
    my $orignalDir = getcwd();
    $scriptDir = dirname($0);
    chdir($scriptDir);
    $scriptDir = getcwd();
    # add $scriptDir into INC
    unshift (@INC, "$scriptDir/../pm");
    chdir($orignalDir);
}


$bundle_scripts_loc = "$scriptDir/bundle_scripts" ; 

get_input();

validate_inputs();

chidr($bundle_scripts_loc) or die "Could not change directory to $bundle_scripts_loc\n";

modify_submit_bundle();

modify_complete_bundle();

submit_order();

sub get_input{
	GetOptions('tag=s' =>\$tag,
		   'version=s' => \$version,
		   'email=s' => \$email,
		   'bundle_scripts_loc=s' => \$bundle_scripts_loc,
		   'pillar=s' => \$pillar,
		   'HA' => \$HA,
		   'help' => \$help) or pod2usage(2);
}

sub validate_inputs{
	if(!($tag && $version && $email && $bundle_scripts_loc && $pillar) || $help){
		pod2usage(2);
	}
	die "All scripts are not present at the $bundle_scripts_loc\n " if (!((-f "$bundle_scripts_loc/complete_bundle.sql")&&(-f "$bundle_scripts_loc/gsi_bundle.sh") && (-f "$bundle_scripts_loc/submit_bundle.sql")));
}

sub modify_submit_bundle{
	
	my $tagcmd = "sed -i -e \"s/PRODUCT_RELEASE_VERSION.*/PRODUCT_RELEASE_VERSION\x27,\x27$version\x27"
		      ."\\\),tas.tas_key_value_t\\\(\x27TAGS\x27,\x27$tag\x27\\\)\\\);/\"";
	
	my $emailcmd = "sed -i -e \"s/email.*/email =>\x27$email\x27,/g\"";

	my $cmd = "$tagcmd submit_bundle.sql";
	run_system_cmd($cmd,"Error in changing tag name in submit_bundle.sql\n");

	$cmd = " $emailcmd submit_bundle.sql";
	run_system_cmd($cmd,"Error in changing email in submit_bundle.sql\n");

}

sub modify_complete_bundle{

	my $emailcmd = "sed -i -e \"s/email.*/email => \x27$email\x27\\\);/g\"";
	
	my $cmd = "$emailcmd complete_bundle.sql";
	run_system_cmd($cmd,"Error in changing email in complete_bundle.sql\n");

}

sub submit_order{
	my $org_id = 1000+int(rand(8999));
	my $order_id = 100+int(rand(899));
	my $pillar_submit = $pillar;
	$pillar_submit = 'ERP' if ($pillar eq 'GSI');
	my $submitoptions;
	$submitoptions = $HA ? "DEPLOY_TEST_INSTANCE_FALSE" : "PROV_TEST_BEFORE_PROD";
	
	my $cmd = './gsi_bundle.sh' . " $org_id $order_id $pillar_submit NONE $submitoptions";
	
	my $output = `$cmd`;
	print "\n$output\n";

	my $successStr = "PL/SQL procedure successfully completed";
	my $num = () = $output =~ /$successStr/g ;	

	if($num !=2){
		die "\nError in running the gsi_bundi.sh script.\n";
	}

	print "\nSubmitted the order successfully on with org id $org_id and order id $order_id\n";
}

sub run_system_cmd{
        my ($cmd,$fail_msg) = @_;
        my $ret_code = system($cmd);
        die "\n$fail_msg\n" unless $ret_code ==0;
}

