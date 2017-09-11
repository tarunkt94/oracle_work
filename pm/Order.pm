#
# $Header: dte/DTE/scripts/fusionapps/cli/pm/Order.pm /main/38 2016/10/28 01:37:50 ljonnala Exp $
#
# Order.pm
#
# Copyright (c) 2016, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      Order.pm - <one-line expansion of the name>
#
# 
package Order;

use strict;
use warnings;
use File::Basename;

BEGIN
{
    use Cwd;
    my $orignalDir = getcwd();
    my $scriptDir = dirname($0);
    chdir($scriptDir);
    $scriptDir = getcwd();
    chdir($orignalDir);
}

use Util;
use Logger;
use RemoteCmd;
use SDI;
use HV;
use RM;
use FADBUtil;
use EM;
use TAS;


### Constructor
### Input:
###     config => default config file
###     importfile => deploy properties file
### Create below objects:
###      logObj => store output to log file
###          loggerLogFIle => log file path
###          maxLogLevel => 4(debug, info, warning, error)
###      remoteObj => used to run remote commands
###          user => remote host user
###          passwd => remote host passwd
###          logObj => log object
###      sdiObj => used to run sdi commands
###          user => sdi host user
###          passwd => sdi host passwd
###          sdiscript => sdi script file
###          host => sdi host name
###          logObj => log object
###      hvObj => hypervisor object
###          user => hypervisor user
###          passwd => hypervisor passwd
###          logObj => log object
###      rmObj => resource manager object
###          logObj => log object
###      dbObj => database object
###          user => database user
###          passwd => database passwd
###          logObj => log object
###      tasObj => tas host object
###          user => tasc database host user
###          passwd => tasc database host passwd
###          logObj => log object
###      emObj => enterprise manager object
###          user => sdi host user
###          passwd => sdi host passwd
###          logObj => log object
### Return required objects and variables
###
sub new {

    my ($class, %args) = @_;

    my $self = {
        config => $args{config},
        importfile => $args{importfile},
    };

    bless($self, $class);

    $self->{'logObj'} = Logger->new(
        {'loggerLogFile' => "$self->{importfile}{'WORKDIR'}/order.log",
        'maxLogLevel' => 4}
    );

    $self->{'remoteObj'} = RemoteCmd->new(
        user => $self->{config}{'SDIUSER'},
        passwd => $self->{config}{'SDIPASSWD'},
        logObj => $self->{'logObj'}
    );

    $self->{'sdiObj'} = SDI->new(user => $self->{config}{'SDIUSER'},
                                 passwd => $self->{config}{'SDIPASSWD'},
                                 host => $self->{importfile}{'SDI_HOST'},
                                 sdiscript => $self->{config}{'SDISCRIPT'},
                                 logObj => $self->{'logObj'});

    $self->{'hvObj'} = HV->new(user => $self->{importfile}{'FA_HVUSER'},
                               passwd => $self->{importfile}{'FA_HVPASSWD'},
                               logObj => $self->{'logObj'});

    $self->{'rmObj'} = RM->new(logObj => $self->{'logObj'});

    $self->{'dbObj'} = FADBUtil->new(user => $self->{config}{'VMROOTUSER'},
                                     passwd => $self->{config}{'VMROOTPWD'},
                                     logObj => $self->{'logObj'});

    $self->{'tasObj'} = TAS->new(user => $self->{config}{'SDIUSER'},
                                 passwd => $self->{config}{'SDIPASSWD'},
                                 logObj => $self->{'logObj'});

    $self->{'emObj'} = EM->new(user => $self->{config}{'VMROOTUSER'},
                               passwd => $self->{config}{'VMROOTPWD'},
                               logObj => $self->{'logObj'});

    return $self;
}

#
# Get EM Agent path
# Input:
#     AGENTDIR from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub getEMAgentPath {

    my ($self) = @_;

    my ($status, $out);

    $self->{'logObj'}->info(["Executing Step: getEMAgentPath"]);

    if (exists $self->{importfile}{'EM_AGENT_CORE'} and
        $self->{importfile}{'EM_AGENT_CORE'} ne "") {
        $status = 0;
        $out = "Agent path: $self->{importfile}{'EM_AGENT_CORE'}";
    } else {
        my $agentfile = $self->{'sdiObj'}->getConfigProperty(
            "fa.emagent.patch.file.name");

        my $agentpath = `find $self->{config}{AGENTDIR} -type f -name $agentfile  -follow | tail -1`;
        chomp($agentpath);
        if ($agentpath ne "") {
            $status = 0;
            $out = "Agent path: $agentpath\n";

            $self->{importfile}{'EM_AGENT_CORE'} = $agentpath;
            my $INPUT_FILE = "$self->{importfile}{'WORKDIR'}/import.txt";
            my $addemagentpath = `sed -i $INPUT_FILE -e 's,EM_AGENT_CORE\=,EM_AGENT_CORE\=$agentpath,g'`;

        } else {
            $status = 1;
            $out = "Provide EM_AGENT_CORE in import.txt\n";
        }
    }

    createAndSendStatusFile(step => "getEMAgentPath", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");

}

