package FAPod;

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
        host => $args{host},
        faenvs => $args{faenvs},
        prj => $args{faenvs}{'faovm.storage.sun.project'},
        oracle_home => $args{faenvs}{'faovm.ha.fusiondb.new.oracle.home'},
        fa_host => $args{faenvs}{'faovm.ha.HOST_FA'},
        primary_host => $args{faenvs}{'faovm.ha.HOST_PRIMARY'},
        sec_host => $args{faenvs}{'faovm.ha.HOST_SECONDARY'},
        osn_host => $args{faenvs}{'faovm.ha.HOST_OSN'},
        bi_host => $args{faenvs}{'faovm.ha.HOST_BI'},
        oid_host => $args{faenvs}{'faovm.ha.HOST_LDAP'},
        oim_host => $args{faenvs}{'faovm.ha.HOST_OIM'},
        ohs_host => $args{faenvs}{'faovm.ha.HOST_OHS'},
        primary_ha1_host => $args{faenvs}{'faovm.ha.HOST_PRIMARY_HA1'},
        sec_ha1_host => $args{faenvs}{'faovm.ha.HOST_SECONDARY_HA1'},
        osn_ha_host => $args{faenvs}{'faovm.ha.HOST_OSN_HA1'},
	ohs_ha1_host => $args{faenvs}{'faovm.ha.HOST_OHS_HA1'},
	webgate_host => $args{faenvs}{'faovm.ha.HOST_WEBGATE'},
    };
    
    bless($self, $class);
    
    $self->{'remoteObj'} = RemoteCmd->new(user => $self->{user},
                                          passwd => $self->{passwd},
                                          logObj => $self->{logObj});
    
    $self->{logdir} = "/home/$self->{user}/DR_CHECKS";
    
    return $self;
}

#
# Create fstab hash
# Input:
#     $self
# Return %fstabHash
#
sub createFstabHash{
    my ($self) = @_;
    
    my %fstabHash = (
		     "fstabfa" => "$self->{fa_host}",
		     "fstabprimary" => "$self->{primary_host}",
		     "fstabsecondary" => "$self->{sec_host}",
		     "fstabbi" => "$self->{bi_host}",
		     "fstabosn" => "$self->{osn_host}",
		     "fstabohs" => "$self->{ohs_host}",
		     "fstaboim" => "$self->{oim_host}",
		     "fstaboid" => "$self->{oid_host}"
		     );
    
    if ($self->{primary_ha1_host} ne '') {
        $fstabHash{"fstabprimaryha1"} = $self->{primary_ha1_host};
    }
    if ($self->{sec_ha1_host} ne '') {
        $fstabHash{"fstabsecondaryha1"} = $self->{sec_ha1_host};
    }
    if ($self->{osn_ha_host}) {
        $fstabHash{"fstabosnha1"} = $self->{osn_ha_host};
    }		
    if ($self->{ohs_ha1_host}) {
        $fstabHash{"fstabohsha1"} = $self->{ohs_ha1_host};
    }
    if ($self->{webgate_host}) {
        $fstabHash{"fstabwebgate"} = $self->{webgate_host};
    }
    
    return %fstabHash;
}

#
# Create Mount hash
# Input:
#     $self
# Return %mountHash
#
sub createMountHash{
    my ($self) = @_;
    
    my %mountHash = (
		     "fau01mp" => "$self->{fa_host}",
		     "primaryu01mp" => "$self->{primary_host}",
		     "secondaryu01mp" => "$self->{sec_host}",
		     "biu01mp" => "$self->{bi_host}",
		     "osnu01mp" => "$self->{osn_host}",
		     "ohsu01mp" => "$self->{ohs_host}",
		     "oimu01mp" => "$self->{oim_host}",
		     "oidu01mp" => "$self->{oid_host}"
		     );
    
    if ($self->{primary_ha1_host} ne '') {
        $mountHash{"primaryha1u01mp"} = $self->{primary_ha1_host};
    }
    if ($self->{sec_ha1_host} ne '') {
        $mountHash{"secondaryha1u01mp"} = $self->{sec_ha1_host};
    }
    if ($self->{osn_ha_host}) {
        $mountHash{"osnha1u01mp"} = $self->{osn_ha_host};
    }	
    if ($self->{ohs_ha1_host}) {
        $mountHash{"ohsha1u01mp"} = $self->{ohs_ha1_host};
    }
    if ($self->{webgate_host}) {
        $mountHash{"webgateu01mp"} = $self->{webgate_host};
    }
    
    return %mountHash;
}

