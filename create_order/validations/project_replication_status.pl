use strict;
use Getopt::Long;

BEGIN {
    push @INC, "$ENV{SAASQA_HOME}/pm";
}

use RemoteCmd;
use DoSystemCmd;

my %p;
get_input(\%p);

my $log = Logger->new(
                  {'loggerLogFile' => "$p{wdir}/project_replication_status.log",
                   'maxLogLevel' => 4}
                     );
my $system = DoSystemCmd->new({filehandle => \*STDOUT});
my $prcmd = RemoteCmd->new(user => $p{trusted_user},
                           passwd => $p{trusted_passwd},
                           logObj => $log);

my $repl = check_replication();


sub get_input
{
    my ($p) = @_;

    GetOptions($p,
               'wdir=s',
               'trusted_host=s',
               'trusted_user=s',
               'trusted_passwd=s',
               'project=s',
               'replication_label=s',
               'filer=s',
               'filer_user=s');

    foreach my $o (qw (wdir trusted_host trusted_user trusted_passwd project
                       replication_label filer filer_user))
    {
        if ($p{$o} eq '')
        {
            print "Parameter $o is missing\n";
            usage();
        }
    }
}

sub usage
{
    print <<EOF;
Usage :
      perl replication.pl --wdir=<work directory for logs>
             --trusted_host=<host where auto login to filer is setup>
             --trusted_user=<os user of trusted host>
             --trusted_passwd=<os user passwd of trusted host>
             --project=<zfs project to enable replication>
             --replication_label=<replicaton target label name>
             --filer=<source filer where project exists>
             --filer_user=<filer user>
EOF
    exit;
}



sub check_replication
{

    my $file = "check_replication_$$.sh";
    open(FILE, ">$p{wdir}/$file");
    print FILE <<EOFILE;
ssh -T -o ServerAliveInterval=60  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $p{filer_user}\@$p{filer}<<EOF
script
run('configuration services replication targets');
var targets = list();
var label;
var id;
for(i=0; i<targets.length; i++)
{
    run('select ' + targets[i]);
    id = get('id');
    label = get('label');
    if (label == '$p{replication_label}')
    {
       break;
    }
}

if (label != '$p{replication_label}')
{
    printf('$p{replication_label} not found');
}
else
{
    run('cd /');
    run('shares select $p{project} replication');
    var actions = list();
    for(i=0; i<actions.length; i++)
    {
       run('select ' + actions[i]);
       var target = get('target');
       var enabled = get('enabled');
       if (id == target)
       {
           printf('%s enabled %s action %s', label, enabled, actions[i]);
           run('done');
           break;
       }
    }
    run('done');
}
.
EOF
EOFILE

    close(FILE);

    $prcmd->copyFileToHost(host => $p{trusted_host},
                           file => "$p{wdir}/$file",
                           dest => "/tmp");

    my $out = $prcmd->executeCommandsonRemote(host => $p{trusted_host},
                                              cmd  => "sh /tmp/$file");

    foreach my $line (@$out)
    {
        chomp($line);
        if ($line =~ /^$p{replication_label} enabled true/)
        {
            print "$line\n";
            return 1;
        }
    }
}


