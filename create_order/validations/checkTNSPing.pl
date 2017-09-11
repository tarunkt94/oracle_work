#!/usr/bin/perl

use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;


my ($ORACLE_HOME,$test,$drmode,$podtype,$db_name,$p_db_uniq_name,$s_db_uniq_name);

take_input();

validate_input();

remove_files();

my $status = get_status();

validate_status($status);

sub take_input{
         GetOptions('ORACLE_HOME=s' =>\$ORACLE_HOME,
                   'test=s' => \$test,
                   'db_name=s' => \$db_name,
                   'p_db_uniq_name=s' => \$p_db_uniq_name,
                   's_db_uniq_name=s' => \$s_db_uniq_name,
				   'drmode=s'=> \$drmode,
			       'podtype=s' => \$podtype);
}

sub validate_input{
        if(!($ORACLE_HOME && $test && $db_name && $p_db_uniq_name && $s_db_uniq_name && $drmode)){
                die "\nArguments ORACLE_HOME, test name, drmode, db_name, primary and standby db_uniq_names are mandatory\n";
        }
}


sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub get_status{

	my @tns_names=(); 

	my $p_db_uniq_nm = "dr_$p_db_uniq_name";
    my $s_db_uniq_nm = "dr_$s_db_uniq_name";

	@tns_names = ($p_db_uniq_nm, $p_db_uniq_nm.1, $p_db_uniq_nm.2, $s_db_uniq_nm, $s_db_uniq_nm.1, $s_db_uniq_nm.2);
	my ($status, $result);

	for my $tns_name (@tns_names)
    {	
		my $cmd = "export ORACLE_HOME=$ORACLE_HOME; cat $ORACLE_HOME/network/admin/tnsnames_orp4$db_name.ora | grep \"^$tns_name\"";
		$status = `$cmd | tee /tmp/$test.log `;
		if($status =~ /$tns_name/){
			if($podtype eq "DR"){
				print "\nDG TNS NAME exist for $tns_name :\n$status\n";
				$result .= "\nDG TNS NAME exist for $tns_name \n";
			}
			else
			{
				print "\nDG TNS NAME CLEANUP_UNSUCCESSFUL for $tns_name :\n$status\n";
				$result .= "\nDG TNS NAME CLEANUP_UNSUCCESSFUL for $tns_name \n";
			}
			print "\nValidating TNS Ping for tns string:\n$tns_name\n";
			$cmd = "export ORACLE_HOME=$ORACLE_HOME;export TNS_ADMIN=$ORACLE_HOME/network/admin; $ORACLE_HOME/bin/tnsping $tns_name";
			$status = `$cmd | tee /tmp/$test.log `;
			print "\nStatus of TNS Ping check for $tns_name is:\n$status\n";
			$result .= $status; 
		}
		else
		{	
			if($podtype eq "DR"){
				print "\nDG TNS NAME missing for $tns_name :\n$status\n";
				$result .= "\nDG TNS NAME missing for $tns_name \n";
			}
			else
			{
				print "\nDG TNS NAME CLEANUP_SUCCESSFUL for $tns_name :\n$status\n";
				$result .= "\nDG TNS NAME CLEANUP_SUCCESSFUL for $tns_name \n";
			}
		}
		$result .= $status; 

	}
	return $result;
}

sub validate_status{
	my $status = shift;
	my $errstr = "exception|ORA-|TNS-|error|missing|CLEANUP_UNSUCCESSFUL";
	my $sucstr = "SUCCESS|OK|CLEANUP_SUCCESSFUL";
	my $searchstr;
	
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
	}
	if($status =~ /$sucstr/){
		system("touch /tmp/$test.suc");
	}
		
	
}