#
# Check OIM Servers status
# Input:
#     drmode => DR mode
#     logpath => log path
# Generate summary file
#
sub checkOIMServersStatus {

    my ($self, %params) = @_;

    my ($cmd, $testresult);
    my $test = "oimfactrlstatus";

    $cmd = "#!/bin/bash

            if [ ! -d \"$self->{logdir}\" ]; then
                mkdir -p \"$self->{logdir}\";
            fi
            rm -rf \"$self->{logdir}/$test*\";
            `/u01/lcm/startstop_saas/idm_control.sh -c status -a all > $self->{logdir}/$test.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";
    
    $self->{'remoteObj'}->createAndRunScript(host => $params{host},
                                             cmd => $cmd);
    
    $self->{'remoteObj'}->copyFileToDir(host => $params{host},
                                        file => "$self->{logdir}/$test*",
                                        destdir => $params{logpath});

    $testresult = validateServersLog(
				     test => $test, 
				     logpath => $params{logpath},
				     logfile => "$params{logpath}/$test.log",
				     extlogfile => "$params{logpath}/${test}_cmdextcode.log");
    
    generateSummaryFile(test => $test, host => $params{host},
                        cmd => $cmd, logpath => $params{logpath},
                        user => $self->{user}, passwd => $self->{passwd},
                        logfile => "$params{logpath}/$test.log",
                        testresult => $testresult);
}

#
# Check FA Servers status
# Input:
#     drmode => DR mode
#     logpath => log path
# Generate summary file
#
sub checkFAServersStatus {
    
    my ($self, %params) = @_;
    
    my ($cmd, $testresult);
    my $test = "fafactrlstatus";
    
    $cmd = "#!/bin/bash

            if [ ! -d \"$self->{logdir}\" ]; then
                mkdir -p \"$self->{logdir}\";
            fi
            rm -rf \"$self->{logdir}/$test*\";
            `/u01/lcm/startstop_saas/fa_control.sh -c status -a all > $self->{logdir}/$test.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";
    
    $self->{'remoteObj'}->createAndRunScript(host => $params{host},
                                             cmd => $cmd);
    
    $self->{'remoteObj'}->copyFileToDir(host => $params{host},
                                        file => "$self->{logdir}/$test*",
                                        destdir => $params{logpath});
    
    $testresult = validateServersLog(
				     test => $test, 
				     logpath => $params{logpath},
				     logfile => "$params{logpath}/$test.log",
				     extlogfile => "$params{logpath}/${test}_cmdextcode.log");
    
    generateSummaryFile(test => $test, host => $params{host},
                        cmd => $cmd, logpath => $params{logpath},
                        user => $self->{user}, passwd => $self->{passwd},
                        logfile => "$params{logpath}/$test.log",
                        testresult => $testresult);
}

#
# Check Scaleout Hosts
# Input ovm_prop_file => ovm properties file
#       key => key
#       logpath => log path
# Generate summary file
#
sub checkForScaleoutHosts {

    my ($self, %params) = @_;

    my %fstabHash;
    my %mountHash;
    my $index = 1;
    my $test = "checkForScaleoutHOSTS";

    my $cmd = "grep \"faovm.ha.HOST_\" $params{logpath}/$params{ovmfile} | grep -i \"scale\" | grep -Ev \"^#\"  | sort | uniq > $params{logpath}/$test.log";
    my $out = `$cmd`;

    open(SOUT, "<$params{logpath}/$test.log") or
        die "Could not open file '$params{logpath}/$test.log' $!";

    while (<SOUT>) {
        $_ =~ s/^\s+|\s+$//g;
        chomp($_);

        my $key = `echo $_ |  cut -d '=' -f1`;
        chomp($key);

        for my $hashkey (keys %{$self->{faenvs}}) {
            if ($hashkey eq $key) {
                my $primary_scale = $self->{faenvs}{$key};
                if ($primary_scale ne '') {
                    $key =~ s/FAOVM.HA.HOST_//gi;
                    $fstabHash{"fstab".$key} = $primary_scale;
                    checkFstabInfo($self, fstabHash => \%fstabHash,
                                   drmode => $params{drmode},
                                   podver => $params{podver},
                                   zdtEnabled => $params{zdtEnabled},
                                   logpath => $params{logpath});
                    $mountHash{$key."u01mp"} = $primary_scale;
                    checkMountPoints($self, mountHash => \%mountHash,
                                     drmode => $params{drmode},
                                     podver => $params{podver},
                                     zdtEnabled => $params{zdtEnabled},
                                     logpath => $params{logpath});
                    $index++;
                }
            }
        }
	
    }
    close(SOUT);
}

#
# Check FaStab entries and mount points
# Input:
#     %fstabMountHash => (host => test)
#     drmode => DR mode
#     logpath => log path
# Generate summary file
#
sub checkFstabInfo {

    my ($self, %params) = @_;

    my ($cmd, $test, $testresult, $index, $host, $fstablist, %fstabHash);
	
    if ($params{podver} >= 11 or $params{zdtEnabled} eq "true") 
    {
	$fstablist = "u01|u02";
    }
    else
    {
	$fstablist = "u01";
    }
    
    for $test (keys %{$params{fstabHash}}) {
	
        $host = $params{fstabHash}{$test};
        $index = index($test, 'osn');
	
        if ($index > 0 ) {
            $cmd = "#!/bin/bash

                    if [ ! -d \"$self->{logdir}\" ]; then
                        mkdir -p \"$self->{logdir}\";
                    fi
                    rm -rf \"$self->{logdir}/$test*\";
                    `cat /etc/fstab | grep -E \"$fstablist|osn_scratch\" | grep $self->{prj} > $self->{logdir}/${test}.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";
	    
        } else {
            $cmd = "#!/bin/bash

                    if [ ! -d \"$self->{logdir}\" ]; then
                        mkdir -p \"$self->{logdir}\";
                    fi
                    rm -rf \"$self->{logdir}/$test*\";
                    `cat /etc/fstab | grep -E \"$fstablist\" | grep $self->{prj} > $self->{logdir}/${test}.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";
	    
        }
	
        $self->{'remoteObj'}->createAndRunScript(host => $host,
                                                 cmd => $cmd);

        $self->{'remoteObj'}->copyFileToDir(host => $host,
                                            file => "$self->{logdir}/${test}*",
                                            destdir => $params{logpath});
	
        $testresult = 
	    validateFastabEntries(
				  test => $test, 
				  logfile => "$params{logpath}/${test}.log",
				  extlogfile => "$params{logpath}/${test}_cmdextcode.log",
				  prj => $self->{prj}, 
				  drmode => $params{drmode},
				  podver => $params{podver}, 
				  zdtEnabled => $params{zdtEnabled},
				  logpath => $params{logpath});
	
        generateSummaryFile(test => $test, host => $host, cmd => $cmd,
                            logpath => $params{logpath},
                            user => $self->{user}, passwd => $self->{passwd},
                            logfile => "$params{logpath}/${test}.log",
                            testresult => $testresult);
    }
    return $testresult;
}

#
# Check mount points
# Input:
#     %mountHash => (host => test)
#     drmode => DR mode
#     logpath => log path
# Generate summary file
#
sub checkMountPoints {

    my ($self, %params) = @_;

    my ($cmd, $test, $testresult, $index, $host, $mountpoints, %mountHash);
	
    if ($params{podver} >= 11 or $params{zdtEnabled} eq "true") 
    {
	$mountpoints = "u01|u02";
    }
    else
    {
	$mountpoints = "u01";
    }
    
    for $test (keys %{$params{mountHash}}) {
	
        $host = $params{mountHash}{$test};
        $index = index($test, 'osn');
	
        if ($index > 0 ) {
            $cmd = "#!/bin/bash

                    if [ ! -d \"$self->{logdir}\" ]; then
                        mkdir -p \"$self->{logdir}\";
                    fi
                    rm -rf \"$self->{logdir}/$test*\";
                    `df -kh  |grep -EB 1 \"$mountpoints|osn_scratch\" | grep $self->{prj} > $self->{logdir}/${test}.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";
	    
        } else {
            $cmd = "#!/bin/bash

                    if [ ! -d \"$self->{logdir}\" ]; then
                        mkdir -p \"$self->{logdir}\";
                    fi
                    rm -rf \"$self->{logdir}/$test*\";
                    `df -kh  |grep -EB 1 \"$mountpoints\" | grep $self->{prj} > $self->{logdir}/${test}.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";
        }

        $self->{'remoteObj'}->createAndRunScript(host => $host,
                                                 cmd => $cmd);
	
        $self->{'remoteObj'}->copyFileToDir(host => $host,
                                            file => "$self->{logdir}/${test}*",
                                            destdir => $params{logpath});
	
        $testresult = 
	    validateMountpoints(
				test => $test,
				logfile => "$params{logpath}/${test}.log",
				extlogfile => "$params{logpath}/${test}_cmdextcode.log",
				prj => $self->{prj}, 
				drmode => $params{drmode},
				podver => $params{podver}, 
				zdtEnabled => $params{zdtEnabled},
				logpath => $params{logpath});
	
        generateSummaryFile(test => $test, host => $host, cmd => $cmd,
                            logpath => $params{logpath},
                            user => $self->{user}, passwd => $self->{passwd},
                            logfile => "$params{logpath}/${test}.log",
                            testresult => $testresult);
	
    }
    
    return $testresult;
}

#
# Check Health on Fa
# Input:
#     drmode => DR mode
#     logpath => log path
# Generate summary file
#
sub checkHealthOnFa {

    my ($self, %params) = @_;

    my ($cmd, $testresult, $primaryHCFilename, $Tests, $Success,
        $Errors, $Failures, $Warnings, $copyTo);
    my $test = "healthcheckonfa";

    $cmd = "#!/bin/bash

            if [ ! -d \"$self->{logdir}\" ]; then
                mkdir -p \"$self->{logdir}\";
            fi
            rm -rf \"$self->{logdir}/$test*\";
            export ORACLE_HOME=/u01/APPLTOP/fusionapps/applications;
            export APPLICATIONS_BASE=/u01/APPLTOP;
            export OHS_INSTANCE_ID=ohs1;
            export OHS_HOST_NAME=$self->{ohs_host};
            `/u01/APPLTOP/fusionapps/applications/lcm/hc/bin/hcplug.sh -manifest /u01/APPLTOP/fusionapps/applications/lcm/hc/config/SaaS/GeneralSystemHealthChecks.xml -DlogLevel=FINEST > $self->{logdir}/$test.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";

    $self->{'remoteObj'}->createAndRunScript(host => $params{host},
                                             cmd => $cmd);

    $self->{'remoteObj'}->copyFileToDir(host => $params{host},
                                        file => "$self->{logdir}/$test*",
                                        destdir => $params{logpath});

    $testresult = validateLog(
        test => $test, logpath => $params{logpath},
        logfile => "$params{logpath}/$test.log",
        extlogfile => "$params{logpath}/${test}_cmdextcode.log");

    generateSummaryFile(test => $test, host => $params{host},
                        cmd => $cmd, logpath => $params{logpath},
                        user => $self->{user}, passwd => $self->{passwd},
                        logfile => "$params{logpath}/$test.log",
                        testresult => $testresult);

    $primaryHCFilename = getHealthCheckFileName($self, host => $params{host},
                                                relver => $params{relver},
                                                test => "hcFileName",
                                                logpath => $params{logpath});
    chomp($primaryHCFilename);

    my($file, $dir, $ext) = fileparse($primaryHCFilename);

    $copyTo = "$params{logpath}/$file";

    $self->{'remoteObj'}->copyFileToDir(host => $params{host},
                                        file => "$primaryHCFilename",
                                        destdir => $params{logpath});

    $Tests = `grep -A 1 "Tests:" $copyTo | tail -1 | cut -d">" -f2 | cut -d"<" -f1`;
    chomp($Tests);

    $Success = `grep -A 1 "Success:" $copyTo | tail -1 | cut -d">" -f2 | cut -d"<" -f1`;
    chomp($Success);

    $Errors = `grep -A 1 "Errors:" $copyTo | tail -1 | cut -d">" -f2 | cut -d"<" -f1`;
    chomp($Errors);

    $Failures = `grep -A 1 "Failures:" $copyTo | tail -1 | cut -d">" -f2 | cut -d"<" -f1`;
    chomp($Failures);

    $Warnings = `grep -A 1 "Warnings:" $copyTo | tail -1 | cut -d">" -f2 | cut -d"<" -f1`;
    chomp($Warnings);

    open(FOUT, ">>$params{logpath}/testSummary.txt");
    print FOUT "*************Health Check Test Statuses************************************\n";
    print FOUT "Tests=$Tests\n";
    print FOUT "Success=$Success\n";
    print FOUT "Errors=$Errors\n";
    print FOUT "Failures=$Failures\n";
    print FOUT "Warnings=$Warnings\n";
    close(FOUT);

}

#
# Get Health check file name
# Input:
#     logpath => log path
# Return healthcheck file name
#
sub getHealthCheckFileName {

    my ($self, %params) = @_;

    my ($cmd, $testresult);
    my $test = "hcFileName";

    $cmd = "#!/bin/bash

            if [ ! -d \"$self->{logdir}\" ]; then
                mkdir -p \"$self->{logdir}\";
            fi
            rm -rf \"$self->{logdir}/$test*\";
            `ls -ltr /u01/APPLTOP/instance/lcm/logs/$params{relver}/healthchecker/*.html | awk '{print \$9}' | tail -1 > $self->{logdir}/$test.log; echo \$? > $self->{logdir}/${test}_cmdextcode.log`";

    $self->{'remoteObj'}->createAndRunScript(host => $params{host},,
                                             cmd => $cmd);

    $self->{'remoteObj'}->copyFileToDir(host => $params{host},
                                        file => "$self->{logdir}/$test*",
                                        destdir => $params{logpath});

    my $l = getLiner."\n";
    $l = $l."Time: ".getTime();

    open(FOUT, ">>$params{logpath}/testSummary.txt");
    print FOUT "$l\n";
    close(FOUT);

    my $primaryHCFilename = `cat "$params{logpath}/$test.log"`;
    print "FA HealthCheck Filename = $primaryHCFilename";

    generateSummaryFile(test => $test, host => $params{host},
                        cmd => $cmd, logpath => $params{logpath},
                        user => $self->{user}, passwd => $self->{passwd},
                        logfile => "$params{logpath}/$test.log");

    return $primaryHCFilename;
}

#
# Validate Servers logs
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     logpath => log path
# Returns status of test
#
sub validateServersLog {

    my (%params) = @_;

    my ($entries, $c);
    my $testresult = "Failed";
    my $errstr = "exception|ASMCMD-|error";
    my $searchstr = "Resuming|starting";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0 or
        $exit_code != 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {
        if (`grep -Ei '$searchstr' $params{logfile} |wc -l ` > 0) {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
            $testresult = "Failed";
        } else {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.suc.html");
            $testresult = "Passed";
        }
    }

    return $testresult;
}

#
# Validate Fastab entry logs
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     logpath => log path
# Returns status of test
#
sub validateFastabEntries {

    my (%params) = @_;

    my ($pjtcounts, $index, $c);
    my $errstr = "exception|error";
    my $searchstr = $params{prj};
    my $testresult = "Failed";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0 or
        $exit_code != 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {
	
        $index = index($params{test}, 'osn');
        if ($index > 0 ) {
            $pjtcounts = 2;
        } else {
            $pjtcounts = 1;
        }
	
	if($params{podver} >= 11 or $params{zdtEnabled} eq "true"){
	 if (($params{test} =~ m/^fstab(fa|primary|secondary|bi|osn|auxvm)/i)) {
	     $pjtcounts = $pjtcounts+1;
	 }
     }
	
        $c = `grep -Ei '$searchstr' $params{logfile} | wc -l`;
        if ($c == $pjtcounts ) {
	    
	    system("cp -rf $params{logfile} $params{logpath}/$params{test}.suc.html");
	    open OUT," > $params{logpath}/$params{test}.suc.html" or die "$!\n";
	    print OUT "Expected FsTab Entries: $pjtcounts\n";
	    print OUT "Actual FsTab Entries: $c\n";
	    close OUT;
            $testresult = "Passed";
        } else {
	    
            system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
	    open OUT," > $params{logpath}/$params{test}.dif.html" or die "$!\n";
	    print OUT "Expected FsTab Entries: $pjtcounts\n";
	    print OUT "Actual FsTab Entries: $c\n";
	    close OUT;
            $testresult = "Failed";
        }
    }
    
    return $testresult;
}

#
# Validate mount points logs
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     drmode => DR mode
#     logpath => log path
# Returns status of test
#
sub validateMountpoints {

    my (%params) = @_;

    my ($entries, $c);
    my $errstr = "exception|error";
    my $searchstr = $params{prj};
    my $testresult = "Failed";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0) {
    #    $exit_code != 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {

        $c = `grep -Ei '$searchstr' $params{logfile} | wc -l`;
        chomp($c);

        if ($params{drmode} eq 'ACTIVE') {
            my $index = index($params{test}, 'osn');
            if ($index > 0 ) {
                $entries = 2;
            } else {
                $entries = 1;
            }
	    if($params{podver} >= 11 or $params{zdtEnabled} eq "true")
	    {
		if(($params{test} =~ m/^(fa|primary|secondary|bi|osn|auxvm)/i))
		{
		    $entries = $entries+1;
		}
	    }
        } else {
            $entries = 0;
        }
        if ($c == $entries ) {
	    
            system("cp -rf $params{logfile} $params{logpath}/$params{test}.suc.html");
	    open OUT," > $params{logpath}/$params{test}.suc.html" or die "$!\n";
	    print OUT "Expected Mount points: $entries\n";
	    print OUT "Actual Mount points: $c\n";
	    close OUT;
            $testresult = "Passed";
        } else {
	    
            system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
	    open OUT," > $params{logpath}/$params{test}.dif.html" or die "$!\n";
	    print OUT "Expected Mount points: $entries\n";
	    print OUT "Actual Mount points: $c\n";
	    close OUT;
            $testresult = "Failed";
        }
    }
    
    return $testresult;
}

#
# Validate health log
# Input:
#     test => test name
#     logfile => log file name
#     extlogfile => exit log file name
#     logpath => log path
# Returns status of test
#
sub validateLog {

    my (%params) = @_;

    my $errstr = "exception|locked|error";
    my $searchstr = "plugin failed";
    my $testresult = "Failed";

    my $exit_code =  `cat $params{extlogfile}`;
    chomp($exit_code);

    if (`grep -Ei '$errstr' $params{logfile} |wc -l ` > 0 or
        $exit_code != 0) {

        system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
        $testresult = "Failed";
    } else {

        if (`grep -Ei '$searchstr' $params{logfile} | wc -l` > 0 ) {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.dif.html");
            $testresult = "Failed";
        } else {

            system("cp -rf $params{logfile} $params{logpath}/$params{test}.suc.html");
            $testresult = "Passed";
        }
    }

    return $testresult;
}

1;
