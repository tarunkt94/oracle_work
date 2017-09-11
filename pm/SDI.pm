package SDI;

use strict;
use warnings;
use File::Basename;
use Util;
use Logger;
use RemoteCmd;
use DoSystemCmd;

my $system = DoSystemCmd->new({filehandle => \*STDOUT});

### Constructor
sub new {
    my ($class, %args) = @_;

    my $self = {
        user => $args{user},
        passwd => $args{passwd},
        host => $args{host},
        sdiscript => $args{sdiscript},
        logObj => $args{logObj},
    };

    bless($self, $class);

    $self->{'remoteObj'} = RemoteCmd->new(user => $self->{user},
                                          passwd => $self->{passwd},
                                          logObj => $self->{logObj});

    return $self;
}


#
# Get Pod details
# Input:
#     id => identity domain
# Return pod details
#
sub getPodDetails {

    my ($self, %params) = @_;

    my %podhash;
    my $cmd = "$self->{sdiscript} list_fa_pods -system_name_criteria $params{system_name}";
    $cmd =~ tr{\n}{ };

    my $filter = "awk -F '|' '/$params{system_name}/ { if " .
                 "(\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 !~ /Connect/ && " .
                 "\$1 !~ /^---/ && \$1 !~ /Found/ && \$1 !~ /Request/) " .
                 "print \"id::\"\$1\",,domain::\"\$2\",,service_name::\"\$3" .
                 "\",,podname::\"\$4\",,poddesignator::\"\$5\",,role::\"\$6" .
                 "\",,drenabled::\"\$7\",,partnerdcid::\"\$8\",,maindb::\"\$9" .
                 "\",,oiddb::\"\$10\",,oimdb::\"\$11\",,cloudname::\"\$12" .
                 "\",,zfsappid::\"\$13\",,sharedzfs::\"\$14}'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");

    if (!@$out) {
        print "No entry found for Release version: $params{system_name}\n";
    } else {
        for my $elem (@$out) {
            my @arr = split(',,', $elem);
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                $podhash{$key} = $value;
            }
        }
    }

    return %podhash;
}

#
# Get Config property
# Input:
#     property_name => property name
# Return the property value
#
sub getConfigProperty {

    my ($self, $property_name) = @_;

    my $cmd = "$self->{sdiscript} config -get $property_name";

    my $filter = "awk '{ if (\$1 !~ (/spawn|aime|Connect" .
                 "|Warning\:/)) print}' " .
                 "| tr -d '\\r\\n' | sed -e 's/SDI Properties\://g'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");
    return "@$out";


}

#
# Get DB details
# Input:
#     id => identity domain
# Return DB details
#
sub getDBDetails {

    my ($self, %params) = @_;

    my %dbhash;
    my $keycount = 0;
    my $cmd = "$self->{sdiscript} listfadbs -long";

    my $filter = "awk -F '|' '/$params{system_name}/ { if (\$1 " .
                 "!~ /spawn/ && \$1 !~ /aime/ && \$1 !~ /Connect/ && " .
                 "\$1 !~ /^---/ && \$1 !~ /Found/ && \$1 !~ /Request/) " .
                 "print \"db_unique_name::\"\$1\",,db_name::\"\$2" .
                 "\",,db_version::\"\$3\",,db_type::\"\$4\",,db_port::\"\$5" .
                 "\",,status::\"\$6\",,rac_node1_vip::\"\$7\",,sid1::\"\$8" .
                 "\",,rac_node2_vip::\"\$9\",,sid2::\"\$10\",,db_service_name::\"\$11" .
                 "\",,data_diskgroup_name::\"\$12\",,reco_diskgroup_name::\"\$13" .
                 "\",,tag_name::\"\$14\",,constraints::\"\$15\",,asm::\"\$16" .
                 "\",,asmuser::\"\$17\",,asmpasswd::\"\$18" .
                 "\",,dg_listener_name::\"\$19\",,dg_listener_port::\"\$20" .
                 "\",,oracle_home::\"\$21\",,oracle_base::\"\$22" .
                 "\",,applistenername::\"\$23\",,standby::\"\$24" .
                 "\",,identity_domain::\"\$25\",,servicename::\"\$26" .
                 "\",,asm_sid1::\"\$27\",,asm_sid2::\"\$28" .
                 "\",,rac_db_host1::\"\$29\",,rac_db_host2::\"\$30" .
                 "\",,cluster_node::\"\$31\",,crs_scan_name::\"\$32" .
                 "\",,crs_scan_port::\"\$33\",,grid_home::\"\$34" .
                 "\",,crs_on_port::\"\$35\",,em_target_name::\"\$36" .
                 "\",,em_registration::\"\$37\",,servicetypes::\"\$38" .
                 "\",,datacenterid::\"\$39}'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");

    if (!@$out) {
        print "No entry found for Release version: $params{system_name}\n";
    } else {
        for my $elem (@$out) {
            my @arr = split(',,', $elem);
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                $value =~ s/^\[+//g;
                $value =~ s/\]+$//g;
                chomp($value);
                $dbhash{$keycount}{$key} = $value;
            }
            $keycount += 1;
        }
    }

    return %dbhash;
}

