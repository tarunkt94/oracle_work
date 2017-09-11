package GenerateHtml;

use strict;
use Util;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(generateHTMLReport getBlockDescription);

#
# Check generated files and create html report
# Input logdir => work directory name
#       drmode => DR mode
#       logpath => log path
#       url => url
#       mailids => complete mail id
# Generate HTML Report
#
sub generateHTMLReport {

    my (%params) = @_;

    open(tmpfh, "$params{logdir}/report.txt");

    chdir($params{logpath});

    my $testCaseNames = `ls -tr *.suc.html *.dif.html > $params{logdir}/testCases.txt`;
    my $time = getTime();
    
    my $hostname = `hostname -f`;
    chomp($hostname);
    
    my $wrkdir = "/net/".$hostname."$params{logdir}";
    chomp($wrkdir);
    my $result;
    
    my $drm = ucfirst($params{drmode});
    
    open(FTEMP,">$params{logpath}/results.html");
    open(tmpfh, "$params{logdir}/testCases.txt");
    print FTEMP "<font style='OraHeaderSubSub'>SDI Host: $params{host}, DR MODE: $drm</font>";
    print FTEMP "<table width = 90% border=\"0\"><tr bgcolor=#56A5EC><th>S.No.<\/th><th>Testcase Name<\/th><th>Description <\/th><th><font>Result<\/font><\/th><\/tr>";
    
    my $count = 1;
    while (<tmpfh>) {
        chomp;
        s/.html$//;
        my $fileExtension = substr($_, -3);
        my $length =  length($_);
        my $testName = substr($_, 0, $length-4);
        if ($fileExtension eq 'dif') {
            if ($params{url})
            {
		$result = "<a href='$params{url}/$testName.dif.html'><font color=red>FAILED</font></a>";
            }
            else
            {
		$result = "<font color=red>FAILED</font>";
            }
        } else {
            if ($params{url}) {
		$result = "<a href='$params{url}/$testName.suc.html'><font color=green>PASSED</font></a>";
            } else {
                $result = "<font color=green>PASSED</font>";
            }
        }
	
        my $des = getBlockDescription(testname => $testName, 
				      podver => $params{podver},
				      drmode => $params{drmode},
				      zdtEnabled => $params{zdtEnabled});
	
	
        $b = uc($testName);
	
        print FTEMP "\n<tr bgcolor = #E7F1FE><td align=CENTER><b>$count<\/b><\/td><td align=left><b>$b<\/b><\/td><td align=left><b>$des<\/b><\/td><td align=CENTER><b>$result<\/b><\/td><\/tr>";
	    $count++;
    }
    close(repfh);
    print FTEMP "<\/table>";
    close(FTEMP);
}

