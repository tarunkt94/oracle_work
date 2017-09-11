package SunStorage;

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
    # add $scriptDir into INC
    unshift (@INC, "$scriptDir/..");
    chdir($orignalDir);
}

use Util;


### Constructor
sub new {

    my ($class, %args) = @_;

    my $self = {
        user => $args{user},
        passwd => $args{passwd},
        sunprj => $args{sunprj},
        storage => $args{storage},
    };

    bless($self, $class);

    return $self;
}

#
# Check Replication status
# Input:
#     logpath => log path
#     scriptDir => script directory path
# Generate summary file
#
sub checkReplicationStatus {

    my ($self, %params) = @_;

    my $test = "ssreplication";
    my $l = getLiner()."\n";
    $l = $l."Time: ".getTime();

    system("$params{scriptDir}/sunStorageShowReplicationInfo.sh $self->{user} $self->{passwd} $self->{storage} $self->{sunprj} > $params{logpath}/$test.log");

    my $testresult = validateReplication(
        test => $test, logpath => $params{logpath},
        drmode => $params{drmode},
        logfile => "$params{logpath}/$test.log",
        sunprj => $self->{sunprj});

    open(FOUT, ">> $params{logpath}/testSummary.txt");
    print FOUT "$l\n";
    print FOUT "**************************checkReplicationStatus**************************\n";
    print FOUT "CMD=$params{scriptDir}/sunStorageShowReplicationInfo.sh $self->{user} $self->{passwd} $self->{storage} $self->{sunprj}\n";
    print FOUT `cat $params{logpath}/$test.log`;
    print FOUT "\nresult = $testresult\n\n";
    close(FOUT);

}

#
# Check sun project
# Input:
#     logpath => log path
#     scriptDir => script directory path
# Generate summary file
#
sub checkSunStoragePrj {

    my ($self, %params) = @_;

    my $test = "sunprojectstatus";
    my $l = getLiner()."\n";
    $l = $l."Time: ".getTime();

    system("$params{scriptDir}/sunStorageVerifyProjectExists.sh $self->{user} $self->{passwd} $self->{storage} $self->{sunprj} > $params{logpath}/$test.log");

    my $testresult = validateSunPrj(
        test => $test, logpath => $params{logpath},
        logfile => "$params{logpath}/$test.log",
        sunprj => $self->{sunprj});

    open(FOUT, ">> $params{logpath}/testSummary.txt");
    print FOUT "$l\n";
    print FOUT "**************************checkSunStoragePrj**************************\n";
    print FOUT "CMD=$params{scriptDir}/sunStorageVerifyProjectExists.sh  $self->{user} $self->{passwd} $self->{storage} $self->{sunprj}\n";
    print FOUT `cat $params{logpath}/$test.log`;
    print FOUT "\nresult = $testresult\n\n";
    close(FOUT);

}


#
# Check sun project exists or not
# Input:
#     test => test name
#     logfile => log file name
#     sunprj => sun project name
#     logpath => log path
# Returns status of test
#
sub validateReplication {

    my (%params) = @_;

    my ($entries, $c);
    my $errstr = "exception|error";
    my $searchstr = "Continuous";
    my $testresult = "Failed";

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {

        $c = `grep -Ei '$searchstr' $params{logfile} | wc -l`;
        chomp($c);

        if ($params{drmode} eq 'ACTIVE') {
            $entries = 2;
        } else {
            $entries = 0;
        }

        if ($c == $entries ) {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.suc.html");
            $testresult = "Passed";
        } else {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
            $testresult = "Failed";
        }
    }

    return $testresult;
}

#
# Check sun project exists or not
# Input:
#     test => test name
#     logfile => log file name
#     sunprj => sun project name
#     logpath => log path
# Returns status of test
#
sub validateSunPrj {

    my (%params) = @_;

    my $errstr = "exception|error";
    my $searchstr = "$params{sunprj} Present";
    my $testresult = "Failed";

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {
        if (`grep -Ei '$searchstr' $params{logfile} |wc -l ` == 1) {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.suc.html");
            $testresult = "Passed";
        } else {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
            $testresult = "Failed";
        }
    }

    return $testresult;
}

1;