#
# Get Template details
# Input:
#     relname => Release version
#     host => sdi host
# Return template details
#
sub getTemplateDetails {

    my ($self, %params) = @_;

    my $keycount = 0;
    my %templateshash;
    my $cmd = "$self->{sdiscript} list_fa_templates";

    my $filter = "awk -F '|' '/$params{relname}/ { if (\$1 !~ /spawn/ && \$1" .
                 " !~ /aime/ && \$1 !~ /Connect/ && \$1 !~ /^---/ && " .
                 "\$1 !~ /Found/ && \$1 !~ /Request/) print \"relver::\"\$1" .
                 "\",,patchrelver::\"\$2\",,relname::\"\$3" .
                 "\",,patchbundle::\"\$4\",,servicebundle::\"\$5" .
                 "\",,langlist::\"\$6\",,servicetype::\"\$7" .
                 "\",,istrail::\"\$8\",,template::\"\$9" .
                 "\",,ispreferred::\"\$10}'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");

    if (!@$out) {
        print "No entry found for Release version: $params{relname}\n";
    } else {
        for my $elem (@$out) {
            my @arr = split(',,', $elem);
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                $templateshash{$keycount}{$key} = $value;
            }
            $keycount += 1;
        }
    }

    return %templateshash;
}

#
# Get Request details
# Input:
#    req_id => req_id
# Return request details
#
sub getReqDetails {

    my ($self, %params) = @_;

    my $keycount = 0;
    my (%reqDetails, $cmd);

    if (exists $params{req_id}) {
        $params{req_id} =~ s/#/\\#/g;
        $cmd = "\"$self->{sdiscript} listrq -filter " .
               "-request_id \\\"$params{req_id}\\\"\"";
    } elsif (exists $params{system_name} and
             $params{req_type} and $params{status}) {
        $cmd = "\"$self->{sdiscript} listrq -filter -system_name " .
               "$params{system_name} -request_type $params{req_type} ".
               "-state $params{status}\"";
    } elsif (exists $params{system_name} and $params{req_type}) {
        $cmd = "\"$self->{sdiscript} listrq -filter -system_name " .
               "$params{system_name} -request_type $params{req_type}\"";
    } elsif (exists $params{system_name}) {
        $cmd = "\"$self->{sdiscript} listrq -filter -system_name " .
               "$params{system_name}\"";
    } else {
        $cmd = "\"$self->{sdiscript} listrq -filter " .
               "-state \\\"STARTED|SCHEDULED|PAUSED|COMPLETED|CANCELED\\\"\"";
    }

    my $filter = "awk -F '|' '/|/ { if (\$1 !~ /spawn/ && \$1 !~ /aime/ && " .
                 "\$1 !~ /Connect/ && \$1 !~ /Pagination/ && " .
                 "\$1 !~ /Filtering/ && \$1 !~ /Batch/ && " .
                 "\$1 !~ /^---/ && \$1 !~ /Found/ && " .
                 "\$1 !~ /Request/) print \"batchid::\"\$1" .
                 "\",,requestid::\"\$2\",,requesttype::\"\$3" .
                 "\",,servicetype::\"\$4\",,status::\"\$5" .
                 "\",,substate::\"\$6" .
                 "\",,identitydomain::\"\$7\",,sdiinstancename::\"\$8" .
                 "\",,sdiversion::\"\$9\",,servicenames::\"\$10" .
                 "\",,creationtime::\"\$11\",,lastupdate::\"\$12" .
                 "\",,scheduletime::\"\$13}'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");
    if (@$out) {
        for my $elem (@$out) {
            chomp($elem);
            my @arr = split(',,', $elem);
            if ( $elem =~ m/,,requestid::,,req|,,requesttype::,,se/) {
                next;
            }
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\-08:00//g;
                $value =~ s/\-07:00//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                if ($key eq 'lastupdate' or $key eq 'creationtime') {
                    my $updatevalue = `date "+%Y-%m-%d %H:%M:%S" -d "$value"`;
                    chomp($updatevalue);
                    $reqDetails{$keycount}{$key} = $updatevalue;
                } else {
                    $reqDetails{$keycount}{$key} = $value;
                }
            }
            $keycount += 1;
        }
    } else {
        print "No requests found\n";
    }

    return %reqDetails;
}

sub getReqLongDetails {

    my ($self, %params) = @_;

    my (%reqLongDetails, $cmd);
    my $keycount = 0;

    $params{req_id} =~ s/#/\\#/g;
    $cmd = "\"$self->{sdiscript} listrq -id \\\"$params{req_id}\\\" -long\"";

    my $filter = "awk -F '|' '/|/ { if (\$1 !~ /spawn/ && \$1 !~ /aime/ && " .
                 "\$1 !~ /Connect/ && \$1 !~ /Pagination/ && " .
                 "\$1 !~ /Filtering/ && \$1 !~ /Batch/ && " .
                 "\$1 !~ /^---/ && \$1 !~ /Found/ && " .
                 "\$1 !~ /Request/) print \"requestid::\"\$1" .
                 "\",,requesttype::\"\$2" .
                 "\",,servicetype::\"\$3\",,status::\"\$4" .
                 "\",,identitydomain::\"\$5\",,sdiinstancename::\"\$6" .
                 "\",,sdiversion::\"\$7" .
                 "\",,creationtime::\"\$8\",,lastupdate::\"\$9" .
                 "\",,scheduletime::\"\$10\",,callbackaddr::\"\$11" .
                 "\",,callbackmsgid::\"\$12\",,orderfullfillment::\"\$13" .
                 "\",,version::\"\$14\",,lastfailureid::\"\$15}'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");
    if (@$out) {
        for my $elem (@$out) {
            chomp($elem);
            my @arr = split(',,', $elem);
            if ( $elem =~ m/,,requestid::,,req|,,requesttype::,,se/) {
                next;
            }
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\-08:00//g;
                $value =~ s/\-07:00//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                if ($key eq 'lastupdate' or $key eq 'creationtime') {
                    my $updatevalue = `date "+%Y-%m-%d %H:%M:%S" -d "$value"`;
                    chomp($updatevalue);
                    $reqLongDetails{$keycount}{$key} = $updatevalue;
                } else {
                    $reqLongDetails{$keycount}{$key} = $value;
                }
            }
            $keycount += 1;
        }
    } else {
        print "No requests found\n";
    }

    return %reqLongDetails;
}

