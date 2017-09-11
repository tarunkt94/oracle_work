package Delete;

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

    my $self = {
        config => $args{config},
        importfile => $args{importfile},
    };

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
# Delete
# Input:
#     $self
# Send mail notifcation to user after order is seeded
#
sub deleteorder {

    my ($self) = @_;

    $self->deleteOrder();
}

#
# Run terminate in Tasc DB host
# Input:
#     SUBSCRIPTION_ID, TASC_DB_HOST from prop file
#     TASCTL from config file
# add .suc(success) or .dif(failure) depending upon status
#
sub deleteOrder {

    my ($self) = @_;

    my ($mailids, $message, $subject);

    # Check deleteOrder step is executed
    # Action: if .suc exists: return 1
    # proceed if .suc and .dif not exists
    return 0 if (isStepExecuted(workdir => "$self->{importfile}{'WORKDIR'}",
                                step => "deleteOrder",
                                logObj => $self->{logObj}));

    $self->{'logObj'}->info(["Executing Step: deleteOrder"]);

    my ($status, $out) = $self->{'tasObj'}->deleteOrder(
        tasc_db_host => $self->{importfile}{'TASC_DB_HOST'},
        tasctl => $self->{config}{'TASCTL'},
        subscription_id => $self->{importfile}{'SUBSCRIPTION_ID'},
    );

    createAndSendStatusFile(step => "deleteOrder", status => $status,
                     importfile => $self->{importfile},
                     logObj => $self->{'logObj'}, out => "$out");

    my $service_name = `echo $out | grep "sql" | grep "ser" | awk -F ' ' '{print $3}'`;

    sleep(300);

    my $sdiObj = SDI->new(host => $self->{importfile}{'SDI_HOST'},
                          sdiscript => $self->{config}{'SDISCRIPT'},
                          user => $self->{config}{'SDIUSER'},
                          passwd => $self->{config}{'SDIPASSWD'},
                          logObj => $self->{logObj});

    my %reqDetails = $sdiObj->getReqDetails(req_id => $service_name);

    $mailids = $self->{importfile}{'EMAIL_ID'};
    $mailids =~ s/[;| ]+/,/g;

    foreach my $keycount (keys %reqDetails){
        if ($reqDetails{$keycount}{'requesttype'} eq 'DELETE') {
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
                        <tr><th>Last Updated On</th><td>$reqDetails{$keycount}{lastupdate}</td></tr></table>";

            sendMail(mailids => $mailids,
                     subject => $subject,
                     message => $message);
        }
    }
}

1;
