# 
# $Header: dte/DTE/scripts/fusionapps/cli/pm/HardwareNetworkInfo.pm /main/1 2015/12/21 02:15:22 ljonnala Exp $
#
# HardwareNetworkInfo.pm
# 
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      HardwareNetworkInfo.pm - Hardware Network Info package
#
#    MODIFIED   (12/21/15)
#    ljonnala    12/21/15 - Add Hardware Network info file
#    ljonnala    12/21/15 - Creation
#

package HardwareNetworkInfo;

use DoSystemCmd;
use Socket qw(AF_INET);
use POSIX qw(floor);


#
# Given a Machine name or IP address this API returns the following data in
# a hash
#  ip         => a scalar for single IP address and
#                an array reference for multiple IP addresses
#  is_scan_ip => 1 for multiple IP addresses and 0 for single IP address
#  name       => Name of the machine
#  fqdn       => Fully Qualified Domain Name
#  subnet     => Subnet the machine belongs to.
#  netmask    => subnet mask used to generate the subnet.
#  network    => Network the machine belongs to.
#  gateway    => IP address of the gateway in the subnet.
#  broadcast  => IP address used to broadcast in the subnet
#  location   => Physical location where the machine is located.
#
# [ NOTE : This API will work for all those machines whose subnet mask lenght
#   is > 16. Bug : 9241587 will fix this issue ]
#
#
sub get_hw_location_details
{
    my (%options) = @_;
    my %result;

    my $system = $options{system} ||
                          DoSystemCmd->new({timeout => 300,
                                            filehandle => $options{filehandle},
                                            no_error_output => 1});

    #
    # Input is either the hardware name or IP Address
    #
    my $hw_ip_addr = ($options{hw_ip_addr}) ? [$options{hw_ip_addr}] : undef;

    unless ($hw_ip_addr)
    {
        $result{name} = $options{hw_name} || undef;

        unless($result{name})
        {
            $result{error_msg} = "Either the hardware name or IP address " .
                             "should be given as input";
            return \%result;
        }

        _get_all_ip_addresses(\%result);
    }
    else
    {
        $result{name} = gethostbyaddr(Socket::inet_aton($hw_ip_addr->[0]),
                                      Socket::AF_INET);

        _get_all_ip_addresses(\%result);
    }


    #
    # Get an IP address to retrieve other details of the host
    #
    my $ip_address;
    $ip_address =
        (ref($result{ip}) eq "ARRAY") ?  $result{ip}->[0] :  $result{ip}
            if (defined $result{ip});

    my $network_details_fh = undef;
    $network_details_fh = $options{network_details_fh}
                                  if ($options{network_details_fh});
    #
    # Get subnet details
    #
    if (defined $ip_address and $ip_address =~ /(\d+\.\d+\.\d+)\.\d+/)
    {
        my $cmd = "ypcat -k networks | grep \^";
        my $ip_addrs_24bits = $1;
        my $network_det = undef;
        my $retry_count;
        for (my $count=0; $count < 255; $count++)
        {

           if ($network_details_fh)
           {
               my $pattern = $ip_addrs_24bits .'\.';
               seek($network_details_fh, 0, 0);
               my @lines = grep /^$pattern/,
                                   <$network_details_fh>;
               chomp(@lines);
               $network_det = \@lines if (@lines);
           }
           else
           {
                #
                #  Adding retry for cases where ypcat -k networks
                # command times out. We don't want it to skip the
                # correct subnet just because command hung(it hangs
                # quite a lot of times)
                #
                $retry_count = 3;
                while ($retry_count--)
                {
                   eval
                   {
                       local $SIG{__DIE__} = 'IGNORE';
                       $network_det = $system->do_cmd_get_output(
                                             $cmd . $ip_addrs_24bits . "\\\\."
                                                             );
                   };
                   if ($@ && $@ =~ /timed out/i)
                   {
                      sleep(1);
                   }
                   else
                   {
                       last;
                   }
               }
           }

           if ($network_det)
           {
               last;
           }
           else
           {
                #
                # We have not got the location details yet. So we will search
                #  in the next range.
                #
                my @ip_addrs_24bits = split(/\./, $ip_addrs_24bits);
                my $third_octet = $ip_addrs_24bits[2]-1;

                #
                # Exit if third octet becomes -ve
                #
                last if ($third_octet < 0);
                $ip_addrs_24bits = $ip_addrs_24bits[0] . "." .
                            $ip_addrs_24bits[1] . "." . $third_octet ;
            }
        }


        #
        # If details are found, we'll split the data.
        #
        if ($network_det)
        {
            if (scalar(@$network_det) == 1)
            {
                my @network_data = split(' ', $network_det->[0]);
                $result{subnet} = $network_data[0];
                $result{location} = $network_data[1];

                if ($result{subnet} =~ /(\d+\.\d+\.\d+\.\d+)\/(\d+)/)
                {
                    #
                    # Generate netmask
                    #
                    my $subnet_mask_length = $2;
                    $result{netmask} =
                            _generate_subnet_mask($subnet_mask_length);

                    #
                    # Generate network, gateway and broadcast
                    #
                    my @subnet = split(/\./, $1);
                    $result{network} = join(".", @subnet);
                    $subnet[3] = int($subnet[3]) | 1;
                    if ($subnet[3] == 0)
                    {
                        $subnet[2] = int($subnet[2]) | 1;
                    }
                    $result{gateway} = join(".", @subnet);

                    $result{broadcast} =
                            _generate_broadcast_addr($subnet_mask_length,
                                                     \@subnet);
                }
            }
            else
            {
                my $subnet_count = scalar(@$network_det);
                for (my $count=0; $count < $subnet_count; $count++)
                {
                    my @network_data = split(' ', $network_det->[$count]);
                    my $subnet = $network_data[0];
                    if ($subnet =~ /(\d+\.\d+\.\d+\.\d+)\/(\d+)/)
                    {
                        my $subnet_mask_length = $2;
                        my $subnet_mask =
                            _generate_subnet_mask($subnet_mask_length);

                        my @subnet_mask_octets = split(/\./,$subnet_mask);
                        my @ip_octets = split(/\./, $ip_address);

                        #
                        # Generate the subnet now.
                        #
                        my @subnet = undef;
                        $subnet[0] =
                            int($subnet_mask_octets[0]) & int($ip_octets[0]);
                        $subnet[1] =
                            int($subnet_mask_octets[1]) & int($ip_octets[1]);
                        $subnet[2] =
                            int($subnet_mask_octets[2]) & int($ip_octets[2]);
                        $subnet[3] =
                            int($subnet_mask_octets[3]) & int($ip_octets[3]);

                        my $calc_subnet = join(".", @subnet) . "/" .
                                             $subnet_mask_length ;

                        if ($subnet eq $calc_subnet)
                        {
                            $result{subnet} = $subnet;
                            $result{location} = $network_data[1];

                            #
                            # Generate netmask, network, gateway and broadcast
                            #
                            $result{network} = join(".", @subnet);
                            my $machine_octets = floor($subnet_mask_length/8);

                            $subnet[$machine_octets]++;
                            $result{gateway} = join(".", @subnet);
                            $result{netmask} = $subnet_mask;

                            $result{broadcast} =
                            _generate_broadcast_addr($subnet_mask_length,
                                                     \@subnet);
                            last;
                        }
                    }
                }
            }
        }
        else
        {
            $result{error_msg} = "ypcat failed to fetch network information" .
                              " for $options{hw_name}";
        }
    }
    else
    {
        $result{error_msg} = "IP address for $options{hw_name} could not be" .
                                    " fetched";
    }

    return \%result;
}

