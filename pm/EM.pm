package EM;

use strict;
use warnings;
use File::Basename;
use RemoteCmd;

### Constructor
sub new {
    my ($class, %args) = @_;

    my $self = {
        user => $args{user},
        passwd => $args{passwd},
        logObj => $args{logObj},
    };

    bless($self, $class);

    $self->{'remoteObj'} = RemoteCmd->new(user => $self->{user},
                                          passwd => $self->{passwd},
                                          logObj => $self->{logObj});

    return $self;
}

#
# Add EM agent
# Input:
#     dbnodes => database node hosts
#     agentcore => Agent core zip
#     em_upload_port => em upload port
#     agent_port => agent port
# Return the status
#
sub addEMAgent {

     my ($self, %params) = @_;

     my ($cmd, $out, $filter, $node, $sedcmd, $status);
     my $emagentdir = "/home/emcadm/emagent";
     my $agentfile = "$params{agentcore}";
     my $agentzip = basename("$params{agentcore}");
     my $fa_template = "$params{fa_template}/$params{release_name}_" .
                       "$params{stage_name}/DedicatedIdm/paid/$params{pillar}";
    my $faovmpatch = "$fa_template/faovm/patchfiles";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1 " .
              "!~ /Warning\:/ && \$1 !~ /Invalid conversion/) print }'";

    $cmd = "\"ls $faovmpatch/$agentzip\"";

    my $remoteObj = RemoteCmd->new(user => $params{sdiuser},
                                   passwd => $params{sdipasswd},
                                   logObj => $self->{logObj});

    $out = $remoteObj->executeCommandsonRemote(host => $params{sdihost},
                                               cmd => "$cmd",
                                               filter => "$filter");

    if (join("", @$out) =~ m/No such/i) {

        $cmd = "\"cp -f $agentfile $faovmpatch\"";


        $out = $remoteObj->executeCommandsonRemote(host => $params{sdihost},
                                                   cmd => "$cmd",
                                                   filter => "$filter");

        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, "@$out";
        }
    }

    my @dbnodes = @{$params{dbnodes}};

    for (my $i=0; $i<=$#dbnodes; $i++) {
        $node = $i+1;

        $cmd = "\"/usr/sbin/useradd -g oinstall " .
               "$params{emuser} -p $params{empasswd}\;\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                             cmd => "$cmd",
                                                             filter => "$filter");

        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, "@$out";
        }

        $cmd = "\"mkdir -p $emagentdir\;" .
               "chmod -R 777 /home/emcadm\;" .
               "chown -R $params{emuser}:oinstall $emagentdir\;\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                             cmd => "$cmd",
                                                             filter => "$filter");

        if (grep(/error|no such|failed|fail|not a directory/i, @$out)) {
            return 1, "@$out";
        }

        $cmd = "\"ls $emagentdir/$agentzip\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                             cmd => "$cmd",
                                                             filter => "$filter");

        if (join("", @$out) =~ m/No such/i) {

            $out = $remoteObj->copySrcToDest(host => $params{sdihost},
                                             file => "$agentfile",
                                             username => $self->{user},
                                             hostpasswd => $self->{passwd},
                                             hostname => $dbnodes[$i],
                                             destdir => $emagentdir);

            if (grep(/error|no such|failed|fail/i, @$out)) {
                return 1, "@$out";
            }
        }

        $cmd = "\"ls $emagentdir/agent.rsp\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                              cmd => "$cmd",
                                                              filter => "$filter");

        if (join("", @$out) =~ m/No such/i) {
            $cmd = "\"cd $emagentdir;unzip -oq $agentzip;\"";

            $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                                 cmd => "$cmd",
                                                                 filter => "$filter");

            if (grep(/error|no such/i, $out)) {
                return 1, "@$out";
            }

            $cmd = "\"cd $emagentdir;cp agent.rsp agent_bak.rsp;\"";

            $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                                 cmd => "$cmd",
                                                                 filter => "$filter");

            if (grep(/error|no such|failed|fail/i, $out)) {
                return 1, "@$out";
            }

            $sedcmd = "\"cd $emagentdir; printf \\\"%s\\n\\\" 'OMS_HOST=$params{oms_host_name}' 'EM_UPLOAD_PORT=$params{em_upload_port}' 'AGENT_INSTANCE_HOME=$emagentdir/basedir/agent_inst' 'AGENT_PORT=$params{agent_port}' 'ORACLE_HOSTNAME=$dbnodes[$i]' 'AGENT_REGISTRATION_PASSWORD=$params{empasswd}' >> agent.rsp\"";

            $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                                 cmd => "$sedcmd",
                                                                 filter => "$filter");

            if (grep(/error|no such|failed|fail/i, $out)) {
                return 1, "@$out";
            }
        }

        $cmd = "\"ls $emagentdir/basedir\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                              cmd => "$cmd",
                                                              filter => "$filter");

        if (join("", @$out) =~ m/No such/i) {
            $cmd = "\"su $params{emuser} " .
                   "$emagentdir/agentDeploy.sh " .
                   "AGENT_BASE_DIR=$emagentdir/basedir " .
                   "RESPONSE_FILE=$emagentdir/agent.rsp\"";

            $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                                 cmd => "$cmd",
                                                                 filter => $filter);

            if (grep(/error|no such|failed|fail/i, @$out)) {
                return 1, "@$out";
            }
        }

        $cmd = "\"ls $emagentdir/basedir/core\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                              cmd => "$cmd",
                                                              filter => "$filter");

        if (join("", @$out) =~ m/No such/i) {
            return 1, "@$out";
        } else {

            $cmd = "\"cd $emagentdir;$emagentdir/runRoot.sh AGENT_BASE_DIR=$emagentdir/basedir\"";

            $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                                 cmd => "$cmd",
                                                                 filter => $filter);

            if (grep(/error|no such|failed|fail/i, @$out)) {
                return 1, "@$out";
            }
        }
    }

    return 0, "@$out";
}

#
# check EM agent Status
# Input:
#     dbnodes => database node hosts
# Return the status
#
sub checkEMAgentStatus {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    my @dbnodes = @{$params{dbnodes}};

    for (my $i=0; $i<=$#dbnodes; $i++) {

        $cmd = "\"su $params{emuser} " .
               "/home/emcadm/emagent/basedir/agent_inst/bin/emctl " .
               "status agent\"";

        $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1" .
                  " !~ /Warning\:/ && \$1 !~ /Invalid conversion/) print }'";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                             cmd => "$cmd",
                                                             filter => $filter);
        if ((grep(/error|no such|failed|fail/i, @$out) or
            !grep(/Agent is Running and Ready/i, @$out))) {
           return 1, "@$out";
        }
    }

    return 0, "@$out";

}

1;
