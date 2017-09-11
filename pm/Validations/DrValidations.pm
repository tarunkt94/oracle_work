package DrValidations;

use strict;
use warnings;
use Cwd;
use File::Basename;
use Validations::DB;

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
use RemoteCmd;
use SDI;
use FAPod;
use Mail;
use Logger;
use SunStorage;
use GenerateHtml;


### Constructor
sub new {

    my ($class, %args) = @_;

    my $self = {
        logdir => $args{logdir},
        logObj => $args{logObj},
        config => $args{config},
        host => $args{host},
    };

    bless($self, $class);

    $self->{'sdiObj'} = SDI->new(user => $self->{config}{'SDIUSER'},
                                 passwd => $self->{config}{'SDIPASSWD'},
                                 sdiscript => $self->{config}{'SDISCRIPT'},
                                 host => $self->{host},
                                 logObj => $self->{'logObj'});

    $self->{'remoteObj'} = RemoteCmd->new('user' => $self->{config}{'REMOTEUSER'},
		                          'passwd' => $self->{config}{'REMOTEPASSWD'},
		                          'logObj' => $self->{'logObj'});

    $self->{'VMRemoteObj'} = RemoteCmd->new(user => $self->{config}{'VMUSER'},
                                            passwd => $self->{config}{'VMPASSWD'},
                                            logObj => $self->{logObj});

    return $self;
}

