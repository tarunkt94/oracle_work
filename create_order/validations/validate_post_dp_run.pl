#!/usr/bin/perl


use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;
use Cwd;
use File::Basename; 

#setenv SAASQA_HOME /scratch/aime/cicd/
#perl validations_for_santhu.pl -p_ovm_smc_props /scratch/aime/tarun/create_order/validations/DRDPTest/primary-ovm-smc-deploy.properties -s_ovm_smc_props /scratch/aime/tarun/create_order/validations/DRDPTest/standby-ovm-smc-deploy.properties -action FA_DR_CLONE_DP -trusted_host slc03why -trusted_user aime -trusted_passwd 2cool -mailid santhosh.kumar.shankaramanchi@oracle.com -logdir /scratch/aime/tarun/create_order/validations/DRDPTest/ -sys_name fadrsdigsiser2017175

my($p_ovm_smc_props,$s_ovm_smc_props,$action, $drmode,$trusted_host,
   $trusted_user, $trusted_passwd,$mailid,$logdir,$logObj,$remoteDB,
   $remoteFA,$html_message,$sys_name,$scriptDir,%ovmHash);

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

my @actions = qw/FA_DR_DP FA_DR_CLEANUP_DP FA_DR_CLONE_DP
    FA_DR_CLONECLEAN_DP FA_DR_SCALE_DP FA_DR_CONFIGURATION_DP
    pause resume replay replay_clone/;

get_input();

validate_inputs();

prepare_objects();


$html_message = '<table width = 100% border=0><tr><td><h2><u><center>DR VALIDATIONS Report</center></u></h2></td></tr></table>' ;


start_test_suite();

sendmail();

sub get_input{
    GetOptions('p_ovm_smc_props=s' => \$p_ovm_smc_props,
	       's_ovm_smc_props=s' => \$s_ovm_smc_props,
	       'action=s'       => \$action,
	       'trusted_host=s'   => \$trusted_host, 
	       'trusted_user=s'   => \$trusted_user, 
	       'trusted_passwd=s' => \$trusted_passwd,
	       'mailid=s' => \$mailid,
	       'logdir=s' => \$logdir,
	       'sys_name=s' => \$sys_name) or pod2usage(2);
}

