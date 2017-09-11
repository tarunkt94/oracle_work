use strict;
use Getopt::Long;
use Conf;

package Options;

my $usage = "Usage and Options:\nperl $0 ";

sub get_options
{
    my (@options) = @_;
    my %options;

    check_shell();

    my (@get_options,@must);

    push @options, ('*e:Comma seperated list of email ids',
                    '*stage:Stage or Drop of the Release',
                    '*pillar:Product pillar, values can be CRM,GSI,HCM',
                    'SAPPHIRE_UPLOAD:To upload sapphire results or not,default value is true',
                    'HOSTNAME:Hostname if required by DTE, takes current host as default',
                    'norun:Debug param to check DTE command, default value is no. Pass \'yes\' to debug',
                    'AUTO_WORK:Auto Work directory, takes ENV value if not passed',
                    'AUTO_HOME:Auto Home directory, takes ENV value or script defined value as default',
                    'skip:To skip any DTE Blocks',
                    'RunKey: Unique identifier for a sapphire upload',
                    'tmp_dir: Temporary writable directory to create misc files, default value is /tmp');

    foreach my $opt (sort @options)
    {
        my $comment;
        if ($opt =~ s/^(.*?):(.*)$/$1/)
        {
            $comment = "$2";
        }

        $usage .= "\n  $opt";
        $usage .= ":\n\t$comment" if ($comment ne '');

        if ($opt =~ s/^\*//)
        {
            push @must, $opt;
        }

        push @get_options, "$opt=s";
    }

    $usage .= "\n\nLegend : * - Mandatory options";
    push @get_options, 'help';

    Getopt::Long::GetOptions(\%options, @get_options);

    if ($options{help})
    {
       print "$usage\n";
       exit 0;
    }

    #Add Default hostname
    if ($options{HOSTNAME} eq '')
    {
        my $hostname = `hostname`;
        chomp($hostname);
        $options{HOSTNAME} = $hostname;
    }

    if ($ENV{AUTO_HOME} ne '' and !exists $options{AUTO_HOME})
    {
        $options{AUTO_HOME} = $ENV{AUTO_HOME};
    }
    if ($ENV{AUTO_WORK} ne '' and !exists $options{AUTO_WORK})
    {
        $options{AUTO_WORK} = $ENV{AUTO_WORK};
    }

    validate(\%options, \@must);

    return %options;
}

sub validate
{
    my ($options, $must) = @_;

    my @missing;
    foreach my $opt (@$must)
    {
        push @missing, $opt if (!exists $options->{$opt} or
                                $options->{$opt} eq '');
    }

    if (scalar @missing)
    {
        die("Options '" . join("','", @missing) . "' are mandatory\n$usage");
    }

    check_email($options->{e});
    check_stage_pillar($options);
}

sub check_stage_pillar
{
    my ($options) = @_;

    my $sf_release = Conf::get_sf_release();
    my @stages = Conf::get_release_stages();
    my @pillars = Conf::get_pillars();

    my $stage_rgx = join("|", @stages);
    die("Stage " . $options->{stage} .
        " doesnot exist for release $sf_release. '" . join("','", @stages) .
        "' are the only allowed stages")
        if ($options->{stage} !~ /^($stage_rgx)$/);

    my $pillar_rgx = join("|", @pillars);
    die("Pillar $options->{pillar} is invalid. '" . join("','", @pillars) .
        "' are the only allowd pillars")
        if ($options->{pillar} !~ /^($pillar_rgx)$/);
}


sub get_gtlf_options
{
    my (%options) = @_;

    check_stage_pillar(\%options);
    my $sf_release = Conf::get_sf_release();

    my $runkey = $options{TESTNAME};
    $runkey .= "::$options{RunKey}" if ($options{RunKey});

    open(FH, ">$options{tmp_dir}/gtlf.$$.prop") ||
        die("Cannot write $options{tmp_dir}/gtlf.$$.prop");
    print FH "gtlf.env.Secondary_Config=" . $options{pillar} . "\n";
    print FH "gtlf.env.RunKey=" . "$runkey\n";
    print FH "gtlf.execaccount=guest\n";
    close(FH);

    my $sapphire_upload='SAPPHIRE_UPLOAD=true';
    $sapphire_upload=''
        if (exists $options{SAPPHIRE_UPLOAD} and
            $options{SAPPHIRE_UPLOAD} eq 'false');

    return "TESTNAME=$options{TESTNAME} GTLF_RELEASE='$sf_release' ".
        "GTLF_STAGE=$options{stage} ".
        "GTLF_STRING=4 PropertyFile=$options{tmp_dir}/gtlf.$$.prop ".
        "$sapphire_upload";
}

#
# Checks if a file exists
# Options :
# file => File name
#
# Returns 1 on valid file, dies for invalid file
#
sub check_file
{
    my (%options) = @_;

    if (-f $options{file})
    {
        if (-s $options{file})
        {
            return 1;
        }

        die("$options{file} is empty");
    }
    else
    {
        die("$options{file} does not exist");
    }
}

#
# Check Emails
#
sub check_email
{
    my ($emails) = @_;

    foreach my $email (split(',', $emails))
    {
        die ("Invalid email id $email")
            if ($email !~ /^[\w\.]+?\@oracle\.com/);
    }
}

#
# Shell must be always bash
#
sub check_shell
{
    my @shell = `echo \$BASH`;
    die("Change to 'bash' shell") if ($shell[0] =~ /Undefined variable/s);
}

1;
