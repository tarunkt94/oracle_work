#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

BEGIN{
        push(@INC, '/scratch/aime/hari_slc06xjl/sampath/DR_AUTO_HOME/scripts/Cloud9/generic');
}
use JSON;

my ($tag,$rackid,$json_file,$em_registration,$pillar,$seed_pool,$running_pool,$sdictl);


get_input();

validate_input();

my $json_object= readJSON($json_file);

register_tag($tag);

get_em_registration();

adddb('FUSION',$json_object);

adddb('IDM',$json_object);

addtags($tag,'FUSION',$json_object);

addtags($tag,'IDM',$json_object);

addrack($rackid,$tag,$json_object);

addOVS($rackid,$json_object);

sub get_input{
        GetOptions('tag=s' => \$tag,
                   'rackid=s' => \$rackid,
                   'json_file=s' => \$json_file,
		   'pillar=s' => \$pillar,
		   'seed_pool=s' => \$seed_pool,
		   'running_pool=s' => \$running_pool) or pod2usage(2);
}

sub validate_input{
	die "\nNo file present at location $json_file\n" unless (-f $json_file);
}

sub create_objects{

	$sdictl = $json_object->{SDI_INFO}{SDI_HOME} . '/sdictl/sdictl.sh';

	my $logObj = Logger->new(
                      {'loggerLogFile' => "/tmp/test.log",
                      'maxLogLevel' => 4}
                      );

	my $sdiObj = new SDI(user => $sdi_user,
			     passwd =>  $sdi_passwd,
			     host => "$json_object->{SDI_INFO}{SDI1_HOST}",
			     sdiscript => $sdictl,
			     logObj => $logObj);

	
}

sub register_tag{
	my $cmd = "$sdictl register_tag -tagName $tag";
	
}

sub get_em_registrations{

	my $em_hostname = "$json_object->{SDI_INFO}{EMGC_HOST}";
	
	my %emhash = $sdiObj->getEMDetails(hostname => $em_hostname);

	my $em_registration = $emhash{0}{name};
}
sub adddb{
	my $type = shift;
	my $json_object = shift;
	my $fa_database_type;
	$fa_database_type = 'MAIN_DB' if $type eq 'FUSION';
	$fa_database_type = 'OID_DB' if $type eq 'OID';
	my $DB_UNIQUE_NAME = $type . "_DB_UNIQUE_NAME";
	my $DB_NAME = $type . "_DB_NAME";
	my $DB_PORT = $type . "_DB_PORT";
	my $DB_SID1 = $type . "_DB_SID1";
	my $DB_SID2 = $type . "_DB_SID2";	
	my $DB_SERVICE_NAME = $type . "_DB_SERVICE_NAME";
	my $DB_DATADISC_NAME = $type . "_DB_DATADISC_NAME";
	my $DB_RECIDISC_NAME = $type . "_DB_RECIDISC_NAME";
	my $DB_ORACLE_HOME = $type . "_DB_ORACLE_HOME";
	my $cmd = "$sdictl addfadb"
		." -db_unique_name $json_object->{RACDB_INFO}{$DB_UNIQUE_NAME}"
	        ." -db_name $json_object->{RACDB_INFO}{$DB_NAME}"
	        ." -port $json_object->{RACDB_INFO}{$DB_PORT}"
	        ." -host_name1 $json_object->{RAC_NODE1_VIP_HOST}"
	        ." -sid1 $json_object->{RACDB_INFO}{$DB_SID1}"
	        ." -db_servicename $json_object->{RACDB_INFO}{$DB_SERVICE_NAME}"
	        ." -data_disc $json_object->{RACDB_INFO}{$DB_DATADISC_NAME}"
	        ." -reco_disc $json_object->{RACDB_INFO}{$DB_RECIDISC_NAME}"
	        ." -is_asm true"
	        ." -asm_user $json_object->{RACDB_INFO}{ASM_USERNAME}"
	        ." -asm_password $json_object->{RACDB_INFO}{ASM_USERPWD}"
	        ." -fa_database_type $fa_database_type"
	        ." -db_version how_to_get_it $json_object->{VMS}{1}{RAC_VERSION}"
	        ." -host_name2 $json_object->{RAC_NODE2_VIP_HOST}"
	        ." -sid2 $json_object->{RACDB_INFO}{$DB_SID2}"
	        ." -cluster_host1 $json_object->{RAC_NODE1_HOST}"
        	." -cluster_host2 $json_object->{RAC_NODE2_HOST}"
	        ." cluster_name $json_object->{RAC_CLUSTER_VIP_HOST}"
	        ." -crs_scan_name $json_object->{RACDB_INFO}{SRC_SCAN_NAME}"
	        ." -crs_scan_port $json_object->{RACDB_INFO}{CRS_SCAN_PORT}"	
	        ." -crs_home $json_object->{RACDB_INFO}{CRS_HOME}"
	        ." -crs_ons_port $json_object->{RACDB_INFO}{CRS_ONS_PORT}"
        	." -asm_sid1 $json_object->{RACDB_INFO}{ASM_SID1}"
	        ." -asm_sid2 $json_object->{RACDB_INFO}{ASM_SID2}"
	        ." -dg_preconfigured_listener_name LISTENER_DG"
	        ." -dg_preconfigured_listener_port 1521"
	        ." -oracle_home $json_object->{RACDB_INFO}{$DB_ORACLE_HOME}"
	        ." -application_listener_name LISTENER_$json_object->{RACDB_INFO}{$DB_UNIQUE_NAME}"
	        ." -oracle_base /u01/app/oracle"
	        ." -em_registration $em_registration"
	        ;

	print "\n$cmd\n";

}

