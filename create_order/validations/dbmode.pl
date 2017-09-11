#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

my($ORACLE_HOME,$ORACLE_SID,$db_name,$drmode,$test);

get_input();

validate_input();

remove_files();

my $mode = get_db_mode();

validate_db_mode($mode);

sub get_input{
         GetOptions('ORACLE_HOME=s' =>\$ORACLE_HOME,
                   'ORACLE_SID=s' => \$ORACLE_SID,
                   'test=s' => \$test,
                   'db_name=s' => \$db_name,
                   'drmode=s' => \$drmode);
}

sub validate_input{
        if(!($ORACLE_HOME && $ORACLE_SID && $test && $db_name && $drmode)){
                die "\nArguments ORACLE_HOME, ORACLE_SID, test name , drmode and db_uniq_name are mandatory\n";
        }
}


sub remove_files{
        my $cmd = `rm -f /tmp/$test*`;
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub get_db_mode{
	my $cmd = "export ORACLE_HOME=$ORACLE_HOME;export ORACLE_SID=$ORACLE_SID;";
	$cmd .= 'echo \'select db_unique_name, name, open_mode, database_role from gv$database;\' |sqlplus / as sysdba';
	
	my $output = `$cmd | tee /tmp/$test.log `;	
	print "\n$output\n";
	return $output;
}

sub validate_db_mode{
	my $status = shift;
	my $errstr = "exception|ORA-|error";
	my $db_uniq_name = uc($db_name);
	my $searchstr;
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
		exit;
	}
	else{
		if(uc($drmode) eq 'ACTIVE'){
			$searchstr = "$db_name.*READ WRITE";
		}
		else{
			$searchstr = "$db_name.*READ ONLY";
		}
		if($status =~ /$searchstr/i){
			system("touch /tmp/$test.suc");
		}
		else{
			system("touch /tmp/$test.dif");
		}
	}
}