sub drValidations {

    my ($self, %params) = @_;

    my($logpath, $ovm_dir, $ovm_file_path, $ovm_prop_file, $ovmfile,
       $podver, %podDetails, %faenvs, %templateDetails, $dbObj);

    my (@paths) = split('/', $params{logdir});
    my $logdir = pop @paths;

    $ovm_dir = $self->{'sdiObj'}->
        getOvmFileDir(system_name => $params{system_name},
                      template => $self->{config}{'TEMPLATE'});
    
    %podDetails = $self->{'sdiObj'}->
        getPodDetails(system_name => $params{system_name});
    
    if ($podDetails{'poddesignator'} eq 'PRIMARY') {
        $logpath = "$params{logdir}/logs/primary";
        $params{url} .= "/$logdir/logs/primary" if ($params{url});
    } elsif ($podDetails{'poddesignator'} eq 'STANDBY') {
        $logpath = "$params{logdir}/logs/standby";
        $params{url} .= "/$logdir/logs/standby" if ($params{url});
    }

    die ("Invalid DR MODE\n") if (!$logpath);

    system("mkdir -p $logpath");

    $ovm_file_path = "$ovm_dir/$podDetails{'service_name'}/deployfw/deployprops";
    $ovm_prop_file = "$ovm_file_path/ovm-ha-deploy.properties";
    $ovmfile = basename("$ovm_prop_file");

    my $relname = `echo $ovm_prop_file | awk -F '/' '{print \$3}'`;
    $relname =~ s/\n$//g;
    $relname =~ s/\r$//g;

    my $cmd = "\"test -f $ovm_prop_file ; echo \$?\"";

    my $filter = "awk ' { if (\$1 !~ /spawn|aime|ssh|exit|" .
                 "Authorized|Warning|Offending|Matching/) print}'";

    my $out = $self->{'remoteObj'}->
        executeCommandsonRemote(host => $self->{host},
                                cmd => "$cmd",
                                filter => "$filter");
    
    # $out equal to 1 indicates file not found, 0 indicates found.

    if($out->[0] == 1) {
        $ovm_prop_file = "$ovm_dir/$podDetails{'service_name'}/standby";
        $ovm_prop_file .= "/deployfw/deployprops/ovm-ha-deploy.properties";
    }
    
    %templateDetails = $self->{'sdiObj'}->
        getTemplateDetails(relname => $relname);
    
    $podver = (split /\./, $templateDetails{0}{'relver'})[2];
    
    $self->{'remoteObj'}->copyFileToDir(host => $self->{host},
                                        file => $ovm_prop_file,
                                        destdir => $logpath);

    %faenvs = getFaEnv("$logpath/ovm-ha-deploy.properties");

    my $fahost = $faenvs{"faovm.ha.HOST_FA"};

    $cmd = "\"grep -q u02 /etc/fstab; test \$? -eq 0 && echo true || echo false\"";
    
    $filter = " awk ' { if (\$1 !~ (/spawn|ssh|exit|Authorized|";
    $filter .= "Warning|Offending|Matching|$fahost|^\$/) ) print }'";
    
    $out = $self->{'VMRemoteObj'}->
	executeCommandsonRemote(host => $fahost,
				cmd => "$cmd",
				filter => "$filter");
    
    my $zdtEnabled = @$out[0];
    $zdtEnabled =~ s/\r?\n//g;
    
    
    if ($params{'action'} =~ m/validatePodRoleInEM|ValidateAll/) {
        $params{'emObj'}->
            validatePodRoleInEM(OMS_HOST => $faenvs{'faovm.emagent.oms.host'},
                                oms_system => $faenvs{'faovm.oms.target.name'},
                                drmode => $podDetails{'role'},
                                logpath => $logpath);
    }
   
    if ($podDetails{'poddesignator'} eq 'PRIMARY') {
        $dbObj = new Validations::DB(user => $self->{config}{'DBPRIMARYUSER'},
	                             passwd => $self->{config}{'DBPRIMARYPASSWD'},
                                     host => $self->{host},
                                     logObj => $self->{logObj},
                                     faenvs => \%faenvs);
    } else {
        $dbObj = new Validations::DB(user => $self->{config}{'DBSTANDBYUSER'},
	                             passwd => $self->{config}{'DBSTANDBYPASSWD'},
                                     host => $self->{host},
                                     logObj => $self->{logObj},
                                     faenvs => \%faenvs);
    }
    
    if ($params{'action'} =~ m/validateDataGuard|ValidateAll/) {
        $dbObj->checkDg(logpath => $logpath, drmode => $podDetails{'role'});
    }
    
    if ($params{'action'} =~ m/checkListenerStatus|ValidateAll/) {
        $dbObj->checkListener(logpath => $logpath);
    }
    
    if ($params{'action'} =~ m/checkASMDB|ValidateAll/) {
        $dbObj->checkAsmDb(logpath => $logpath);
    }
    
    if ($params{'action'} =~ m/checkDatabaseMode|ValidateAll/) {
        $dbObj->checkOpenModeDb(logpath => $logpath,
                                drmode => $podDetails{'role'});
    }
    
    my $fapodObj = new FAPod(user => $self->{config}{'VMUSER'},
			     passwd => $self->{config}{'VMPASSWD'},
			     logObj => $self->{logObj},
			     faenvs => \%faenvs);
    
    if ($params{'action'} =~ m/checkFsTabInfo|ValidateAll/) {
        my %fstabHash = $fapodObj->createFstabHash();
        $fapodObj->checkFstabInfo(fstabHash => \%fstabHash,
                                  podver => $podver,
                                  drmode => $podDetails{'role'},
                                  zdtEnabled =>	$zdtEnabled,
                                  logpath => $logpath);
    }
    
    if ($params{'action'} =~ m/checkMountPoints|ValidateAll/) {
        my %mountHash = $fapodObj->createMountHash();
        $fapodObj->checkMountPoints(mountHash => \%mountHash,
                                    podver => $podver,
                                    drmode => $podDetails{'role'},
                                    zdtEnabled => $zdtEnabled,
                                    logpath => $logpath);
    }
    
    if ($params{'action'} =~ m/checkForScaleoutHosts|ValidateAll/) {
        $fapodObj->checkForScaleoutHosts(logdir => $params{logdir},
                                         logpath => $logpath,
                                         podver => $podver,
                                         drmode => $podDetails{'role'},
                                         zdtEnabled => $zdtEnabled,
                                         ovmfile => $ovmfile);
    }
    
    if ($podDetails{'role'} eq 'ACTIVE') {
        if ($params{'action'} =~ m/checkFAServersStatus|ValidateAll/) {
            $fapodObj->checkFAServersStatus(logpath => $logpath,
                                            host => $faenvs{'faovm.ha.HOST_FA'});
        }

        if ($params{'action'} =~ m/checkOIMServersStatus|ValidateAll/) {
            $fapodObj->checkOIMServersStatus(host => $faenvs{'faovm.ha.HOST_OIM'},
                                             logpath => $logpath);
        }

        if ($params{'action'} =~ m/checkHealthOnFa|ValidateAll/) {
             $fapodObj->checkHealthOnFa(host => $faenvs{'faovm.ha.HOST_FA'},
                                        ohs_host => $faenvs{'faovm.ha.HOST_OHS'},
                                        logpath => $logpath,
                                        relver => $templateDetails{'relver'});
        }
    }
    
    my $sunprj = $faenvs{'faovm.storage.sun.project'};
    my $storage = $faenvs{'faovm.storage.sun.host'};
    
    my $sunObj = new SunStorage(user => $self->{config}{'FAUSER'},
                                passwd => $self->{config}{'FAPASSWD'},
                                sunprj => $sunprj, storage => $storage);
    
    if ($params{'action'} =~ m/checkSunStoragePrj|ValidateAll/) {
        $sunObj->checkSunStoragePrj(logpath => $logpath,
                                    scriptDir => "$params{scriptDir}");
    }
    
    if ($params{'action'} =~ m/checkReplicationStatus|ValidateAll/) {
        $sunObj->checkReplicationStatus(scriptDir => $params{scriptDir},
                                        logpath => $logpath,
                                        drmode => $podDetails{'role'});
    }
   
    system("sed -i '1i <pre>' $logpath/*.html");
    system("sed -i '\$a </pre>' $logpath/*.html");
 
    generateHTMLReport(logdir => $params{logdir}, logpath => $logpath,
                       podver => $podver,
		       drmode => $podDetails{'role'},
		       zdtEnabled => $zdtEnabled,
                       mailids => $params{mailids},
                       url => $params{url},
                       host => $self->{host});

}

1;