#
# Get ovmha properties file directory
# Input:
#     id => identity domain
# Return ovm ha prop file directory
#
sub getOvmFileDir {

    my ($self, %params) = @_;

    my $ovmdir = "";
    my $cmd = "find $params{template} -maxdepth 6 -iname '$params{system_name}' -type d";

    my $filter = " awk '/$params{system_name}/ { if (\$1 !~ (/spawn|ssh|exit|";
    $filter   .= "Authorized|Warning|aime|find|^\$/) ) print }'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");

    die ("No directory structure found for Identity domain: $params{system_name}\n") if (!@$out);

    for $ovmdir (@$out) {
        $ovmdir =~ s/\n$//g;
        $ovmdir =~ s/\r$//g;
        return $ovmdir;
    }

    return $ovmdir;
}

# This method gets the OVM Deploy Properties file paths
# for all the identity domains in the Lab.
sub getOVMFilePathsfromSDI {
        
    my ($self, %params) = @_;

    my ($cmd, $filter, $out, $podname, %OVMFilePaths, %podstmpdt);
    
    %OVMFilePaths = ();
    %podstmpdt =();

    my $dir1 = "/fa_template/*/DedicatedIdm/paid/*/deployments/*/*/deployfw/deployprops/";
    my $dir2 = "/fa_template/*/DedicatedIdm/paid/*/deployments/*/*/*/deployfw/deployprops/";
    
    $cmd = "find $dir1 $dir2 -type f ! -path \\\"*DELETED*\\\"";
    $cmd.= " -name 'ovm-ha-deploy.properties' -printf ''%h\/%f,%TY%Tm%Td%TH%TM%TS''\\\\\\\\n";

    $filter = "awk '{if (\$1 !~ (/spawn|$params{host}|";
    $filter.= "ssh|aime|2cool|Warning|find|exit/)) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{host},
							 cmd => $cmd,
							 filter => $filter);

    if (!@$out) {
        print "No Identity Domains found in the Host.\n";
    } 
    else 
    {
        for my $elem(@$out) 
        {
	    if($elem ne "")
	    {
	        my ($filepath, $file_modifydate) = split(',', $elem);
		print "filepath :: $filepath\n";
		print "file_modifydate :: $file_modifydate\n";

	       my $podname = (split('/', $filepath))[7];
	       print "podname :: $podname\n";

	       $OVMFilePaths{$podname} = $filepath;
		   
	       $podstmpdt{$podname} = $file_modifydate;

         }
        }
    }

    return (\%OVMFilePaths, \%podstmpdt) ;
}

# This method returns the SDI Server path by getting the SDI_HOME environment
# variable from SDI Hosts.
sub getSDIServerPath {

        my ($self) = @_;

        my ($cmd, $filter, $out, $sdiServerPath);

        $cmd = "\"echo \\\$SDI_HOME\"";

        $filter = "awk '{if (\$1 !~ (/spawn|$self->{host}|";
	$filter.= "exit|ssh|Connecting|find|.:|Warning/)) print \$1}'";

        $out = $self->{'remoteObj'}->
            executeCommandsonRemote(host => $self->{host},
                                    cmd => $cmd,
                                    filter => $filter);

        $sdiServerPath = @$out[0];
        chomp($sdiServerPath);
        $sdiServerPath =~ s/\s+$//g;

        return $sdiServerPath;
}

# This method returns the FA DR Scripts path in SDI Host by getting SDI Home.
sub getFADRScriptsPath {

        my ($self) = @_;

        my ($sdihome,$fadrScriptsPath);

        $sdihome = $self->getSDIServerPath();

        $fadrScriptsPath = "$sdihome/fa_dr_utilities/switchover/scripts/bin";

        return $fadrScriptsPath;
}

# This method returns the Utility Host Name for SDI Host from ENV variable.
sub getUtilityHost {

        my ($self) = @_;

        my ($cmd, $filter, $out, $Utilityhostname);

        $cmd = "echo \\\$SDI_UTIL_HOST";

       	$filter = "awk '{if (\$1 !~ (/spawn|aime|find|exit|ssh|";
	$filter.= "Warning/)) print \$1}'";

        $out = $self->{'remoteObj'}->
            executeCommandsonRemote(host => $self->{host},
                                    cmd => "$cmd",
                                    filter => "$filter");

        $Utilityhostname = @$out[0];
        chomp($Utilityhostname);
        $Utilityhostname =~ s/\s+$//g;

        return $Utilityhostname;

}


