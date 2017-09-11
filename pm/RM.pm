package RM;

use strict;
use warnings;
use Socket;
use Util;
use HV;
use FAConf;
use DoSystemCmd;
use Data::Dumper;

my $system = DoSystemCmd->new({filehandle => \*STDOUT});

### Constructor
sub new {

    my ($class, %args) = @_;

    my $self = {
        logObj => $args{logObj},
    };

    bless($self, $class);

    return $self;
}

#
# reserver Mem if VMs are available
# Input:
#     release_name => release name
#     pillar => service type
#     hypervisors => hypervisors
#     farm => farm name(DRQA/drqa)
#     tag_name => tag name
#     qafarmmanager => QA Farm manager .pl script
#     template_type => template type
#     type => nonha/ha
#     hvhashfile => empty hv hash file name
# Return the hypervisors hash and status
#
sub reserveMem {

    my ($self, %params) = @_;

    my (%vmdetails, %hvhash, @vms, $cmd, $out, $hv, $allocatedmem);
    my @vmsmem = ();

    my $avmem = 0;
    my $vmsallocated = 0;

    my $hvhashfile = $params{hvhashfile};
    my @hvs = split(',', $params{hypervisors});
    my %vmsinfo = %FAConf::vmsinfo;
    my $reqvms = $vmsinfo{$params{'type'}}{$params{'release_name'}}{$params{'pillar'}}{'vms'};
    my $reqmem = $vmsinfo{$params{'type'}}{$params{'release_name'}}{$params{'pillar'}}{'mem'};
    my $eachvmmem = int($reqmem/$reqvms);
    my $remmem = (${reqmem}%${reqvms});

    my ($status, $msg) = $self->checkGatewayForHVs(@hvs);
    if ($status == 1) {
        return 1, "$msg";
    }

    my %hvdetails = %$msg;

    for $hv (keys %hvdetails) {

        # if required vms are equal to available vms break the loop
        if (($reqvms - $vmsallocated) == 0) {
            last;
        }

        # get available vms for each hypervisors against farm
        $cmd = "perl $params{qafarmmanager} -o listvm -farm $params{farm} " .
               "| sort -k 4 -n -r | awk '/$hvdetails{$hv}{gateway}/ " .
               "{if (\$7 ~ /AVAILABLE/) print \$1\",\"\$2}' | head -$reqvms";

        $out = $system->do_cmd_get_output($cmd);
        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, @$out;
        }

        # store vms with ips in vmdetails hash
        for my $vminfo (@$out) {
            if ($vminfo !~ m/^sh:/i) {
                my ($host, $ipaddr) = split(/,/, $vminfo);
                $vmdetails{$vmsallocated} = "$host:$ipaddr";
                $vmsallocated += 1;
            }
        }
    }

    # if required vms != available vms then error message
    if (($reqvms - $vmsallocated) != 0) {
        $msg = "VMs free are not enough\n";
        $self->{'logObj'}->error([$msg]);
        return 1, $msg;
    }

    # get available memory for all hypervisors
    for $hv (@hvs) {
        $avmem += $self->getAvailableMemory(hv => $hv,
                                            farm => $params{farm},
                                            qafarmmanager =>
                                                $params{qafarmmanager});
    }

    # if required mem is greater than available memory then error message
    if ($avmem < $reqmem) {
        $msg = "Memory size is not enough\n";
        $self->{'logObj'}->error([$msg]);
        return 1, $msg;
    }

    # create array of memory size for each vm
    for (my $i=0; $i<$reqvms; $i++){
        if ($i == $reqvms -1) {
            my $leftmem = $eachvmmem + $remmem;
            push (@vmsmem, $leftmem);
        } else {
            push (@vmsmem, $eachvmmem);
        }
    }

    my $i = 0;
    foreach $hv(@hvs) {
        my @resvms = ();
        while(defined($allocatedmem = shift(@vmsmem))) {
            my ($vm, $ipaddr) = split(/:/, $vmdetails{$i});
            chomp($ipaddr);
            push (@resvms, "$ipaddr");
            my $hasMem = $self->hasMem(hv => $hv, farm => $params{farm},
                                       allocatemem => $allocatedmem,
                                       qafarmmanager => $params{qafarmmanager});

            if (!$hasMem) {
                push (@vmsmem, $allocatedmem);
                last;
            }

            my ($status, $out)  = $self->allocateVM(hv => $hv, vm => $vm,
                                      farm => $params{farm},
                                      allocatemem => $allocatedmem,
                                      qafarmmanager => $params{qafarmmanager},
                                      dteid => $params{tag_name},
                                      template_type => $params{template_type});
            push (@vms, $vm);
            # if allocate vm fails in between due
            # to some reasons then release all allocated vms
            return $self->releaseVMs(vms => \@vms,
                                     qafarmmanager =>
                                         $params{qafarmmanager}) if ($status == 1);
            $i += 1;
        }
        $hvhash{$hv}{'netmask'} = $hvdetails{$hv}{netmask};
        $hvhash{$hv}{'gateway'} = $hvdetails{$hv}{gateway};
        $hvhash{$hv}{'ipaddr'} = \@resvms;
    }

    writeHashtoFile(file => $hvhashfile,
                    hash => \%hvhash);

    return 0, $out;
}

