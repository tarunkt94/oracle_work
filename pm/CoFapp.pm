#
# $Header: dte/DTE/scripts/fusionapps/cli/pm/CoFapp.pm /main/18 2016/10/28 01:37:50 ljonnala Exp $
#
# CoFapp.pm
#
# Copyright (c) 2016, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      CoFapp.pm - <one-line expansion of the name>
#
package CoFapp;

use Order;
use strict;
use warnings;
our @ISA = qw(Order);
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
use TAS;
use SDI;
use RemoteCmd;
use Util;


### Constructor
### Input:
###     config => default config file
###     importfile => deploy properties file
### Create below objects:
###      logObj => store output to log file
###          loggerLogFIle => log file path
###          maxLogLevel => 4(debug, info, warning, error)
###      tasObj => tas host object
###          user => tasc host user
###          passwd => tasc host passwd
###          logObj => log object
### Return required objects and variables
###
sub new {

    my ($class, %args) = @_;

    my $self = Order->new(%args);

    $self->{config} = $args{config};
    $self->{importfile} = $args{importfile};

    bless($self, $class);

    $self->{'logObj'} = Logger->new(
        {'loggerLogFile' => "$self->{importfile}{'WORKDIR'}/order.log",
        'maxLogLevel' => 4}
    );

    $self->{'remoteObj'} = RemoteCmd->new(user => $self->{config}{'SDIUSER'},
                                          passwd => $self->{config}{'SDIPASSWD'},
                                          logObj => $self->{'logObj'});

    $self->{'tasObj'} = TAS->new(user => $self->{config}{'SDIUSER'},
                                 passwd => $self->{config}{'SDIPASSWD'},
                                 logObj => $self->{'logObj'});

    return $self;
}

#
# COFAPP
# Input:
#     $self
# Send mail notifcation to user after order is seeded
#
sub Cofapp {

    my ($self) = @_;

    $self->process();

    $self->copyDRDPPatch();

    $self->runCoFapp();
}

sub process {

    my ($self) = @_;

    $self->getEMAgentPath();

    $self->getOracleHomePath();

    $self->getGridHomePath();

    $self->createCustomDirs();

    $self->reserveMem();

    $self->addFADB();

    $self->addOIMDB();

    $self->addOIDDB();

    $self->addDBTags();

    $self->addFATemplate();

    $self->createFATemplateDir();

    $self->createFSNAdminDir();

    $self->mountFSNAdminDir();

    $self->addPools();

    $self->checkOVSEntry();

    $self->addRack();

    $self->addOVS();

    $self->addEMAgent();

    $self->checkEMAgentStatus();

    $self->checkDBStatus();

}