#    This method would get the OVM Deploy Properties from SDI Host.
#    SDI Host name and Identity Domain name are the inputs.
#    OVM Deploy Properties hash is the output of this method.
sub getOVMPropertiesHashfromSDI {

        my ($self, %params) = @_;

        my ($dcshortname, $hosttype, %podDetails, %SDIOVMProps, %fatemplate,
            $ovm_dir, $ovm_file_path, $ovm_prop_file, $ovmfile, $logdir,
            $cmd, $filter, $out);


        %podDetails =
            $self->getPodDetails(system_name => $params{system_name});

        $ovm_dir =
            $self->getOvmFileDir(system_name => $params{system_name},
                                 template => $params{config}{'TEMPLATE'});
		
	chomp($ovm_dir);
	my $relname = (split('/', $ovm_dir))[2]; 
	
	my %templateDetails = $self->getTemplateDetails(relname => $relname);
	
	my $podver =  (split /\./, $templateDetails{0}{'relver'})[2];
	
        $dcshortname = $self->
        getConfigProperty("datacenter.shortname");

        if ($podDetails{'poddesignator'} eq 'PRIMARY') {
            $hosttype = "primary";
        } elsif ($podDetails{'poddesignator'} eq 'STANDBY') {
            $hosttype = "standby";
        }

        $ovm_prop_file = "$ovm_dir/$podDetails{'service_name'}";
        $ovm_prop_file .= "/deployfw/deployprops/ovm-ha-deploy.properties";

        $cmd = "\"test -f $ovm_prop_file ; echo \$?\"";
	
        $filter = "awk ' {if (\$1 !~ (/spawn|aime|ssh|";
	$filter .= "exit|Warning/)) print}'";
	
        $out = $self->{'remoteObj'}->
            executeCommandsonRemote(host => $self->{host},
                                    cmd => "$cmd",
                                    filter => "$filter");

        # $out equal to 1 indicates file not found, 0 indicates found.

        if($out->[0] == 1)
        {
            $ovm_prop_file = "$ovm_dir/$podDetails{'service_name'}/standby";
            $ovm_prop_file .= "/deployfw/deployprops/ovm-ha-deploy.properties";
        }

        if($hosttype eq "standby")
        {
            $logdir ="$params{logdir}/Standby";
            system("mkdir -p $logdir");
        }
        else
        {
            $logdir ="$params{logdir}/primary";
            system("mkdir -p $logdir");
        }

        $out = $self->{'remoteObj'}->copyFileToDir(host => $self->{host},
                                                   file => $ovm_prop_file,
                                                   destdir => $logdir);


        %SDIOVMProps = getFaEnv("$logdir/ovm-ha-deploy.properties");
	
	$SDIOVMProps{'podver'} = $podver;
        $SDIOVMProps{'podname'} = $podDetails{'podname'};
        $SDIOVMProps{'service_name'} = $podDetails{'service_name'};
        $SDIOVMProps{'dcshortname'} = $dcshortname;

        return %SDIOVMProps;

}