sub releaseVMs {

    my ($self, %params) = @_;

    my ($cmd, $out);

    for my $vm (@{$params{vms}}) {
        $cmd = "perl $params{qafarmmanager} -o release -host_name $vm";

        $out = $system->do_cmd_get_output($cmd);
        if (grep(/error|no such|failed|fail/i, @$out)) {
            return 1, @$out;
        }
    }
    return 1, @$out;
}

sub allocateVM {

    my ($self, %params) = @_;

    my ($cmd, $out);

    $cmd = "perl $params{qafarmmanager} -o request_adv -mem " .
           "$params{allocatemem} -cpu 4 -temp_type $params{template_type} " .
           "-hypervisor $params{hv} --create_vm false " .
           "-farm $params{farm} -host_name $params{vm} -dteid $params{dteid}";

   $out = `$cmd`;
   if (grep(/is registered on/i, $out)) {
       return 0, $out;
   }

   return 1, $out;
}

sub hasMem {

    my ($self, %params) = @_;

    my ($cmd, $out, $avmem);
    $avmem = $self->getAvailableMemory(hv => $params{hv},
                                       farm => $params{farm},
                                       qafarmmanager => $params{qafarmmanager});
    return 0 if $avmem < $params{allocatemem};
    return 1;
}

sub getAvailableMemory {

    my ($self, %params) = @_;

    my ($cmd, $out);

    $cmd = "perl $params{qafarmmanager} -o listhv -farm $params{farm} " .
           "| awk '/$params{hv}/ {print \$2}'";

    $out = $system->do_cmd_get_output($cmd);

    if (grep(/error|no such|failed|fail/i, @$out)) {
        return 1;
    }

    for my $avmem (@$out) {
        if ($avmem !~ m/^sh:/i) {
            return $avmem;
        }
    }

    return 0;
}

