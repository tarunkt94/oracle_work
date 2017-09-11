package Validations::DB;

use strict;
use warnings;
use Cwd;
use File::Basename;

BEGIN
{
    my $orignalDir = getcwd();
    my $scriptDir = dirname($0);
    chdir($scriptDir);
    $scriptDir = getcwd();
    # add $scriptDir into INC
    unshift (@INC, "$scriptDir/..");
    chdir($orignalDir);
}

use Logger;
use Util;
use RemoteCmd;


### Constructor
sub new {

    my ($class, %args) = @_;

    my $self = {
        user => $args{user},
        passwd => $args{passwd},
        logObj => $args{logObj},
        faenvs => $args{faenvs},
        db_host => $args{faenvs}{'faovm.ha.HOST_DB'},
        db2_host => $args{faenvs}{'faovm.ha.HOST_DB2'},
        oracle_home => $args{faenvs}{'faovm.ha.fusiondb.new.oracle.home'},
        oracle_grid => $args{faenvs}{'faovm.ha.fusiondb.new.crs.home'},
        fa_db_sid1 => $args{faenvs}{'faovm.ha.fusiondb.new.rac.sid1'},
        fa_db_sid2 => $args{faenvs}{'faovm.ha.fusiondb.new.rac.sid2'},
        oid_db_sid1 => $args{faenvs}{'faovm.ha.oiddb.new.rac.sid1'},
        oid_db_sid2 => $args{faenvs}{'faovm.ha.oiddb.new.rac.sid2'},
        oim_db_sid1 => $args{faenvs}{'faovm.ha.idsdb.new.rac.sid1'},
        oim_db_sid2 => $args{faenvs}{'faovm.ha.idsdb.new.rac.sid2'},
        fa_db_uniq_name => $args{faenvs}{'faovm.ha.fusiondb.new.dbuniquename'},
        oid_db_uniq_name => $args{faenvs}{'faovm.ha.oiddb.new.dbuniquename'},
        oim_db_uniq_name => $args{faenvs}{'faovm.idsdb.new.dbuniquename'},
        fa_db_name => $args{faenvs}{'faovm.ha.fusiondb.new.dbname'},
        oid_db_name => $args{faenvs}{'faovm.ha.oiddb.new.dbname'},
        oim_db_name => $args{faenvs}{'faovm.idsdb.new.dbname'},
    };

    if (!$self->{oim_db_sid1}) {
        $self->{oim_db_sid1} = $self->{faenvs}{'faovm.idsdb.new.rac.sid1'};
    }

    if (!$self->{oim_db_sid2}) {
        $self->{oim_db_sid2} = $self->{faenvs}{'faovm.idsdb.new.rac.sid2'};
    }

    if (!$self->{oim_db_name}) {
        $self->{oim_db_name} = $self->{faenvs}{'faovm.ha.idsdb.new.dbname'};
    }

    if (!$self->{oim_db_uniq_name}) {
        $self->{oim_db_uniq_name} = $self->{faenvs}{'faovm.ha.idsdb.new.dbuniquename'};
    }

    bless($self, $class);

    $self->{'remoteObj'} = RemoteCmd->new(user => $self->{user},
                                          passwd => $self->{passwd},
                                          logObj => $self->{logObj});

    $self->{logdir} = "/home/$self->{user}/DR_CHECKS";

    return $self;
}