#
# Add DB
# Input:
#     db_unique_name => database uniquee name
#     db_name => database name
#     port => port
#     host_name1 => rac node1 host name
#     sid1 => database name1
#     db_service_name => database name
#     data_disc => data disk grorup name
#     reco_disc => reco disk group name
#     is_asm => true|false
#     asm_user => asm user name
#     asm_password => asm password
#     fa_database_type => database type: MAIN_DB|IDM_DB|IDS_DB
#     db_version => database version
#     host_name2 => rac node2 host name
#     sid2 => database name2
#     cluster_host1 => rac databse host 1
#     cluster_host2 => rac databse host 2
#     cluster_name => cluster node
#     crs_scan_name => cluster node
#     crs_scan_port => crs scan port
#     crs_home => grid home
#     crs_ons_port => crs on port
#     asm_sid1 => asm sid1
#     asm_sid2 => asm sid2
#     dg_preconfigured_listener_name => dataguard listener name
#     dg_preconfigured_listener_port => dataguard listener port
#     oracle_home => oracle home
#     oracle_base => oracle base
#     em_registration => EM agent registration name
# Return the status
#
sub addDB {

    my ($self, %params) = @_;

    my ($cmd, $filter, $out);
    my $applistenername = "LISTENER_" . uc($params{db_unique_name});

    $cmd = "\"$self->{sdiscript} addfadb -db_unique_name " .
           "$params{db_unique_name} -db_name $params{db_name} " .
           "-port $params{port} -host_name1 $params{host_name1} " .
           "-sid1 $params{sid1} -db_service_name $params{db_service_name} " .
           "-data_disc $params{data_disc} -reco_disc $params{reco_disc} " .
           "-is_asm $params{is_asm} -asm_user $params{asm_user} " .
           "-asm_password $params{asm_password} -fa_database_type " .
           "$params{fa_database_type} -db_version $params{db_version} " .
           "-host_name2 $params{host_name2} -sid2 $params{sid2} " .
           "-cluster_host1 $params{cluster_host1} -cluster_host2 " .
           "$params{cluster_host2} -cluster_name $params{cluster_name} " .
           "-crs_scan_name $params{crs_scan_name} -crs_scan_port " .
           "$params{crs_scan_port} -crs_home $params{crs_home} " .
           "-crs_ons_port $params{crs_ons_port} -asm_sid1 $params{asm_sid1} " .
           "-asm_sid2 $params{asm_sid2} -dg_preconfigured_listener_name " .
           "$params{dg_preconfigured_listener_name} " .
           "-dg_preconfigured_listener_port " .
           "$params{dg_preconfigured_listener_port} -oracle_home " .
           "$params{oracle_home} -oracle_base $params{oracle_base} " .
           "-application_listener_name $applistenername";

    if (exists $params{em_registration}) {
        $cmd .= " -em_registration $params{em_registration}";
    }

    if (exists $params{is_standby} and
       lc($params{is_standby}) eq 'true' ) {
        $cmd .= " -is_standby $params{is_standby}";
    }

    $cmd .= "\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Remove DBs from SDI
# Input:
#      db_unique_name: database unique name
# Return the status
#
sub removeDB {

    my ($self, $db_unique_name) = @_;

    my ($cmd, $filter, $out);

    $cmd = "\"$self->{sdiscript} removefadb -db_unique_name $db_unique_name\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ &&" .
              " \$1 !~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Register DBs with tag name
# Input:
#     tagName => tag name
#     fa_db_unique_name => fa database unique name
#     oid_db_unique_name => oid database unique name
#     oim_db_unique_name => oim databse unique name
# Return the status
#
sub addDBTags {

    my ($self, %params) = @_;

    my ($cmd, $filter, $out);

    $cmd = "\"$self->{sdiscript} register_tag -tagName $params{tagName}\;" .
           "$self->{sdiscript} updatefadb -name $params{fa_db_unique_name} " .
           "-addtag $params{tagName} -addconstraint " .
           "OPC_ORDER:+$params{tagName} -addconstraint OPC_RACK:" .
           "+$params{tagName}\;$self->{sdiscript} updatefadb -name " .
           "$params{oid_db_unique_name} -addtag $params{tagName} " .
           "-addconstraint OPC_ORDER:+$params{tagName} -addconstraint " .
           "OPC_RACK:+$params{tagName}\;";

    if ($params{release_name} ne 'REL12') {
        $cmd .= "$self->{sdiscript} updatefadb " .
                "-name $params{oim_db_unique_name} -addtag $params{tagName} " .
                "-addconstraint OPC_ORDER:+$params{tagName} -addconstraint " .
                "OPC_RACK:+$params{tagName}\;";
    }

    $cmd .= "\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}


#
# Add fa_template
# Input:
#     release_name => release name
#     service_type => pillar name
#     release_version => release version
#     template_name => template name
#     is_trail => true|false(default value: false)
#     is_preferred => true|false(default_value: true)
# Return the status
#
sub addFATemplate {

    my ($self, %params) = @_;

    my $templateExists = 0;
    my $modifyflag = 0;
    my ($cmd, $filter, $out, $msg);

    my %templateDetails = $self->getTemplateDetails(
        relname => $params{release_version});

    if (%templateDetails) {

        $cmd .= "\"";
        $self->{'logObj'}->info(
            ["Template details exists for release version: $params{release_version}"]);

        $self->{'logObj'}->info(["Adding new template for release: ".
                                 "$params{release_name}"]);
        $cmd .= "$self->{sdiscript} add_fa_template -release_version " .
                "$params{release_version} -release_name $params{release_name}" .
                " -service_type FA_$params{service_type} -template_name " .
                "$params{template_name} -is_trial $params{is_trial} " .
                "-is_preferred false\;";

        foreach my $keycount (keys %templateDetails){
            # if release version and servicetype already exists,
            # update the previous is_preferred = false.
            # Add new fa template with is_preferred = true
            if ($templateDetails{$keycount}{relver} eq $params{release_version} and
      $templateDetails{$keycount}{servicetype} eq "FA_$params{service_type}") {
                $modifyflag = 1;
                print "$templateDetails{$keycount}{relname}";
                print "$params{release_name}";
                if ( $templateDetails{$keycount}{relname} ne $params{release_name}) {
                    $self->{'logObj'}->info(["Updating is_preferred=false" .
                                             " for release: $params{release_name}"]);
                    $cmd .= "$self->{sdiscript} " .
                            "modify_fa_template_preference -release_name " .
                            "$params{release_name} -service_type " .
                            "FA_$params{service_type} -is_trial " .
                            "$params{is_trial}\;";
                } else {
                    $msg = "FA Template exists for release: $params{release_name}";
                    $self->{'logObj'}->info([$msg]);
                    return 0, "$msg";
                }
            }
        }
        if ($modifyflag == 0) {
            $cmd .= "$self->{sdiscript} " .
                    "modify_fa_template_preference -release_name " .
                    "$params{release_name} -service_type " .
                    "FA_$params{service_type} -is_trial " .
                    "$params{is_trial}\;";
        }
        $cmd .= "\"";
    } else {

        $self->{'logObj'}->info(["Adding new template as template details" .
           " not exists for release: $params{release_name}"]);
        $cmd .= "\"$self->{sdiscript} add_fa_template -release_version " .
                "$params{release_version} -release_name " .
                "$params{release_name} -service_type FA_$params{service_type}" .
                " -template_name $params{template_name} -is_trial " .
                "$params{is_trial} -is_preferred $params{is_preferred}\;\"";
    }

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Create FA Template directory
# Input:
#     release_name => release name
#     pillar => service type
#     stage_name => stage name
#     host => mount host name
#     rootscript => root script cmd
# Return the status
#
sub createFATemplateDir {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    $out = $self->{'remoteObj'}->copyFileToHost(
        host => $self->{host}, dest => "/tmp",
        file => "$params{scriptdir}/createFATempDir.pl");

    $cmd = "perl /tmp/createFATempDir.pl -release_name $params{release_name}" .
           " -release_version $params{release_version} -stage_name " .
           "$params{stage_name} -pillar $params{pillar} -rootscript " .
           "$params{rootscript} -fa_template_nfs_path " .
           "$params{fa_template_nfs_path} -fa_template $params{fa_template}";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail|usage/i, @$out)) {
        return 1, "@$out";
    }

    my $rm_cmd = "rm -rf /tmp/createFATempDir.pl";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$rm_cmd");

    return 0, "@$out";
}

#
# Create FSN Admin directory
# Input:
#     release_name => release name
#     pillar => service type
#     db_node1 => database node 1
#     host => mount host name
#     rootscript => root script cmd
# Return the status
#
sub createFSNAdminDir {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    $out = $self->{'remoteObj'}->copyFileToHost(
        host => $self->{host}, dest => "/tmp",
        file => "$params{scriptdir}/createFSNAdminDir.pl");

    my $fsnadmindir = $self->getConfigProperty("fa.fsnadmin.root.dir");

    $cmd = "perl /tmp/createFSNAdminDir.pl -release_name " .
           "$params{release_name} -stage_name $params{stage_name} " .
           "-pillar $params{pillar} -rootscript $params{rootscript} " .
           "-fsnadmin_nfs_path $params{fsnadmin_nfs_path} -fsnadmindir " .
           "$fsnadmindir -fa_template $params{fa_template}";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail|usage/i, @$out)) {
        return 1, "@$out";
    }

    my $rm_cmd = "rm -rf /tmp/createFSNAdminDir.pl";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$rm_cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

# check hypervisor exists in listOVS
sub getOVSDetailsFromHost {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    my %ovsHash;

    $cmd = "$self->{sdiscript} listOVS -filter -hostname $params{hv}";

    $filter = "awk -F '|' '{ if (\$1 !~ /spawn/ && \$1 " .
              "!~ /aime/ && \$1 !~ /Warning\:/ && \$1 !~ /Connect/ " .
              "&& \$1 !~ /---/ && \$1 !~ /Filter/ && \$1 !~ /OVS/) " .
              "print \"ovs_id::\"\$1\",,hostname::\"\$2" .
              "\",,server_pool::\"\$3\",,seed_pool::\"\$4" .
              "\",,running_pool::\"\$5\",,username::\"\$6}'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (!@$out) {
        print "No entry found for Hypervisor: $params{hv}\n";
    } else {
        for my $elem (@$out) {
            my @arr = split(',,', $elem);
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                if ($value) {
                    $ovsHash{$key} = $value;
                }
            }
        }
    }

    return %ovsHash;
}

