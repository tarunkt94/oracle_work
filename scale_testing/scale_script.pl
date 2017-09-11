#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::LibXML;
use Getopt::Long;
use Fcntl qw(:flock);

my ($logDir,$plan_names,@plan_names,$help,$steps,@steps,$emcli_dir);

get_input();

validate_input();

run_suite();

sub get_input{
	GetOptions('logDir=s' => \$logDir,
		   'plan_names=s' => \$plan_names,
		   'help' => \$help,
		   'steps=s' => \$steps,
		   'emcli_dir=s' => \$emcli_dir);	
}

sub validate_input{
	@plan_names = split(',',$plan_names);
	@steps = split(',',$steps);
	
	usage() if(defined $help);
	die"\nNon existent emcli directory\n" unless(-d $emcli_dir);
	die"\nemcli executable not present in the emcli directory\n" unless(-x "$emcli_dir/emcli");
	die"\nNumber of plans and steps given are not equal\n" unless( scalar(@plan_names) == scalar(@steps));
	system("mkdir -p $logDir");
	system("touch $logDir/master_log.log");
}


sub get_instance_id{

	my $plan_name=shift;
	my $cmd = "$emcli_dir/emcli run_prechecks -plan_name=\"$plan_name\"";

	my $output = `$cmd`;

	print "\n$output\n";

	if($output =~ /Execution Guid - (\w+)\b/){
	        my $instance_id = $1;
	        print "\nThe instance id is $instance_id for plan name $plan_name\n";
		return $instance_id;
	}
	else{	

		open(my $LOG,'>>',"$logDir/master_log.log");
		flock($LOG,2);
                print $LOG "\n[ERROR] Clould not get the instance id for the plan $plan_name\n";
                close($LOG);
		exit(1);
	}

}

sub run_suite{

	my $num = @plan_names;
	
	for(my $i=1;$i<=$num;$i++){
		
		my $pid = fork();
		if($pid==0){
			run_and_suspend($i);
		}
	}
	
}

sub run_and_suspend{
	my $num = shift;
	my $plan_name = $plan_names[$num-1];
	my $step_to_stop = $steps[$num-1];

	system("mkdir -p $logDir/logs$num");

	my $process_logDir = "$logDir/logs$num";
	my $basic_log = "$process_logDir/basic_log.log";

	my $instance_id = get_instance_id($plan_name);
	
	open(my $BASIC,">>",$basic_log);

	my $i=0;
	while(1){
		my $xmlfile = "$process_logDir/$i.xml";
	
		my $cmd = "$emcli_dir/emcli get_instance_status  -xml -details -showJobOutput -instance=$instance_id >  $xmlfile";
		print $BASIC "\nRunning the command $cmd\n";
		my $output = `$cmd`;
		print $BASIC "\n$output\n";

		$cmd  = "sed -i 's/xmlns.*\".*\"//' $xmlfile";
                print $BASIC "\nRunning the command $cmd\n";
                $output = `$cmd`;
                print $BASIC "\n$output\n";

		my $tree = XML::LibXML->load_xml(location => $xmlfile);

		my $status = $tree->findvalue("/procedureInstanceStatusDetails/step[\@name='$step_to_stop']/stateDetails/status");

		if($status eq ''){
			print $BASIC "\nThe job has not yet reached the step $step_to_stop\n";
		}
		elsif($status eq 'EXECUTING'){
			print $BASIC "\nThe job is currently executing the step $step_to_stop. Will suspend it now\n";
			my $cmd = "$emcli_dir/emcli suspend_instance -instance=$instance_id";
			print $BASIC "\nRunning the command $cmd\n";
			my $output = `$cmd`;
			print $BASIC "\n$output\n";

		        open(my $LOG,'|-'," tee $logDir/master_log.log");
		        flock($LOG,2);
			print $LOG "\n[INFO] The plan $plan_name with num $num and instance id $instance_id has been suspended successfully at $step_to_stop\n";
			close($LOG);
			close($BASIC);
			
			exit(0);
		}
		else{
                        open(my $LOG,'|-'," tee $logDir/master_log.log");
                        flock($LOG,2);
			print $LOG "\n[INFO] The plan $plan_name with num $num and instance id $instance_id has status of $status in step $step_to_stop. Not suspending it\n";
                        close($LOG);
			close($BASIC);
                        exit(1);

		}
		$i++;
		sleep(20);
	}
	
}

sub usage{
	print "\nWrong usage. try again\n";
}
