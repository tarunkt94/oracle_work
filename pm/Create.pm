#
# $Header: dte/DTE/scripts/fusionapps/cli/pm/Create.pm /main/16 2016/11/01 01:56:17 ljonnala Exp $
#
# Create.pm
#
# Copyright (c) 2016, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      Create.pm - <one-line expansion of the name>
#
package Create;

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
###          user => tasc database host user
###          passwd => tasc database host passwd
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

    $self->{'tasObj'} = TAS->new(user => $self->{config}{'SDIUSER'},
                                 passwd => $self->{config}{'SDIPASSWD'},
                                 logObj => $self->{'logObj'});

    return $self;
}

#
# Create order
# Input:
#     $self
# Send mail notifcation to user after order is seeded
#
sub create {

    my ($self) = @_;

    $self->process();

    $self->runGSIBundle();
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
# Run gsi bundle.sh in Tasc DB host under /scratch/aime/order_scripts
# Input:
#     TAG_NAME, TASC_DB_HOST, TASC_ORACLE_HOME, TASC_DB_NAME, EMAIL_ID,
#      PILLAR, DB_VERSION, ENV_TYPE from prop file
#     CREATESCRIPTS from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub runGSIBundle {

    my ($self) = @_;

    my ($mailids, $message, $subject);

    # Check DBStatus step was executed
    # if .suc exists: return 1
    return 0 if (!isStepExecuted(step => "checkDBStatus",
                                 workdir => $self->{importfile}{'WORKDIR'},
                                 logObj => $self->{'logObj'}));

    # Check runGSIBundle step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "runGSIBundle",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: runGSIBundle"]);

    my $release_version = "$self->{importfile}{'RELEASE_NAME'}RELEASEVERSION";

    my ($status, $out) = $self->{'tasObj'}->runGSIBundle(
        tag_name => $self->{importfile}{'TAG_NAME'},
        sdihost => $self->{importfile}{'SDI_HOST'},
        tasc_db_host => $self->{importfile}{'TASC_DB_HOST'},
        tasc_oracle_home => $self->{importfile}{'TASC_ORACLE_HOME'},
        tasc_db_name => $self->{importfile}{'TASC_DB_NAME'},
        email_id => (split(/[,|;| ]+/, $self->{importfile}{'EMAIL_ID'}))[0],
        pillar => $self->{importfile}{'PILLAR'},
        faversion => $self->{config}{$release_version},
        createscripts => $self->{config}{'CREATESCRIPTS'},
        type => $self->{importfile}{'ENV_TYPE'},
        enable_federation => $self->{importfile}{'ENABLE_FEDERATION'},
        system_name => $self->{importfile}{'SYSTEM_NAME'},
        system_admin_user_name => $self->{importfile}{'SYSTEM_ADMIN_USERNAME'},
        scriptdir => "$self->{config}{'SOURCESCRIPTS'}/order_scripts",
    );

    createAndSendStatusFile(step => "runGSIBundle", status => $status,
                     importfile => $self->{importfile},
                     logObj => $self->{'logObj'}, out => "$out");

    my $service_name = `echo "$out" | grep "sql" | grep "ser" | awk -F" " '{print \$3}'`;

    sleep(300);

    my $sdiObj = SDI->new(host => $self->{importfile}{'SDI_HOST'},
                          sdiscript => $self->{config}{'SDISCRIPT'},
                          user => $self->{config}{'SDIUSER'},
                          passwd => $self->{config}{'SDIPASSWD'},
                          logObj => $self->{logObj});

    my %reqDetails = $sdiObj->getReqDetails(req_id => $service_name);

    $mailids = $self->{importfile}{'EMAIL_ID'};
    $mailids =~ s/[;| ]+/,/g;

    my $hostname = `hostname`;

    foreach my $keycount (keys %reqDetails){
        if ($reqDetails{$keycount}{'requesttype'} eq 'CREATE') {
            $subject = "$reqDetails{$keycount}{requesttype}\' " .
                       "Req \'$reqDetails{$keycount}{requestid}\' for " .
                       "Domain \'$reqDetails{$keycount}{identitydomain}\'" .
                       " \'$reqDetails{$keycount}{status}\'";

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