# check rack details exists in listracks
sub getRackDetailsFromTagName {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    my %rackHash;

    $cmd = "$self->{sdiscript} listracks -matches $params{tag_name}";

    $filter = "awk -F '|' '{ if (\$1 !~ /spawn/ && \$1 " .
              "!~ /aime/ && \$1 !~ /Warning\:/ && \$1 !~ /Connect/ " .
              "&& \$1 !~ /---/ && \$1 !~ /Filter/ && \$1 !~ /Rack/ " .
              "&& \$1 !~ /No valid/ && \$1 !~ /Pagination/) " .
              "print \"rack_id::\"\$1\",,types::\"\$2" .
              "\",,ovmm::\"\$3\",,networkBridge0::\"\$4" .
              "\",,networkBridge1::\"\$5\",,registeredips::\"\$6" .
              "\",,allocatedips::\"\$7\",,private_zfs_id::\"\$8" .
              "\",,shared_zfs_id::\"\$9\",,ovs_pool::\"\$10" .
              "\",,resource_mgr::\"\$11\",,pref_level::\"\$12" .
              "\",,assembly_pref_level::\"\$13\",,tags::\"\$14" .
              "\",,constraints::\"\$15\",,deployer_host::\"\$16" .
              "\",,deployer_username::\"\$17\",,deployer_passwd::\"\$18" .
              "\",,predictable_hostname::\"\$19\",,new_service_headroom::\"\$20" .
              "\",,upsize_headroom::\"\$21\",,datacenterid::\"\$22}'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (!@$out) {
        print "No entry found for Tag name: $params{tag_name}\n";
    } else {
        for my $elem (@$out) {
            my @arr = split(',,', $elem);
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                if ($value) {
                    $rackHash{$key} = $value;
                }
            }
        }
    }

    return %rackHash;
}

sub getOVSDetailsFromServerPool {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    my %ovsHash;
    my $keycount = 0;

    $cmd = "$self->{sdiscript} listOVS -filter -server_pool " .
           "$params{server_pool} ";

    $filter = "awk -F '|' '{ if (\$1 !~ /spawn/ && \$1 " .
              "!~ /aime/ && \$1 !~ /Warning\:/ && \$1 !~ /Connect/ " .
              "&& \$1 !~ /---/ && \$1 !~ /Filter/ && \$1 !~ /OVS/) " .
              "print \"ovs_id::\"\$1\",,hostname::\"\$2" .
              "\",,server_pool::\"\$3\",,seed_pool::\"\$4" .
              "\",,running_pool::\"\$5\",,username::\"\$6}'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (!@$out) {
        print "No entry found for Hypervisor: $params{hv}\n";
    } else {
        for my $elem (@$out) {
            my @arr = split(',,', $elem);
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                if ($value) {
                    $ovsHash{$keycount}{$key} = $value;
                }
            }
            $keycount += 1;
        }
    }

    return %ovsHash;
}

