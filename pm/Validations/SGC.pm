package SGC;

use strict;
use warnings;
use Options;
use Getopt::Long;
use Pod::Usage;


my $scriptDir;

BEGIN
{
    use File::Basename;
    use Cwd;
    my $orignalDir = getcwd();
    $scriptDir = dirname($0);
    chdir($scriptDir);
    $scriptDir = getcwd();
    # add $scriptDir into INC
    unshift (@INC, "$scriptDir/..");
    chdir($orignalDir);
}

use Util;
use Logger;
require RemoteCmd;
use SDI;
use GenerateHtml; 



### Constructor
sub new {

    my ($class, %args) = @_;

    my $self = {
        logdir => $args{logdir},
        logObj => $args{logObj},
        config => $args{config}
    };

    bless($self, $class);

    $self->{'InfraRemoteObj'} =
    RemoteCmd->new(user => $self->{config}{'REMOTEUSER'}, 
		   passwd => $self->{config}{'REMOTEPASSWD'}, 
		   logObj => $self->{logObj});

    $self->{'DBremoteObj'} = 
    RemoteCmd->new(user => $self->{config}{'DBUSER'}, 
		   passwd => $self->{config}{'DBPASSWD'}, 
		   logObj => $self->{logObj});

	$self->{'VMRemoteObj'} =
    RemoteCmd->new(user => $self->{config}{'VMUSER'}, 
		   passwd => $self->{config}{'VMPASSWD'}, 
		   logObj => $self->{logObj});

    return $self;
}

# This method would first get the OVM Properties file from primary and Standby
# It will then prepare the MW Hosts and DB Hosts seperately.
# It would get the Plans from EM and then gets the Plan Details for each plan
# and also builds the Expected Plan and compares both if they are equal
sub SGC {
        
    my ($self, %params) = @_;
    
    my (@paths) = split('/', $self->{logdir});
    my $logdir = pop @paths;
    
    my $logpath;

    my $primsdiObj = new SDI(user => $self->{config}{'SDIUSER'}, 
			     passwd => $self->{config}{'SDIPASSWD'}, 
			     host => $params{primarysdi}, 
			     sdiscript => $self->{config}{'SDISCRIPT'}, 
			     logObj => $self->{logObj});
    
    my %poddetails = 
	$primsdiObj->getPodDetails(system_name => $params{System_Name});
    
    if ($poddetails{'role'} eq 'ACTIVE')
    {
        $logpath = "$self->{logdir}/logs/primary";
        $params{url} .= "/$logdir/logs/primary" if ($params{url});
    } elsif ($poddetails{'role'} eq 'PASSIVE') 
    {
        $logpath = "$self->{logdir}/logs/standby";
        $params{url} .= "/$logdir/logs/standby" if ($params{url});
    }
    
    system("mkdir -p $logpath");

    my $DREnabled=$poddetails{"drenabled"};
    my $PatnerDCId=$poddetails{"partnerdcid"};
    
    if($DREnabled eq "true" and $PatnerDCId ne "N/A")
    {  
        my $OVMProperties = 
	    getOVMDeployProperties(System_Name => $params{System_Name}, 
				   primarysdi => $params{primarysdi}, 
				   standbysdi => $params{standbysdi}, 
			           logdir => $self->{logdir}, 
			           logObj => $self->{'logObj'}, 
			           InfraRemoteObj =>$self->{'InfraRemoteObj'}, 
				   DBremoteObj => $self->{'DBremoteObj'},
		                   config => $self->{config});
        
        my %OVMProps = %{$OVMProperties};
        my %PrimSDIOVMDetails =%{$OVMProps{'PrimSDIOVMDetails'}};
        
        my $OMS_HOST=$PrimSDIOVMDetails{"faovm.emagent.oms.host"};
        my $OMS_USER_NAME=$PrimSDIOVMDetails{"faovm.oms.user"};
	my $OMS_Target_Name=$PrimSDIOVMDetails{"faovm.oms.target.name"};
	
	my $fahost = $PrimSDIOVMDetails{"faovm.ha.HOST_FA"};
	
	my $cmd = "\"grep -q u02 /etc/fstab; test \$? -eq 0 && echo true || echo false\"";
	
	my $filter = " awk ' { if (\$1 !~ (/spawn|ssh|exit|Authorized|";
	$filter .= "Warning|Offending|Matching|$fahost|^\$/) ) print }'";	
	
	my $out = $self->{VMRemoteObj}->
	    executeCommandsonRemote(host => $fahost,
				    cmd => "$cmd",
				    filter => "$filter");
	
	my $zdtEnabled = @$out[0];
	$zdtEnabled =~ s/\r?\n//g;
	
	validateEMPlans
	    (OMS_HOST => $OMS_HOST, 
	     OMS_USER_NAME => $OMS_USER_NAME,
	     OMS_Target_Name => $OMS_Target_Name,
	     System_Name => $params{System_Name}, 
	     zdtEnabled	 =>	$zdtEnabled,
	     fadrScriptsPath => $OVMProperties->{'fadrScriptsPath'}, 
	     PrimarydbOLSNode => $OVMProperties->{'PrimarydbOLSNode'}, 
	     StandbydbOLSNode => $OVMProperties->{'StandbydbOLSNode'}, 
	     PrimaryUtilityHost => $OVMProperties->{'PrimaryUtilityHost'}, 
	     StandbyUtilityHost => $OVMProperties->{'StandbyUtilityHost'}, 
	     Primary_MW_Hosts => $OVMProperties->{'Primary_MW_Hosts'}, 
	     Primary_App_Hosts => $OVMProperties->{'Primary_App_Hosts'}, 
	     Primary_DB_Hosts => $OVMProperties->{'Primary_DB_Hosts'}, 
	     Standby_MW_Hosts => $OVMProperties->{'Standby_MW_Hosts'}, 
	     Standby_App_Hosts => $OVMProperties->{'Standby_App_Hosts'}, 
	     Standby_DB_Hosts => $OVMProperties->{'Standby_DB_Hosts'}, 
	     logObj => $self->{'logObj'}, 
	     InfraRemoteObj => $self->{'InfraRemoteObj'}, 
	     logdir => $self->{'logdir'}, 
	     logpath => $logpath,
	     PrimSDIOVMDtls => $OVMProperties->{'PrimSDIOVMDetails'}, 
	     StandbySDIOVMDtls => $OVMProperties->{'StandbySDIOVMDetails'});
	
    }
    else
    {
	open OUT," > $logpath/SGCPlansTest.dif.html" or die "$!\n";
	print OUT "DR is not enabled on this Domain, please check once.\n";
	close OUT;
    }
    
    if ($params{'action'} eq "validateSGCPlans")
    {
	generateHTMLReport(logdir => $self ->{'logdir'}, 
			   logpath => $logpath,
			   drmode => $poddetails{'role'},
			   mailids => $params{mailids},
			   url => $params{url},
			   host => $params{primarysdi});
    }
}



