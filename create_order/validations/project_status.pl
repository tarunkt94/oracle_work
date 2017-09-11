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
                  {'loggerLogFile' => "$p{wdir}/project_status.log",
                   'maxLogLevel' => 4}
                     );
my $system = DoSystemCmd->new({filehandle => \*STDOUT});
my $prcmd = RemoteCmd->new(user => $p{trusted_user},
                           passwd => $p{trusted_passwd},
                           logObj => $log);

my $proj_status = check_project();

##perl project_status.pl -wdir /scratch/aime/tarun/create_order/validations/ -trusted_host slc03why -trusted_user aime -trusted_passwd 2cool -project fa_fadrsdigsiser2017175 -proj_avbl YES -clone_status NO -filer slcnas570 -filer_user fadr

sub get_input
{
    my ($p) = @_;

    GetOptions($p,
               'wdir=s',
               'trusted_host=s',
               'trusted_user=s',
               'trusted_passwd=s',
               'project=s',
               'filer=s',
               'filer_user=s');

    foreach my $o (qw (wdir trusted_host trusted_user trusted_passwd project
                       filer filer_user))
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
      perl project_status.pl --wdir=<work directory for logs>
             --trusted_host=<host where auto login to filer is setup>
             --trusted_user=<os user of trusted host>
             --trusted_passwd=<os user passwd of trusted host>
             --project=<zfs project to enable replication>
             --filer=<source filer where project exists>
             --filer_user=<filer user>
EOF
    exit;
}



sub check_project
{

    my $file = "check_project_$$.sh";
    open(FILE, ">$p{wdir}/$file");
    print FILE <<EOFILE;
ssh -T -o ServerAliveInterval=60  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $p{filer_user}\@$p{filer}<<EOF
script
var proj_origin;
var shares_count;
run('shares');
projects = list();

try {
	run('select ' + '$p{project}');
	printf("PROJ_AVAILABLE\\n");
}
catch (err) {
	if (err.code == EAKSH_ENTITY_NOTFOUND) {
		printf("PROJ_NOT_AVAILABLE\\n");
		exit(1);
    }
}
try {
	proj_origin = get('origin');
    if (proj_origin =~ /<remote replication>/)
    {
      printf("CLONED_PROJECT\\n");
    }
	else
	{
	  printf("LOCAL_PROJECT\\n");
	}	
}
catch (err) {
	printf("Could not get the Project Clone Status.\\n");
	exit(1);
}

shares = list();

shares_count = shares.length;

printf("SHARES_COUNT= %d\\n",shares_count);

for (j = 0; j < shares.length; j++) {
   run('select ' + shares[j]);

   share = shares[j];
   sharenfs = run('get sharenfs');

   printf('%-40s %-10s\\n', share, sharenfs);
   run('cd ..');
}

run('done');
.
EOF
EOFILE

    close(FILE);

    $prcmd->copyFileToHost(host => $p{trusted_host},
                           file => "$p{wdir}/$file",
                           dest => "/tmp");

    my $out = $prcmd->executeCommandsonRemote(host => $p{trusted_host},
                                              cmd  => "sh /tmp/$file");
	
	system("rm -rf $p{wdir}/project_status_out.log");
	system("touch $p{wdir}/project_status_out.log");
	
	foreach my $line (@$out)
    {
        chomp($line);
        open OUT," >> $p{wdir}/project_status_out.log" or die "$!\n";
		print OUT "$line\n";
		close OUT;
    }


}