#
# Get Oracle Home path
# Input:
#     RAC_DB_HOST1 from import file
# add .suc(success) or .dif(failure) depending upon status
#
sub getOracleHomePath {

     my ($self) = @_;

    my ($status, $out, $cmd);

    $self->{'logObj'}->info(["Executing Step: getOracleHomePath"]);

    if (exists $self->{importfile}{'ORACLE_HOME'} and
        $self->{importfile}{'ORACLE_HOME'} ne "") {
        $status = 0;
        $out = "Oracle Home Path: $self->{importfile}{'ORACLE_HOME'}";
    } else {
        $cmd = "find /u01/app/oracle/product -name 'dbhome_1' -type d -follow | tail -1";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{importfile}{'RAC_DB_HOST1'},
                                                   cmd => "$cmd");

        my $oracle_home = join("", @$out);
        chop($oracle_home);
        if ($oracle_home ne "") {
            $status = 0;
            $out = "Oracle Home Path: $oracle_home\n";

            $self->{importfile}{'ORACLE_HOME'} = $oracle_home;
            my $INPUT_FILE = "$self->{importfile}{'WORKDIR'}/import.txt";
            my $addoraclehomepath = `sed -i $INPUT_FILE -e 's,ORACLE_HOME\=,ORACLE_HOME\=$oracle_home,g'`;

        } else {
            $status = 1;
            $out = "Provide ORACLE_HOME in import.txt\n";
        }
    }

    createAndSendStatusFile(step => "getOracleHomePath", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Get Grid Home path
# Input:
#     RAC_DB_HOST1 from import file
# add .suc(success) or .dif(failure) depending upon status
#
sub getGridHomePath {

     my ($self) = @_;

    my ($status, $out, $cmd);

    $self->{'logObj'}->info(["Executing Step: getGridHomePath"]);

    if (exists $self->{importfile}{'GRID_HOME'} and
        $self->{importfile}{'GRID_HOME'} ne "") {
        $status = 0;
        $out = "Grid Home Path: $self->{importfile}{'GRID_HOME'}";
    } else {
        $cmd = "find /u01/app -name 'grid' -type d -follow | tail -1";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{importfile}{'RAC_DB_HOST1'},
                                                   cmd => "$cmd");

        my $grid_home = join("", @$out);
        chop($grid_home);
        if ($grid_home ne "") {
            $status = 0;
            $out = "Grid Home Path: $grid_home\n";

            $self->{importfile}{'GRID_HOME'} = $grid_home;
            my $INPUT_FILE = "$self->{importfile}{'WORKDIR'}/import.txt";
            my $addgridhomepath = `sed -i $INPUT_FILE -e 's,GRID_HOME\=,GRID_HOME\=$grid_home,g'`;

        } else {
            $status = 1;
            $out = "Provide GRID_HOME in import.txt\n";
        }
    }

    createAndSendStatusFile(step => "getGridHomePath", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Create custome directories in DB Node1
# Input:
#     TAG_NAME, RAC_DB_HOST1, FA_DB_NAME, IDM_DB_NAME,
#       OIM_DB_NAME, FA_DB_UNIQUE_NAME, IDM_DB_UNIQUE_NAME,
#       OIM_DB_UNIQUE_NAME,IS_STANDBY, RAC_DB_HOST2 from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub createCustomDirs {

    my ($self) = @_;

    # Check createCustomDirs step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "createCustomDirs",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: createCustomDirs"]);

    my @dbnodes = ($self->{importfile}{'RAC_DB_HOST1'},
                   $self->{importfile}{'RAC_DB_HOST2'});

    my ($status, $out) = $self->{'dbObj'}->createCustomDirs(
        db_version => $self->{importfile}{'DB_VERSION'},
        db_node1 => $self->{importfile}{'RAC_DB_HOST1'},
        dbnodes => \@dbnodes,
        is_standby => $self->{importfile}{'IS_STANDBY'},
        fa_db_name => $self->{importfile}{'FA_DB_NAME'},
        oid_db_name => $self->{importfile}{'IDM_DB_NAME'},
        oim_db_name => $self->{importfile}{'OIM_DB_NAME'},
        fa_db_unique_name => $self->{importfile}{'FA_DB_UNIQUE_NAME'},
        oid_db_unique_name => $self->{importfile}{'IDM_DB_UNIQUE_NAME'},
        oim_db_unique_name => $self->{importfile}{'OIM_DB_UNIQUE_NAME'},
    );

    createAndSendStatusFile(step => "createCustomDirs", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Add FADb in SDI Host
# Input:
#     FA_DB_UNIQUE_NAME, FA_DB_NAME, FA_DB_PORT, RAC_NODE1_VIP,
#       RAC_NODE2_VIP, DATA_DISKGROUP_NAME, RECO_DISKGROUP_NAME,
#       RAC_DB_HOST1, RAC_DB_HOST2, CLUSTER_NODE, GRID_HOME,
#       ORACLE_HOME, ORACLE_BASE, CRS_SCAN_PORT, CRS_ONS_PORT,
#       DG_LISTENER_NAME, DG_LISTENER_PORT,
#       EM_REGISTRATION from prop file
#     ISASM( true|false), ASMUSER, ASMPASSWD,
#       ASMSID1, ASMSID2 from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub addFADB {

    my ($self) = @_;

    # Check addFADB step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addFADB",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addFADB"]);

    my ($status, $out) = $self->{'sdiObj'}->addDB(
        db_unique_name => $self->{importfile}{'FA_DB_UNIQUE_NAME'},
        db_name => $self->{importfile}{'FA_DB_NAME'},
        port => $self->{importfile}{'FA_DB_PORT'},
        host_name1 => $self->{importfile}{'RAC_NODE1_VIP'},
        sid1 => "$self->{importfile}{'FA_DB_NAME'}1",
        db_service_name => $self->{importfile}{'FA_DB_NAME'},
        data_disc => $self->{importfile}{'DATA_DISKGROUP_NAME'},
        reco_disc => $self->{importfile}{'RECO_DISKGROUP_NAME'},
        is_asm => $self->{config}{'ISASM'},
        asm_user => $self->{config}{'ASMUSER'},
        asm_password => $self->{config}{'ASMPASSWD'},
        fa_database_type => "MAIN_DB",
        db_version => $self->{importfile}{'DB_VERSION'},
        host_name2 => $self->{importfile}{'RAC_NODE2_VIP'},
        sid2 => "$self->{importfile}{'FA_DB_NAME'}2",
        cluster_host1 => $self->{importfile}{'RAC_DB_HOST1'},
        cluster_host2 => $self->{importfile}{'RAC_DB_HOST2'},
        cluster_name => $self->{importfile}{'CLUSTER_NODE'},
        crs_scan_name => $self->{importfile}{'CRS_SCAN_NAME'},
        crs_scan_port => $self->{importfile}{'CRS_SCAN_PORT'},
        crs_home => $self->{importfile}{'GRID_HOME'},
        crs_ons_port => $self->{importfile}{'CRS_ONS_PORT'},
        asm_sid1 => $self->{config}{'ASMSID1'},
        asm_sid2 => $self->{config}{'ASMSID2'},
        is_standby => $self->{importfile}{'IS_STANDBY'},
        dg_preconfigured_listener_name =>
            $self->{importfile}{'DG_LISTENER_NAME'},
        dg_preconfigured_listener_port =>
            $self->{importfile}{'DG_LISTENER_PORT'},
        oracle_home => $self->{importfile}{'ORACLE_HOME'},
        oracle_base => $self->{importfile}{'ORACLE_BASE'},
        em_registration => $self->{importfile}{'EM_REGISTRATION'},
    );

    createAndSendStatusFile(step => "addFADB", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Add OIMDb in SDI Host
# Input:
#     FA_DB_UNIQUE_NAME, FA_DB_NAME, FA_DB_PORT, RAC_NODE1_VIP,
#       RAC_NODE2_VIP, DATA_DISKGROUP_NAME, RECO_DISKGROUP_NAME,
#       RAC_DB_HOST1, RAC_DB_HOST2, CLUSTER_NODE, GRID_HOME,
#       ORACLE_HOME, ORACLE_BASE, CRS_SCAN_PORT, CRS_ONS_PORT,
#       DG_LISTENER_NAME, DG_LISTENER_PORT from prop file
#     ISASM( true|false), ASMUSER, ASMPASSWD,
#       ASMSID1, ASMSID2 from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub addOIMDB {

    my ($self) = @_;

    # Check addOIMDB step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addOIMDB",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addOIMDB"]);

    my ($status, $out);
    if ($self->{importfile}{'RELEASE_NAME'} ne 'REL12') {
        ($status, $out) = $self->{'sdiObj'}->addDB(
            db_unique_name => $self->{importfile}{'OIM_DB_UNIQUE_NAME'},
            db_name => $self->{importfile}{'OIM_DB_NAME'},
            port => $self->{importfile}{'OIM_DB_PORT'},
            host_name1 => $self->{importfile}{'RAC_NODE1_VIP'},
            sid1 => "$self->{importfile}{'OIM_DB_NAME'}1",
            db_service_name => $self->{importfile}{'OIM_DB_NAME'},
            data_disc => $self->{importfile}{'DATA_DISKGROUP_NAME'},
            reco_disc => $self->{importfile}{'RECO_DISKGROUP_NAME'},
            is_asm => $self->{config}{'ISASM'},
            asm_user => $self->{config}{'ASMUSER'},
            asm_password => $self->{config}{'ASMPASSWD'},
            fa_database_type => "IDS_DB",
            db_version => $self->{importfile}{'DB_VERSION'},
            host_name2 => $self->{importfile}{'RAC_NODE2_VIP'},
            sid2 => "$self->{importfile}{'OIM_DB_NAME'}2",
            cluster_host1 => $self->{importfile}{'RAC_DB_HOST1'},
            cluster_host2 => $self->{importfile}{'RAC_DB_HOST2'},
            cluster_name => $self->{importfile}{'CLUSTER_NODE'},
            crs_scan_name => $self->{importfile}{'CRS_SCAN_NAME'},
            crs_scan_port => $self->{importfile}{'CRS_SCAN_PORT'},
            crs_home => $self->{importfile}{'GRID_HOME'},
            crs_ons_port => $self->{importfile}{'CRS_ONS_PORT'},
            asm_sid1 => $self->{config}{'ASMSID1'},
            asm_sid2 => $self->{config}{'ASMSID2'},
            is_standby => $self->{importfile}{'IS_STANDBY'},
            dg_preconfigured_listener_name =>
                $self->{importfile}{'DG_LISTENER_NAME'},
            dg_preconfigured_listener_port =>
                $self->{importfile}{'DG_LISTENER_PORT'},
            oracle_home => $self->{importfile}{'ORACLE_HOME'},
            oracle_base => $self->{importfile}{'ORACLE_BASE'},
        );
      } else {
          $status = 0;
          $out = "As REL12 is selected. Skipping addfadb step for OIM DB";
      }

    createAndSendStatusFile(step => "addOIMDB", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Add OIDDb in SDI Host
# Input:
#     FA_DB_UNIQUE_NAME, FA_DB_NAME, FA_DB_PORT, RAC_NODE1_VIP,
#       RAC_NODE2_VIP, DATA_DISKGROUP_NAME, RECO_DISKGROUP_NAME,
#       RAC_DB_HOST1, RAC_DB_HOST2, CLUSTER_NODE, GRID_HOME,
#       ORACLE_HOME, ORACLE_BASE, CRS_SCAN_PORT, CRS_ONS_PORT,
#       DG_LISTENER_NAME, DG_LISTENER_PORT from prop file
#     ISASM( true|false), ASMUSER, ASMPASSWD,
#       ASMSID1, ASMSID2 from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub addOIDDB {

    my ($self) = @_;

    # Check addOIDDB step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addOIDDB",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addOIDDB"]);

    my ($status, $out) = $self->{'sdiObj'}->addDB(
        db_unique_name => $self->{importfile}{'IDM_DB_UNIQUE_NAME'},
        db_name => $self->{importfile}{'IDM_DB_NAME'},
        port => $self->{importfile}{'IDM_DB_PORT'},
        host_name1 => $self->{importfile}{'RAC_NODE1_VIP'},
        sid1 => "$self->{importfile}{'IDM_DB_NAME'}1",
        db_service_name => $self->{importfile}{'IDM_DB_NAME'},
        data_disc => $self->{importfile}{'DATA_DISKGROUP_NAME'},
        reco_disc => $self->{importfile}{'RECO_DISKGROUP_NAME'},
        is_asm => $self->{config}{'ISASM'},
        asm_user => $self->{config}{'ASMUSER'},
        asm_password => $self->{config}{'ASMPASSWD'},
        fa_database_type => "OID_DB",
        db_version => $self->{importfile}{'DB_VERSION'},
        host_name2 => $self->{importfile}{'RAC_NODE2_VIP'},
        sid2 => "$self->{importfile}{'IDM_DB_NAME'}2",
        cluster_host1 => $self->{importfile}{'RAC_DB_HOST1'},
        cluster_host2 => $self->{importfile}{'RAC_DB_HOST2'},
        cluster_name => $self->{importfile}{'CLUSTER_NODE'},
        crs_scan_name => $self->{importfile}{'CRS_SCAN_NAME'},
        crs_scan_port => $self->{importfile}{'CRS_SCAN_PORT'},
        crs_home => $self->{importfile}{'GRID_HOME'},
        crs_ons_port => $self->{importfile}{'CRS_ONS_PORT'},
        asm_sid1 => $self->{config}{'ASMSID1'},
        asm_sid2 => $self->{config}{'ASMSID2'},
        is_standby => $self->{importfile}{'IS_STANDBY'},
        dg_preconfigured_listener_name =>
            $self->{importfile}{'DG_LISTENER_NAME'},
        dg_preconfigured_listener_port =>
            $self->{importfile}{'DG_LISTENER_PORT'},
        oracle_home => $self->{importfile}{'ORACLE_HOME'},
        oracle_base => $self->{importfile}{'ORACLE_BASE'},
    );

    createAndSendStatusFile(step => "addOIDDB", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Register DBs with tag name in SDI host
# Input:
#     TAG_NAME => tag name from prop file
#     FA_DB_UNIQUE_NAME => fa db uniq name from prop file
#     IDM_DB_UNIQUE_NAME => idm db uniq name from prop file
#     OIM_DB_UNIQUE_NAME => oim db uniq name from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub addDBTags {

    my ($self) = @_;

    # Check addDBTags step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addDBTags",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addDBTags"]);

    my ($status, $out) = $self->{'sdiObj'}->addDBTags(
        tagName => $self->{importfile}{'TAG_NAME'},
        fa_db_unique_name => $self->{importfile}{'FA_DB_UNIQUE_NAME'},
        oid_db_unique_name => $self->{importfile}{'IDM_DB_UNIQUE_NAME'},
        oim_db_unique_name => $self->{importfile}{'OIM_DB_UNIQUE_NAME'},
        release_name => $self->{importfile}{'RELEASE_NAME'},
    );

    createAndSendStatusFile(step => "addDBTags", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Add FATemplate in SDI host
# Input:
#     PILLAR, RELEASE_NAME, STAGE_NAME from prop file
#     RELEASEVER, ISTRIAL, ISPREFERRED from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub addFATemplate {

    my ($self) = @_;

    # Check addFATemplate step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addFATemplate",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addFATemplate"]);

    my $template_name = lc($self->{importfile}{'PILLAR'}.
                           "_". $self->{importfile}{'RELEASE_NAME'}.
                           "_". $self->{importfile}{'STAGE_NAME'});

    my $release_name = ($self->{importfile}{'RELEASE_NAME'}.
                        "_" . $self->{importfile}{'STAGE_NAME'});

    my $release_version = "$self->{importfile}{'RELEASE_NAME'}RELEASEVERSION";

    my ($status, $out) = $self->{'sdiObj'}->addFATemplate(
        release_name => $release_name,
        release_version => $self->{config}{$release_version},
        service_type => $self->{importfile}{'PILLAR'},
        template_name => $template_name,
        is_trial => $self->{config}{'ISTRIAL'},
        is_preferred => $self->{config}{'ISPREFERRED'},
    );

    createAndSendStatusFile(step => "addFATemplate", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Create FA Template directory in SDI host
# Input:
#     RELEASE_NAME, STAGE_NAME, PILLAR from prop file
#     NFSPATH, RELEASEVER, ROOTSCRIPT from config file
#     scriptDir => source path for create order scripts
# add .suc(success) or .dif(failure) depending upon status
#
sub createFATemplateDir {

    my ($self) = @_;

    # Check createFATemplateDir step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "createFATemplateDir",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: createFATemplateDir"]);

    my $release_version = "$self->{importfile}{'RELEASE_NAME'}RELEASEVERSION";

    my ($status, $out) = $self->{'sdiObj'}->createFATemplateDir(
        release_name => $self->{importfile}{'RELEASE_NAME'},
        stage_name => $self->{importfile}{'STAGE_NAME'},
        fa_template => $self->{config}{'TEMPLATE'},
        pillar => $self->{importfile}{'PILLAR'},
        fa_template_nfs_path => $self->{config}{'RELEASENFSPATH'},
        rootscript => $self->{config}{'ROOTSCRIPT'},
        release_version => $self->{config}{$release_version},
        scriptdir => "$self->{config}{'SOURCESCRIPTS'}/dr",
    );

    createAndSendStatusFile(step => "createFATemplateDir", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Create FSNADMIN directory in SDI host
# Input:
#     RELEASE_NAME, STAGE_NAME, PILLAR
#      RAC_NODE1_VIP from prop file
#      FSNADMINNFSPATH from config file
#     scriptDir => source path for create order scripts
# add .suc(success) or .dif(failure) depending upon status
#
sub createFSNAdminDir {

    my ($self) = @_;

    # Check createFSNAdminDir step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "createFSNAdminDir",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: createFSNAdminDir"]);

    my ($status, $out) = $self->{'sdiObj'}->createFSNAdminDir(
        release_name => $self->{importfile}{'RELEASE_NAME'},
        stage_name => $self->{importfile}{'STAGE_NAME'},
        fa_template => $self->{config}{'TEMPLATE'},
        db_node1 => $self->{importfile}{'RAC_NODE1_VIP'},
        pillar => $self->{importfile}{'PILLAR'},
        fsnadmin_nfs_path => $self->{config}{'FSNADMINNFSPATH'},
        rootscript => $self->{config}{'ROOTSCRIPT'},
        scriptdir => "$self->{config}{'SOURCESCRIPTS'}/dr",
    );

    createAndSendStatusFile(step => "createFSNAdminDir", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# mount FSNADMIN directory in DB node1
# Input:
#     RAC_NODE1_VIP from prop file
#       FSNADMINNFSPATH from config file
#     scriptDir => source path for create order scripts
# add .suc(success) or .dif(failure) depending upon status
#
sub mountFSNAdminDir {

    my ($self) = @_;

    # Check mountFSNAdminDir step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "mountFSNAdminDir",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: mountFSNAdminDir"]);

    my ($status, $out) = $self->{'dbObj'}->mountFSNAdminDir(
        db_node1 => $self->{importfile}{'RAC_NODE1_VIP'},
        fsnadmin_nfs_path => $self->{config}{'FSNADMINNFSPATH'},
        scriptdir => "$self->{config}{'SOURCESCRIPTS'}/dr",
    );

    createAndSendStatusFile(step => "mountFSNAdminDir", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# reserve memory in QA Farm against pillar for each Hypervisor
# Input:
#     RELEASE_NAME, FA_HYPERVISOR, PILLAR,
#       FARM(DRQA|fastha), TAG_NAME from prop file
#     QAFARMMANAGER, TEMP_TYPE(template type(image)),
#       ENV_TYPE(HA|NONHA) from config file
#     hvhash => create hvhash file(it stores netmask, gateway, vm ips for each Hypervisors)
# add .suc(success) or .dif(failure) depending upon status
#
sub reserveMem {

    my ($self) = @_;

    my ($status, $out);
    # Check reserveMem step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "reserveMem",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: reserveMem"]);

    if (lc($self->{importfile}{'USE_QAFARM_FA'}) eq 'yes') {
        ($status, $out) = $self->{'rmObj'}->reserveMem(
            release_name => $self->{importfile}{'RELEASE_NAME'},
            pillar => "FA_$self->{importfile}{'PILLAR'}",
            hypervisors => $self->{importfile}{'FA_HYPERVISOR'},
            farm => $self->{importfile}{'FARM'},
            tag_name => $self->{importfile}{'TAG_NAME'},
            qafarmmanager => $self->{config}{'QAFARMMANAGER'},
            template_type => $self->{config}{'TEMP_TYPE'},
            type => $self->{importfile}{'ENV_TYPE'},
            hvhashfile => "$self->{importfile}{'WORKDIR'}/hvhash",
        );
    } else {
        ($status, $out) = $self->{'rmObj'}->reserveMemNonQAFarm(
            release_name => $self->{importfile}{'RELEASE_NAME'},
            pillar => "FA_$self->{importfile}{'PILLAR'}",
            hypervisors => $self->{importfile}{'FA_HYPERVISOR'},
            type => $self->{importfile}{'ENV_TYPE'},
            hvhashfile => "$self->{importfile}{'WORKDIR'}/hvhash",
            vms_data_file => "$self->{importfile}{'vms_data_file'}",
            hvuser => $self->{importfile}{'FA_HVUSER'},
            hvpasswd => $self->{importfile}{'FA_HVPASSWD'},
        );
    }

    createAndSendStatusFile(step => "reserveMem", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# create running and seed pool directories in Hypervisors
# Input:
#     RELEASE_NAME, STAGE_NAME, PILLAR, SDI_HOST, WORKDIR from prop file
#     SDIUSER, SDIPASSWD, SDIHOST,
#      SEEDPOOL, RUNNINGPOOL, ROOTSCRIPT from config file
#     hvhash => get hypervisors from hvhash file
#     scriptDir => source path for create order scripts
# add .suc(success) or .dif(failure) depending upon status
#
sub addPools {

    my ($self) = @_;

    # check reserveMem step is executed
    # if .suc exists: return 1
    return 0 if (! isStepExecuted(step => "reserveMem",
                                  workdir => $self->{importfile}{'WORKDIR'},
                                  logObj => $self->{'logObj'}));

    # Check addPools step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addPools",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addPools"]);

    my ($status, $out) = $self->{'hvObj'}->addPools(
        release_name => $self->{importfile}{'RELEASE_NAME'},
        pillar => $self->{importfile}{'PILLAR'},
        stage_name => $self->{importfile}{'STAGE_NAME'},
        rootscript => $self->{config}{'ROOTSCRIPT'},
        workdir => $self->{importfile}{'WORKDIR'},
        seedpool_nfs_path => $self->{config}{'SEEDPOOLNFSPATH'},
        seedpool => $self->{config}{'SEEDPOOL'},
        runningpool => $self->{config}{'RUNNINGPOOL'},
        ovsrepositories => $self->{config}{'OVSREPOSITORIES'},
        sdihost => $self->{importfile}{'SDI_HOST'},
        sdiuser => $self->{config}{'SDIUSER'},
        sdipasswd => $self->{config}{'SDIPASSWD'},
        hvhashfile => "$self->{importfile}{'WORKDIR'}/hvhash",
        scriptdir => "$self->{config}{'SOURCESCRIPTS'}/dr",
    );

    createAndSendStatusFile(step => "addPools", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Check OVS entry in SDI host
# Input:
#     FA_HYPERVISOR => fa hypervisor name
# add .suc(success) or .dif(failure) depending upon status
#
sub checkOVSEntry {

    my ($self) = @_;

    # check addPools and reserveMem steps are executed
    # if .suc exists: return 1
    return 0 if (!(isStepExecuted(step => "addPools",
                                  workdir => $self->{importfile}{'WORKDIR'},
                                  logObj => $self->{'logObj'}) and
                 isStepExecuted(step => "reserveMem",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'})));

    # Check checkOVSEntry is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "checkOVSEntry",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: checkOVSEntry"]);

    my ($status, $out) = $self->{'sdiObj'}->checkOVSEntry(
        hypervisors => $self->{importfile}{'FA_HYPERVISOR'},
        use_serverpool => $self->{config}{'USE_SERVERPOOL'},
        serverpoolfile => "$self->{importfile}{'WORKDIR'}/serverpoolfile",
    );

    createAndSendStatusFile(step => "checkOVSEntry", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Add rack in SDI host
# Input:
#     TAG_NAME, PILLAR, WORKDIR from prop file
#     ZFS_ID, PREF_LEVEL from config file
#     racidfile => if hv is not found in SDI(listOVS), add racid to racidfile)
#     hvhash => get hypervisor netmask, gateway and vm ips from hvhash file
# add .suc(success) or .dif(failure) depending upon status
#
sub addRack {

    my ($self) = @_;

    # check addPools and reserveMem steps are executed
    # if .suc exists: return 1
    return 0 if (!(isStepExecuted(step => "addPools",
                                  workdir => $self->{importfile}{'WORKDIR'},
                                  logObj => $self->{'logObj'}) and
                 isStepExecuted(step => "reserveMem",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}) and
                 isStepExecuted(step => "checkOVSEntry",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'})));

    # Check addRack is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addRack",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addRack"]);

    my ($status, $out) = $self->{'sdiObj'}->addRack(
        zfs_id => $self->{importfile}{'ZFS_ID'},
        pillar => $self->{importfile}{'PILLAR'},
        pref_level => $self->{config}{'PREF_LEVEL'},
        tag_name => $self->{importfile}{'TAG_NAME'},
        racidfile => "$self->{importfile}{'WORKDIR'}/racidfile",
        hvhashfile => "$self->{importfile}{'WORKDIR'}/hvhash",
        use_serverpool => $self->{config}{'USE_SERVERPOOL'},
        serverpoolfile => "$self->{importfile}{'WORKDIR'}/serverpoolfile",
        networkBridge0 => "$self->{importfile}{'NETWORK_BRIDGE0'}",
        networkBridge1 => "$self->{importfile}{'NETWORK_BRIDGE1'}",
        backendNetmask => "$self->{importfile}{'BACKEND_NETMASK'}",
        backendGateway => "$self->{importfile}{'BACKEND_GATEWAY'}",
        frontendGateway => "$self->{importfile}{'FRONTEND_GATEWAY'}",
        frontendNetmask => "$self->{importfile}{'FRONTEND_NETMASK'}",
        rackheadroomsize => "$self->{importfile}{'RACK_HEADROOM_SIZE'}",
        rackupsizeheadroom => "$self->{importfile}{'RACK_UPSIZE_HEADROOM'}",
        predictablehostnameenable => "$self->{importfile}{'PREDICTABLE_HOSTNAME_ENABLE'}",
    );

    createAndSendStatusFile(step => "addRack", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Add OVS in SDI host
# Input:
#     TAG_NAME, WORKDIR, FA_HVUSER, FA_HVPASSWD from prop file
#     SEEDPOOL, RUNNINGPOOL from config file
#     racidfile => get hypervisors from racidfile
# add .suc(success) or .dif(failure) depending upon status
#
sub addOVS {

    my ($self) = @_;

    # check addPools, reserveMem and addRack steps are executed
    # if .suc exists: return 1
    return 0 if (!(isStepExecuted(step => "addPools",
                                  workdir => $self->{importfile}{'WORKDIR'},
                                  logObj => $self->{'logObj'}) and
                   isStepExecuted(step => "reserveMem",
                                  workdir => $self->{importfile}{'WORKDIR'},
                                  logObj => $self->{'logObj'}) and
                   isStepExecuted(step => "addRack",
                                  workdir => $self->{importfile}{'WORKDIR'},
                                  logObj => $self->{'logObj'})));

    # Check addOVS step is executed
    # if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addOVS",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addOVS"]);

    my ($status, $out) = $self->{'sdiObj'}->addOVS(
        racidfile => "$self->{importfile}{'WORKDIR'}/racidfile",
        tag_name => $self->{importfile}{'TAG_NAME'},
        fa_hvuser => $self->{importfile}{'FA_HVUSER'},
        fa_hvpasswd => $self->{importfile}{'FA_HVPASSWD'},
        seedpool => $self->{config}{'SEEDPOOL'},
        runningpool => $self->{config}{'RUNNINGPOOL'},
    );

    createAndSendStatusFile(step => "addOVS", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Add EMagents on DB Nodes
# Input:
#     RAC_DB_HOST1, RAC_DB_HOST2, STAGE_NAME,
#      OMS_HOST_NAME, EM_UPLOAD_PORT, AGENT_PORT, AGENT_CORE from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub addEMAgent {

    my ($self) = @_;

    # Check addEMAgent step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "addEMAgent",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: addEMAgent"]);

    my @dbnodes = ($self->{importfile}{'RAC_DB_HOST1'},
                   $self->{importfile}{'RAC_DB_HOST2'});

    my ($status, $out) = $self->{'emObj'}->addEMAgent(
        dbnodes => \@dbnodes,
        stage_name => $self->{importfile}{'STAGE_NAME'},
        fa_template => $self->{config}{'TEMPLATE'},
        sdihost => $self->{importfile}{'SDI_HOST'},
        release_name => $self->{importfile}{'RELEASE_NAME'},
        stage_name => $self->{importfile}{'STAGE_NAME'},
        pillar => $self->{importfile}{'PILLAR'},
        oms_host_name => $self->{importfile}{'OMS_HOST_NAME'},
        em_upload_port => $self->{importfile}{'EM_UPLOAD_PORT'},
        agent_port => $self->{importfile}{'EM_AGENT_PORT'},
        sdiuser => $self->{config}{'SDIUSER'},
        sdipasswd => $self->{config}{'SDIPASSWD'},
        emuser => $self->{config}{'EMUSER'},
        empasswd => $self->{config}{'EMPASSWD'},
        agentcore => $self->{importfile}{'EM_AGENT_CORE'},
    );

    createAndSendStatusFile(step => "addEMAgent", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# check EMagents status on DB Nodes
# Input:
#     RAC_DB_HOST1, RAC_DB_HOST2 from prop file
#     EMUSER from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub checkEMAgentStatus {

    my ($self) = @_;

    # Check checkEMAgentStatus step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "checkEMAgentStatus",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: checkEMAgentStatus"]);

    my @dbnodes = ($self->{importfile}{'RAC_DB_HOST1'},
                   $self->{importfile}{'RAC_DB_HOST2'});

    my ($status, $out) = $self->{'emObj'}->checkEMAgentStatus(
        dbnodes => \@dbnodes,
        emuser => $self->{config}{'EMUSER'},
    );

    createAndSendStatusFile(step => "checkEMAgentStatus", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# check DBs and Listener up and running
# Input:
#     RAC_NODE1_VIP, RAC_NODE2_VIP, FA_DB_NAME,
#      OIM_DB_NAME, IDM_DB_NAME from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub checkDBStatus {

    my ($self) = @_;

    # Check DBStatus step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "checkDBStatus",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: checkDBStatus"]);

    my @dbnodes = ($self->{importfile}{'RAC_DB_HOST1'},
                   $self->{importfile}{'RAC_DB_HOST2'});

    my ($status, $out) = $self->{'dbObj'}->checkDBStatus(
        dbnodes => \@dbnodes,
        fa_db_name => $self->{importfile}{'FA_DB_NAME'},
        oid_db_name => $self->{importfile}{'OIM_DB_NAME'},
        oim_db_name => $self->{importfile}{'IDM_DB_NAME'},
        fa_db_unique_name => $self->{importfile}{'FA_DB_UNIQUE_NAME'},
        oid_db_unique_name => $self->{importfile}{'OIM_DB_UNIQUE_NAME'},
        oim_db_unique_name => $self->{importfile}{'IDM_DB_UNIQUE_NAME'},
    );

    createAndSendStatusFile(step => "checkDBStatus", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

1;