# // This method finds the DB Host name by taking VIP Host name as the input.
# Can be merged to DB.pm file as this is a library method.
sub getDBNodeNamefromDBHost {
    
    my (%params) = @_;
    
    my ($cmd, $filter, $out, $dbOLSNode);
    
    my $dbVIPNode = (split /\./, $params{DB_HOST})[0];
    
    $cmd = "olsnodes -i|grep '".$dbVIPNode."'";
    
    $filter = "awk ' { if (\$1 !~ /spawn|oracle|exit|ssh|";
    $filter .= "Authorized|Warning|Offending|Matching/) print \$1}'";
    
    $out = $params{DBremoteObj}->
        executeCommandsonRemote(host => $params{DB_HOST}, 
				cmd => "$cmd",
				filter => "$filter");
    
    $dbOLSNode = @$out[0];
    chomp($dbOLSNode);
    $dbOLSNode =~ s/\s+$//g;
    
    return $dbOLSNode;
}

# This method would first get the OVM Properties file from primary and Standby
# It will prepare the MW Hosts and DB Hosts for both primary and Standby 
# and will also find the DB Nodes.

sub getOVMDeployProperties {
    
    my (%params) = @_;
    
    my %config = %{$params{config}};
    
    my %OVMProps = ();
    
    my $primsdiObj = new SDI(user => $config{'SDIUSER'}, 
			     passwd => $config{'SDIPASSWD'}, 
			     host => $params{primarysdi}, 
			     sdiscript => $config{'SDISCRIPT'}, 
			     logObj => $params{logObj});
    
    my $fadrScriptsPath = $primsdiObj->getFADRScriptsPath();
    
    my %PrimSDIOVMDetails = $primsdiObj->
	getOVMPropertiesHashfromSDI(system_name => $params{System_Name}, 
				    logdir => $params{logdir}, 
				    config => $params{config});
    
    
    my $standbysdiObj = new SDI(user => $config{'SDIUSER'}, 
				passwd => $config{'SDIPASSWD'}, 
				host => $params{standbysdi}, 
				sdiscript => $config{'SDISCRIPT'}, 
				logObj => $params{logObj});
    
    my %StandbySDIOVMDetails =$standbysdiObj->
	getOVMPropertiesHashfromSDI(system_name => $params{System_Name}, 
				    logdir => $params{logdir}, 
				    config => $params{config});
    
    my @Primary_MW_Hosts=();
    my @Primary_App_Hosts=();
    my @Primary_DB_Hosts=();
    my @Standby_MW_Hosts=();
    my @Standby_App_Hosts=();
    my @Standby_DB_Hosts=();
    
    my $MW_Hosts = "faovm.ha.HOST_(BI\$|OHS\$|OHS_HA1\$|OSN\$|OSN_HA1\$";
    $MW_Hosts .= "|FA\$|PRIMARY\$|PRIMARY_HA1\$|SECONDARY\$";
    $MW_Hosts .= "|SECONDARY_HA1\$|PRIMARY_SCALE|OHS_SCALE|AUXVM_SCALE" ;
    $MW_Hosts .= "|LDAP\$|OIM\$|WEBGATE\$)" ;
    
    my $App_Hosts = "faovm.ha.HOST_(FA\$|PRIMARY\$|PRIMARY_HA1\$|";
    $App_Hosts.= "SECONDARY\$|SECONDARY_HA1\$|BI\$|OSN\$|OSN_HA1\$|";
    $App_Hosts.= "PRIMARY_SCALE|OHS_SCALE|AUXVM_SCALE)" ;
    
    my $DB_Hosts = "faovm.ha.HOST_(DB\$|IDSDB\$|OIDDB\$)";
    
    
    map { push @Primary_MW_Hosts, $PrimSDIOVMDetails{$_} 
	  if ($_ =~ /$MW_Hosts/) } keys %PrimSDIOVMDetails;
    
    map { push @Primary_DB_Hosts, $PrimSDIOVMDetails{$_} 
	  if ($_ =~ /$DB_Hosts/) } keys %PrimSDIOVMDetails;
    
    map { push @Primary_App_Hosts, $PrimSDIOVMDetails{$_} 
	  if ($_ =~ /$App_Hosts/) } keys %PrimSDIOVMDetails;
    
    map { push @Standby_MW_Hosts, $StandbySDIOVMDetails{$_} 
	  if ($_ =~ /$MW_Hosts/) } keys %StandbySDIOVMDetails;
    
    map { push @Standby_DB_Hosts, $StandbySDIOVMDetails{$_} 
	  if ($_ =~ /$DB_Hosts/) } keys %StandbySDIOVMDetails;
    
    map { push @Standby_App_Hosts, $StandbySDIOVMDetails{$_} 
	  if ($_ =~ /$App_Hosts/) } keys %StandbySDIOVMDetails;
    
    
    my $PrimarydbOLSNode = 
	getDBNodeNamefromDBHost
	(DB_HOST => $PrimSDIOVMDetails{"faovm.ha.HOST_DB"},
	 logObj => $params{logObj},
	 DBremoteObj => $params{DBremoteObj});
    
    my $StandbydbOLSNode = 
	getDBNodeNamefromDBHost
	(DB_HOST => $StandbySDIOVMDetails{"faovm.ha.HOST_DB"},
	 logObj => $params{logObj},
	 DBremoteObj => $params{DBremoteObj});
    
    my $PrimaryUtilityHost = $primsdiObj->getUtilityHost();
    my $StandbyUtilityHost = $standbysdiObj->getUtilityHost();
    
    $OVMProps{'fadrScriptsPath'} = $fadrScriptsPath;
    $OVMProps{'PrimarydbOLSNode'} = $PrimarydbOLSNode;
    $OVMProps{'StandbydbOLSNode'} = $StandbydbOLSNode;
    $OVMProps{'PrimaryUtilityHost'} = $PrimaryUtilityHost;
    $OVMProps{'StandbyUtilityHost'} = $StandbyUtilityHost;
    $OVMProps{'PrimSDIOVMDetails'} = \%PrimSDIOVMDetails;
    $OVMProps{'StandbySDIOVMDetails'} = \%StandbySDIOVMDetails;
    $OVMProps{'Primary_MW_Hosts'} = \@Primary_MW_Hosts;
    $OVMProps{'Primary_App_Hosts'} = \@Primary_App_Hosts;
    $OVMProps{'Primary_DB_Hosts'} = \@Primary_DB_Hosts;
    $OVMProps{'Standby_MW_Hosts'} = \@Standby_MW_Hosts;
    $OVMProps{'Standby_App_Hosts'} = \@Standby_App_Hosts;
    $OVMProps{'Standby_DB_Hosts'} = \@Standby_DB_Hosts;
    
    return (\%OVMProps);
    
}


