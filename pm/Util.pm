package Util;

use strict;
use warnings;
use Data::Dumper;

use DoSystemCmd;
use Mail;
use Logger;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(getLiner getTime parseConfigFile generateSummaryFile writeHashtoFile
                 isStepExecuted createAndSendStatusFile getFaEnv saveOutputtoLog
                 getHardwareInfo vmsInfo createHashFromFile sendMail Uniq);

my $system = DoSystemCmd->new({filehandle => \*STDOUT});

use HardwareNetworkInfo;

sub getLiner {

    my $line = '';

    for ( my $i=0; $i<100; $i++ ) {
        $line .= "#";
    }

    return $line;
}

sub getTime {

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    $ENV{TZ} = 'Asia/Calcutta';

    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset,
        $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();

    my $year = 1900 + $yearOffset;
    my $theTime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";

    return $theTime;
}


#
# Get Hardware details
# Input:
#     hardware => hardware name
# return hardware details
#
sub getHardwareInfo {

    my ($hardware) = @_;

    my %hypervisor_values = ();
    my ($input_type, $result) = ('hw_name');
    $input_type = 'hw_ip_addr' if ($hardware =~ /^\d/);

    $result =
        HardwareNetworkInfo::get_hw_location_details(
                                                     $input_type => $hardware,
                                                     system      => $system
                                                    );
    return %$result;
}

#
# Create vmsinfo
# No input
# Return vmsinfo as has
#
sub vmsInfo {

    my %vmsinfo = (
        'REL10' => {'FA_GSI' => '14:611840', 'FA_HCM' => '12:307712', 'FA_CRM' => '12:325120'},
        'REL11' => {'FA_GSI' => '14:328192', 'FA_HCM' => '12:310784', 'FA_CRM' => '12:638464'},
    );

    return \%vmsinfo;
}