#
# Retrieve all IPs of a host and also determine if it is a scan ip
#
sub _get_all_ip_addresses
{
    my ($result) = @_;

    #
    # Fetch the IP address based on the hardware name
    #
    my ($name, $aliases, $addr_type, $length, @address) =
        gethostbyname($result->{name});

    #
    # Get ip(s) and is_scan_ip if gethostbyname returns a value
    #
    if ($name)
    {
        $result->{fqdn} = $name;

        my $ip_cnt = @address;
        if ($ip_cnt > 1)
        {
            foreach my $address(@address)
            {
                push(@{$result->{ip}}, Socket::inet_ntoa($address));
            }
            $result->{is_scan_ip} = 1;
        }
        else
        {
            $result->{ip} = Socket::inet_ntoa(@address);
            $result->{is_scan_ip} = 0;
        }
    }
}

#
# Given a subnet, generate broadcast ip addrs in the subnet.
#
sub _generate_broadcast_addr
{
    my ($subnet_mask_length, $subnet) = @_;
    my $num_of_octets = 0;
    my $broadcast;

    my $num_of_subnet_octets = floor($subnet_mask_length / 8);
    for (my $count=0; $count < $num_of_subnet_octets; $count++)
    {
        $broadcast .= $subnet->[$count] . ".";
        $num_of_octets++;
    }

    my $num_of_0s_in_octet = $subnet_mask_length % 8;
    my $octet = undef;
    for (my $count=0; $count < 8; $count++)
    {
        if ($num_of_0s_in_octet-- > 0)
        {
            $octet .= "0";
        }
        else
        {
            $octet .= "1";
        }
    }
    $octet = bin2dec($octet);
    my $octet_elem = int($octet) | int($subnet->[$num_of_octets]);
    $broadcast .= $octet_elem;
    $num_of_octets++;

    #
    # If there are any more octets remaining, fill them 1s.
    #
    while($num_of_octets++ < 4)
    {
        $broadcast .= ".255" ;
    }

    return $broadcast;
}

#
# Given a subnet mask lenght, generate the subnet mask address.
#
sub _generate_subnet_mask
{
    my ($subnet_mask_length) = @_;
    my $subnet_mask;
    my $num_of_octets = 0;

    my $num_of_255_octets = floor($subnet_mask_length / 8);
    for (my $count=0; $count < $num_of_255_octets; $count++)
    {
        $subnet_mask .= 255 . "." ;
        $num_of_octets++;
    }

    my $num_of_1s_in_octet = $subnet_mask_length % 8;
    my $octet = undef;
    for (my $count=0; $count < 8; $count++)
    {
        if ($num_of_1s_in_octet-- > 0)
        {
            $octet .= "1";
        }
        else
        {
            $octet .= "0";
        }
    }
    $subnet_mask .= bin2dec($octet);
    $num_of_octets++;

    #
    # If there are any more octets remaining, fill them 0s.
    #
    while($num_of_octets++ < 4)
    {
        $subnet_mask .= ".0" ;
    }

    return $subnet_mask;
}


sub bin2dec
{
    my $binary_num = @_;

    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

1;