# // This Method would prepare the EM Operation Plan for the environment. 
#   Input is the Operation Plan Name which tells whether it is fail-over
#   or switch-over and whether it is from Primary to Secondary or vice-versa.
#   It would also take the OVM Hosts details and generates the plan dynamically
#   and the Plan Array would be the Ouput.
sub buildSGCPlan {

    my (%params) = @_;

    
    my $EmPlanNm = $params{EmPlanNm};
    my $logdir = $params{logdir};

    my $EMOperationType = (split /\_/, $EmPlanNm)[1];
    my $EMPrimarySystem = (split /\_/, $EmPlanNm)[2];
    
    my ($dbOLSNode, $MW_Hosts, $App_Hosts, $SDIOVMDetails, $PlanNm); 
    
    my $file1 = "$EmPlanNm\_generated.txt";
    
    my @EM_PlanExpectedArray=();
    
    
    push @EM_PlanExpectedArray, 
    updatedcScripts(fadrScriptsPath => $params{fadrScriptsPath},
		    System_Name => $params{System_Name},
		    EMOperationType => $EMOperationType,
		    EMPrimarySystem => $EMPrimarySystem,
		    PrimaryUtilityHost => $params{PrimaryUtilityHost}, 
		    StandbyUtilityHost => $params{StandbyUtilityHost}, 
		    PrimSDIOVMDetails => $params{PrimSDIOVMDetails}, 
		    StandbySDIOVMDetails => $params{StandbySDIOVMDetails});
    
    if($EMPrimarySystem eq "from") {
        $MW_Hosts = $params{Primary_MW_Hosts};
        $App_Hosts = $params{Primary_App_Hosts};
        $SDIOVMDetails = $params{PrimSDIOVMDetails};
    }
    else{
        $MW_Hosts = $params{Standby_MW_Hosts} ;
        $App_Hosts = $params{Standby_App_Hosts};
        $SDIOVMDetails = $params{StandbySDIOVMDetails};
    }    
    
    push @EM_PlanExpectedArray, 
    prepostScriptsonSite1(MW_Hosts => $MW_Hosts,
			  App_Hosts => $App_Hosts,
			  zdtEnabled => $params{zdtEnabled},
			  SDIOVMDetails => $SDIOVMDetails);
    
    if($EMPrimarySystem eq "from") {
        $MW_Hosts = $params{Standby_MW_Hosts};
        $App_Hosts = $params{Standby_App_Hosts};
        $SDIOVMDetails = $params{StandbySDIOVMDetails};
    }
    else{
        $MW_Hosts = $params{Primary_MW_Hosts} ;
        $App_Hosts = $params{Primary_App_Hosts} ;
        $SDIOVMDetails = $params{PrimSDIOVMDetails};
    }
    
    push @EM_PlanExpectedArray, 
    prepostScriptsonSite2(EMOperationType => $EMOperationType,
			  MW_Hosts => $MW_Hosts,
			  App_Hosts => $App_Hosts,
			  zdtEnabled => $params{zdtEnabled},
			  SDIOVMDetails => $SDIOVMDetails);
    
    
    push @EM_PlanExpectedArray, 
    storageScripts(EMOperationType => $EMOperationType,
		   EMPrimarySystem => $EMPrimarySystem,
		   PrimaryUtilityHost => $params{PrimaryUtilityHost}, 
		   StandbyUtilityHost => $params{StandbyUtilityHost}, 
		   PrimSDIOVMDetails => $params{PrimSDIOVMDetails}, 
		   StandbySDIOVMDetails => $params{StandbySDIOVMDetails});
    
    if($EMPrimarySystem eq "from") {
        $dbOLSNode = $params{StandbydbOLSNode};
        $SDIOVMDetails = $params{StandbySDIOVMDetails};
    }
    else{
        $dbOLSNode = $params{PrimarydbOLSNode} ;
        $SDIOVMDetails = $params{PrimSDIOVMDetails};
    }
    
    push @EM_PlanExpectedArray, 
    databaseScripts(dbOLSNode => $dbOLSNode,
		    SDIOVMDetails => $SDIOVMDetails);
    
    
    open OUT," > $logdir/$file1" or die "$!\n";
    
    foreach $PlanNm(@EM_PlanExpectedArray) {
	print OUT "$PlanNm\n";
    }
    
    close OUT;
    
    sortFile("$logdir/$file1");
    
}