# Check Data guard configuration
# Input:
#     drmode => DR mode
#     logpath => log path
# Generate summary file
#
sub checkDg {

    my ($self, %params) = @_;

    my ($cmd, $testresult);

    my %dbHash = (
        "dgmgrl_fa_rac1:$self->{fa_db_sid1}" =>
            "$self->{db_host}:$self->{fa_db_uniq_name}",
        "dgmgrl_fa_rac2:$self->{fa_db_sid2}" =>
            "$self->{db2_host}:$self->{fa_db_uniq_name}",
        "dgmgrl_oid_rac1:$self->{oid_db_sid1}" =>
            "$self->{db_host}:$self->{oid_db_uniq_name}",
        "dgmgrl_oid_rac2:$self->{oid_db_sid2}" =>
            "$self->{db2_host}:$self->{oid_db_uniq_name}",
        "dgmgrl_oim_rac1:$self->{oim_db_sid1}" =>
            "$self->{db_host}:$self->{oim_db_uniq_name}",
        "dgmgrl_oim_rac2:$self->{oim_db_sid2}" =>
            "$self->{db2_host}:$self->{oim_db_uniq_name}"
    );

    for my $key (sort keys %dbHash) {
        my ($test, $db_sid) = split(/:/, $key);
        my($host, $db_uniq_name) = split(/:/, $dbHash{$key});

        $cmd = "#!/bin/bash

                if [ ! -d \"$self->{logdir}\" ]; then
                    mkdir -p \"$self->{logdir}\";
                fi
                rm -rf \"$self->{logdir}/$test*\";
                export ORACLE_HOME=$self->{oracle_home};
                export ORACLE_SID=$db_sid;
                `dgmgrl sys/Welcome1 \"show configuration\" > $self->{logdir}/$test.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";

        $self->{'remoteObj'}->createAndRunScript(host => $host,
                                                 cmd => $cmd);

        $self->{'remoteObj'}->copyFileToDir(host => $host,
                                            destdir => $params{logpath},
                                            file => "$self->{logdir}/$test*");

        $testresult = validateDgLog(
            test => $test, logpath => $params{logpath},
            drmode => $params{drmode}, db_uniq_name => $db_uniq_name,
            logfile => "$params{logpath}/$test.log",
            extlogfile => "$params{logpath}/${test}_cmdextcode.log");

        generateSummaryFile(user => $self->{user}, passwd => $self->{passwd},
                            test => $test, host => $host, cmd => $cmd,
                            logpath => $params{logpath},
                            logfile => "$params{logpath}/$test.log",
                            testresult => $testresult);
    }
}

#
# Check ASM db
# Input:
#     logpath => log path
# Generate summary file
#
sub checkAsmDb {

    my ($self, %params) = @_;

    my ($cmd, $dbn, $testresult);

    my %asmDbHash = (
        "asm_fa_rac1:ASM1" =>
            "$self->{db_host}:$self->{fa_db_uniq_name}:$self->{fa_db_name}",
        "asm_fa_rac2:ASM2" =>
            "$self->{db2_host}:$self->{fa_db_uniq_name}:$self->{fa_db_name}",
        "asm_oid_rac1:ASM1" =>
            "$self->{db_host}:$self->{oid_db_uniq_name}:$self->{oid_db_name}",
        "asm_oid_rac2:ASM2" =>
            "$self->{db2_host}:$self->{oid_db_uniq_name}:$self->{oid_db_name}",
        "asm_oim_rac1:ASM1" =>
            "$self->{db_host}:$self->{oim_db_uniq_name}:$self->{oim_db_name}",
        "asm_oim_rac2:ASM2" =>
            "$self->{db2_host}:$self->{oim_db_uniq_name}:$self->{oim_db_name}"
    );

    for my $key (sort keys %asmDbHash) {
        my ($test, $db_sid) = split(/:/, $key);
        my($host, $dbuniqname, $db_name) = split(/:/, $asmDbHash{$key});

        $cmd = "#!/bin/bash

                if [ ! -d \"$self->{logdir}\" ]; then
                    mkdir -p \"$self->{logdir}\";
                fi
                rm -rf \"$self->{logdir}/$test*\";
                export ORACLE_HOME=$self->{oracle_grid};
                export ORACLE_SID=+$db_sid;
                `asmcmd ls DATA/$dbuniqname > $self->{logdir}/${test}.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";

        $self->{'remoteObj'}->createAndRunScript(host => $host,
                                                 cmd => $cmd);

        $self->{'remoteObj'}->copyFileToDir(host => $host,
                                            file => "$self->{logdir}/$test*",
                                            destdir => $params{logpath});

        $testresult = validateAsmDbLog(
            test => $test, logpath => $params{logpath},
            orafile => "spfile$db_name.ora",
            logfile => "$params{logpath}/$test.log",
            extlogfile => "$params{logpath}/${test}_cmdextcode.log");

        generateSummaryFile(user => $self->{user}, passwd => $self->{passwd}, 
                            test => $test, host => $host, cmd => $cmd,
                            logpath => $params{logpath},
                            logfile => "$params{logpath}/$test.log",
                            testresult => $testresult);

    }
}

#
# Check Listener enabled and running
# Input:
#     logpath => log path
# Generate summary file
#
sub checkListener {

    my ($self, %params) = @_;

    my ($cmd, $dbn, $testresult);

    my %listenerHash = (
        "listener_fa_rac1:$self->{fa_db_sid1}" =>
            "$self->{db_host}:$self->{fa_db_uniq_name}",
        "listener_fa_rac2:$self->{fa_db_sid2}" =>
            "$self->{db2_host}:$self->{fa_db_uniq_name}",
        "listener_oid_rac1:$self->{oid_db_sid1}" =>
            "$self->{db_host}:$self->{oid_db_uniq_name}",
        "listener_oid_rac2:$self->{oid_db_sid2}" =>
            "$self->{db2_host}:$self->{oid_db_uniq_name}",
        "listener_oim_rac1:$self->{oim_db_sid1}" =>
            "$self->{db_host}:$self->{oim_db_uniq_name}",
        "listener_oim_rac2:$self->{oim_db_sid2}" =>
            "$self->{db2_host}:$self->{oim_db_uniq_name}"
    );

    for my $key (sort keys %listenerHash) {
        my ($test, $db_sid) = split(/:/, $key);
        my($host, $db_uniq_name) = split(/:/, $listenerHash{$key});
        $dbn = uc($db_uniq_name);

        $cmd = "#!/bin/bash

                if [ ! -d \"$self->{logdir}\" ]; then
                    mkdir -p \"$self->{logdir}\";
                fi
                rm -rf \"$self->{logdir}/$test*\";
                `srvctl status listener -l LISTENER_$dbn > $self->{logdir}/$test.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";

        $self->{'remoteObj'}->createAndRunScript(host => $host,
                                                 cmd => $cmd);

        $self->{'remoteObj'}->copyFileToDir(host => $host,
                                            file => "$self->{logdir}/$test*",
                                            destdir => $params{logpath});

        $testresult = validateListenerLog(
            test => $test, logpath => $params{logpath},
            logfile => "$params{logpath}/$test.log",
            extlogfile => "$params{logpath}/${test}_cmdextcode.log");

        generateSummaryFile(user => $self->{user}, passwd => $self->{passwd},
                            test => $test, logpath => $params{logpath},
                            host => $host, cmd => $cmd,
                            logfile => "$params{logpath}/$test.log",
                            testresult => $testresult);
    }
}

#
# Check Open mode of DB
# Input:
#     drmode => DR mode
#     logpath => log path
# Generate summary file
#
sub checkOpenModeDb {

    my ($self, %params) = @_;

    my ($cmd, $testresult);

    my %openModeHash = (
        "openmode_fa_rac1:$self->{fa_db_sid1}" =>
            "$self->{db_host}:$self->{fa_db_name}",
        "openmode_fa_rac2:$self->{fa_db_sid2}" =>
            "$self->{db2_host}:$self->{fa_db_name}",
        "openmode_oid_rac1:$self->{oid_db_sid1}" =>
            "$self->{db_host}:$self->{oid_db_name}",
        "openmode_oid_rac2:$self->{oid_db_sid2}" =>
            "$self->{db2_host}:$self->{oid_db_name}",
        "openmode_oim_rac1:$self->{oim_db_sid1}" =>
            "$self->{db_host}:$self->{oim_db_name}",
        "openmode_oim_rac2:$self->{oim_db_sid2}" =>
            "$self->{db2_host}:$self->{oim_db_name}"
    );

    for my $key (sort keys %openModeHash) {
        my ($test, $db_sid) = split(/:/, $key);
        my($host, $db_uniq_name) = split(/:/, $openModeHash{$key});


        $cmd = "#!/bin/bash

                if [ ! -d \"$self->{logdir}\" ]; then
                    mkdir -p \"$self->{logdir}\";
                fi
                rm -rf \"$self->{logdir}/$test*\";
                export ORACLE_HOME=$self->{oracle_home};
                export ORACLE_SID=$db_sid;
                `echo 'select name, open_mode from v\$database;' |sqlplus / as sysdba > $self->{logdir}/$test.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";

        $self->{'remoteObj'}->createAndRunScript(host => $host,
                                                 cmd => $cmd);

        $self->{'remoteObj'}->copyFileToDir(host => $host,
                                            file => "$self->{logdir}/$test*",
                                            destdir => $params{logpath});

        $testresult = validateOpenModeDbLog(
            test => $test, logpath => $params{logpath},
            drmode => $params{drmode},
            logfile => "$params{logpath}/$test.log",
            db_uniq_name => $db_uniq_name,
            extlogfile => "$params{logpath}/${test}_cmdextcode.log");

        generateSummaryFile(user => $self->{user}, passwd => $self->{passwd},
                            test => $test, host => $host, cmd => $cmd,
                            logpath => $params{logpath},
                            logfile => "$params{logpath}/$test.log",
                            testresult => $testresult);

    }
}

#
# Check dataguard is configured or not
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     drmode => DR mode
#     db_uniq_name => db unique name
#     logpath => log path
# Returns status of test
#
sub validateDgLog {

    my (%params) = @_;

    my $errstr = "exception|ORA-|error";
    my $searchstr = "SUCCESS";
    my $testresult = "Failed";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0 or
        $exit_code != 0) {
        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {

        if (`grep -Ei '$searchstr' $params{logfile} | wc -l` == 1 ) {

            if ($params{drmode} eq 'ACTIVE') {
                $searchstr = "$params{db_uniq_name} .*Primary database";
            } else {
                $searchstr = "$params{db_uniq_name} .*Physical standby database";
            }

            if (`grep -Ei '$searchstr' $params{logfile} | wc -l` == 1 ) {

                system("cp -rf $params{logfile} $params{logpath}/$params{test}.suc.html");
                $testresult = "Passed";
            } else {

                system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
                $testresult = "Failed";
            }
        } else {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
            $testresult = "Failed";
        }
    }

    return $testresult;
}

#
# Check asmcmd ls command
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     logpath => log path
# Returns status of test
#
sub validateAsmDbLog {

    my (%params) = @_;

    my $testresult = "Failed";
    my $errstr = "exception|ASMCMD-|error";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0 or
        $exit_code != 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {
        if (`grep -Ei '$params{orafile}' $params{logfile} |wc -l ` == 1) {

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
# Check Listener is up and running or not
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     logpath => log path
# Returns status of test
#
sub validateListenerLog {

    my (%params) = @_;

    my $errstr = "exception|ORA-|error";
    my $searchstr = "enabled|running";
    my $testresult = "Failed";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0 or
        $exit_code != 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {
        if (`grep -Ei '$searchstr' $params{logfile} | wc -l` == 2 ) {

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
# Check name and open mode of the database
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     drmode => DR mode
#     db_uniq_name => db unique name
#     logpath => log path
# Returns status of test
#
sub validateOpenModeDbLog {

    my (%params) = @_;

    my ($searchstr);
    my $errstr = "exception|ORA-|error";
    my $testresult = "Failed";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0 or
        $exit_code != 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {

        if ($params{drmode} eq 'ACTIVE') {
             $searchstr = "$params{db_uniq_name}.*READ WRITE";
        } else {
             $searchstr = "$params{db_uniq_name}.*READ ONLY WITH APPLY";
        }

        if (`grep -Ei '$searchstr' $params{logfile} | wc -l` == 1 ) {

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
