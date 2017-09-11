package FADBUtil;

use strict;
use warnings;

BEGIN
{
    use File::Basename;
    use Cwd;
    my $orignalDir = getcwd();
    my $scriptDir = dirname($0);
    chdir($scriptDir);
    $scriptDir = getcwd();
    # add $scriptDir into INC
    unshift (@INC, "$scriptDir/..");
    chdir($orignalDir);
}

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
# check db status
# Input:
#     fa_db_name => fa database name
#     oid_db_name => oid database name
#     oim_db_name => idm database name
# Return the status
#
sub checkDBStatus {

     my ($self, %params) = @_;

     my ($node, $cmd, $out, $filter, $status);
     my $fadb = $params{fa_db_name};
     my $oiddb = $params{oid_db_name};
     my $oimdb = $params{oim_db_name};
     my $fadbuniquename = $params{fa_db_unique_name};
     my $oiddbuniquename = $params{oid_db_unique_name};
     my $oimdbuniquename = $params{oim_db_unique_name};

     my @dbnodes = @{$params{dbnodes}};

     $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1 " .
               "!~ /Warning\:/) print }'";

     for (my $i=0; $i<=$#dbnodes; $i++) {
         $node = $i+1;

         $cmd = "#!/bin/bash

                 if  ! ps -ef | grep pmon |grep -i ASM$node; then
                     echo \"DB ASM$node is not up\";
                     exit 1;
                 fi
                 if  ! ps -ef | grep pmon | grep -i ${fadb}$node; then
                     echo \"DB ${fadb}$node is not up\";
                     exit 1;
                 fi
                 if  ! ps -ef | grep pmon |grep -i ${oiddb}$node; then
                     echo \"DB ${oiddb}$node is not up\";
                     exit 1;
                 fi
                 if  ! ps -ef | grep pmon | grep -i ${oimdb}$node; then
                     echo \"DB ${oimdb}$node is not up\";
                     exit 1;
                 fi
                 if  ! ps -ef | grep tnsl | grep -i $fadbuniquename; then
                     echo \"LISTENER $fadbuniquename is not up and running\";
                     exit 1;
                 fi
                 if  ! ps -ef | grep tnsl |grep -i $oiddbuniquename; then
                     echo \"LISTENER $oiddbuniquename is not up and running\";
                     exit 1;
                 fi
                 if  ! ps -ef | grep tnsl | grep -i $oimdbuniquename; then
                     echo \"LISTENER $oimdbuniquename is not up and running\";
                     exit 1;
                 fi";

         ($status, $out) = $self->{'remoteObj'}->createAndRunScript(host => $dbnodes[$i],
                                                                    cmd => "$cmd",
                                                                    filter => "$filter");

         if (grep(/error|no such|failed|fail|is not up/i, $out)) {
            return 1, "$out";
         }

     }

     return 0, "$out";
}