# This method would get the Middleware Home Env Variable from a given Host.
sub getMWHOME {
    
    my (%params) = @_;
    
    my ($cmd, $filter, $out, $MW_HOME);
    
    $cmd="\"echo \\\$MW_HOME\"";
    
    $filter = " awk ' { if (\$1 !~ (/spawn|ssh|Authorized|Warning|";
    $filter .= "Offending|Matching|$params{HOST}|exit|";
    $filter .= ".:/)) print \$1}'";
    
    $out = $params{InfraRemoteObj}->
        executeCommandsonRemote(host => $params{HOST},
				cmd => "$cmd",
				filter => "$filter");
    
    $MW_HOME=@$out[0];
    $MW_HOME =~ s/\r?\n//g;
    $MW_HOME =~ s/MW_HOME=//g;
    
    return $MW_HOME;
    
}

#   This Method would get the Pod System Roles in Enterprise Manager.
#   This role should be updated in EM accordingly when user does 
#   a Switchover or Switchback operations on a pod.
#   Input: OMS System Name, OMS HOST, DR Role of that Pod.
sub validatePodRoleInEM {
    
    my ($self, %params) = @_;        
    
    my ($cmd, $filter, $out, $MW_HOME);
    
    $MW_HOME = getMWHOME(HOST => $params{OMS_HOST},
			 InfraRemoteObj => $self->{'InfraRemoteObj'});
    
    $cmd  ="$MW_HOME/bin/./emcli get_siteguard_configuration ";
    if($params{drmode} eq "ACTIVE"){
	$cmd .="-primary_system_name=$params{oms_system}";
    }
    else{
	$cmd .="-standby_system_name=$params{oms_system}";
    }
    $cmd .="_generic_system -format=name:csv"; 
    
    $filter = " awk ' { if (\$1 !~ (/spawn|ssh|exit|Primary|Warning|";
    $filter .= "Authorized|Offending|Matching|$params{OMS_HOST}|";
    $filter .= ".:/)) print \$1}' | tr -d '\r\n'";     
    
    $out = $self->{'InfraRemoteObj'}->
	executeCommandsonRemote(host => $params{OMS_HOST}, 
				cmd => "$cmd",
				filter => "$filter");
    
    if (@$out and grep(/^$params{oms_system}/i, @$out) 
	and !grep(/^Stale configurations found/i, @$out)) {
	open OUT," > $params{logpath}/EMPodRoleTest.suc.html" or die "$!\n";
	print OUT "@$out\n";
	close OUT;	
    }
    else
    {
	open OUT," > $params{logpath}/EMPodRoleTest.suc.html" or die "$!\n";
	print OUT "@$out\n";
	close OUT;
    }
    
}

