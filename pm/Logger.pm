package Logger;

use strict;
use warnings;

sub new () {
        my $class = shift;
        my $self = shift;
        bless ($self, $class);
        $self->_initialize();
        return $self;
}

sub _initialize () {
        my $self = shift;
        $self->{'stdLogLevels'} = {'error'         => 1,
                                   'warning'       => 2,
                                   'info'          => 3,
                                   'debug'         => 4,
                                };

        if ((! defined $self->{'maxLogLevel'}) or (! exists ${$self->{'stdLogLevels'}}{lc($self->{'maxLogLevel'})})) {
                $self->{'maxLogLevel'} = 'debug';
        }

        return ($self);
}


sub set_max_log_level () {
        my ($self, $newMaxLogLeval) = @_;
        if ((defined $newMaxLogLeval) and (exists ${$self->{'stdLogLevels'}}{lc($newMaxLogLeval)})) {
                $self->{'maxLogLevel'} = $newMaxLogLeval;
        }
        return $self;
}


sub _getTimeDetails () {
        my $self = shift;

        my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
        my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
        my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
        my $year = 1900 + $yearOffset;
        my $timeStamp = {'year'         =>      $year,
                        'dayOfWeek'     =>      $weekDays[$dayOfWeek],
                        'month'         =>      $months[$month],
                        'dayOfMonth'    =>      $dayOfMonth,
                        'hour'          =>      $hour,
                        'minute'        =>      $minute,
                        'second'        =>      $second,
                        };
        #print $timeStamp;

        return ($timeStamp);
}


sub _rotateLog () {
        my $self = shift;

}

sub _printLog () {
        my ($self, $logLevel, $msg) = @_;
        my $maxLogLevel = $self->{'maxLogLevel'};
        my $logFile = $self->{'loggerLogFile'};

        # Form message string
        my $msgStr = '';
        foreach my $mesg (@$msg) {
                $msgStr = $msgStr." ".$mesg;
        }
        # Get current timestamp
        my $currentTimeStamp = _getTimeDetails();

        # Log Level in upper case
        my $ucLogLevel = uc($logLevel);
        if (${$self->{'stdLogLevels'}}{lc($logLevel)} <= ${$self->{'stdLogLevels'}}{lc($maxLogLevel)}) {
                chomp($msg);
                open (LOGFILE, ($logFile ? ">>$logFile" : ">&STDOUT")) or die "Could not open $logFile\n";

                printf  LOGFILE "%-4s,%-3s %-3s %-2s %-8s %9s : $msgStr\n", "$currentTimeStamp->{'year'}", "$currentTimeStamp->{'dayOfWeek'}",  "$currentTimeStamp->{'month'}",  "$currentTimeStamp->{'dayOfMonth'}", "$currentTimeStamp->{'hour'}:$currentTimeStamp->{'minute'}:$currentTimeStamp->{'second'}", "[$ucLogLevel]";

                close (LOGFILE);
        }

        return $self;
}

sub error () {
        my ($self, $msg) = @_;
        my $logLevel = 'error';
        $self->_printLog($logLevel, $msg);
#       die "@$msg\nTerminating the test execution... . Refer $self->{'loggerLogFile'} for more details.\n";
}

sub warning () {
        my ($self, $msg) = @_;
        my $logLevel = 'warning';
        $self->_printLog($logLevel, $msg);
}

sub info () {
        my ($self, $msg) = @_;
        my $logLevel = 'info';
        $self->_printLog($logLevel, $msg);
}

sub debug () {
        my ($self, $msg) = @_;
        my $logLevel = 'debug';
        unshift (@$msg, "\t");
        $self->_printLog($logLevel, $msg);
}


1;