#
# reserver Mem for NONQA Farm if VMs are available
# Input:
#     release_name => release name
#     pillar => service type
#     hypervisors => hypervisors
#     type => type name(nonha/ha)
#     hvhashfile => empty hv hash file name
#     hvuser => hv user name
#     hvpasswd => hv passwd
# Return the hypervisors hash and status
#
sub reserveMemNonQAFarm {

    my ($self, %params) = @_;

    my (%vmdetails, %hvhash, $hv, $backretval);

    my $avmem = 0;
    my $vmsallocated = 0;

    my $hvhashfile = $params{hvhashfile};
    my @hvs = split(',', $params{hypervisors});
    my %vmsinfo = %FAConf::vmsinfo;
    my $reqvms = $vmsinfo{$params{'type'}}{$params{'release_name'}}{$params{'pillar'}}{'vms'};
    my $reqmem = $vmsinfo{$params{'type'}}{$params{'release_name'}}{$params{'pillar'}}{'mem'};
    my $eachvmmem = int($reqmem/$reqvms);
    my $remmem = (${reqmem}%${reqvms});

    my ($status, $msg) = $self->checkGatewayForHVs(@hvs);
    if ($status == 1) {
        return 1, "$msg";
    }

    my %hvdetails = %$msg;

    open ( FILE, "$params{vms_data_file}" ) || die "can't open file!";
    my @lines = <FILE>;
    close (FILE);
    for $hv (keys %hvdetails) {
        for my $line(@lines) {
             # if required vms are equal to available vms break the loop
             if (($reqvms - $vmsallocated) == 0) {
                 last;
             }

             if ($line =~ m/$hv/i) {
                 chomp($line);
                 my ($hvnew, $vm) = (split /:/, $line)[0, 1];
                 chomp($vm);
                 my $ipaddr = inet_ntoa(scalar(gethostbyname($vm)));
                 $self->{'logObj'}->info(["Pinging frontend vm: $vm, ip_address: $ipaddr"]);
                 my $retval = system("ping -c 1 $ipaddr");
                 my $backvm = (split /:/, $line)[2];
                 if ($backvm) {
                     chomp($backvm);
                     my $backipaddr = inet_ntoa(scalar(gethostbyname($backvm)));
                     $self->{'logObj'}->info(["Pinging backend vm: $backvm, ip_address: $backipaddr"]);
                     $backretval = system("ping -c 1 $backipaddr");
                     if ($retval != 0 and $backretval != 0) {
                         push @{$vmdetails{$hv}}, "$vm:$ipaddr:$backipaddr";
                         $vmsallocated += 1;
                     }
                 } else {
                     if ($retval != 0) {
                         push @{$vmdetails{$hv}}, "$vm:$ipaddr";
                         $vmsallocated += 1;
                     }
                 }
             }
         }
     }

     # if required vms != available vms then error message
     if (($reqvms - $vmsallocated) != 0) {
         $msg = "VMs free are not enough\n";
         $self->{'logObj'}->error([$msg]);
         return 1, $msg;
     }

     my $hvObj = HV->new(user => $params{hvuser},
                         passwd => $params{hvpasswd},
                         logObj => $self->{'logObj'});

     # get available memory for all hypervisors
     for $hv (@hvs) {
         my ($status, $msg) = $hvObj->getHVInfo($hv);
         if ($status == 1) {
             return 1, $msg;
         }

         my %hvinfo = %$msg;
         if (exists $hvinfo{free_memory}) {
             $avmem += $hvinfo{free_memory};
         }
     }

    # if required mem is greater than available memory then error message
    if ($avmem < $reqmem) {
        $msg = "Memory size is not enough\n";
        $self->{'logObj'}->error([$msg]);
        return 1, $msg;
    }

    for my $hv (keys %vmdetails) {
        my @resvms = ();
        my @resbackvms = ();
        for my $vmdetail(@{$vmdetails{$hv}}) {
            my ($vm, $ipaddr, $backipaddr) = split(/:/, $vmdetail);

            chomp($ipaddr);
            push (@resvms, "$ipaddr");
            if ($backipaddr) {
                chomp($backipaddr);
                push (@resbackvms, "$backipaddr");
            }
        }
        $hvhash{$hv}{'netmask'} = $hvdetails{$hv}{netmask};
        $hvhash{$hv}{'gateway'} = $hvdetails{$hv}{gateway};
        $hvhash{$hv}{'ipaddr'} = \@resvms;
        if (@resbackvms) {
            $hvhash{$hv}{'backipaddr'} = \@resbackvms;
        }
    }

    writeHashtoFile(file => $hvhashfile,
                    hash => \%hvhash);

    return 0, "Successful";

}

sub checkGatewayForHVs {

    my ($self, @hvs) = @_;

    my (%hwdetails, %gateways, %hvdetails);
    my $msg = "Hypervisors gateways are same";

    # get hardware details for each hypervisors(netmask, gateway...)
    for my $hv (@hvs) {
        %hwdetails = getHardwareInfo($hv);

        if (exists $hwdetails{'error_msg'}) {
            $self->{'logObj'}->error([$hwdetails{'error_msg'}]);
            return 1, $hwdetails{'error_msg'};
        }

        for my $key (keys %hwdetails) {
            $hvdetails{$hv}{$key} = $hwdetails{$key};
            if ($key eq 'gateway') {
                $gateways{$hwdetails{$key}} = undef;
            }
        }
    }

    # check gateway is same for all hypervisors
    my $noofgateways = scalar keys %gateways;
    if ($noofgateways != 1) {
        $msg = "Hypervisors gateways are not same\n";
        $self->{'logObj'}->error([$msg]);
        return 1, $msg;
    }

    return 0, \%hvdetails;
}

1;
