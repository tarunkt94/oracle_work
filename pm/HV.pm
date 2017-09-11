package HV;

use strict;
use warnings;
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
# Add Seed and OVS running Pool
# Input:
#     hvs => hypervisors
#     pillar => service type
#     release_name => release name
#     stage_name => stage name
#     seedpool => seed pool path
#     runningpool => running pool path
#     sdiuser => sdi user
#     sdihost => sdi host name
# Return the status
#
sub addPools {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter, $status);
    my $relstage = "$params{pillar}_$params{release_name}_$params{stage_name}";
    my $tempdir = lc($relstage);
    my $hvhashfile = $params{hvhashfile};

    no strict;
    no warnings;
    open my $in, '<', "$hvhashfile" or die ("Cannot open $hvhashfile\n");
    my $data;
    {
        local $/;
        $data = eval <$in>;
    }
    close $in;
    my %hvhash = %$data;
    use strict;
    use warnings;

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/) print}'";

    for my $hv (keys %hvhash) {

        $cmd = "\"ls $params{seedpool}/${tempdir}/SystemImg.tar.gz\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $hv,
                                                             cmd => "$cmd",
                                                             filter => "$filter");

        if (join("", @$out) =~ m/No such/i) {

            ($status, $out) = $self->poolCreation(
                 release_name => $params{release_name}, hv => $hv,
                 stage_name => $params{stage_name}, pillar => $params{pillar},
                 seedpool_nfs_path => $params{seedpool_nfs_path}, prodtype => "fa",
                 sdiuser => $params{sdiuser}, sdipasswd => $params{sdipasswd},
                 sdihost => $params{sdihost}, seedpool => $params{seedpool});

            if ($status != 0) {
                return 1, "$out";
            }
        }

        $cmd = "\"ls $params{seedpool}/${tempdir}_bi/SystemImg.tar.gz\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $hv,
                                                             cmd => "$cmd",
                                                             filter => "$filter");

        if (join("", @$out) =~ m/No such/i) {

            ($status, $out) = $self->poolCreation(
                 release_name => $params{release_name}, hv => $hv,
                 stage_name => $params{stage_name}, pillar => $params{pillar},
                 seedpool_nfs_path => $params{seedpool_nfs_path}, prodtype => "bi",
                 sdiuser => $params{sdiuser}, sdipasswd => $params{sdipasswd},
                 sdihost => $params{sdihost}, seedpool => $params{seedpool});

            if ($status != 0) {
                return 1, "$out";
            }
        }
    }

    return 0, "$out";
}

sub poolCreation {

    my ($self, %params) = @_;

    my ($cmd, $out, $filter, $status);

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/ &&  \$1 !~ /ovmroot/ && \$1 !~ " .
              "/root/) print}'";

    my $pool = (split('/', $params{seedpool}))[1];

    if (! -d "/$pool") {
        $cmd = "\"mkdir -p /$pool\"";

        $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{hv},
                                                             cmd => $cmd,
                                                             filter => "$filter");

        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, "@$out";
        }
    }

    my $relstage = "$params{pillar}_$params{release_name}_$params{stage_name}";
    my $tempdir = lc($relstage);

    my $mountline = "$params{seedpool_nfs_path} /$pool";

    my $currentdate = `date +%m%d`;
    chomp($currentdate);

    my $cpfstab = "cp -rf /etc/fstab /etc/fstab_$params{prodtype}$currentdate";
    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{hv},
                                                         cmd => "$cpfstab",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    $cmd = "#!/bin/bash

            value=\$(grep -i \"$mountline\" /etc/fstab);
            if [ -z \"\$value\" ]; then
                echo \"$mountline\" >> /etc/fstab;
            fi";

    ($status, $out) = $self->{'remoteObj'}->createAndRunScript(host => $params{hv},
                                                               cmd => $cmd,
                                                               filter => "$filter");

    if (grep(/error|no such|failed|fail/i, $out)) {
        return 1, "$out";
    }

    my $mountcmd = "\"mount -a\"";
    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{hv},
                                                         cmd => "$mountcmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    my ($rsyncmd, $tarfile, $destdir);

    if ($params{prodtype} eq 'bi') {
        $cmd = "#!/bin/bash

                if [[ ! -d \"$params{seedpool}/${tempdir}_$params{prodtype}\" ]]; then
                    `mkdir -p $params{seedpool}/${tempdir}_$params{prodtype}`;
                fi";

        $tarfile = "/fa_template/$params{release_name}_$params{stage_name}" .
                   "/DedicatedIdm/paid/$params{pillar}/OVAB_HOME/vm/" .
                   "$params{prodtype}/SystemImg.tar.gz";

        $destdir = "$params{seedpool}/${tempdir}_$params{prodtype}";
    } else {
         $cmd = "#!/bin/bash

                 if [[ ! -d \"$params{seedpool}/${tempdir}\" ]]; then
                     `mkdir -p $params{seedpool}/${tempdir}`;
                 fi";

        $tarfile = "/fa_template/$params{release_name}_$params{stage_name}" .
                   "/DedicatedIdm/paid/$params{pillar}/OVAB_HOME/vm/" .
                   "SystemImg.tar.gz";

        $destdir = "$params{seedpool}/${tempdir}";
    }
    $tarfile =~ s/\r?\n//g;

    ($status, $out) = $self->{'remoteObj'}->createAndRunScript(host => $params{hv},
                                                               cmd => $cmd,
                                                               filter => "$filter");

    if (grep(/error|no such|failed|fail/i, $out)) {
        return 1, "$out";
    }

    my $remoteObj = RemoteCmd->new(user => $params{sdiuser},
                                   passwd => $params{sdipasswd},
                                   logObj => $self->{logObj});

    $out = $remoteObj->copySrcToDest(
        host => "$params{sdihost}", destdir => "$destdir",
        file => "$tarfile", hostname => $params{hv},
        username => $self->{user}, hostpasswd => $self->{passwd});

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    my $tarcmd = "\"cd \\\"$destdir\\\";tar -xvf SystemImg.tar.gz\"";
    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $params{hv},
                                                         cmd => "$tarcmd",
                                                         filter => "$filter");

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

sub getHVInfo {

    my ($self, $hv) = @_;

    my ($cmd, $out, $filter, %hvinfo);

    $cmd = "\"xm info\"";

    $filter = "awk '{ if (\$1 !~ /spawn/ && \$1 !~ /aime/ && \$1 " .
              "!~ /Warning\:/ &&  \$1 !~ /ovmroot/ && \$1 !~ " .
              "/root/) print}'";

    $out = $self->{'remoteObj'}->executeCommandsonRemote(host => $hv,
                                               cmd => "$cmd",
                                               filter => "$filter");

    my $output = join("", @$out);

    if (grep(/error|no such|failed|fail/i, $output)) {
        return 1, $output;
    }

    %hvinfo = map{ my ($key, $value) = split /\s+:\s+/; $key => $value } (split /\n/, $output);

    return 0, \%hvinfo;
}

1;