#
# Mount FSN Admin directory on db node 1
# Input:
#     db_node1 => database node 1
#     scriptdir => script dir path
#     fsnadmin_nfs_path => fsnadmin nfs path
# Return the status
#
sub mountFSNAdminDir {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    $out = $self->{'remoteObj'}->copyFileToHost(
        host => "$params{db_node1}", dest => "/tmp",
        file => "$params{scriptdir}/mountFSNAdminDir.pl");

    $cmd = "perl /tmp/mountFSNAdminDir.pl -fsnadmin_nfs_path " .
           "$params{fsnadmin_nfs_path}";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => "$params{db_node1}",
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    my $rm_cmd = "rm -rf /tmp/mountFSNAdminDir.pl";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{db_node1},
                                                         cmd => "$rm_cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

#
# Create custom directories in DB node1 host
# Input:
#     db_version => db version
#     fa_db_name => FA database name
#     oid_db_name => oid database name
#     oim_db_name => oim database name
#     db_node1 => db node1 name
# Return the status
#
sub createCustomDirs {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter, $db_dir, $admin_dir, $node);

    my $dir = "/u01/app/oracle/admin";
    if ($params{db_version} =~/12.1.0.2/) {
        $db_dir="/u05/dbadir";
        $admin_dir="/u02/app/oracle/admin/12.1.0.2/rdbms";
    } elsif ($params{db_version} =~/11.2.0.4/) {
        $db_dir="/u05/dbadir";
        $admin_dir="/u02/app/oracle/admin/11.2.0.4/rdbms";
    } elsif($params{db_version} =~/11.2.0.3/) {
        $db_dir="/u05/dbadir";
        $admin_dir="/u02/app/oracle/admin/11.2.0.3/rdbms";
    }

    $cmd = "\"mkdir -p $admin_dir/$params{fa_db_name}/admin;" .
           "mkdir -p $admin_dir/$params{fa_db_name}/search/webapp/config;" .
           "mkdir -p $admin_dir/$params{fa_db_name}/xml;" .
           "mkdir -p $admin_dir/$params{fa_db_name}/search/data/language;" .
           "mkdir -p $admin_dir/$params{fa_db_name}/ccr/state;" .
           "mkdir -p $admin_dir/$params{fa_db_name}/admin/dpdump;" .
           "mkdir -p $admin_dir/$params{fa_db_name}/cache;" .
           "mkdir -p $admin_dir/$params{oid_db_name}/demo/schema/" .
           "sales_history;".
           "mkdir -p $admin_dir/$params{oid_db_name}/admin/" .
           "$params{oid_db_name}/dpdump;" .
           "mkdir -p $admin_dir/$params{oid_db_name}/demo/schema/log;" .
           "mkdir -p $admin_dir/$params{oid_db_name}/demo/schema/product_media;" .
           "mkdir -p $admin_dir/$params{oid_db_name}/ccr/state;" .
           "mkdir -p $admin_dir/$params{oid_db_name}/demo/schema/order_entry;" .
           "mkdir -p $admin_dir/$params{oid_db_name}/demo/schema/order_entry" .
           "/2002/Sep;" .
           "mkdir -p $admin_dir/$params{oid_db_name}/rdbms/xml;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/demo/schema/sales_history;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/admin/" .
           "$params{oim_db_name}/dpdump;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/demo/schema/log;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/demo/schema/product_media;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/ccr/state;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/demo/schema/order_entry;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/demo/schema/order_entry" .
           "/2002/Sep;" .
           "mkdir -p $admin_dir/$params{oim_db_name}/rdbms/xml;" .
           "mkdir -p $db_dir/$params{fa_db_name}/incident_logs;" .
           "mkdir -p $db_dir/$params{fa_db_name}/appllog_dir;" .
           "chown -R oracle:oinstall /u02;" .
           "chown -R oracle:oinstall /u05;\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{db_node1},
                                                         cmd => "$cmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail|permission denied/i, @$out)) {
        return 1, "@$out";
    }

    if (lc($params{is_standby}) eq 'true') {

        my @dbnodes = @{$params{dbnodes}};

        for (my $i=0; $i<=$#dbnodes; $i++) {
            $node = $i+1;

            $cmd = "\"mkdir -p $dir/$params{fa_db_unique_name}/temp;" .
                   "mkdir -p $dir/$params{fa_db_unique_name}/adump;" .
                   "mkdir -p $dir/$params{oim_db_unique_name}/temp;" .
                   "mkdir -p $dir/$params{oim_db_unique_name}/adump;" .
                   "mkdir -p $dir/$params{oid_db_unique_name}/temp;" .
                   "mkdir -p $dir/$params{oid_db_unique_name}/adump;" .
                   "chown -R oracle:oinstall /u01;\"";

            $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $dbnodes[$i],
                                                                 cmd => "$cmd",
                                                                 filter => "$filter");

            if (grep(/error|no such|failed|fail|permission denied/i, @$out)) {
                return 1, "@$out";
            }
        }
    }

    return 0, "@$out";
}

1;