#
# Remove OVS entry in SDI host
# Input:
#     ovsid => OVS id
# Return the status
#
sub removeOVS {

    my ($self, $ovsid) = @_;

    my ($cmd, $out, $filter);

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $cmd = "\"$self->{sdiscript} removeOVS -ovsid $ovsid\"";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Remove Rack entry in SDI host
# Input:
#     rackid => Rack id
# Return the status
#
sub removeRack {

    my ($self, $rackid) = @_;

    my ($cmd, $out, $filter);

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $cmd = "\"$self->{sdiscript} removerack -id $rackid\"";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Check OVS exists
# Input:
#     hypervisors => FA hypervisors
#     use_serverpool => yes|no
#     serverpoolfile => store serverpool name
# If same server pool exists for multiple hypervisors remove it.
# Return error if hypervisors have different server pool
#
sub checkOVSEntry {

    my ($self, %params) = @_;

    my ($cmd, $out, $ovs_id, $status, %hvHash, %hostHash,
        %serverHash, %serverPool, %hvPool, %hvOVS);

    my @hvs = split(',', $params{hypervisors});

    for my $hv (@hvs) {
        %hostHash = $self->getOVSDetailsFromHost(hv => $hv);
        $serverPool{$hv} = $hostHash{server_pool};
        $hvHash{$hv} = \%hostHash;
    }

    my @serverpools = Uniq(values %serverPool);
    my $noofserverpools = scalar @serverpools;

    if ($noofserverpools > 1) {
        my $msg = "Different server pool for @hvs\n";
        return 1, "$msg";
    } else {
        for my $serverpool (@serverpools) {
            %serverHash = $self->getOVSDetailsFromServerPool(
                server_pool => $serverpool);
            for my $count(keys %serverHash) {
                for my $key(keys %{$serverHash{$count}}) {
                    if ($key eq 'hostname') {
                        $hvPool{$serverHash{$count}{$key}} = undef;
                        if (grep {$_ eq $serverHash{$count}{$key}} @hvs) {
                            $hvOVS{$serverHash{$count}{ovs_id}} = undef;
                        }
                    }
                }
            }
        }
    }

    my @hvsPool = sort(keys %hvPool);
    my @hvsOVS = sort(keys %hvOVS);

    if (!-f $params{serverpoolfile}) {
        my $touchcmd = system("touch $params{serverpoolfile}");
    }

    my $chmhvs = system("chmod 777 $params{serverpoolfile}");
    die ("Couldn't change the permissions to $params{serverpoolfile}\n") if ($chmhvs != 0);

    open my $output, '>', $params{serverpoolfile} or
        die ("Cannot open $params{serverpoolfile} file \n");

    if ((@hvsPool == @hvs or
       lc($params{use_serverpool}) eq 'no') and
       lc($params{use_serverpool}) ne 'yes') {
        for $ovs_id(@hvsOVS) {
            ($status , $out) = $self->removeOVS($ovs_id);
            if ($status != 0) {
                return 1, "$out";
            }
        }
    } else {
        $out = "Using existing server pool: @serverpools\n";
        print $output join("", @serverpools)."\n";
    }

    $chmhvs = system("chmod 555 $params{serverpoolfile}");
    die ("Couldn't change the permissions to $params{serverpoolfile}\n") if ($chmhvs != 0);

    return 0, "$out";
}

#
# Add Rack:
#     run listOVS for hypervisor
#     If Exists: remove serverpool
#     Else: Add new serverpool for hypervisor
# Input:
#     rac_id => rac id
#     resource_manager => resource manager
#     tag_name => tag name
#     pillar => service type
#     pref_level => pref level
#     zfs_id => zfs id
# Return the status
#
sub addRack {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter, $hv, $ipaddr, $netmask,
        $backipaddr, $serverpool, $gateway, %ovsHash);

    my $randnum = int(rand(99999));
    while ($randnum < 10000) {
        $randnum = int(rand(99999));
    }
    my $racid = $params{tag_name} ."_$randnum";

    no strict;
    no warnings;
    open my $in, '<', "$params{hvhashfile}" or die $!;
    my $data;
    {
        local $/;
        $data = eval <$in>;
    }
    close $in;

    my %hvhash = %$data;
    use strict;
    use warnings;

    if (!-f $params{racidfile}) {
        my $touchcmd = system("touch $params{racidfile}");
    }

    my $chmhvs = system("chmod 777 $params{racidfile}");
    die ("Couldn't change the permissions to $params{racidfile}\n") if ($chmhvs != 0);

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    open my $output, '>', $params{racidfile} or die ("Cannot open $params{racidfile} file \n");
    for $hv (keys %hvhash) {
        # check serverpool exists for the given hypervisor
        if (not $netmask) {
            if (exists $params{frontendNetmask} and
               $params{frontendNetmask}) {
                $netmask = $params{frontendNetmask};
            } else {
                $netmask = $hvhash{$hv}{'netmask'};
            }
        }
        if (not $gateway) {
            if (exists $params{frontendGateway} and
               $params{frontendGateway}) {
                $gateway = $params{frontendGateway};
            } else {
                $gateway = $hvhash{$hv}{'gateway'};
            }
        }
        if ($ipaddr) {
            $ipaddr .= ':';
        }
        $ipaddr .= join(":", @{$hvhash{$hv}{'ipaddr'}});

        if ($backipaddr) {
            $backipaddr .= ':';
        }
        if (exists $hvhash{$hv}{'backipaddr'}) {
            $backipaddr .= join(":", @{$hvhash{$hv}{'backipaddr'}});
        }
        if (-f $params{serverpoolfile} and -s $params{serverpoolfile}) {
            open(my $fh, '<', $params{serverpoolfile})
                or die "Could not open file '$params{serverpoolfile}' $!";
            $serverpool = <$fh>;
            chomp($serverpool);
            if (not $serverpool or $serverpool eq "") {
                $serverpool = "$params{tag_name}";
                print $output "$serverpool:$hv\n";
            }
        } else {
            $serverpool = "$params{tag_name}";
            if (lc($params{use_serverpool}) eq 'no') {
                print $output "$racid:$hv\n";
            } else {
                print $output "$serverpool:$hv\n";
            }
        }
    }

    $cmd = "$self->{sdiscript} addrack -id $racid -frontend " .
           "$netmask:$gateway:$ipaddr -ovsserverpool $serverpool" .
           " -type FA_$params{pillar} -prefLevel $params{pref_level}" .
           " -zfs $params{zfs_id}";

    if ($backipaddr and exists $params{backendNetmask} and $params{backendNetmask} and
       exists $params{backendGateway} and $params{backendGateway}) {
        $cmd .= " -backend $params{backendNetmask}:$params{backendGateway}:$backipaddr";
    }

    if (exists $params{networkBridge0} and
       $params{networkBridge0}) {
        $cmd .= " -networkBridge0 $params{networkBridge0}";
    }

    if (exists $params{networkBridge1} and
       $params{networkBridge1}) {
        $cmd .= " -networkBridge1 $params{networkBridge1}";
    }

    if (exists $params{rackheadroomsize} and
       $params{rackheadroomsize}) {
        $cmd .= " -newserviceHeadroom $params{rackheadroomsize}";
    }

    if (exists $params{rackupsizeheadroom} and
       $params{rackupsizeheadroom}) {
        $cmd .= " -upsizeHeadroom $params{rackupsizeheadroom}";
    }

    if (exists $params{predictablehostnameenable} and
       $params{predictablehostnameenable}) {
        my $value = uc($params{predictablehostnameenable});
        $cmd .= " -predictableHostnameEnable $value";
    }

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
         return 1, "@$out";
    }
    close($output);

    $chmhvs = system("chmod 555 $params{racidfile}");
    die ("Couldn't change the permissions to $params{racidfile}\n") if ($chmhvs != 0);

    $cmd = "$self->{sdiscript} updaterack -id $racid -addtag " .
           "$params{tag_name} -addconstraint OPC_ORDER:+$params{tag_name}" .
           " -addconstraint OPC_FADATABASE:+$params{tag_name}";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Add OVS
# Input:
#     tag_name => tag name
#     racidfile => list of new hypervisors which doesn't contain serverpool
# Return the status
#
sub addOVS {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter, $result);

    open my $in, '<', $params{racidfile} or die ("Cannot open file $params{racidfile}\n");
    open my $output, '>', "$params{racidfile}.new" or die ("Cannot open file $params{racidfile}.new\n");
    while ( <$in> ) {

        if ($_) {
            my ($racid, $hostname) = split(/:/, $_);
            chomp($hostname);
            my $randnum = int(rand(999999));
            while ($randnum < 100000) {
                $randnum = int(rand(999999));
            }
            my $ovsid = $params{tag_name}. "_$randnum";

            $cmd = "$self->{sdiscript} addOVS -ovsId $ovsid " .
                   "-hostname $hostname -username $params{fa_hvuser} " .
                   "-password $params{fa_hvpasswd} -rackId $racid -seed_pool" .
                   " $params{seedpool} -running_pool $params{runningpool}";

            $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
                      "!~ /Warning\:/) print }'";

            $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                                 cmd => "$cmd",
                                                                 filter => "$filter");

            if (grep(/error|no such|failed|fail/i, @$out)) {
                return 1, "@$out";
            }
            $result = join("", @$out);
            print $output $_;
        }
    }
    close($output);

    if (!-f $params{racidfile}) {
        my $touchcmd = system("touch $params{racidfile}");
    }

    my $chmhvs = system("chmod 777 $params{racidfile}");
    die ("Couldn't change the permissions to $params{racidfile}\n") if ($chmhvs != 0);

    my $mvcmd = system("mv \"$params{racidfile}.new\" $params{racidfile}");
    die ("Couldn't move $params{racidfile}.new to $params{racidfile}") if ($mvcmd != 0);

    $chmhvs = system("chmod 555 $params{racidfile}");
    die ("Couldn't change the permissions to $params{racidfile}\n") if ($chmhvs != 0);

    return 0, "$result";
}

