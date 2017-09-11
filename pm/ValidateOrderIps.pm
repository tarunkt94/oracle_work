#
# ValidateOrderIps.pm
#
# Copyright (c) 2016, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      ValidateOrderIps.pm - <one-line expansion of the name>
#
#
package ValidateOrderIps;

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

use Logger;
use SDI;
use RemoteCmd;

sub new {

    my ($class, %args) = @_;

    my $self = {
        config => $args{config},
        importfile => $args{importfile},
    };

    bless($self, $class);

    $self->{'logObj'} = Logger->new(
        {'loggerLogFile' => "$self->{importfile}{'WORKDIR'}/validateparams.log",
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

    return $self;
}

sub validateDbs {

    my ($self, %params) = @_;

    if ($param =~ m/db_name|db_unique_name/i and
       $param !~ m/tas/i) {
        my $dblen = length($importfile{$param});
        if ($dblen <= 8) {
            print "$param - validated\n";
        } else {
            die ("$param has to be less than or equal to 8 chars\n");
        }
        $cmd = "\"$config{SDISCRIPT} listfadbs | grep $importfile{$param}\"";

        $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
                          "!~ /Warning\:/) print }'";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $self->{importfile}{SDI_HOST},
                                                             cmd => "$cmd",
                                                             filter => "$filter");

        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, "@$out";
        }

        if (@$out) {
            return 1, "@$out";
        }
        return 0, "@$out";

}

#
# Remove FADB from SDI host
# Input:
#     FA_DB_UNIQUE_NAME from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub removeFADB {

    my ($self) = @_;

    my ($status, $out);

    # Check removeFADB step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "removeFADB",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: removeFADB"]);

    if (exists $self->{importfile}{'FA_DB_UNIQUE_NAME'} and
       $self->{importfile}{'FA_DB_UNIQUE_NAME'}) {
        ($status, $out) = $self->{'sdiObj'}->removeDB(
            $self->{importfile}{'FA_DB_UNIQUE_NAME'},
        );
    } else {
        $status = 0;
        $out = "FA_DB_UNIQUE_NAME entry not exists\n";
    }

    createAndSendStatusFile(step => "removeFADB", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Remove OIDDB from SDI host
# Input:
#     IDM_DB_UNIQUE_NAME from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub removeOIDDB {

    my ($self) = @_;

    my ($status, $out);

    # Check removeOIDDB step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "removeOIDDB",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: removeOIDDB"]);

    if (exists $self->{importfile}{'IDM_DB_UNIQUE_NAME'} and
       $self->{importfile}{'IDM_DB_UNIQUE_NAME'}) {
        ($status, $out) = $self->{'sdiObj'}->removeDB(
            $self->{importfile}{'IDM_DB_UNIQUE_NAME'},
        );
    } else {
        $status = 0;
        $out = "IDM_DB_UNIQUE_NAME entry not exists\n";
    }

    createAndSendStatusFile(step => "removeOIDDB", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Remove OIMDB from SDI host
# Input:
#     OIM_DB_UNIQUE_NAME from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub removeOIMDB {

    my ($self) = @_;

    my ($status, $out);

    # Check removeOIMDB step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "removeOIMDB",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: removeOIMDB"]);

    if (exists $self->{importfile}{'OIM_DB_UNIQUE_NAME'} and
       $self->{importfile}{'OIM_DB_UNIQUE_NAME'}) {
        ($status, $out) = $self->{'sdiObj'}->removeDB(
            $self->{importfile}{'OIM_DB_UNIQUE_NAME'},
        );
    } else {
        $status = 0;
        $out = "OIM_DB_UNIQUE_NAME entry not exists\n";
    }

    createAndSendStatusFile(step => "removeOIMDB", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Remove OVS from SDI host
# Input:
#     OVS id from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub removeOVS {

    my ($self) = @_;

    my ($status, $out);

    # Check removeOVS step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "removeOVS",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: removeOVS"]);

    if (exists $self->{importfile}{'OVS_ID'} and
       $self->{importfile}{'OVS_ID'}) {
        ($status, $out) = $self->{'sdiObj'}->removeOVS(
            $self->{importfile}{'OVS_ID'},
        );
    } else {
        $status = 0;
        $out = "OVS entry not exists\n";
    }

    createAndSendStatusFile(step => "removeOVS", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

#
# Remove Rack from SDI host
# Input:
#     Rack Id from prop file
# add .suc(success) or .dif(failure) depending upon status
#
sub removeRack {

    my ($self) = @_;

    my ($status, $out);

    # Check removeRack step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(step => "removeRack",
                                workdir => $self->{importfile}{'WORKDIR'},
                                logObj => $self->{'logObj'}));

    $self->{'logObj'}->info(["Executing Step: removeRack"]);

    if (exists $self->{importfile}{'RACK_ID'} and
       $self->{importfile}{'RACK_ID'}) {
        ($status, $out) = $self->{'sdiObj'}->removeRack(
            $self->{importfile}{'RACK_ID'},
        );
    } else {
        $status = 0;
        $out = "Rack entry not exists\n";
    }
    createAndSendStatusFile(step => "removeRack", status => $status,
                            importfile => $self->{importfile},
                            logObj => $self->{'logObj'}, out => "$out");
}

1;
