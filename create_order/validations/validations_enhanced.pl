#!/usr/bin/perl


use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;
use Cwd;
use File::Basename; 

my($p_ovm_smc_props,$p_drmode,$s_ovm_smc_props,$s_drmode,$drmode,$mailid,$logdir,$logObj,$remoteDB,$remoteFA,$html_message,$sys_name,$scriptDir,%ovmHash,%p_ovmHash,%s_ovmHash);

BEGIN{
	my $orignalDir = getcwd();
	$scriptDir = dirname($0);
	chdir($scriptDir);
	$scriptDir = getcwd();
        # add $scriptDir into INC
	unshift (@INC, "$scriptDir/../../pm");
	chdir($orignalDir);

}
use RemoteCmd;
use Logger;
use Mail;


get_input();

validate_inputs();

%p_ovmHash = read_props_file($p_ovm_smc_props);

$html_message = '<table width = 100% border=0><tr><td><h2><u><center>DR VALIDATIONS Report</center></u></h2></td></tr></table>';

my $logdir_parent = $logdir;

$logdir = "$logdir_parent/primary";
system("mkdir -p $logdir");

%ovmHash = %p_ovmHash;
prepare_objects();

$drmode = $p_drmode;
start_test_suite();

if(defined($s_ovm_smc_props)){

	%s_ovmHash = read_props_file($s_ovm_smc_props);

	$logdir = "$logdir_parent/standby";
	system("mkdir -p $logdir");

	%ovmHash = %s_ovmHash;
	prepare_objects();

	$drmode = $s_drmode;
	start_test_suite();
	
}

sendmail();

sub get_input{
	GetOptions('p_ovm_smc_props=s' => \$p_ovm_smc_props,
		   's_ovm_smc_props=s' => \$s_ovm_smc_props,
		   'p_drmode=s' => \$p_drmode,
		   's_drmode=s' => \$s_drmode,
		   'mailid=s' => \$mailid,
		   'logdir=s' => \$logdir,
		   'sys_name=s' => \$sys_name) or usage();
}

sub validate_inputs{
	if(!($p_ovm_smc_props and $p_drmode and $mailid and $logdir and $sys_name)){
		usage();
	}
	die "\nNo file present at $p_ovm_smc_props\n" unless (-f $p_ovm_smc_props);
	
	if(defined ($s_ovm_smc_props)){
		usage() unless ( defined ($s_drmode) and (-f $s_ovm_smc_props));
	}

}

sub read_props_file{
        my $file =shift;
        my %hash ;

        open(my $FH, '<', $file);
        while(my $line = <$FH>){
                if($line !~ /^#/ and $line !~ /^\s+$/){
                        $line =~ s/^\s+//;
                        $line =~ s/\s+$//g;
                        my $key = (split('=',$line))[0];
                        my $value = (split('=',$line))[1];
                        $hash{$key} = $value;
                }
        }
        return %hash;
}


sub prepare_objects{

	$logObj = new Logger(
                          {'loggerLogFile' => "$logdir/full_validations_log.log",
                           'maxLogLevel' => 4}
                          );
	
	my $db_user_name = $ovmHash{'faovm.smc.fusiondb.new.host.login.user.name'};
	my $db_password = 'oracle'; 
	$remoteDB = new RemoteCmd(user => $db_user_name,
       				    passwd => $db_password,
        			    logObj => $logObj);

        $remoteFA = new RemoteCmd(user => 'oracle',
                                    passwd => 'Welcome1',
                                    logObj => $logObj);
 
}

