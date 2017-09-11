#!/usr/bin/perl

use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;

my ($GRID_HOME,$db_uniq_name,$podtype,$test);

get_input();

validate_input();

remove_files();

my $status = get_listener_dg_status();

validate_status($status);

sub get_input{
        GetOptions('test=s' => \$test,
		  'GRID_HOME=s' => \$GRID_HOME,
	       'podtype=s' => \$podtype,
		   'db_uniq_name=s' => \$db_uniq_name);
}

sub validate_input{
	if(!($test and $db_uniq_name and $GRID_HOME)){
		print "\nThe arguments test and db_uniq_name and grid home are mandatory\n";
	}
}

sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub get_listener_dg_status{
	my $db_uniq_name = uc($db_uniq_name);
	my ($cmd, $status, $result);

	$cmd = "$GRID_HOME/bin/srvctl status listener -l LISTENER_DG";
	$status = `$cmd | tee /tmp/$test.log `;
	print "\n$status\n";
	$result .= $status;
	
	if($podtype eq "DR"){
		$cmd = "$GRID_HOME/bin/lsnrctl status listener | grep -i \"$db_uniq_name\_DGMGRL\\|$db_uniq_name\_DGB\" ";
		$status = `$cmd | tee /tmp/$test.log `;
		print "\n$status\n";
	
		if($status =~ /$db_uniq_name\_DGMGRL/i and $status =~ /$db_uniq_name\_DGB/i){
			print "\nDGMGRL and DGB services exist for $db_uniq_name in LISTENER_DG\n";
			$result .= "\nDGMGRL and DGB services exist for $db_uniq_name in LISTENER_DG\n";
			$result .= $status;
		}
		else
		{
			print "\nDGMGRL and DGB services missing for $db_uniq_name in LISTENER_DG\n";
			$result .= "\nEither of DGMGRL/DGB services missing for $db_uniq_name in LISTENER_DG\n";
			$result .= $status;
		}
		
		$cmd = "cat $GRID_HOME/network/admin/listener_dg.ora | grep -i \"$db_uniq_name\_DGMGRL\"";
		$status = `$cmd | tee /tmp/$test.log `;
		print "\n$status\n";
		if($status =~ /$db_uniq_name\_DGMGRL/i){
			print "\n$db_uniq_name\_DGMGRL exist in LISTENER_DG\n";
			$result .= "\n$db_uniq_name\_DGMGRL exist in LISTENER_DG\n";
			$result .= $status;
		}
		else
		{
			print "\n$db_uniq_name\_DGMGRL missing in LISTENER_DG\n";
			$result .= "\n$db_uniq_name\_DGMGRL missing in LISTENER_DG\n";
			$result .= $status;
		}
	}
	else{

		$cmd = "$GRID_HOME/bin/lsnrctl status listener | grep -i \"$db_uniq_name\_DGB\"";
		$status = `$cmd | tee /tmp/$test.log `;
		print "\n$status\n";

		if($status =~ /$db_uniq_name\_DGB/i){
			print "\nDGB service CLEANUP_UNSUCCESSFUL for $db_uniq_name in LISTENER_DG\n";
			$result .= "\nDGB service CLEANUP_UNSUCCESSFUL for $db_uniq_name in LISTENER_DG\n";
			$result .= $status;
		}
		else
		{
			print "\nDGB services CLEANUP_SUCCESSFUL for $db_uniq_name in LISTENER_DG\n";
			$result .= "\nDGB services CLEANUP_SUCCESSFUL for $db_uniq_name in LISTENER_DG\n";
			$result .= $status;
		}
		
		$cmd = "cat $GRID_HOME/network/admin/listener_dg.ora | grep -i \"$db_uniq_name\_DGMGRL\"";
		$status = `$cmd | tee /tmp/$test.log `;
		print "\n$status\n";
		if($status =~ /$db_uniq_name\_DGMGRL/i){
			print "\n$db_uniq_name\_DGMGRL CLEANUP_UNSUCCESSFUL in LISTENER_DG\n";
			$result .= "\n$db_uniq_name\_DGMGRL CLEANUP_UNSUCCESSFUL in LISTENER_DG\n";
			$result .= $status;
		}
		else
		{
			print "\n$db_uniq_name\_DGMGRL CLEANUP_SUCCESSFUL in LISTENER_DG\n";
			$result .= "\n$db_uniq_name\_DGMGRL CLEANUP_SUCCESSFUL in LISTENER_DG\n";
			$result .= $status;
		}
	}

	return $result;
}

sub validate_status{
	my $status = shift;
	my $errstr = "exception|ORA-|error|missing|CLEANUP_UNSUCCESSFUL";
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
		exit;
	}
	else{
		if($status =~ /enabled/i and $status =~ /running/i 
			and ($status =~ /exist/i or $status =~ /CLEANUP_SUCCESSFUL/i)){
			system("touch /tmp/$test.suc");
		}
		else{
			system("touch /tmp/$test.dif");
		}	
	}
	
}