sub validate_inputs{
    if(!($p_ovm_smc_props and $s_ovm_smc_props and $action and $mailid and $logdir and $sys_name)){
	pod2usage(2);
    }
    die "\nNo file present at $p_ovm_smc_props\n" unless (-f $p_ovm_smc_props);
    die "\nNo file present at $s_ovm_smc_props\n" unless (-f $s_ovm_smc_props);
    die "\nThe log directory provided does not exist\n" unless (-d $logdir);
    
    if(! ( grep /$action/, @actions))
    {
        print "Please provide options from below list and retry.\n";
        print join("\n",@actions), "\n";
        die ();
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
    
}

sub prepare_hash{
    
    my (%params) = @_;
    
    my %ovmHash = read_props_file($params{dep_props});
    
    my $AUX_SCALE_COUNT = 0 ;
    
    #my %dbProps = ();
    #my %faProps = ();
    #my %storageProps = ();
    
    my %ovmProps = ();
    
    my $cmd = "cat $params{dep_props} | grep \"faovm.smc.HOST_AUXVM_SCALE\" | wc -l " ;
    
    $AUX_SCALE_COUNT = `$cmd`;
    $ovmProps{'AUX_SCALE_COUNT'} = $AUX_SCALE_COUNT;
    
    foreach my $key (keys %ovmHash) {
	$ovmProps{$key} = $ovmHash{$key}; 
    }
    
    $ovmProps{'fadb_uniq_name'} = $ovmHash{'faovm.smc.fusiondb.new.dbuniquename'};
    $ovmProps{'fadb_rac1_sid'} = $ovmHash{'faovm.smc.fusiondb.new.rac.sid1'};
    $ovmProps{'fadb_rac2_sid'} = $ovmHash{'faovm.smc.fusiondb.new.rac.sid2'};
    $ovmProps{'fadb_oracle_home'} = $ovmHash{'faovm.smc.fusiondb.new.oracle.home'};
    $ovmProps{'fadb_grid_home'} = $ovmHash{'faovm.smc.fusiondb.new.crs.home'};
    $ovmProps{'fadb_name'} = $ovmHash{'faovm.smc.fusiondb.new.dbname'};
    
    $ovmProps{'oiddb_uniq_name'} = $ovmHash{'faovm.smc.oiddb.new.dbuniquename'};
    $ovmProps{'oiddb_rac1_sid'} = $ovmHash{'faovm.smc.oiddb.new.rac.sid1'};
    $ovmProps{'oiddb_rac2_sid'} = $ovmHash{'faovm.smc.oiddb.new.rac.sid2'};
    $ovmProps{'oiddb_oracle_home'} = $ovmHash{'faovm.smc.oiddb.new.oracle.home'};
    $ovmProps{'oiddb_grid_home'} = $ovmHash{'faovm.smc.oiddb.new.crs.home'};
    $ovmProps{'oiddb_name'} = $ovmHash{'faovm.smc.oiddb.new.dbname'};
    
    $ovmProps{'rac_node1'} = $ovmHash{'faovm.smc.HOST_DB'};
    $ovmProps{'rac_node2'} = $ovmHash{'faovm.smc.HOST_DB2'};
    
    $ovmProps{'asm_sid'} = $ovmHash{'faovm.smc.fusiondb.new.asm.sid'};
    $ovmProps{'asm_sid2'} = '+ASM2';
    
    $ovmProps{'db_user_name'} = $ovmHash{'faovm.smc.fusiondb.new.host.login.user.name'};
    #$ovmProps{'db_password'} = $ovmHash{'faovm.smc.fusiondb.new.host.login.user.password'}; 
    $ovmProps{'db_password'} = 'oracle';
    
    
    $ovmProps{'fa_host'} = $ovmHash{'faovm.smc.HOST_FA'};
    $ovmProps{'idm_host'} = $ovmHash{'faovm.smc.HOST_IDM_MIDTIER'};
    $ovmProps{'ohs_host'} = $ovmHash{'faovm.smc.HOST_OHS'};
    $ovmProps{'fa_ha_host'} = $ovmHash{'faovm.smc.HOST_FA_HA1'};
    $ovmProps{'opt1_host'} = $ovmHash{'faovm.smc.HOST_OPT1'};
    $ovmProps{'opt2_host'} = $ovmHash{'faovm.smc.HOST_OPT2'};
    $ovmProps{'opt3_host'} = $ovmHash{'faovm.smc.HOST_OPT3'};
    $ovmProps{'opt4_host'} = $ovmHash{'faovm.smc.HOST_OPT4'};
    
    $ovmProps{'fa_user_name'} = $ovmHash{'faovm.os.apps.user.name'};
    $ovmProps{'fa_password'} = 'Welcome1'; 
    
    
    $ovmProps{'sun_username'} = $ovmHash{'faovm.storage.sun.username'};
    #$ovmProps{'sun_pswd'} = $ovmHash{'faovm.storage.sun.password'};
    $ovmProps{'sun_pswd'} = 'fadr';
    $ovmProps{'sun_proj'} = $ovmHash{'faovm.storage.sun.project'};
    $ovmProps{'sun_storage'} = $ovmHash{'faovm.storage.sun.host'};
    
    $ovmProps{'fa_share_u01'} = $ovmHash{'faovm.smc.fa.storage.name'};
    $ovmProps{'fa_share_u02'} = $ovmHash{'faovm.smc.fa.split.instance.storage.name'};
    $ovmProps{'ohs_share_u01'} = $ovmHash{'faovm.smc.ohs.storage.name'};
    $ovmProps{'idm_share_u01'} = $ovmHash{'faovm.smc.idm.storage.name'};
    $ovmProps{'fa_scratch_share'} = $ovmHash{'faovm.smc.fa.scratch.storage.name'};
    $ovmProps{'osn_scratch_share'} = $ovmHash{'faovm.smc.osn.scratch.storage.name'};
    $ovmProps{'bi_repo_share'} = $ovmHash{'faovm.smc.bi.scratch.storage.name'};
    $ovmProps{'grc_repo_share'} = $ovmHash{'faovm.smc.opt4.scratch.storage.name'};
    
    return (\%ovmProps);
    
}

sub start_test_suite{
    
    print "Entered start_test_suite\n";
    my $p_ovmHash = prepare_hash (dep_props => $p_ovm_smc_props);
    my $s_ovmHash = prepare_hash (dep_props => $s_ovm_smc_props);	
    
    my %p_ovmHash = %{$p_ovmHash};
    my %s_ovmHash = %{$s_ovmHash};
    
    my $log_dir_parent  = $logdir;
    
    system("mkdir -p $log_dir_parent/active");    
    system("mkdir -p $log_dir_parent/passive");
    
    
    my $db_user_name = $p_ovmHash{'faovm.smc.fusiondb.new.host.login.user.name'};
    my $db_password = 'oracle';
    $remoteDB = new RemoteCmd(user => $db_user_name,
			      passwd => $db_password,
			      logObj => $logObj);
    
    $remoteFA = new RemoteCmd(user => 'oracle',
			      passwd => 'Welcome1',
			      logObj => $logObj);
    
    
    
    $html_message .= "<br><b>DP VALIDATED: </b>\n" . $action . '<br><table width = 90% border=0><tr bgcolor=#56A5EC><th>Testcase Name</th><th>Description </th><th>Result</th></tr>' . "\n";
    
    if ($action =~ m/FA_DR_DP/) 
    {
	$drmode = 'ACTIVE' ;
	check_asm_test(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/active");
	check_db_mode(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		logdir => "$log_dir_parent/active");
	check_dg_conf(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "DR",
		logdir => "$log_dir_parent/active");
	check_tnsping(p_ovmHash => $p_ovmHash,
		s_ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "DR",
		logdir => "$log_dir_parent/active");
	check_lsnr_stat(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/active");
	check_dg_lsnr_stat(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB,
		podtype => "DR",
		logdir => "$log_dir_parent/active");
	
	check_mounts(ovmHash => $p_ovmHash,
		remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/active");
	
	check_proj_status(ovmHash => $p_ovmHash, 
	  drmode => $drmode,
	  logdir => "$log_dir_parent/active");
	
	$drmode = 'PASSIVE' ;
	check_asm_test(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/passive");
	check_db_mode(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");
	check_dg_conf(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "DR",
		logdir => "$log_dir_parent/passive");
	check_tnsping(p_ovmHash => $s_ovmHash,
		s_ovmHash => $p_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "DR",
		logdir => "$log_dir_parent/passive");
	check_lsnr_stat(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/passive");
	check_dg_lsnr_stat(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB,
		podtype => "DR",
		logdir => "$log_dir_parent/passive");

	check_mounts(ovmHash => $s_ovmHash,
		remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");

	check_proj_status(ovmHash => $p_ovmHash, 
	  drmode => $drmode,
	  logdir => "$log_dir_parent/passive");
	
    }
    if ($action =~ m/FA_DR_CLEANUP_DP/) 
    {
	$drmode = 'ACTIVE' ;
	check_asm_test(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/active");
	check_db_mode(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		logdir => "$log_dir_parent/active");
	check_dg_conf(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "NONDR",
		logdir => "$log_dir_parent/active");
	check_tnsping(p_ovmHash => $p_ovmHash,
		s_ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "NONDR",
		logdir => "$log_dir_parent/active");
	check_lsnr_stat(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/active");
	check_dg_lsnr_stat(ovmHash => $p_ovmHash,
		remoteDB => $remoteDB,
		podtype => "NONDR",
		logdir => "$log_dir_parent/active");
	
	check_mounts(ovmHash => $p_ovmHash,
		remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/active");
	
	check_proj_status(ovmHash => $p_ovmHash, 
	  drmode => $drmode,
	  logdir => "$log_dir_parent/active");
	
	$drmode = 'PASSIVE' ;
	check_proj_replication_status(ovmHash => $p_ovmHash, 
	  drmode => $drmode,
	  logdir => "$log_dir_parent/active");

	$drmode = 'ACTIVE' ;
	check_db_mode(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");
	
	$drmode = 'PASSIVE' ;
	check_asm_test(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/passive");
	check_lsnr_stat(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB,
		logdir => "$log_dir_parent/passive");

	check_dg_conf(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "NONDR",
		logdir => "$log_dir_parent/passive");
	check_tnsping(p_ovmHash => $s_ovmHash,
		s_ovmHash => $p_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		podtype => "NONDR",
		logdir => "$log_dir_parent/passive");
	check_dg_lsnr_stat(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB,
		podtype => "NONDR",
		logdir => "$log_dir_parent/passive");

	check_mounts(ovmHash => $s_ovmHash,
		remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");
	check_proj_status(ovmHash => $s_ovmHash, 
	  drmode => $drmode,
	  logdir => "$log_dir_parent/passive");
    }
    if ($action =~ m/FA_DR_CLONE_DP/) 
    {
	$drmode = 'ACTIVE' ; 
	check_mounts(ovmHash => $p_ovmHash,
	remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/active");
	
	$drmode = 'ACTIVE' ; 
	check_proj_status(ovmHash => $s_ovmHash, 
			  drmode => 	$drmode,
			  logdir => "$log_dir_parent/passive");
	
	check_proj_clone_status(ovmHash => $s_ovmHash, 
				clonestatus => 	"YES",
				logdir => "$log_dir_parent/passive");
	
#	$drmode = 'PASSIVE' ;
	check_mounts(ovmHash => $s_ovmHash,
	remoteFA => $remoteFA, 
	drmode => $drmode,
	logdir => "$log_dir_parent/passive");
    }
    if ($action =~ m/FA_DR_CLONECLEAN_DP/) 
    {
		$drmode = 'PASSIVE' ; 
		check_proj_status(ovmHash => $s_ovmHash, 
				  drmode => 	$drmode,
				  logdir => "$log_dir_parent/passive");
		
		check_proj_clone_status(ovmHash => $s_ovmHash, 
					clonestatus => 	"YES",
					logdir => "$log_dir_parent/passive");
		
		check_mounts(ovmHash => $s_ovmHash,
		remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");
    }
    if ($action =~ m/FA_DR_SCALE_DP/) 
    {
	
	$drmode = 'ACTIVE' ;
	check_mounts(ovmHash => $p_ovmHash,
		remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/active");

	$drmode = 'PASSIVE' ; 
	check_mounts(ovmHash => $s_ovmHash,
		remoteFA => $remoteFA, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");
	
	check_proj_status(ovmHash => $s_ovmHash, 
		  drmode => 	$drmode,
		  logdir => "$log_dir_parent/passive");

	check_proj_nfs_exceptions_status(p_ovmHash => $p_ovmHash, 
				 s_ovmHash => $s_ovmHash, 
				 logdir => "$log_dir_parent/active");

    }
    if ($action =~ m/FA_DR_CONFIGURATION_DP/) 
    {
	
    }
    if ($action =~ m/pause/) 
    {	
	$drmode = 'PASSIVE' ;
	check_proj_replication_status(ovmHash => $p_ovmHash, 
	  drmode => $drmode,
	  logdir => "$log_dir_parent/active");
	
	check_dg_repl_status(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");
    }
    if ($action =~ m/resume/) 
    {
	$drmode = 'ACTIVE' ;
	check_proj_replication_status(ovmHash => $p_ovmHash, 
	  drmode => $drmode,
	  logdir => "$log_dir_parent/active");

	check_dg_repl_status(ovmHash => $s_ovmHash,
		remoteDB => $remoteDB, 
		drmode => $drmode,
		logdir => "$log_dir_parent/passive");
    }
    if ($action =~ m/replay/) 
    {
	
    }
    if ($action =~ m/replay_clone/) 
    {
	
    }
    
    $html_message .= "</table>";	
    
}

sub check_asm_test{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $remoteDB = $params{remoteDB} ;
    
    run_test('asm_fa_rac1',"$scriptDir/check_asm.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'fadb_grid_home'},
	     ORACLE_SID => $ovmHash{'asm_sid'},
	     db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
	     db_name => $ovmHash{'fadb_name'},
		 logdir => $params{logdir});
    
    generate_msg('asm_fa_rac1',"Check spfile exists on ASM Disk on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('asm_oid_rac1',"$scriptDir/check_asm.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'oiddb_grid_home'},
	     ORACLE_SID => $ovmHash{'asm_sid'},
	     db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
	     db_name => $ovmHash{'oiddb_name'},
  		 logdir => $params{logdir});
    
    generate_msg('asm_oid_rac1',"Check spfile exists on ASM Disk on $ovmHash{'rac_node1'}",$params{logdir});
    
    
    run_test('asm_fa_rac2',"$scriptDir/check_asm.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'fadb_grid_home'},
	     ORACLE_SID => $ovmHash{'asm_sid2'},
	     db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
	     db_name => $ovmHash{'fadb_name'},
		 logdir => $params{logdir});
    
    generate_msg('asm_fa_rac2',"Check spfile exists on ASM Disk on $ovmHash{'rac_node2'}",$params{logdir});	
    
    
    run_test('asm_oid_rac2',"$scriptDir/check_asm.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'oiddb_grid_home'},
	     ORACLE_SID => $ovmHash{'asm_sid2'},
	     db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
	     db_name => $ovmHash{'oiddb_name'},
		 logdir => $params{logdir});
    
    generate_msg('asm_oid_rac2',"Check spfile exists on ASM Disk on $ovmHash{'rac_node1'}",$params{logdir});
    
}

sub check_mounts{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $remoteFA = $params{remoteFA};
    my $drmode = $params{drmode} ;
    
    run_test('fa_mounts',"$scriptDir/check_mount.pl",
	     $ovmHash{'fa_host'},$remoteFA,
	     project_name =>  $ovmHash{'sun_proj'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('fa_mounts',"Verify mount points and fstab entries on FA Host $ovmHash{'fa_host'} ",$params{logdir});
    
    if (defined ($ovmHash{'fa_ha_host'})) {
	run_test('fa_ha_mounts',"$scriptDir/check_mount.pl",
		 $ovmHash{'fa_ha_host'},$remoteFA,
		 project_name =>  $ovmHash{'sun_proj'},
		 drmode => $drmode,
		 logdir => $params{logdir});
	
	generate_msg('fa_ha_mounts',"Verify mount points and fstab entries on FA_HA Host $ovmHash{'fa_ha_host'} ",$params{logdir});
    } 
    
    run_test('idm_mounts',"$scriptDir/check_mount.pl",
	     $ovmHash{'idm_host'},$remoteFA,
	     project_name =>  $ovmHash{'sun_proj'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('idm_mounts',"Verify mount points and fstab entries on IDM Host $ovmHash{'idm_host'}",$params{logdir});
    
    run_test('ohs_mounts',"$scriptDir/check_mount.pl",
	     $ovmHash{'ohs_host'},$remoteFA,
	     project_name =>  $ovmHash{'sun_proj'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('ohs_mounts',"Verify mounts on OHS Host $ovmHash{'ohs_host'}",$params{logdir});
    
	if (defined ($ovmHash{'opt1_host'})) {
	run_test('opt1_mounts',"$scriptDir/check_mount.pl",
		 $ovmHash{'opt1_host'},$remoteFA,
		 project_name =>  $ovmHash{'sun_proj'},
		 drmode => $drmode,
		 logdir => $params{logdir});
	
	generate_msg('opt1_mounts',"Verify mount points and fstab entries on OPT1 VM host $ovmHash{'opt1_host'}",$params{logdir});
    } 
    
	if (defined ($ovmHash{'opt2_host'})) {
	run_test('opt2_host',"$scriptDir/check_mount.pl",
		 $ovmHash{'opt2_host'},$remoteFA,
		 project_name =>  $ovmHash{'sun_proj'},
		 drmode => $drmode,
		 logdir => $params{logdir});
	
	generate_msg('opt2_host',"Verify mount points and fstab entries on OPT2 VM host $ovmHash{'opt2_host'}",$params{logdir});
    } 
    
	if (defined ($ovmHash{'opt3_host'})) {
	run_test('opt3_host',"$scriptDir/check_mount.pl",
		 $ovmHash{'opt3_host'},$remoteFA,
		 project_name =>  $ovmHash{'sun_proj'},
		 drmode => $drmode,
		 logdir => $params{logdir});
	
	generate_msg('opt3_host',"Verify mount points and fstab entries on OPT3 VM host $ovmHash{'opt3_host'}",$params{logdir});
    } 

    if (defined ($ovmHash{'opt4_host'})) {
	run_test('opt4_host',"$scriptDir/check_mount.pl",$ovmHash{'opt4_host'},$remoteFA,
		 project_name =>  $ovmHash{'sun_proj'},
		 drmode => $drmode,
		 logdir => $params{logdir});
	
	generate_msg('opt4_host',"Verify mount points and fstab entries on OPT4 VM host $ovmHash{'opt4_host'}",$params{logdir});
    } 
    
    foreach my $key (keys %ovmHash){
	if ($key =~ /^faovm.smc.HOST_AUXVM_SCALE/ )
	{	run_test('$ovmHash{$key}',"$scriptDir/check_mount.pl",
			 $ovmHash{$key},$remoteFA,
			 project_name =>  $ovmHash{'sun_proj'},
			 drmode => $drmode,
		     logdir => $params{logdir});
		
		generate_msg($ovmHash{$key},"Verify mount points and fstab entries on AUX SCALE host",$params{logdir});
	    }		
    }	
}

sub check_db_mode{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $remoteDB = $params{remoteDB} ;
    my $drmode = $params{drmode} ;

    run_test('dbmode_fa_rac1',"$scriptDir/dbmode.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
	     ORACLE_SID => $ovmHash{'fadb_rac1_sid'},
	     db_name =>  $ovmHash{'fadb_name'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('dbmode_fa_rac1',"Check DB Open Mode and Role on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('dbmode_fa_rac2',"$scriptDir/dbmode.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
	     ORACLE_SID => $ovmHash{'fadb_rac2_sid'},
	     db_name =>  $ovmHash{'fadb_name'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('dbmode_fa_rac2',"Check DB Open Mode and Role on $ovmHash{'rac_node2'}",$params{logdir});
    
    run_test('dbmode_oid_rac1',"$scriptDir/dbmode.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
	     ORACLE_SID => $ovmHash{'oiddb_rac1_sid'},
	     db_name =>  $ovmHash{'oiddb_name'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('dbmode_oid_rac1',"Check DB Open Mode and Role on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('dbmode_oid_rac2',"$scriptDir/dbmode.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
	     ORACLE_SID => $ovmHash{'oiddb_rac2_sid'},
	     db_name =>  $ovmHash{'oiddb_name'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('dbmode_oid_rac2',"Check DB Open Mode and Role on $ovmHash{'rac_node2'}",$params{logdir});
    
}

sub check_dg_conf{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $remoteDB = $params{remoteDB} ;
    my $drmode = $params{drmode} ;
	my $podtype = $params{podtype} ;    

    run_test('dgconf_fa_rac1',"$scriptDir/dgmgrl.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
	     ORACLE_SID => $ovmHash{'fadb_rac1_sid'},
	     db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('dgconf_fa_rac1',"Checks the DG configuration on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('dgconf_fa_rac2',"$scriptDir/dgmgrl.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
	     ORACLE_SID => $ovmHash{'fadb_rac2_sid'},
	     db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('dgconf_fa_rac2',"Checks the DG configuration on $ovmHash{'rac_node2'}",$params{logdir});
    
    run_test('dgconf_oid_rac1',"$scriptDir/dgmgrl.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
	     ORACLE_SID => $ovmHash{'oiddb_rac1_sid'},
	     db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('dgconf_oid_rac1',"Checks the DG configuration on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('dgconf_oid_rac2',"$scriptDir/dgmgrl.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
	     ORACLE_SID => $ovmHash{'oiddb_rac2_sid'},
	     db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('dgconf_oid_rac2',"Checks the DG configuration on $ovmHash{'rac_node2'}",$params{logdir});
    
}

sub check_tnsping{
    
    my (%params) = @_;
    
    my %p_ovmHash = %{$params{p_ovmHash}};
    my %s_ovmHash = %{$params{s_ovmHash}};

    my $remoteDB = $params{remoteDB} ;
    my $drmode = $params{drmode} ;
	my $podtype = $params{podtype} ;    
    
    run_test('tnsping_fa_rac1',"$scriptDir/checkTNSPing.pl",
	     $p_ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $p_ovmHash{'fadb_oracle_home'},
	     p_db_uniq_name =>  $p_ovmHash{'fadb_uniq_name'},
		 s_db_uniq_name =>  $s_ovmHash{'fadb_uniq_name'},
 		 db_name => $p_ovmHash{'fadb_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('tnsping_fa_rac1',"Checks if DG TNS NAMES exist and TNS Ping Status on $p_ovmHash{'rac_node1'}",$params{logdir});

	 run_test('tnsping_fa_rac2',"$scriptDir/checkTNSPing.pl",
	     $p_ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $p_ovmHash{'fadb_oracle_home'},
	     p_db_uniq_name =>  $p_ovmHash{'fadb_uniq_name'},
		 s_db_uniq_name =>  $s_ovmHash{'fadb_uniq_name'},
 		 db_name => $p_ovmHash{'fadb_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('tnsping_fa_rac2',"Checks if DG TNS NAMES exist and TNS Ping Status on $p_ovmHash{'rac_node2'}",$params{logdir});

	 run_test('tnsping_oid_rac1',"$scriptDir/checkTNSPing.pl",
	     $p_ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $p_ovmHash{'oiddb_oracle_home'},
	     p_db_uniq_name =>  $p_ovmHash{'oiddb_uniq_name'},
		 s_db_uniq_name =>  $s_ovmHash{'oiddb_uniq_name'},
 		 db_name => $p_ovmHash{'fadb_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('tnsping_oid_rac1',"Checks if DG TNS NAMES exist and TNS Ping Status on $p_ovmHash{'rac_node1'}",$params{logdir});

   run_test('tnsping_oid_rac2',"$scriptDir/checkTNSPing.pl",
	     $p_ovmHash{'rac_node2'},$remoteDB,
	     ORACLE_HOME => $p_ovmHash{'oiddb_oracle_home'},
	     p_db_uniq_name =>  $p_ovmHash{'oiddb_uniq_name'},
		 s_db_uniq_name =>  $s_ovmHash{'oiddb_uniq_name'},
 		 db_name => $p_ovmHash{'fadb_name'},
	     drmode => $drmode,
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('tnsping_oid_rac2',"Checks if DG TNS NAMES exist and TNS Ping Status on $p_ovmHash{'rac_node2'}",$params{logdir});
}

sub check_dg_repl_status{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $remoteDB = $params{remoteDB} ;
    my $drmode = $params{drmode} ;
    
    run_test('dg_repl_fa_rac1',"$scriptDir/check_dg_repl_status.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'fadb_oracle_home'},
	     ORACLE_SID => $ovmHash{'fadb_rac1_sid'},
	     db_uniq_name =>  $ovmHash{'fadb_uniq_name'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('dg_repl_fa_rac1',"Checks the DG Replication configuration on $ovmHash{'rac_node1'}",$params{logdir});    
   
    run_test('dg_repl_oid_rac1',"$scriptDir/check_dg_repl_status.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     ORACLE_HOME => $ovmHash{'oiddb_oracle_home'},
	     ORACLE_SID => $ovmHash{'oiddb_rac1_sid'},
	     db_uniq_name =>  $ovmHash{'oiddb_uniq_name'},
	     drmode => $drmode,
		 logdir => $params{logdir});
    
    generate_msg('dg_repl_oid_rac1',"Checks the DG Replication configuration on $ovmHash{'rac_node1'}",$params{logdir});
   
}

sub check_lsnr_stat{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $remoteDB = $params{remoteDB} ;
    
    run_test('lnsr_fa_rac1',"$scriptDir/listener_check.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     db_uniq_name => $ovmHash{'fadb_uniq_name'},
		 logdir => $params{logdir});
    
    generate_msg('lnsr_fa_rac1',"Check Listener status on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('lnsr_fa_rac2',"$scriptDir/listener_check.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     db_uniq_name => $ovmHash{'fadb_uniq_name'},
		 logdir => $params{logdir});
    
    generate_msg('lnsr_fa_rac2',"Check Listener status on $ovmHash{'rac_node2'}",$params{logdir});
    
    run_test('lnsr_oid_rac1',"$scriptDir/listener_check.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     db_uniq_name => $ovmHash{'oiddb_uniq_name'},
		 logdir => $params{logdir});
    
    generate_msg('lnsr_oid_rac1',"Check Listener status on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('lnsr_oid_rac2',"$scriptDir/listener_check.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     db_uniq_name => $ovmHash{'oiddb_uniq_name'},
		 logdir => $params{logdir});
    
    generate_msg('lnsr_oid_rac2',"Check Listener status on $ovmHash{'rac_node2'}",$params{logdir});
    
}

sub check_dg_lsnr_stat{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $remoteDB = $params{remoteDB} ;
    my $podtype = $params{podtype} ;
	
   run_test('lnsr_dg_fa_rac1',"$scriptDir/listener_dg_check.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     GRID_HOME => $ovmHash{'fadb_grid_home'},
	     db_uniq_name => $ovmHash{'fadb_uniq_name'},
	     podtype => $podtype,
		 logdir => $params{logdir});
    
  generate_msg('lnsr_dg_fa_rac1',"Check DG Listener status and DGMGRL/DGB services on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('lnsr_dg_fa_rac2',"$scriptDir/listener_dg_check.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     GRID_HOME => $ovmHash{'fadb_grid_home'},
	     db_uniq_name => $ovmHash{'fadb_uniq_name'},
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('lnsr_dg_fa_rac2',"Check DG Listener status and DGMGRL/DGB services on $ovmHash{'rac_node2'}",$params{logdir});
    
    run_test('lnsr_dg_oid_rac1',"$scriptDir/listener_dg_check.pl",
	     $ovmHash{'rac_node1'},$remoteDB,
	     GRID_HOME => $ovmHash{'fadb_grid_home'},
	     db_uniq_name => $ovmHash{'oiddb_uniq_name'},
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('lnsr_dg_oid_rac1',"Check DG Listener status and DGMGRL/DGB services on $ovmHash{'rac_node1'}",$params{logdir});
    
    run_test('lnsr_dg_oid_rac2',"$scriptDir/listener_dg_check.pl",
	     $ovmHash{'rac_node2'},$remoteDB,
	     GRID_HOME => $ovmHash{'fadb_grid_home'},
	     db_uniq_name => $ovmHash{'oiddb_uniq_name'},
	     podtype => $podtype,
		 logdir => $params{logdir});
    
    generate_msg('lnsr_dg_oid_rac2',"Check DG Listener status and DGMGRL/DGB services on $ovmHash{'rac_node2'}",$params{logdir});
    
}
sub check_proj_status{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $drmode = $params{drmode};
    
    my $cmd = "perl $scriptDir/project_status.pl -wdir $params{logdir} ";
    $cmd .= " -trusted_host slc03why -trusted_user aime ";
    $cmd .= " -trusted_passwd 2cool -project $ovmHash{'sun_proj'} ";
    $cmd .= " -filer $ovmHash{'sun_storage'} -filer_user $ovmHash{'sun_username'} ";
    $cmd .= " | tee $params{logdir}/check_proj_status.log";
    
    my $status = `$cmd`;
    print "\n$status\n";
    if($drmode eq 'ACTIVE' and $status =~ /PROJ_AVAILABLE/){
	system("touch $params{logdir}/project_status.suc");
    }
    if($drmode eq 'ACTIVE' and $status =~ /PROJ_NOT_AVAILABLE/){
	system("touch $params{logdir}/project_status.dif");
    }
    if($drmode eq 'PASSIVE' and $status =~ /PROJ_NOT_AVAILABLE/){
	system("touch $params{logdir}/project_status.suc");
    }
    if($drmode eq 'PASSIVE' and $status =~ /PROJ_AVAILABLE/
		and $status =~ /SHARES_COUNT= 0/){
	system("touch $params{logdir}/project_status.suc");
    }
    else{
	system("touch $params{logdir}/project_status.dif");
    }
    generate_msg('project_status',"check project status on $ovmHash{'sun_storage'} Filer" ,$params{logdir});
}


sub check_proj_clone_status{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $clonestatus = $params{clonestatus};
    
    my $cmd = "perl $scriptDir/project_status.pl -wdir $params{logdir} ";
    $cmd .= " -trusted_host slc03why -trusted_user aime ";
    $cmd .= " -trusted_passwd 2cool -project $ovmHash{'sun_proj'} ";
    $cmd .= " -filer $ovmHash{'sun_storage'} -filer_user $ovmHash{'sun_username'} ";
    $cmd .= " | tee $params{logdir}/check_proj_clone_status.log";
    
    my $status = `$cmd`;
    print "\n$status\n";
    if($clonestatus eq 'YES' and $status =~ /CLONED_PROJECT/){
	system("touch $params{logdir}/project_clone_status.suc");
    }
    if($clonestatus eq 'YES' and $status =~ /LOCAL_PROJECT/){
	system("touch $params{logdir}/project_clone_status.dif");
    }
    if($clonestatus eq 'NO' and $status =~ /LOCAL_PROJECT/){
	system("touch $params{logdir}/project_clone_status.suc");
    }
    if($clonestatus eq 'NO' and $status =~ /CLONED_PROJECT/){
	system("touch $params{logdir}/project_clone_status.dif");
    }
    else{
	system("touch $params{logdir}/project_clone_status.dif");
    }
    generate_msg('project_clone_status',"check project clone status on $ovmHash{'sun_storage'} Filer" ,$params{logdir});
}


sub check_proj_nfs_exceptions_status{
    
    my (%params) = @_;
    
    my %p_ovmHash = %{$params{p_ovmHash}};
    my %s_ovmHash = %{$params{s_ovmHash}};
    
    my ($status, $nfsshares_status, $shares_count, @FA_Hosts) ;
    
    my $MW_Hosts = "faovm.smc.HOST_(FA\$|FA_HA1\$|OPT|AUXVM_SCALE)" ;
    
    map { push @FA_Hosts, $p_ovmHash{$_} if ($_ =~ /$MW_Hosts/) } keys %p_ovmHash;
    map { push @FA_Hosts, $s_ovmHash{$_} if ($_ =~ /$MW_Hosts/) } keys %s_ovmHash;
    
    my $cmd = "perl $scriptDir/project_status.pl -wdir $params{logdir} ";
    $cmd .= " -trusted_host slc03why -trusted_user aime ";
    $cmd .= " -trusted_passwd 2cool -project $p_ovmHash{'sun_proj'} ";
    $cmd .= " -filer $p_ovmHash{'sun_storage'} -filer_user $p_ovmHash{'sun_username'} ";
    $cmd .= " | tee $params{logdir}/check_proj_nfs_exceptions_status.log";
    
    $status = `$cmd`;
    print "\n$status\n";
    
	$status=~ s/^(\s*|\r|\n)$//mg;

    my @output = split /\n/, $status;
    for my $line (@output)
    {
        chomp($line);
	if($line =~ /$p_ovmHash{'fa_share_u01'}/){			
	    foreach my $hostnm(@FA_Hosts) 
	    {      
		if($line =~ /$hostnm/){
		    $nfsshares_status .= "$hostnm exist in $p_ovmHash{'fa_share_u01'} NFS exceptions.\n";
		}
		else{
		    $nfsshares_status .= "$hostnm missing in $p_ovmHash{'fa_share_u01'} NFS exceptions.\n";
		}
	    }
	}
	if($line =~ /$p_ovmHash{'fa_share_u02'}/){			
	    foreach my $hostnm(@FA_Hosts) 
	    {      
		if($line =~ /$hostnm/){
		    $nfsshares_status .= "$hostnm exist in $p_ovmHash{'fa_share_u02'} NFS exceptions.\n";
		}
		else{
		    $nfsshares_status .= "$hostnm missing in $p_ovmHash{'fa_share_u02'} NFS exceptions.\n";
		}
	    }
	}
	if($line =~ /$p_ovmHash{'ohs_share_u01'}/){
	    if($line =~ /$p_ovmHash{'ohs_host'}/){
		$nfsshares_status .= "$p_ovmHash{'ohs_host'} exist in $p_ovmHash{'ohs_share_u01'} NFS exceptions.\n";
	    }
	    else{
		$nfsshares_status .= "$p_ovmHash{'ohs_host'} missing in $p_ovmHash{'ohs_share_u01'} NFS exceptions.\n";
	    }
	    if($line =~ /$s_ovmHash{'ohs_host'}/){
		$nfsshares_status .= "$s_ovmHash{'ohs_host'} exist in $p_ovmHash{'ohs_share_u01'} NFS exceptions.\n";
	    }
	    else{
		$nfsshares_status .= "$s_ovmHash{'ohs_host'} missing in $p_ovmHash{'ohs_share_u01'} NFS exceptions.\n";
	    }
	}
	if($line =~ /$p_ovmHash{'idm_share_u01'}/){			
	    if($line =~ /$p_ovmHash{'idm_host'}/){
		$nfsshares_status .= "$p_ovmHash{'idm_host'} exist in $p_ovmHash{'idm_share_u01'} NFS exceptions.\n";
	    }
	    else{
		$ nfsshares_status .= "$p_ovmHash{'idm_host'} missing in $p_ovmHash{'idm_share_u01'} NFS exceptions.\n";
	    }
	    if($line =~ /$s_ovmHash{'idm_host'}/){
		$nfsshares_status .= "$s_ovmHash{'idm_host'} exist in $p_ovmHash{'idm_share_u01'} NFS exceptions.\n";
	    }
	    else{
		$nfsshares_status .= "$s_ovmHash{'idm_host'} missing in $p_ovmHash{'idm_share_u01'} NFS exceptions.\n";
	    }
	}
	if($line =~ /SHARES_COUNT/){
		$shares_count = (split /\= /, $line)[1];
	}

    }
    
	print "\n$nfsshares_status\n";
    if($nfsshares_status =~ /missing/) {
	system("touch $params{logdir}/proj_nfs_exceptions_status.dif");	
	#open OUT," >> $params{logdir}/proj_nfs_exceptions_status.dif" or die "$!\n";
	#print OUT "$nfsshares_status\n";
	#close OUT;
	}
    if($shares_count lt 5) {
	system("touch $params{logdir}/proj_nfs_exceptions_status.dif");	
	#open OUT," >> $params{logdir}/proj_nfs_exceptions_status.dif" or die "$!\n";
	#print OUT "SHARES COUNT LESS THAN $shares_count\n";
	#close OUT;
	}
    else{
	system("touch $params{logdir}/proj_nfs_exceptions_status.suc");
	#open OUT," >> $params{logdir}/proj_nfs_exceptions_status.suc" or die "$!\n";
	#print OUT "$nfsshares_status\n";
	#close OUT;
    }
    generate_msg('proj_nfs_exceptions_status',"check project nfs exceptions status on $p_ovmHash{'sun_storage'} Filer" ,$params{logdir});
}


sub check_proj_replication_status{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    my $drmode = $params{drmode};

    my $cmd = "perl $scriptDir/project_replication_status.pl -wdir $params{logdir} ";
    $cmd .= " -trusted_host slc03why -trusted_user aime ";
    $cmd .= " -trusted_passwd 2cool -project $ovmHash{'sun_proj'} ";
    $cmd .= " -filer $ovmHash{'sun_storage'} -filer_user $ovmHash{'sun_username'} ";
    $cmd .= " -replication_label slcnas559 | tee $params{logdir}/check_proj_replication_status.log";
    
    my $status = `$cmd`;
    print "\n$status\n";
    if($drmode eq 'ACTIVE' and $status =~ /enabled/){
	system("touch $params{logdir}/project_repl_status.suc");
    }
    if($drmode eq 'PASSIVE' and $status =~ /disabled/){
	system("touch $params{logdir}/project_repl_status.suc");
    }
    else{
	system("touch $params{logdir}/project_repl_status.dif");
    }
    generate_msg('project_repl_status',"check project replication status on $ovmHash{'sun_storage'} Filer" ,$params{logdir});
}

sub check_proj_exists{
    
    my (%params) = @_;
    
    my %ovmHash = %{$params{ovmHash}};
    
    my $cmd = "sh $scriptDir/sunStorageVerifyProjectExists.sh $ovmHash{'sun_username'} ";
    $cmd .= " $ovmHash{'sun_pswd'} $ovmHash{'sun_storage'} $ovmHash{'sun_proj'} ";
    $cmd .= "| tee $params{logdir}/sun_proj_exists.log";
    
    my $status = `$cmd`;
    print "\n$status\n";
    if($status =~ /$ovmHash{'sun_proj'} Present/){
	system("touch $params{logdir}/sun_proj_exists.suc");
    }
    else{
	system("touch $params{logdir}/sun_proj_exists.dif");
    }
    generate_msg('sun_proj_exists',"check project existence on filer " ,$params{logdir});
}



sub run_test{
    my ($test,$file,$host,$remoteCmdObj,%params) = @_;
    my $filename = (split('/',$file))[-1];
    copy_script_to_tmp($file,$host,$remoteCmdObj);
    run_script_on_host($filename,$test,$host,$remoteCmdObj,%params);
    get_log_status_files($test,$host,$params{logdir},$remoteCmdObj);
    
}

sub copy_script_to_tmp{
    my($file,$host,$remoteCmdObj) = @_;
    
    $remoteCmdObj->copyFileToHost(file => $file,
				  host => $host,
				  dest => '/tmp');	
}

sub run_script_on_host{
    my ($file,$test,$host,$remoteCmdObj,%params) = @_;
    
	my $cmd = "";
	
	if($file =~ /\.pl/){
		$cmd .= "perl ";
	}
	if($file =~ /\.sh/){
	 $cmd .= "sh ";
	}
	 
    $cmd .= "/tmp/$file -test $test ";
    
    for my $key(keys % params){
	$cmd .= "-$key $params{$key} ";
    }
    
    #$cmd .= " \| tee /tmp/$test.log";
    $remoteCmdObj->executeCommandsonRemote(	cmd => $cmd,
						host => $host);
}

sub get_log_status_files{
    my ($test,$host,$logdir, $remoteCmdObj) = @_;
    
    $remoteCmdObj->copyFileToDir(file => "/tmp/$test*",
				 host => $host,
				 destdir => $logdir);
}

sub generate_msg{
    my($test,$desc,$logdir) = @_;
    
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




