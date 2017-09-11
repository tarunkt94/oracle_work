#!/usr/bin/perl

use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;


my ($ORACLE_HOME,$ORACLE_SID,$test,$drmode,$db_uniq_name);

take_input();

validate_input();

remove_files();

my $status = get_status();

validate_status($status);

sub take_input{
         GetOptions('ORACLE_HOME=s' =>\$ORACLE_HOME,
                   'ORACLE_SID=s' => \$ORACLE_SID,
                   'test=s' => \$test,
                   'db_uniq_name=s' => \$db_uniq_name,
		   'drmode=s'=> \$drmode);
}

sub validate_input{
        if(!($ORACLE_HOME && $ORACLE_SID && $test && $db_uniq_name && $drmode)){
                die "\nArguments ORACLE_HOME, ORACLE_SID, test name , drmode and db_uniq_name are mandatory\n";
        }
}


sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub get_status{
	my $cmd = "export ORACLE_HOME=$ORACLE_HOME;export ORACLE_SID=$ORACLE_SID; dgmgrl sys/Welcome1 \"show database verbose $db_uniq_name\"";
	my $status = `$cmd | tee /tmp/$test.log `;
	print "\nStatus of DG Replication check is:\n$status\n";
	return $status; 
}

sub validate_status{
	my $status = shift;
	my $errstr = "exception|ORA-|error";
	my $sucstr = "SUCCESS";
	my $searchstr;
	
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
		exit(1);
	}
	if($status =~ /$sucstr/){
		if(uc($drmode) eq 'ACTIVE'){
			$searchstr = "Intended State.*APPLY-ON";
		}
		else{
			$searchstr = "Intended State.*APPLY-OFF";
		}
		if($status =~ /$searchstr/i){
			system("touch /tmp/$test.suc");
		}
		else{
			system("touch /tmp/$test.dif");
		}
		
	}
	
}