sub start_test_suite{

	$ovmHash{'fadb_uniq_name'} = $ovmHash{'faovm.smc.fusiondb.new.dbuniquename'};
	$ovmHash{'fadb_rac1_sid'} = $ovmHash{'faovm.smc.fusiondb.new.rac.sid1'};
	$ovmHash{'fadb_rac2_sid'} = $ovmHash{'faovm.smc.fusiondb.new.rac.sid2'};
	$ovmHash{'fadb_oracle_home'} = $ovmHash{'faovm.smc.fusiondb.new.oracle.home'};
	$ovmHash{'fadb_grid_home'} = $ovmHash{'faovm.smc.fusiondb.new.crs.home'};
	$ovmHash{'fadb_name'} = $ovmHash{'faovm.smc.fusiondb.new.dbname'};

	
	$ovmHash{'oiddb_uniq_name'} = $ovmHash{'faovm.smc.oiddb.new.dbuniquename'};
	$ovmHash{'oiddb_rac1_sid'} = $ovmHash{'faovm.smc.oiddb.new.rac.sid1'};
        $ovmHash{'oiddb_rac2_sid'} = $ovmHash{'faovm.smc.oiddb.new.rac.sid2'};
        $ovmHash{'oiddb_oracle_home'} = $ovmHash{'faovm.smc.oiddb.new.oracle.home'};
        $ovmHash{'oiddb_grid_home'} = $ovmHash{'faovm.smc.oiddb.new.crs.home'};
	$ovmHash{'oiddb_name'} = $ovmHash{'faovm.smc.oiddb.new.dbname'};

 
	$ovmHash{'fa_host'} = $ovmHash{'faovm.smc.HOST_FA'};
	$ovmHash{'idm_host'} = $ovmHash{'faovm.smc.HOST_IDM_MIDTIER'};
	$ovmHash{'ohs_host'} = $ovmHash{'faovm.smc.HOST_OHS'};
	$ovmHash{'rac_node1'} = $ovmHash{'faovm.smc.HOST_DB'};
	$ovmHash{'rac_node2'} = $ovmHash{'faovm.smc.HOST_DB2'};

	$ovmHash{'asm_sid'} = $ovmHash{'faovm.smc.fusiondb.new.asm.sid'};
	$ovmHash{'asm_sid2'} = '+ASM2';

	$ovmHash{'sun_username'} = $ovmHash{'faovm.storage.sun.username'};
	$ovmHash{'sun_pswd'} = 'fadr';
	$ovmHash{'sun_proj'} = $ovmHash{'faovm.storage.sun.project'};
	$ovmHash{'sun_storage'} = $ovmHash{'faovm.storage.sun.host'};
	
	$html_message .= "<br><b>DR MODE: </b>' \n" . $drmode . '<br><table width = 90% border=0><tr bgcolor=#56A5EC><th>Testcase Name</th><th>Description </th><th>Result</th></tr>' . "\n";


	check_asm_test($remoteDB);
	
	check_mounts($remoteFA);

	check_db_mode($remoteDB);	

	check_dg_conf($remoteDB);

	check_lsnr_stat($remoteDB);

	check_proj_exists();

	if (uc($drmode) =~ /ACTIVE/){

		check_server_health($remoteFA);

		check_health($remoteFA);
	}
	$html_message .= "</table>";	
	
}
 
sub check_asm_test{
	
	run_test('asm_fa_rac1',"$scriptDir/check_asm.pl",$ovmHash{'rac_node1'},$remoteDB,
		 ORACLE_HOME => $ovmHash{'fadb_grid_home'},
		 ORACLE_SID => $ovmHash{'asm_sid'},
		 db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
		 db_name => $ovmHash{'fadb_name'});

	generate_msg('asm_fa_rac1','Check spfile exists on ASM Disk');

        run_test('asm_oid_rac1',"$scriptDir/check_asm.pl",$ovmHash{'rac_node1'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'oiddb_grid_home'},
                 ORACLE_SID => $ovmHash{'asm_sid'},
                 db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
		 db_name => $ovmHash{'oiddb_name'});

        generate_msg('asm_oid_rac1','Check spfile exists on ASM Disk',$html_message);

	
	run_test('asm_fa_rac2',"$scriptDir/check_asm.pl",$ovmHash{'rac_node2'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'fadb_grid_home'},
                 ORACLE_SID => $ovmHash{'asm_sid2'},
                 db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
                 db_name => $ovmHash{'fadb_name'});

	generate_msg('asm_fa_rac2','Check spfile exists on ASM Disk',$html_message);	


	run_test('asm_oid_rac2',"$scriptDir/check_asm.pl",$ovmHash{'rac_node2'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'oiddb_grid_home'},
                 ORACLE_SID => $ovmHash{'asm_sid2'},
                 db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
                 db_name => $ovmHash{'oiddb_name'});
	
	generate_msg('asm_oid_rac2','Check spfile exists on ASM Disk',$html_message);

}

sub check_mounts{
	run_test('fa_mounts',"$scriptDir/check_mount.pl",$ovmHash{'fa_host'},$remoteFA,
		 project_name =>  $ovmHash{'sun_proj'},
		 'drmode' => $drmode);
	
	generate_msg('fa_mounts','Verify mounts on FA host',$html_message);

	run_test('idm_mounts',"$scriptDir/check_mount.pl",$ovmHash{'idm_host'},$remoteFA,
                 project_name =>  $ovmHash{'sun_proj'},
                 'drmode' => $drmode);

	generate_msg('idm_mounts','Verify mounts on IDM host',$html_message);

	run_test('ohs_mounts',"$scriptDir/check_mount.pl",$ovmHash{'ohs_host'},$remoteFA,
                 project_name =>  $ovmHash{'sun_proj'},
                 'drmode' => $drmode);

	generate_msg('ohs_mounts','Verify mounts on OHS host',$html_message);

}

