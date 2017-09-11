package TAS;

use strict;
use warnings;
use Util;
use Logger;
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

sub runGSIBundle {

    my ($self, %params) = @_;

    my ($tasc_oracle_home, $tasc_oracle_sid, $cmd,
        $out, $filter, $status, $cmd2, $cmd3, $pillar);

 #   $tasc_oracle_home = $params{'tasc_oracle_home'};
 #   $tasc_oracle_sid = $params{'tasc_db_name'};

    $out = $self->{'remoteObj'}->copySrcToDest(
        host => $params{sdihost}, file => "$params{scriptdir}/*",
        username => $self->{user}, hostpasswd => $self->{passwd},
        hostname => $params{tasc_db_host}, destdir => $params{createscripts});

    $cmd = "#!/bin/bash

            if [[ ! -d $params{createscripts} ]]; then
                `mkdir -p $params{createscripts}`;
            fi";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1 " .
              "!~ /Warning\:/) print }'";

    ($status, $out) = $self->{'remoteObj'}->createAndRunScript(host => $params{tasc_db_host},
                                                               cmd => $cmd,
                                                               filter => $filter);

    if (grep(/error|no such|failed|fail/i, $out)) {
        return 1, "$out";
    }

    $cmd = "\"cd $params{createscripts}\;" .
           "ls gsi_bundle.sh complete_bundle.sql submit_bundle.sql\;\"";


    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{tasc_db_host},
                                                         cmd => "$cmd",
                                                         filter => $filter);

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    if ($params{enable_federation} eq 'NO') {
        $cmd2 = "sed -i -e \"s/PRODUCT_RELEASE_VERSION.*/PRODUCT_RELEASE_VERSION\x27," .
                "\x27$params{'faversion'}\x27\\\),tas.tas_key_value_t\\\(\x27TAGS\x27," .
                "\x27$params{'tag_name'}\x27\\\)\\\)\\\;/g\"";
    } else {
        $cmd2 = "sed -i -e \"s/PRODUCT_RELEASE_VERSION.*/PRODUCT_RELEASE_VERSION\x27," .
                "\x27$params{'faversion'}\x27\\\),tas.tas_key_value_t\\\(\x27TAGS\x27," .
                "\x27$params{'tag_name'}\x27\\\),tas.tas_key_value_t\\\(\x27OPERATION" .
                "AL_POLICY\x27,\x27ENTERPRISE\x27\\\),tas.tas_key_value_t" .
                "\\\(\x27IDM_FEDERATION\x27, \x27true\x27\\\)\\\)\\\;/g\"";
    }

    $cmd2 .= " -e \"s/email.*/email \\\=\\\> \x27$params{'email_id'}\x27,/g\"";

    my  $pillar_val =lc($params{'pillar'});

    if (exists $params{system_name} and
       $params{system_name}) {
        $cmd3 = "sed -i -e \"s/l_order_item.system_name.*" .
                "/l_order_item.system_name \:= \x27$params{system_name}\';/g\" " .
                "-e \"s/email.*/email => \x27$params{'email_id'}\x27);/g\"";
    } else {
        $cmd3 = "sed -i -e \"s/l_order_item.system_name \:= \x27fadrsdi.*\x27|" .
                "/l_order_item.system_name \:= \x27fadrsdi$pillar_val\'|/g\" " .
                "-e \"s/email.*/email => \x27$params{'email_id'}\x27);/g\"";
    }
    if (exists $params{system_admin_user_name} and
       $params{system_admin_user_name}) {
        $cmd3 .= " -e \"s/fadradmin/$params{system_admin_user_name}/g\"";
    }

    $cmd = "#!/bin/bash

            cd $params{createscripts};
            `$cmd2 submit_bundle.sql`;
            `$cmd3 complete_bundle.sql`";

    ($status, $out) = $self->{'remoteObj'}->createAndRunScript(host => $params{tasc_db_host},
                                                               cmd => $cmd,
                                                               filter => $filter);

    if (grep(/error|no such|failed|fail/i, $out)) {
        return 1, "$out";
    }

    my $org_id = int(rand(9999));
    while ($org_id < 1000) {
       $org_id = int(rand(9999));
    }
    my $order_id = int(rand(999));
    while ($order_id < 100) {
       $order_id = int(rand(999));
    }

    if ($params{pillar} eq 'GSI') {
        $pillar = 'ERP';
    } else {
        $pillar = $params{pillar};
    }

    if ($params{type} eq 'HA') {
        $cmd = "\"cd $params{createscripts}; gsi_bundle.sh " .
               "$org_id $order_id $pillar NONE " .
               "DEPLOY_TEST_INSTANCE_FALSE\"";
    } else {
        $cmd = "\"cd $params{createscripts}; gsi_bundle.sh " .
               "$org_id $order_id $pillar NONE " .
               "PROV_TEST_BEFORE_PROD\"";
    }
    $cmd =~ s/\r?\n//g;

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{tasc_db_host},
                                                         cmd => "$cmd",
                                                         filter => $filter);

    if (grep(/error|no such|failed|fail|Command not found|Name or service not known/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

sub runCoFapp {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    $cmd = "\"$params{tasctl} add_explicit_dr --subscription_id " .
           "$params{subscription_id}\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{tasc_host},
                                                         cmd => "$cmd",
                                                         filter => $filter);

    if (grep(/error|no such|failed|fail|Command not found|Name or service not known/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

sub runDoFapp {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    $cmd = "\"$params{tasctl} modify_subscription --subscription_id " .
           "$params{subscription_id} --terminate_passive\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{tasc_host},
                                                         cmd => "$cmd",
                                                         filter => $filter);

    if (grep(/error|no such|failed|fail|Command not found|Name or service not known/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

sub deleteOrder {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter);

    $cmd = "\"$params{tasctl} modify_subscription --subscription_id " .
           "$params{subscription_id} --terminate\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /root/ && \$1 " .
              "!~ /Warning\:/) print }'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{tasc_db_host},
                                                         cmd => "$cmd",
                                                         filter => $filter);

    if (grep(/error|no such|failed|fail|Command not found|Name or service not known/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

sub getOrderInfofromReqId {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter, %orderHash);

    my $sdi_req_id = $params{sdireqid};
    $sdi_req_id =~ s/#/\\#/g;

    $cmd = "\"$params{tasctl} " .
           "list_orders --no_wrap --no_stagger --sdi_request_id \\\"$sdi_req_id\\\"\"";

    $filter = "awk -F '|' '/$params{sdireqid}/ { if (\$1 !~ /spawn/ && " .
              "\$1 !~ /root/ && \$1 !~ /Warning\:/) print " .
              "\"external_order_id::\"\$1\",,item_id::\"\$2" .
              "\",,order_id::\"\$3\",,service_name::\"\$4" .
              "\",,service_type::\"\$5\",,system_name::\"\$6" .
              "\",,created_by::\"\$7\",,order_date::\"\$8" .
              "\",,completion_date::\"\$9\",,operation_type::\"\$10" .
              "\",,order_status::\"\$11\",,order_item_status::\"\$12" .
              "\",,last_err_msg::\"\$13\",,is_recoverable::\"\$14" .
              "\",,subscription_type::\"\$15\",,subscription_id::\"\$16" .
              "\",,sdi_request_id::\"\$17\",,service_configuration::\"\$18" .
              "\",,priority::\"\$19\",,associated_subscription_id::\"\$20" .
              "\",,associated_service_name::\"\$21" .
              "\",,associated_service_type::\"\$22" .
              "\",,customer::\"\$23\",,created_on::\"\$24" .
              "\",,activated::\"\$25\",,start_date::\"\$26" .
              "\",,end_date::\"\$27\",,account_admin_username::\"\$28" .
              "\",,data_center_id::\"\$29\",,om_order_number::\"\$30}'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{tasc_host},
                                                         cmd => "$cmd",
                                                         filter => $filter);

    if (grep(/error|no such|failed|fail|Name or service not known/i, @$out)) {
        return 1, "@$out";
    }

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
            $orderHash{$key} = $value;
        }
    }

    return 0, %orderHash;
}

1;