#   This Method would perform the switchover of a pod from site 1 to site 2
#   or fail over from site 1 to site 2 or Vice-versa.
#   Input: Primary System Name based on Site1/Site2 or Site2/Site1 
#   Input: Operation if switchver/failover, OMS_HOST
sub performSwitchoverFailOver {
    
    my ($self, %params) = @_;        
    
    my ($cmd, $filter, $out, $plan_nm, $MW_HOME, $exstproc, $newproc, 
	$jobrunning, $jobname);
    
    $MW_HOME = getMWHOME(HOST => $params{OMS_HOST},
			 InfraRemoteObj => $self->{'InfraRemoteObj'});
    
    $cmd  ="$MW_HOME/bin/./emcli get_operation_plans ";
    $cmd .="-primary_system_name=$params{oms_system_nm}";
    $cmd .="_generic_system -operation=$params{operation}";
    $cmd .=" -format=name:csv | cut -d\",\" -f1";        
    
    $filter = " awk ' { if (\$1 !~ (/spawn|ssh|exit|Authorized|";
    $filter .= "Warning|Offending|Matching|$params{OMS_HOST}|Plan|";
    $filter .= ".:/)) print \$1}' | tr -d '\r\n'";     
    
    $plan_nm = $self->{'InfraRemoteObj'}->
        executeCommandsonRemote(host => $params{OMS_HOST}, 
				cmd => "$cmd",
				filter => "$filter");
    
    $plan_nm =~ s/\r?\n//g;
    
    print "@$plan_nm[0]";
    
    $filter = " awk ' { if (\$1 !~ (/spawn|ssh|exit|Authorized|Warning|";
    $filter .= "Offending|Matching|$params{OMS_HOST}|^\$/) ) print }'";	
    
    $cmd ="$MW_HOME/bin/./emcli get_instances -type=SiteGuard";
    $cmd .=" -format=name:csv -noheader | cut -d \",\" -f4";
    
    $exstproc = $self->{'InfraRemoteObj'}->
        executeCommandsonRemote(host => $params{OMS_HOST}, 
				cmd => "$cmd",
				filter => "$filter");
    
    $cmd ="$MW_HOME/bin/./emcli run_prechecks -operation_plan=@$plan_nm[0]";
    
    $out = $self->{'InfraRemoteObj'}->
        executeCommandsonRemote(host => $params{OMS_HOST}, 
				cmd => "$cmd",
				filter => "$filter");
    
#	$cmd ="$MW_HOME/bin/./emcli submit_operation_plan";
#   $cmd .=" -name=@$plan_nm[0] -run_prechecks=true";
#
#	$out = $self->{'InfraRemoteObj'}->
#        executeCommandsonRemote(host => $params{OMS_HOST}, 
#				cmd => "$cmd",
#				filter => "$filter");
    
    $out =~ s/\r?\n//g;
    
    if (!@$out) {
        print "Could not run pre-checks on Operation Plan $plan_nm\n";
    } else {
	print "@$out";
    }
    
    $cmd ="$MW_HOME/bin/./emcli get_instances -type=SiteGuard";
    $cmd .=" -format=name:csv -noheader | cut -d \",\" -f4";
    
    $newproc = $self->{'InfraRemoteObj'}->
        executeCommandsonRemote(host => $params{OMS_HOST}, 
				cmd => "$cmd",
				filter => "$filter");
    
    my %exstproc = map {$_, 1} @$exstproc;
    my @difference = grep {!$exstproc {$_}} @$newproc;
    
    
    print "@{[%exstproc]}"; 
   
    $jobname = $difference[0];
    chomp($jobname);
    
    print "jobname::$jobname\nEnd";
    print "difference::@difference\nEnd";
	
    my $jobid = (split / /, $jobname)[1];
    
    if("$#difference" > -1){
	
		$jobrunning = "true";
		
		$cmd ="$MW_HOME/bin/./emcli get_instances -type=SiteGuard -format=name:csv ";
		
		print "command is :: $cmd\n";

	        $filter = " awk -F ','  ' /$jobid/ { if (\$1 !~ (/spawn|ssh|exit|Authorized|Warning|";
	        $filter .= "Offending|Matching|$params{OMS_HOST}|^\$/) ) print \$5}' | tr -d '\r\n'";

		while ($jobrunning eq "true") {
		
		$out = $self->{'InfraRemoteObj'}->
			executeCommandsonRemote(host => $params{OMS_HOST}, 
						cmd => "$cmd",
						filter => "$filter");
		
		if(! grep(/Succeeded|Failed/i, @$out)) {
			$jobrunning = "true";
			print "Job Status :: @$out[0]\n";
		}
		else{
			$jobrunning = "false";
			print "Job Status :: @$out[0]\n";
		}
		
		sleep(30);
		}
    
	}
    

}

#   This Method would connect to EM or SDI Host machine and would get the
#   Operation Plans defined for the Identity domain which is the input
#   Compares the EM Plan setup in system currently and compares against the 
#   EM Operation plan built and sets the PASS/FAIL Status.
sub getOperationPlansfromEM {
    
    my (%params) = @_;        
    
    my ($cmd, $filter, $out, $MW_HOME);
    
    $cmd  ="$params{MW_HOME}/bin/./emcli get_operation_plans ";
    $cmd .="-system_name=$params{OMS_Target_Name}";
        $cmd .="_generic_system -format=name:csv| cut -d\",\" -f1";        
    
    $filter = " awk ' { if (\$1 !~ (/spawn|ssh|exit|$params{OMS_HOST}|";
    $filter .= "Authorized|Warning|Offending|Matching|";
    $filter .= ".:/)) print \$1}'";
    
    $out = $params{InfraRemoteObj}->
        executeCommandsonRemote(host => $params{OMS_HOST}, 
				cmd => "$cmd",
				filter => "$filter");
    
    my @Plans_Array=();
    
    for my $value(@$out) {
	$value =~ s/\r?\n//g;
	chomp($value);
	if($value ne "" and $value !~ /Plan/ 
	   and $value !~ m/$params{OMS_HOST}/){
	    push(@Plans_Array, $value);
	}
    }
    
    return @Plans_Array;
    
}

# This method would fetch the Operation Plan Details by connecting to EM Host
# Operation Plan Name would be input and Operation Plan details would be saved
# to an array and a file.
sub getOperationPlanDetailsfromEM {
    
    my (%params) = @_;
    
    my ($cmd, $filter, $out);
    
    my $filename = "$params{EmPlanName}.txt";
    
    system("rm -f $params{logdir}/$filename");
    
    $cmd="$params{MW_HOME}/bin/./emcli get_operation_plan_details";
    $cmd.=" -name=$params{EmPlanName} -format=name:csv ";
    
    $filter = " awk -F ',' ' { if (\$1 !~ (/spawn|ssh|exit|$params{OMS_HOST}";
    $filter .= "|Authorized|Warning|Offending|Matching/)) ";
    $filter .= "print \$3 \",\" \$4}' >> $params{logdir}/$filename";
    
    $out = $params{InfraRemoteObj}->
        executeCommandsonRemote(host => $params{OMS_HOST},
				cmd => "$cmd", 
				filter => "$filter");
    
    sortFile("$params{logdir}/$filename");
    
    
}

