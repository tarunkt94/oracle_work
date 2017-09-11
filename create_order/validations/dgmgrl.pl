#!/usr/bin/perl

use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;


my ($ORACLE_HOME,$ORACLE_SID,$test,$drmode,$podtype,$db_uniq_name);

take_input();

validate_input();

remove_files();

my $status1 = get_dg_status();

my $status2 = get_dg_conf_status();

validate_status($podtype, $status1, $status2);

sub take_input{
         GetOptions('ORACLE_HOME=s' =>\$ORACLE_HOME,
                   'ORACLE_SID=s' => \$ORACLE_SID,
                   'test=s' => \$test,
			       'podtype=s' => \$podtype,
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


sub get_dg_status{
	my $cmd = "export ORACLE_HOME=$ORACLE_HOME;export ORACLE_SID=$ORACLE_SID; dgmgrl sys/Welcome1 \"show configuration\"";
	my $status = `$cmd | tee /tmp/$test.log `;
	print "\nStatus of DG configuration check is:\n$status\n";
	return $status; 
}

sub get_dg_conf_status{
	my $cmd = "export ORACLE_HOME=$ORACLE_HOME;export ORACLE_SID=$ORACLE_SID; dgmgrl sys/Welcome1 \"show database verbose $db_uniq_name\"";
	my $status = `$cmd | tee /tmp/$test.log `;
	print "\nStatus of DG configuration check is:\n$status\n";
	return $status; 
}


sub validate_status{
	my ($podtype, $test1_status, $test2_status) = @_;

	my $errstr = "exception|ORA-|error";
	my $sucstr = "SUCCESS";
	my ($searchstr1, $searchstr2);
	
	if($podtype eq "DR"){
		if($test1_status =~ /$errstr/i or $test2_status =~ /$errstr/i){
			system("touch /tmp/$test.dif");
			exit(1);
		}
		if($test2_status =~ /$sucstr/ and $test2_status =~ /$sucstr/){
			if(uc($drmode) eq 'ACTIVE'){
				$searchstr1 = "$db_uniq_name.*Primary database";
				$searchstr2 = "Intended State.*TRANSPORT-ON";
			}
			else{
				$searchstr1 = "$db_uniq_name.*Physical standby database";
				$searchstr2 = "Intended State.*APPLY-ON";
			}
			if($test1_status =~ /$searchstr1/i and $test2_status =~ /$searchstr2/i){
				system("touch /tmp/$test.suc");
			}
			else{
				system("touch /tmp/$test.dif");
			}			
		}
	}
	else
	{
		if($test1_status =~ /ORA-16525: The Oracle Data Guard broker is not yet available/i
			or $test1_status =~ /Configuration details cannot be determined by DGMGRL/i){
			system("touch /tmp/$test.suc");
		}
		else{system("touch /tmp/$test.dif");}
	}
}