#
# Get login user ids and passwds
# Input configfile => config file name
# Return hash(userid => passwd)
#
sub parseConfigFile {

    my (%params) = @_;

    my ($configline, $key, $value, %config);

    open (CONFIGFILE, "$params{configfile}") or die "ERROR: Config file not found : $params{configfile}";
    while (<CONFIGFILE>) {
        $configline = $_;
        chomp ($configline);
        $configline =~ s/^\s*//;
        $configline =~ s/\s*$//;
        if ( ($configline !~ /^#/) && ($configline ne "") ) {
            ($key, $value) = split (/=/, $configline);
            $config{$key} = $value;
        }
    }
    close(CONFIGFILE);

    return %config;
}

#
# Generate summary file
# Input logfile => log file name
#       logpath => log path
#       test => test case name
#       host => host name
#       user => user name
#       passwd => password
#       cmd => command
#       testresult => passed or failed
#
sub generateSummaryFile {

    my (%params) = @_;

    my $ln = getLiner() ."\n";
    my $filecontent = `cat $params{logfile}`;

    open(FOUT, ">>$params{logpath}/testSummary.txt");
    print FOUT "\n$ln\n";
    print FOUT "TEST=$params{test}\t\t\t\t - \t\tTime: ".getTime()."\n";
    print FOUT "$ln\n";
    print FOUT "HOST=$params{host}($params{user}/$params{passwd})\n";
    print FOUT "CMD=$params{cmd}\n";
    print FOUT "Log File Path:$params{logfile}\n";
    print FOUT "*************************Log File Contents**********************\n";
    print FOUT "$filecontent\n";

    if ($params{testresult}) {
        print FOUT "result = $params{testresult}\n\n";
    }

    close(FOUT);
}

#
# Save output to Logfile
# Input:
#     file => file path where output to be saved
#     out => output
#     cmd => command executed
# Return ovmprop hash
#
sub saveOutputtoLog {

    my (%params) = @_;

    my $status = 0;

    open(FILE, ">$params{file}") or
        die("Can't open $params{file}\n");

    print FILE "Command Executed: \n\t$params{cmd}\n\n";
    print FILE "Output:\n\t";
    for my $output (@{$params{out}}) {
        $output =~ s/\r?\n//g;

        if ($output =~ /error/i) {
            $status = 1;
        }

        print FILE "$output\n";
    }
    close (FILE);

    return $status;
}

#
# Generate ovmprop hash
# Input:
#     ovmfile => ovm prop file name
# Return ovmprop hash
#
sub getFaEnv {

    my ($ovmfile) = @_;

    my (%ovmprop, $propkey, $propvalue);

    open OVMFILE, "$ovmfile" or die("Cannot open file $ovmfile");
    while (my $line = <OVMFILE>) {
        if ($line !~ /^\n/) {
            if ($line !~ /^#/) {
                ($propkey, $propvalue) = split /=/, $line;
                $propvalue =~ s/\n$//g;
                $ovmprop{$propkey} = $propvalue;
            }
        }
    }

    return %ovmprop;
}

#
# Generate hash from file
# Input:
#     file => file name
# Return hash
#
sub createHashFromFile {

    my ($file) = @_;

    my (%prop, $propkey, $propvalue);

    open FILE, "$file" or die("Cannot open file $file");
    while (my $line = <FILE>) {
        if ($line !~ /^\n/) {
            if ($line !~ /^#/) {
                ($propkey, $propvalue) = split /=/, $line;
                $propvalue =~ s/\n$//g;
                $prop{$propkey} = $propvalue;
            }
        }
    }

    return %prop;
}

# check step of action item is executed
sub isStepExecuted {

    my (%params) = @_;

    # if .dif exists, error in log file
    if (-f "$params{workdir}/$params{step}.dif") {
        $params{'logObj'}->error(["Step: $params{step} already executed and failed.".
                                 " Please fix the issue and re-run the script".
                                 " with deleting or renaming .dif file"]);
        exit 1;
    # .suc exists, step is successfully executed
    } elsif (-f "$params{workdir}/$params{step}.suc") {
        $params{'logObj'}->info(["Step: $params{step} already executed."]);
        return 1;
    # .suc and .dif not exists, execute the step
    } elsif (!-f "$params{workdir}/$params{step}.suc" and
             ! -f "$params{workdir}/$params{step}.dif") {
        return 0;
    }

}

# create .suc or .dif file
sub createAndSendStatusFile {

    my (%params) = @_;

    my ($filename, $message, $subject, $rel_name, $pillar, $tag_name);

    my $hostname = `hostname`;
    my %importfile = %{$params{importfile}};

    my $mailids = $importfile{'EMAIL_ID'};
    $mailids =~ s/[;| ]+/,/g;
    if ((exists $importfile{RELEASE_NAME} and $importfile{RELEASE_NAME}) and
       (exists $importfile{STAGE_NAME} and $importfile{STAGE_NAME})) {
        $rel_name = $importfile{RELEASE_NAME} . "_" . $importfile{STAGE_NAME};
    }

    if (exists $importfile{PILLAR} and $importfile{PILLAR}) {
        $pillar = $importfile{PILLAR};
    }

    if (exists $importfile{TAG_NAME} and $importfile{TAG_NAME}) {
        $tag_name = $importfile{TAG_NAME};
    }

    # step executed successfully, create .suc file
    if ($params{status} == 0) {
        $filename = "$importfile{WORKDIR}/$params{step}.suc";

        open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
        print $fh "$params{out}\n";
        close $fh;

        $params{'logObj'}->info(["Added $params{step}.suc file"]);

    # step failed, create .dif file
    } else {
        $filename = "$importfile{WORKDIR}/$params{step}.dif";

        open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
        print $fh "$params{out}\n";
        close $fh;

        $message = "<h4>Order Details<h4><table><tr><th>Step</th><td>$params{step}</td></tr>
                <tr><th>Host Name</th><td>$hostname</td></tr>
                <tr><th>Work Directory</th><td>$importfile{WORKDIR}</td></tr>
                <tr><th>Release Name</th><td>$rel_name</td></tr>
                <tr><th>Pillar</th><td>$pillar</td></tr>
                <tr><th>Tag Name</th><td>$tag_name</td></tr>
                <tr><th>FA Hypervisors</th><td>$importfile{FA_HYPERVISOR}</td></tr>
                <tr><th>DB Hypervisors</th><td>$importfile{DB_HYPERVISOR}</td></tr>
                <tr><th>Failure Reason</th><td>$params{out}</td></tr>
                <tr><th>More details</th><td>$importfile{WORKDIR}/order.log</td></tr></table>";
        $subject = "Order Step Failure Notification - $params{step}";

        sendMail(mailids => $mailids,
              subject => $subject,
              message => $message);

        $params{'logObj'}->error(["Added $params{step}.dif file"]);
    }

    if ($params{status} != 0) {
        exit 1;
    }
}

sub writeHashtoFile {

    my (%params) = @_;

    if (! -f $params{file}) {
        my $touchcmd = system("touch $params{file}");
        die("Couldn't touch $params{file}") if ($touchcmd != 0);
    }

    my $chmhash = system("chmod 777 $params{file}");
    die ("Couldn't change the permissions to $params{file}") if($chmhash != 0);
    open my $output, '>', $params{file} or die $!;
    print $output Dumper(\%{$params{hash}});
    close $output;
    $chmhash = system("chmod 555 $params{file}");
    die ("Couldn't change the permissions to $params{file}") if($chmhash != 0);

    return;

}

sub sendMail {

    my (%params) = @_;

    Mail::sendmail($params{mailids},
        {
            Subject => "$params{subject}",
            'From' => "SDI FA POD PROVISIONING REQUESTS",
            'Content-type' => "text/html"
        },
    $params{message});
}

sub Uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

1;