# This method compares the Operation Plans configured in the system against
# the one that is generated by the Script manually based on OVM Properties.

sub validateEMPlans {
    
    my (%params) = @_;
    
    my $MW_HOME = getMWHOME(HOST => $params{OMS_HOST},
			    InfraRemoteObj => $params{'InfraRemoteObj'});
    
    my @EMPlans_Array = 
	getOperationPlansfromEM(OMS_HOST => $params{OMS_HOST},
				OMS_Target_Name => $params{OMS_Target_Name},
				MW_HOME => $MW_HOME,
				logObj => $params{'logObj'},
				InfraRemoteObj => $params{'InfraRemoteObj'},
				logdir => $params{'logdir'});
    
    
    my $testresult = "";
    my $testcomments = "";
    
    if ("$#EMPlans_Array" > -1) 
    {
	foreach my $PlanNm(@EMPlans_Array){
	    buildSGCPlan(EmPlanNm => $PlanNm,
			 fadrScriptsPath => $params{fadrScriptsPath}, 
			 System_Name => $params{System_Name}, 
			 zdtEnabled	 =>	$params{zdtEnabled},
			 PrimarydbOLSNode => $params{PrimarydbOLSNode}, 
			 StandbydbOLSNode => $params{StandbydbOLSNode}, 
			 PrimaryUtilityHost => $params{PrimaryUtilityHost}, 
			 StandbyUtilityHost => $params{StandbyUtilityHost}, 
			 Primary_MW_Hosts => $params{Primary_MW_Hosts},
			 Primary_App_Hosts => $params{Primary_App_Hosts},
			 Primary_DB_Hosts => $params{Primary_DB_Hosts}, 
			 Standby_MW_Hosts => $params{Standby_MW_Hosts}, 
			 Standby_App_Hosts => $params{Standby_App_Hosts}, 
			 Standby_DB_Hosts => $params{Standby_DB_Hosts}, 
			 logdir => $params{logdir}, 
			 PrimSDIOVMDetails => $params{PrimSDIOVMDtls}, 
			 StandbySDIOVMDetails=>$params{StandbySDIOVMDtls});
	    
	    getOperationPlanDetailsfromEM
		(OMS_HOST => $params{OMS_HOST}, 
		 EmPlanName   => $PlanNm, 
		 MW_HOME => $MW_HOME, 
		 logObj     => $params{logObj}, 
		 InfraRemoteObj  => $params{InfraRemoteObj}, 
		 logdir     => $params{logdir});
	    
	    my $file1="$params{logdir}/$PlanNm\_generated.txt"; 
	    my $file2="$params{logdir}/$PlanNm.txt"; 
	    
	    
	    my $test1 = `comm -23 $file1 $file2 `;
	    
	    
	    if($test1 ne "")
            {
		$testcomments="$testcomments$PlanNm Plan is missing steps. ";
		$testcomments .="Please review missing Steps >> \n$test1\n\n";
            }
            
	    my $test2 = `comm -13 $file1 $file2 `;
	    
	    if($test2 ne "")
            {
		$testcomments="$testcomments$PlanNm Plan is having extra steps";
		$testcomments .=". Please review extra Steps >> \n$test2\n\n";
            }
            if($test1 eq "" and $test2 eq "")
            {
		print("$PlanNm Plan is setup well. No issues.\n");
            }
	    
        }
    }
    else
    {
	$testcomments="Could not fetch the Operation Plans for $params{System_Name}.";
    }
    
    print "testcomments=$testcomments\n";
    
    if($testcomments ne "")
    {
	$testresult = "Failed";
	$testcomments =~ s/[\n\r]/\n\r<br>/g;
	open OUT," > $params{logpath}/SGCPlansTest.dif.html" or die "$!\n";
	print OUT "$testcomments\n";
	close OUT;
	
    }
    else
    {
	system("touch $params{logpath}/SGCPlansTest.suc.html");
	$testresult = "Passed";
    }
    
    return $testresult;
}

# This method sorts the file alphabetically and saves in the same file. Input 
# is file name with File path and output is sorted file without empty lines.
sub sortFile {
    
    my ($filename) = @_;
    
    open(FILE, "<$filename");
    my(@lines) = <FILE>;
    @lines = sort(@lines);

    open(FILE, ">$filename");
    
    my($line);
    foreach $line (@lines)
    {
         if ($line !~ /^$/ and $line !~ /^\s*$/ and $line !~ /^,/ 
             and $line !~ /^Step/  and $line !~ /^Target/)
         {
	     print FILE "$line" 
	     }
     }
    close(FILE);
    
}


