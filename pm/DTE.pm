use strict;
use Options;

package DTE;

# This is a frontend package for DTE command line run_one_job and
# jobReqAgent The api's run_one_job and jobReqAgent will build the DTE
# command and append the required GTLF parameters for the generation
# of GTLF file and upload to Sapphire.

#
# API to execute run_one_job
# Parameters are passed in a hash
# topoid => Id of the topology being run
# toposetMemberID => Id of the toposetMember
# TESTNAME => Name of the Test Unit in sapphire to which results
#             need to be uploaded.
# options => User input params hash as returned by Options::get_options
# cmd_line => The command line that needs to be appended to run_one_job,
#             it must include the dte params like -noproxy -e emaild
#             OVM_DEPLOY_PROPERTIES_FILE='/u01/....' , topo information will be
#             taken care by the api.
#
sub run_one_job
{
    my (%params) = @_;

    die('TESTNAME is missing')
        if (!exists $params{TESTNAME} or $params{TESTNAME} eq '');

    check_auto_home($params{options});
    check_auto_work($params{options});
    check_run_one_job($params{options});

    $params{options}->{tmp_dir} = "/tmp"
        unless (exists $params{options}->{tmp_dir});
    my $gtlf_opts =
        Options::get_gtlf_options(TESTNAME => $params{TESTNAME},
                                  RunKey => $params{options}->{RunKey},
                                  pillar => $params{options}->{pillar},
                                  stage => $params{options}->{stage},
                                  SAPPHIRE_UPLOAD =>
                                  $params{options}->{SAPPHIRE_UPLOAD},
                                  tmp_dir => $params{options}->{tmp_dir}
                                 );

    $params{topoid} = $params{topo_id} if (exists $params{topo_id});
    my $topo_info = _get_topo_info(%params);
    my $dte_cmd = "export AUTO_HOME=$params{options}->{AUTO_HOME};".
        "export AUTO_WORK=$params{options}->{AUTO_WORK};".
        "$params{options}->{run_one_job} $topo_info -report $params{cmd_line} ".
        "$gtlf_opts";

    my $work_dir = "$params{options}->{AUTO_WORK}/oracle/work";
    `mkdir -p $work_dir`;
    die("Unable to create $work_dir") unless (-d "$work_dir");

    print "DTE Command : \n$dte_cmd\n";
    if ($params{options}->{norun} ne 'yes')
    {
        # Create an info file with command line arguments.
        open(FH,">$work_dir/dte_cmd.info")
            or die("Unable to create $work_dir/dte_cmd.info");
        print FH "$dte_cmd\n";
        close(FH);

        my @output = `$dte_cmd`;
        print @output;
    }

    print "DTE Command : \n$dte_cmd\n";
}

#
# API to execute jobReqAgent
# Parameters are passed in a hash
# topoid => Id of the topology being run
# toposetMemberID => Ids of the toposetMember
# toposetSubsetID => Ids of the toposetSubsetId
# TESTNAME => Name of the Test Unit in sapphire to which results
#             need to be uploaded.
# options => User input params hash as returned by Options::get_options
# cmd_line => The command line that needs to be appended to run_one_job,
#             it must include the dte params like -noproxy -e emaild
#             OVM_DEPLOY_PROPERTIES_FILE='/u01/....' , topo information will be
#             taken care by the api.
#
sub jobReqAgent
{
    my (%params) = @_;

    die('TESTNAME is missing')
        if (!exists $params{TESTNAME} or $params{TESTNAME} eq '');

    check_jobReqAgent($params{options});

    die("Option 'tmp_dir' must be accesible over /net, give a value like /net/slc06xjl/scratch/aime")
        if ($params{options}->{tmp_dir} !~ /^\/net\/[^\/]+?\/scratch\/.*$/);

    my $gtlf_opts =
        Options::get_gtlf_options(TESTNAME => $params{TESTNAME},
                                  RunKey => $params{options}->{RunKey},
                                  pillar => $params{options}->{pillar},
                                  stage => $params{options}->{stage},
                                  SAPPHIRE_UPLOAD =>
                                  $params{options}->{SAPPHIRE_UPLOAD},
                                  tmp_dir => $params{options}->{tmp_dir}
                                 );
    my $topo_info = _get_topo_info(%params);
    my $dte_cmd =
        "$params{options}->{jobReqAgent} $topo_info $params{cmd_line} ".
            " $gtlf_opts";

    print "DTE Command : \n$dte_cmd\n";
    if ($params{options}->{norun} ne 'yes')
    {
        my @output = `$dte_cmd`;
        print @output;
        print "DTE Command : \n$dte_cmd\n";
    }


}

sub _get_topo_info
{
    my (%params) = @_;

    my $topo_info;
    $params{topoid} = $params{topo_id} if (exists $params{topo_id});
    if (exists $params{topoid})
    {
        $topo_info = "-topoid $params{topoid}";
    }
    if (exists $params{toposetid})
    {
        $topo_info = "-toposetid $params{toposetid}";
        if (exists $params{toposetMemberID})
        {
            $topo_info .= " -toposetMemberID $params{toposetMemberID}";
        }
        if (exists $params{toposetSubsetID})
        {
            $topo_info .= " -toposetSubsetID $params{toposetSubsetID}";
        }
    }

    return $topo_info;
}


sub check_auto_home
{
    my ($options) = @_;

    die ("AUTO_HOME is not set") if ($options->{AUTO_HOME} eq '');
    die ("AUTO_HOME " . $options->{AUTO_HOME} . " does not exist")
        unless(-d $options->{AUTO_HOME});
}

sub check_auto_work
{
    my ($options) = @_;

    die ("AUTO_WORK is not set") if ($options->{AUTO_WORK} eq '');
    `mkdir -p $options->{AUTO_WORK}`;
    die ("AUTO_WORK " . $options->{AUTO_WORK} . " is not a directory")
        unless (-d $options->{AUTO_WORK});

    open(FH, ">$options->{AUTO_WORK}/test.$$") or
        die ("$options->{AUTO_WORK} is not writable");
    close(FH);

    `rm $options->{AUTO_WORK}/test.$$`;

    if (-d $options->{AUTO_WORK} . "/oracle/work")
    {
        open(FH, ">$options->{AUTO_WORK}/oracle/work/test.$$") or
        die ("$options->{AUTO_WORK}/oracle/work is not writable");
        close(FH);
        `rm $options->{AUTO_WORK}/oracle/work/test.$$`;

        my @wc = `ls -ltr $options->{AUTO_WORK}/oracle/work | wc -l`;
        my $wc = join('',@wc);
        chomp($wc);

        die("$options->{AUTO_WORK}/oracle/work is not empty") if ($wc > 1);
    }

}

sub check_run_one_job
{
    my ($options) = @_;

    $options->{run_one_job} =
        "/usr/local/packages/aime/dte/DTE3/bin/run_one_job"
            if ($options->{run_one_job} eq '');

    die("$options->{run_one_job} does not exist")
        unless (-f $options->{run_one_job});
}

sub check_jobReqAgent
{
    my ($options) = @_;

    $options->{jobReqAgent} =
        "/usr/local/packages/aime/dte/DTE3/bin/jobReqAgent"
            if ($options->{jobReqAgent} eq '');

    die("$options->{jobReqAgent} does not exist")
        unless (-f $options->{jobReqAgent});
}

1;