sub check_db_mode{
	
	run_test('dbmode_fa_rac1',"$scriptDir/dbmode.pl",$ovmHash{'rac_node1'},$remoteDB,
		 ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
                 ORACLE_SID => $ovmHash{'fadb_rac1_sid'},
                 db_name =>  $ovmHash{'fadb_name'},
		 drmode => $drmode);

	generate_msg('dbmode_fa_rac1','Check DB Mode',$html_message);

	run_test('dbmode_fa_rac2',"$scriptDir/dbmode.pl",$ovmHash{'rac_node2'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
                 ORACLE_SID => $ovmHash{'fadb_rac2_sid'},
                 db_name =>  $ovmHash{'fadb_name'},
                 drmode => $drmode);

	generate_msg('dbmode_fa_rac2','Check DB Mode',$html_message);

        run_test('dbmode_oid_rac1',"$scriptDir/dbmode.pl",$ovmHash{'rac_node1'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
                 ORACLE_SID => $ovmHash{'oiddb_rac1_sid'},
                 db_name =>  $ovmHash{'oiddb_name'},
                 drmode => $drmode);

	generate_msg('dbmode_oid_rac1','Check DB Mode',$html_message);

        run_test('dbmode_oid_rac2',"$scriptDir/dbmode.pl",$ovmHash{'rac_node2'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
                 ORACLE_SID => $ovmHash{'oiddb_rac2_sid'},
                 db_name =>  $ovmHash{'oiddb_name'},
                 drmode => $drmode);

	generate_msg('dbmode_oid_rac2','Check DB Mode',$html_message);

}

sub check_dg_conf{

	run_test('dgconf_fa_rac1',"$scriptDir/dgmgrl.pl",$ovmHash{'rac_node1'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
                 ORACLE_SID => $ovmHash{'fadb_rac1_sid'},
                 db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
                 drmode => $drmode);

	generate_msg('dgconf_fa_rac1','Checks the DG configuration on the node ',$html_message);

        run_test('dgconf_fa_rac2',"$scriptDir/dgmgrl.pl",$ovmHash{'rac_node2'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
                 ORACLE_SID => $ovmHash{'fadb_rac2_sid'},
                 db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
                 drmode => $drmode);
	
	generate_msg('dgconf_fa_rac2','Checks the DG configuration on the node',$html_message);

        run_test('dgconf_oid_rac1',"$scriptDir/dgmgrl.pl",$ovmHash{'rac_node1'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
                 ORACLE_SID => $ovmHash{'oiddb_rac1_sid'},
                 db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
                 drmode => $drmode);

	generate_msg('dgconf_oid_rac1','Checks the DG configuration on the node',$html_message);

        run_test('dgconf_oid_rac2',"$scriptDir/dgmgrl.pl",$ovmHash{'rac_node2'},$remoteDB,
                 ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
                 ORACLE_SID => $ovmHash{'oiddb_rac2_sid'},
                 db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
                 drmode => $drmode);
	
	generate_msg('dgconf_oid_rac2','Checks the DG configuration on the node');

}

sub check_lsnr_stat{
	run_test('lnsr_fa_rac1',"$scriptDir/listener_check.pl",$ovmHash{'rac_node1'},$remoteDB,
		 db_uniq_name => $ovmHash{'fadb_uniq_name'});

	generate_msg('lnsr_fa_rac1','Check listener status',$html_message);

	run_test('lnsr_fa_rac2',"$scriptDir/listener_check.pl",$ovmHash{'rac_node2'},$remoteDB,
                 db_uniq_name => $ovmHash{'fadb_uniq_name'});

	generate_msg('lnsr_fa_rac2','Check listener status',$html_message);

	run_test('lnsr_oid_rac1',"$scriptDir/listener_check.pl",$ovmHash{'rac_node1'},$remoteDB,
                 db_uniq_name => $ovmHash{'oiddb_uniq_name'});

	generate_msg('lnsr_oid_rac1','Check listener status',$html_message);

        run_test('lnsr_oid_rac2',"$scriptDir/listener_check.pl",$ovmHash{'rac_node2'},$remoteDB,
                 db_uniq_name => $ovmHash{'oiddb_uniq_name'});

	generate_msg('lnsr_oid_rac2','Check listener status',$html_message);

}

sub check_proj_exists{
	
	my $cmd = "$scriptDir/sunStorageVerifyProjectExists.sh $ovmHash{'sun_username'} $ovmHash{'sun_pswd'} ";
	$cmd .= " $ovmHash{'sun_storage'} $ovmHash{'sun_proj'} ";
	$cmd .= "| tee $logdir/sun_proj_exists.log";

	print "\n$cmd\n";
	my $status = `$cmd`;
	print "\n$status\n";
	if(($status =~ /$ovmHash{'sun_proj'} Present/ and $drmode eq 'ACTIVE') or (($status =~ /$ovmHash{'sun_proj'} not Present/ and $drmode eq 'PASSIVE'))){
		system("touch $logdir/sun_proj_exists.suc");
	}
	else{
		system("touch $logdir/sun_proj_exists.dif");
	}
	generate_msg('sun_proj_exists','check project existence on filer ' ,$html_message);
}

sub check_server_health{
	run_test('health_fa',"$scriptDir/fa_server_health.pl",$ovmHash{'fa_host'},$remoteFA);

	generate_msg('health_fa','FA servers health',$html_message);

	run_test('health_idm',"$scriptDir/idm_server_health.pl",$ovmHash{'idm_host'},$remoteFA);

	generate_msg('health_idm','IDM servers health',$html_message);
}

sub check_health{
	run_test('health_check_on_fa',"$scriptDir/health_check.pl",$ovmHash{'fa_host'},$remoteFA,
	ORACLE_HOME => '/u01/APPLTOP/fusionapps/applications',
	OHS_INSTANCE_ID => 'ohs1',
	OHS_HOST_NAME => $ovmHash{'ohs_host'},
	APPLICATIONS_BASE => '/u01/APPLTOP');

	generate_msg('health_check_on_fa','Trigger health check on FA',$html_message);
}

sub run_test{
	my ($test,$file,$host,$remoteCmdObj,%params) = @_;
	my $filename = (split('/',$file))[-1];
	copy_script_to_tmp($file,$host,$remoteCmdObj);
	run_script_on_host($filename,$test,$host,$remoteCmdObj,%params);
	get_log_status_files($test,$host,$remoteCmdObj);

}

sub copy_script_to_tmp{
	my($file,$host,$remoteCmdObj) = @_;
	
	$remoteCmdObj->copyFileToHost(file => $file,
				      host => $host,
				      dest => '/tmp');	
}

sub run_script_on_host{
	my ($file,$test,$host,$remoteCmdObj,%params) = @_;
	
	my $cmd = "/tmp/$file -test $test ";

	for my $key(keys % params){
		$cmd .= "-$key $params{$key} ";
	}
	
	#$cmd .= " \| tee /tmp/$test.log";
	$remoteCmdObj->executeCommandsonRemote(	cmd => $cmd,
						host => $host);
}

sub get_log_status_files{
	my ($test,$host,$remoteCmdObj) = @_;
	
	$remoteCmdObj->copyFileToDir(file => "/tmp/$test*",
				     host => $host,
				     destdir => $logdir);
}

sub generate_msg{
	my($test,$desc) = @_;
	
	my $result = 'FAILED';
	$result = 'PASSED' if(-e "$logdir/$test.suc");
	
	$html_message .= "<tr bgcolor = #E7F1FE><td align=CENTER><b>$test</b></td>";
	$html_message .= "<td align=CENTER><b>$desc</b></td>";
	
	if($result eq 'PASSED'){
		$html_message .= "<td align=CENTER><b><font color=green>PASSED</font></b></td></tr>\n";
	}
	else{
		$html_message .= "<td align=CENTER><b><font color=red>FAILED</font></b></td></tr>\n";
	}
}

sub sendmail{
	
	my $from = 'tarun.karamshetty@oracle.com';
	my $to = $mailid;
	my $subject = "DR Validations report on $sys_name";
	my $message = $html_message;


	Mail::sendmail($to,
                       {
                           Subject => $subject,
                           From => $from,
                           'Content-type' => "text/html"
                           },
                       $message);


	print "Sent mail to $to successfully\n";

}

sub usage{

	print "\nMandatory parameters:\n p_ovm_smc_props -> Primary deploy properties\n p_drmode -> DR mode of primary pod i.e. ACTIVE or PASSIVE\n mailid -> List of mail ids to send the generated validations report to, comma seperated\n logdir ->Log directory to save log files and suc/dif files\n sys_name -> Name of the system to be included in the mail subject \n Optional parameters below (provide all or none): \n s_ovm_smc_props -> Standby deploy properties\n s_drmode -> DR mode of standby pod\n";

	exit(1);
	
}