#
# Copy DRDP patch
# Input:
#     RELEASE_NAME, STAGE_NAME, PILLAR, SDI_HOST from import file
# add .suc(success) or .dif(failure) depending upon status
#
sub copyDRDPPatch {

    my ($self) = @_;

    # Check copyDRDPPatch step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "copydrdpPatch",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: copydrdpPatch"]);

    my ($status, $out) = $self->copyDRDP();

    createAndSendStatusFile(step => "copydrdpPatch", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");

}

sub copyDRDP {

    my ($self) = @_;

    my ($cmd, $filter, $out, $msg);

    my $sdiObj = SDI->new(host => $self->{importfile}{'SDI_HOST'},
                          sdiscript => $self->{config}{'SDISCRIPT'},
                          user => $self->{config}{'SDIUSER'},
                          passwd => $self->{config}{'SDIPASSWD'},
                          logObj => $self->{logObj});

    my $fsnadmin = $sdiObj->getConfigProperty("fa.fsnadmin.root.dir");

    my $fa_dr_dp_tools = "$fsnadmin/SDI_FA_DR_DP_TOOLS";

    my $fa_dr_utils_dir = "$fa_dr_dp_tools/$self->{importfile}{'RELEASE_NAME'}_" .
                          "$self->{importfile}{'STAGE_NAME'}" .
                          "/DedicatedIdm/paid/$self->{importfile}{'PILLAR'}/" .
                          "fa_drdp_conversiontool_master_home";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print}'";

    my $sdihost = $self->{importfile}{'SDI_HOST'};

    $cmd = "\"ls $fa_dr_utils_dir\"";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $sdihost,
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (join("", @$out) =~ m/No such/i) {
        $cmd = "\"mkdir -p $fa_dr_utils_dir\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $sdihost,
                                                             cmd => "$cmd",
                                                             filter => "$filter");
        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, "@$out";
        }
    }

    $cmd = "\"ls $fa_dr_utils_dir/fa_dr_utils.zip\"";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $sdihost,
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (join("", @$out) =~ m/No such/i) {

        $cmd = "\"ls $fa_dr_dp_tools/fa_dr_utils.zip\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $sdihost,
                                                             cmd => "$cmd",
                                                             filter => "$filter");
        if (join("", @$out) =~ m/No such/i) {
            $msg = "$fa_dr_dp_tools/fa_dr_utils.zip doesn't exists on $sdihost";
            $self->{'logObj'}->error(["$msg"]);
            return 1, "$msg";
        }

        $cmd = "\"cp -rf $fa_dr_dp_tools/fa_dr_utils.zip $fa_dr_utils_dir/\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $sdihost,
                                                             cmd => "$cmd",
                                                             filter => "$filter");

        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, "@$out";
        }

    }

    $cmd = "\"cd $fa_dr_utils_dir/; unzip -oq fa_dr_utils.zip\"";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $sdihost,
                                                         cmd => "$cmd",
                                                         filter => "$filter");
    if (grep(/error|no such/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Run add_explicit_dr in Tasc DB host
# Input:
#     SUBSCRIPTION_ID from prop file
#     TASCTL from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub runCoFapp {

    my ($self) = @_;

    my ($mailids, $message, $subject);

    # Check runCoFapp step was executed
    # if .suc exists: return 1
    return 0 if (!isStepExecuted(step => "checkDBStatus",
                                 workdir => $self->{importfile}{'WORKDIR'},
                                 logObj => $self->{'logObj'}));

    # Check runCoFapp step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "runCoFapp",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: runCoFapp"]);

    my ($status, $out) = $self->{'tasObj'}->runCoFapp(
        tasc_host => $self->{importfile}{'TASC_HOST'},
        tasctl => $self->{config}{'TASCTL'},
        subscription_id => $self->{importfile}{'SUBSCRIPTION_ID'},
    );

    createAndSendStatusFile(step => "runCoFapp", status => $status,
                     importfile => $self->{importfile},
                     logObj => $self->{'logObj'}, out => "$out");

    sleep(300);

    my $sdiObj = SDI->new(host => $self->{importfile}{'PRIMARY_SDIHOST'},
                          sdiscript => $self->{config}{'SDISCRIPT'},
                          user => $self->{config}{'SDIUSER'},
                          passwd => $self->{config}{'SDIPASSWD'},
                          logObj => $self->{logObj});

    my %reqDetails = $sdiObj->getReqDetails(req_id => $self->{importfile}{'IDENTITYDOMAIN'});

    $mailids = $self->{importfile}{'EMAIL_ID'};
    $mailids =~ s/[;| ]+/,/g;


    my $hostname = `hostname`;

    foreach my $keycount (keys %reqDetails){
        if ($reqDetails{$keycount}{'requesttype'} eq 'PREPARE_CREATE_ONLY_FA_PASSIVE_POD') {
            $subject = "$reqDetails{$keycount}{requesttype}\' " .
                       "Req \'$reqDetails{$keycount}{requestid}\' " .
                       "for Domain \'$reqDetails{$keycount}{identitydomain}\' " .
                       "\'$reqDetails{$keycount}{status}\'";

            $message = "<h4>Order Details<h4><table><tr><th>Request Id</th><td>$reqDetails{$keycount}{requestid}</td></tr>
                        <tr><th>Request Type</th><td>$reqDetails{$keycount}{requesttype}</td></tr>
                        <tr><th>SDI Host</th><td>$self->{importfile}{'SDI_HOST'}</td></tr>
                        <tr><th>Identity Domain</th><td>$reqDetails{$keycount}{identitydomain}</td></tr>
                        <tr><th>Status</th><td>$reqDetails{$keycount}{status}</td></tr>
                        <tr><th>Service Type</th><td>$reqDetails{$keycount}{servicetype}</td></tr>
                        <tr><th>Last Updated On</th><td>$reqDetails{$keycount}{lastupdate}</td></tr>
                        <tr><th>Hostname</th><td>$hostname</td></tr>
                        <tr><th>For more details check log files at</th><td>$self->{importfile}{WORKDIR}</td></tr></table>";

            sendMail(mailids => $mailids,
                     subject => $subject,
                     message => $message);
        }
    }
}

1;