# This method would build the data center update scripts of EM Operation Plan
# for both Switchover and Failover cases between Primary and Standby.
sub updatedcScripts{
    
    my (%params) = @_;
    
    my $fadrScriptsPath = $params{fadrScriptsPath};
    my $System_Name = $params{System_Name};
    my $PrimaryUtilityHost = $params{PrimaryUtilityHost};
    my $StandbyUtilityHost = $params{StandbyUtilityHost};
    my %PrimSDIOVMDetails = %{$params{PrimSDIOVMDetails}}; 
    my %StandbySDIOVMDetails = %{$params{StandbySDIOVMDetails}};
    my $EMOperationType = $params{EMOperationType};
    my $EMPrimarySystem = $params{EMPrimarySystem};
    
    my @updateDCScript =();


    if(($EMOperationType eq "sw" or $EMOperationType eq "fv") and $EMPrimarySystem eq "from")
    {    
        if($EMOperationType eq "sw") 
        {    
	    
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_before_activating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_after_activating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_before_passivating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_after_passivating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
        }
        else {
	    
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_before_activating_during_failover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_after_activating_during_failover.pl--id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_before_passivating_during_failover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_after_passivating_during_failover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
        }
    }
    elsif(($EMOperationType eq "sw" or $EMOperationType eq "fv") and $EMPrimarySystem eq "to") # This elseif loop covers switch over and failover cases from Standby to Primary.
    {    
        if($EMOperationType eq "sw")
        {
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_before_passivating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
           
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_after_passivating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_before_activating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_after_activating_during_switchover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
        }
        else
        {    
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_before_passivating_during_failover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_standby_dc_after_passivating_during_failover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $StandbySDIOVMDetails{\"podname\"} --dc_short_name $StandbySDIOVMDetails{\"dcshortname\"},$StandbyUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_before_activating_during_failover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
            
            push(@updateDCScript, "$fadrScriptsPath/update_primary_dc_after_activating_during_failover.pl --id_name $System_Name --svc_name $PrimSDIOVMDetails{\"service_name\"} --pod_name $PrimSDIOVMDetails{\"podname\"} --dc_short_name $PrimSDIOVMDetails{\"dcshortname\"},$PrimaryUtilityHost");
        }
    }
    
    return @updateDCScript;

}

# This method would build the Pre and Post scripts of Operation Plan 
# on current Active Site.

sub prepostScriptsonSite1{
    
    my (%params) = @_;

    my $EmVersion = $params{EmVersion};
    my @MW_Hosts = @{$params{MW_Hosts}}; 
    my @App_Hosts = @{$params{App_Hosts}}; 
    my %SDIOVMDetails = %{$params{SDIOVMDetails}}; 
    
    my $emagentlocation = "$SDIOVMDetails{\"faovm.emagent.oracle.base\"}/core/$SDIOVMDetails{\"faovm.emagent.version\"}";

    my $val1;
    my @prepostScriptsonSite1 =();

       foreach $val1(@MW_Hosts) # Pre-Switch Over scripts, Stop and unmount Primary primary Hosts.
        {
      
        #Sample Generated line sh siteguard_control.sh -u stop -t pre -c Y -b on  -a /oem/app/oracle/product/12c/core/12.1.0.5.0,slc04qob.us.oracle.com
           #Sample Generated line sh mount_umount.sh -o umount -f /u01,slc04qob.us.oracle.com
           
           push(@prepostScriptsonSite1, "sh siteguard_control.sh -u stop -t pre -c Y -b on  -a $emagentlocation,$val1");
           
           push(@prepostScriptsonSite1, "sh siteguard_control.sh -u stop -t post -c Y -b on  -a $emagentlocation,$val1");
           
           push(@prepostScriptsonSite1, "sh mount_umount.sh -o umount -f /u01,$val1");
        }
	
	print "zdtEnabled Value=$params{zdtEnabled} End##";
    if($SDIOVMDetails{'podver'} >= 11 or $params{zdtEnabled} eq "true")
    {
	# Pre-Switch Over scripts, Stop and unmount Primary primary Hosts.
	foreach my $hostnm(@App_Hosts) 
	{      
	    #Sample sh mount_umount.sh -o umount -f /u01,slc04qob.us.oracle.com
	    push(@prepostScriptsonSite1, "sh mount_umount.sh -o umount -f /u02,$hostnm");
	}
    }
    
    push(@prepostScriptsonSite1, "sh mount_umount.sh -o umount -f /osn_scratch,$SDIOVMDetails{\"faovm.ha.HOST_OSN\"}");
    
    
    return @prepostScriptsonSite1;
}

# This method would build the Pre and Post scripts of Operation Plan 
# on current Passive Site.
sub prepostScriptsonSite2{
    
    my (%params) = @_;
    
    my $EmVersion = $params{EmVersion};
    my @MW_Hosts = @{$params{MW_Hosts}};
    my @App_Hosts = @{$params{App_Hosts}}; 
    my %SDIOVMDetails = %{$params{SDIOVMDetails}}; 
    my $EMOperationType = $params{EMOperationType};
    
    my $emagentlocation = "$SDIOVMDetails{\"faovm.emagent.oracle.base\"}/core/$SDIOVMDetails{\"faovm.emagent.version\"}";

    my $val1;
    my @prepostScriptsonSite2 =();


    # Post Switch over Start and Mount Scripts for Standby.
    foreach $val1(@MW_Hosts) {
       push @prepostScriptsonSite2,"sh mount_umount.sh -o mount -f /u01,$val1";
       
       if($EMOperationType eq "sw"){
           push(@prepostScriptsonSite2, "sh siteguard_control.sh -u start -c Y -b on  -a $emagentlocation,$val1");
       }
       else
        {
           push(@prepostScriptsonSite2, "sh siteguard_control.sh -u start -i y -c Y -b on  -a $emagentlocation,$val1");
        }
        
    }
    
    if($SDIOVMDetails{'podver'} >= 11 or $params{zdtEnabled} eq "true")
    {
	# Post Switch over Start and Mount Scripts for Standby.
	foreach my $hostnm(@App_Hosts) 
	{      
	    #Sample sh mount_umount.sh -o mount -f /u02,slc04qob.us.oracle.com
	    push(@prepostScriptsonSite2, "sh mount_umount.sh -o mount -f /u02,$hostnm");
	}
    }
    
    push(@prepostScriptsonSite2, "sh mount_umount.sh -o mount -f /osn_scratch,$SDIOVMDetails{\"faovm.ha.HOST_OSN\"}");
    
  if($EMOperationType eq "fv")
  {
      push(@prepostScriptsonSite2, "/u01/APPLTOP/instance/drscripts/sgLCMWrapper.sh,$SDIOVMDetails{\"faovm.ha.HOST_FA\"}");
  }

    return @prepostScriptsonSite2;

}

# This method would build the Storage Reversal scripts of EM Operation Plan
# for both Switchover and Failover cases between Primary and Standby.
sub storageScripts{
    
    my (%params) = @_;

    my $PrimaryUtilityHost = $params{PrimaryUtilityHost};
    my $StandbyUtilityHost = $params{StandbyUtilityHost};
    my %PrimSDIOVMDetails = %{$params{PrimSDIOVMDetails}}; 
    my %StandbySDIOVMDetails = %{$params{StandbySDIOVMDetails}};
    my $EMOperationType = $params{EMOperationType};
    my $EMPrimarySystem = $params{EMPrimarySystem};


    my @storageScripts =();

    if(($EMOperationType eq "sw" or $EMOperationType eq "fv") and $EMPrimarySystem eq "from")
    {    
        if($EMOperationType eq "sw") # Role-Reversal scripts for Storage in case of switch-over.
        {    
            #Sample Generated line sh zfs_storage_role_reversal.sh -c N -f N -s get_action -o opc_switchover -t slcnas570.us.oracle.com -h slcnas559.us.oracle.com -j fa_fadrsdihcmser9833343 -p pool-570 -q pool-559,slc03why.us.oracle.com
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_action -o opc_switchover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_replication_properties -o opc_switchover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_source -o opc_switchover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s role_reverse -o opc_switchover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
        }
        else
        {  # Role-Reversal scripts for Storage in case of fail-over.
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_action -o opc_failover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_replication_properties -o opc_failover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_source -o opc_failover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s role_reverse -o opc_failover -t $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -h $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"} -q $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
        }
    }
    elsif(($EMOperationType eq "sw" or $EMOperationType eq "fv") and $EMPrimarySystem eq "to") # This elseif loop covers switch over and failover cases from Standby to Primary.
    {
        if($EMOperationType eq "sw") # Role-Reversal scripts for Storage in case of switch-over.
        {
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_action -o opc_switchover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_replication_properties -o opc_switchover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_source -o opc_switchover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s role_reverse -o opc_switchover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
        }
        else  # Role-Reversal scripts for Storage in case of fail-over.
        {
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_action -o opc_failover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_replication_properties -o opc_failover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$StandbyUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s get_source -o opc_failover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
            
            push(@storageScripts, "sh zfs_storage_role_reversal.sh -c N -f N -s role_reverse -o opc_failover -t $PrimSDIOVMDetails{\"faovm.storage.sun.host\"} -h $StandbySDIOVMDetails{\"faovm.storage.sun.host\"} -j $PrimSDIOVMDetails{\"faovm.storage.sun.project\"} -p $PrimSDIOVMDetails{\"faovm.storage.sun.pool\"} -q $StandbySDIOVMDetails{\"faovm.storage.sun.pool\"},$PrimaryUtilityHost");
        }
    }
        
    return @storageScripts;

}

# This method would build the Database update scripts of EM Operation Plan.
sub databaseScripts{
    
    my (%params) = @_;

    my $dbOLSNode = $params{dbOLSNode};
    my %SDIOVMDetails = %{$params{SDIOVMDetails}}; 

    my @databaseScripts =();

    # Database Switch over scripts
    #Sample Generated line fadrsdihcmser9833343_ser9833343.us2_4_fadbr9s_fadbr9p1,slc03whj.us.oracle.com
   
    push(@databaseScripts,"$SDIOVMDetails{\"faovm.oms.target.name\"}_$SDIOVMDetails{\"faovm.ha.fusiondb.new.dbuniquename\"}_$SDIOVMDetails{\"faovm.ha.fusiondb.new.rac.sid1\"},$dbOLSNode.us.oracle.com");
    
    push(@databaseScripts,"$SDIOVMDetails{\"faovm.oms.target.name\"}_$SDIOVMDetails{\"faovm.ha.idsdb.new.dbuniquename\"}_$SDIOVMDetails{\"faovm.ha.idsdb.new.rac.sid1\"},$dbOLSNode.us.oracle.com");
    
    push(@databaseScripts,"$SDIOVMDetails{\"faovm.oms.target.name\"}_$SDIOVMDetails{\"faovm.ha.oiddb.new.dbuniquename\"}_$SDIOVMDetails{\"faovm.ha.oiddb.new.rac.sid1\"},$dbOLSNode.us.oracle.com");


    return @databaseScripts;

}


__END__

=head1 NAME

    Validate Site Guard Plans

=head1 SYNOPSIS

    ValidateSiteGuardPlans [arguments]

    Options:

        *system_name:
            Identity domain. Example: fadrsdihcmser1010101

        *primarysdi:
            Primary SDI Host name. Example: slc03wel

        *standbysdi:
            Standby SDI Host name. Example: slc03wlg

        *PrimaryHost:
            Primary Utility Host name. Example: slc03wlf.us.oracle.com

        *StandbyHost:
            Standby Utility Host name. Example: slc03why.us.oracle.com

        *logdir:
            Log directory to save *.log, *.dif.. Example: /scratch/aime/mytest


=cut