#
# Check testname and provide description
# Input testname => testcase name
#       drmode => DR mode
# Return description of given testCase
#
sub getBlockDescription {
    
    my (%params) = @_;
    
    my $desc = '';
    my $tname = uc $params{testname};
    
    if ($tname =~ /dgmgrl_fa_rac1/i or $tname =~ /dgmgrl_fa_rac2/i or
        $tname =~ /dgmgrl_oid_rac1/i or $tname =~ /dgmgrl_oid_rac2/i or
        $tname =~ /dgmgrl_oim_rac1/i or $tname =~ /dgmgrl_oim_rac2/i) {
	
        if ($params{drmode} eq 'ACTIVE' or $params{drmode} eq 'PRIMARY') {
            $desc = "Check DB instance is in 'Primary database' ";
        } else {
            $desc = "Check DB instance is in 'Physical standby database' ";
        }
    } 
    elsif ($tname =~ /openmode_fa_rac1/i or $tname =~ /openmode_fa_rac2/i or
	   $tname =~ /openmode_oid_rac1/i or $tname =~ /openmode_oid_rac2/i or
	   $tname =~ /openmode_oim_rac1/i or $tname =~ /openmode_oim_rac2/i) {
	
	if ($params{drmode} eq 'ACTIVE' or $params{drmode} eq 'PRIMARY') {
	    $desc = "Check DB instance is 'READ WRITE' ";
	} else {
	    $desc = "Check DB instance is 'READ ONLY WITH APPLY' ";
	}
    } 
    elsif ($tname =~ /listener_fa_rac1/i or $tname =~ /listener_fa_rac2/i or
	   $tname =~ /listener_oid_rac1/i or $tname =~ /listener_oid_rac2/i or
	   $tname =~ /listener_oim_rac1/i or $tname =~ /listener_oim_rac2/i) {
	
        $desc = "Check DB instance Listener is enabled and running ";
    } 
    elsif ($tname =~ /fstabfa/i or $tname =~ /fstabprimary/i or 
	   $tname =~ /fstabsecondary/i or $tname =~ /fstabohs/i or
	   $tname =~ /fstabosn/i or $tname =~ /fstabbi/i or
	   $tname =~ /fstaboid/i or $tname =~ /fstaboim/i or
	   $tname =~ /fstabprimaryha1/i or $tname =~ /fstabsecondaryha1/i or
	   $tname =~ /fstabosnha1/i or $tname =~ /fstab/i) {
	
        if ($params{drmode} eq 'ACTIVE') {
            $desc = "Check the project existed under FSTAB ";
        } else {
            $desc = "Check the project existed under FSTAB ";
        }
    } 
    elsif (($tname =~ /fau01mp/i or $tname =~ /primaryu01mp/i or
	    $tname =~ /secondaryu01mp/i  or
	    $tname =~ /osnu01mp/i or $tname =~ /biu01mp/i or             
	    $tname =~ /primaryha1u01mp/i or $tname =~ /secondaryha1u01mp/i or
	    $tname =~ /osnha1u01mp/i or $tname =~ /scale/i or 
	    $tname =~ /auxvm/i) and 
	   ($params{podver} >= 11 or $params{zdtEnabled} eq "true")) {
	
        if ($params{drmode} eq 'ACTIVE') {
            $desc = "check u01 and u02 are mounted ";
        } else {
            $desc = "Check u01 and u02 are not mounted ";
        }
    }
    elsif ($tname =~ /fau01mp/i or $tname =~ /primaryu01mp/i or
	   $tname =~ /secondaryu01mp/i or $tname =~ /ohsu01mp/i or
	   $tname =~ /osnu01mp/i or $tname =~ /biu01mp/i or
	   $tname =~ /oidu01mp/i or $tname =~ /oimu01mp/i or
	   $tname =~ /ohsha1u01mp/i or $tname =~ /webgateu01mp/i or
	   $tname =~ /primaryha1u01mp/i or $tname =~ /secondaryha1u01mp/i or
	   $tname =~ /osnha1u01mp/i or $tname =~ /scale/i) {
	
        if ($params{drmode} eq 'ACTIVE') {
            $desc = "check u01 is mounted ";
        } else {
            $desc = "Check u01 is not mounted ";
        }
    } elsif ($tname =~ /asm_fa_rac1/i or $tname =~ /asm_fa_rac2/i or
             $tname =~ /asm_oid_rac1/i or $tname =~ /asm_oid_rac2/i or
             $tname =~ /asm_oim_rac1/i or $tname =~ /asm_oim_rac2/i) {
        $desc = "Check DB instance spfile is existed in ASM disk ";
	
    } elsif ($tname =~ /fafactrlstatus/i) {
        $desc = "Check to verify FA servers are in running state ";
	
    } elsif ($tname =~ /oimfactrlstatus/i) {
        $desc = "Check to verify OIM servers are in running state ";
	
    } elsif ($tname =~ /healthcheckonfa/i) {
        $desc = "Triggers health check on FA admin host ";
	
    } elsif ($tname =~ /sunprojectstatus/i) {
        $desc = "Check the project existed under Sun Storage ";
	
    } elsif ($tname =~ /ssreplication/i) {
        $desc = "Check the project replication status ";
    }
    elsif ($tname =~ /SGCPlansTest/i) {
        $desc = "Check the Site Guard Operations Plans status ";
    }
    elsif ($tname =~ /EMPodRoleTest/i) {
        $desc = "Check the Pod Role in Enterprise Manager ";
    }
    
    return $desc;
}

1;
