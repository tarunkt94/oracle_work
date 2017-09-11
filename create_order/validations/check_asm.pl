#!/usr/bin/perl


use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;


my($ORACLE_HOME,$ORACLE_SID,$test,$logdir,$db_uniq_name,$db_name);

get_input();

validate_input();

remove_files();

my $status = get_asm_files();

validate_asm_files($status);

sub get_input{
	 GetOptions('ORACLE_HOME=s' =>\$ORACLE_HOME,
                   'ORACLE_SID=s' => \$ORACLE_SID,
                   'test=s' => \$test,
					'logdir=s' => \$logdir,
                   'db_uniq_name=s' => \$db_uniq_name,
		   'db_name=s' => \$db_name);
}

sub validate_input{
	if(!($ORACLE_HOME && $ORACLE_SID && $test && $db_uniq_name && $db_name )){
		die "\nArguments ORACLE_HOME, ORACLE_SID, test name, db_name  and db_uniq_name are mandatory\n";
	}
}

sub remove_files{
        my $cmd = "rm -f /tmp/$test*";
        system($cmd);
        print "\nRemoved the previous files from tmp directory\n";
}


sub get_asm_files{
	my $cmd = "export ORACLE_HOME=$ORACLE_HOME;export ORACLE_SID=$ORACLE_SID;";
	$cmd .= "asmcmd ls DATA/$db_uniq_name";
	my $status = `$cmd | tee /tmp/$test.log `;
	print"\n$status\n";
	return $status;
}

sub validate_asm_files{
	my $status = shift;
	my $errstr = "exception|ASMCMD-|error";
	if($status =~ /$errstr/i){
		system("touch /tmp/$test.dif");
		exit;
	}
	else{
		my $spfile = "spfile$db_name.ora";
		my $num = () = $status =~ /$spfile/g ;
		if($num ==1){
			system("touch /tmp/$test.suc");
			exit;
		}
		else{
			system("touch /tmp/$test.dif");
			exit;
		}
	}
	exit;
}
	