sub getEMDetails {

    my ($self, %params) = @_;

    my $keycount = 0;
    my %templateshash;
    my $cmd = "$self->{sdiscript} lstcc";

    my $filter = "awk -F '|' '/$params{hostname}/ { if (\$1 !~ /spawn/ && \$1" .
                 " !~ /aime/ && \$1 !~ /Connect/ && \$1 !~ /^---/ && " .
                 "\$1 !~ /Found/ && \$1 !~ /Request/) print \"name::\"\$1" .
                 "\",,isdefault::\"\$2\",,dcshortname::\"\$3" .
                 "\",,host::\"\$4\",,port::\"\$5" .
                 "\",,httpsport::\"\$6\",,protocol::\"\$7" .
                 "\",,jvmdport::\"\$8\",,omsagentport::\"\$9" .
                 "\",,omsuploadport::\"\$10\" " .
                 ",,fasaasuser::\"\$11\" ".
                 ",,fasaaspasswd::\"\$12\",,monitoruser::\"\$13\"" .
                 ",,monitorpasswd::\"\$14\",,javaassembly::\"\$14".
                 "}'";

    my $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{host},
                                                            cmd => "$cmd",
                                                            filter => "$filter");

    if (!@$out) {
       print "No entry found for hostname: $params{hostname}\n";

    } else {
        for my $elem (@$out) {
            my @arr = split(',,', $elem);
            for my $keyvalue(@arr) {
                my ($key, $value) = split('::', $keyvalue);
                $value =~ s/\r?\n//g;
                $value =~ s/\s+$//g;
                $value =~ s/^\s+//g;
                $value =~ s/\t+$//g;
                $value =~ s/^\t+//g;
                chomp($value);
                $templateshash{$keycount}{$key} = $value;
            }
            $keycount += 1;
        }
    }

    return %templateshash;
}


1;