sub addtags{
	my $tag = shift;
	my $type = shift;
	my $json_object = shift;
	my $DB_UNIQUE_NAME = $type . "_DB_UNIQUE_NAME";
	my $cmd = "$sdictl updatefadb -db_unique_name $json_object->{RACDB_INFO}{$DB_UNIQUE_NAME}"
		 ." -addtag $tag"
		 ." -addconstraint ORC_ORDER:+$tag"
		 ." -addconstraint OPC_RACK:+$tag";	
        print "\n$cmd\n";

}

sub addrack{
	my $rackid = shift;
	my $tag = shift;
	my $json_object = shift;
	my $type = "FA_"."$pillar";	
	
	my $cmd = "$sdictl addrack -id $rackid -frontend $json_object->{VMS}{10}{VM_SUBNET_MASK}:$json_object->{VMS}{10}{VM_GATEWAY}";
	for my $i(6 .. 14){
		$cmd .= ":$json_object->{VMS}{10}{VM_IP}";
	}
	
	$cmd =  $cmd." -serverpool $rackid -type $type -prefLevel ?? -zfs $json_object->{SDI_INFO}{ZFS_ID} -addtag $tag"
		." -addconstraint OPC_ORDER:+$tag -addconstraint OPC_FADATABASE:+$tag";
	
        print "\n$cmd\n";

}

sub addOVS{
	my $rackid = shift;
	my $json_object = shift;
	
	my $hyp = "$json_object->{VMS}{6}{VM_HV_NAME}";
	my $ovsid  = (split('\.',$hyp))[0];
	my $cmd = "$sdictl addOVS -ovsId $ovsid -hostname $hyp"
		 ." -username $json_object->{ZFS_STORAGE}{OVS_HYPERVISOR_USERNAME}"
		 ." -password  $json_object->{ZFS_STORAGE}{OVS_HYPERVISOR_PASSWORD}"
		 ." -rackId $rackid"
		 ." -seed_pool $seed_pool -running_pool $running_pool";

        print "\n$cmd\n";

}


sub readJSON{

        my $json_file = shift;
        my $json_input;
        {
                local $/ = undef;
                open my $json_file,'<',$json_file;
                $json_input=<$json_file>;
                close $json_file;
        }

        my $json_return = decode_json($json_input);
        return $json_return;
}


