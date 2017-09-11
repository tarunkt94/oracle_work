use strict;
use File::Basename;
use Cwd;

package Conf;

my %releases = ("11.1.8.0.0" => "FA11.1.8.0.0",
                "11.1.9.2.0" => "FA11.1.9.2.0",
                "11.1.10.0.0" => "FA11.1.10.0.0",
                "11.1.11.0.0" => "FA11.1.11.0.0");

my %stages = ("FA11.1.8.0.0" => ["GA"],
              "FA11.1.9.2.0" => ["ST13", "ST13A", "GA"],
              "FA11.1.10.0.0" => ["ST9", "ST10", "ST11","ST12","ST13","ST14","ST15","ST16","ST17","GA"],
              "FA11.1.11.0.0" => ["ST1", "ST2", "ST3", "ST4", "ST5", "ST6",
                                  "ST7", "ST8", "ST9","ST10","ST11","ST12",
                                  "ST13","ST14","ST15", "ST16", "ST17",
                                  "ST18", "GA"]);

my @pillars = ('HCM', 'CRM', 'GSI','GSIL','HCM_CDBPDB','CRM_CDBPDB','GSI_CDBPDB');

my $release;
sub get_sf_release
{
    my $orignalDir = Cwd::getcwd();

    my $scriptDir = File::Basename::dirname($0);
    chdir($scriptDir);
    my $scriptDir =  Cwd::getcwd();

    chdir($orignalDir);

    if ($scriptDir =~ /^.*\/([^\/]+)\/bin$/)
    {
        if (exists $releases{$1})
        {
            $release = $releases{$1};
            return $releases{$1};
        }
    }

    die("Cannot predict release");
}

sub get_release_stages()
{
    get_sf_release() if ($release eq '');

    return @{$stages{$release}};
}

sub get_pillars()
{
    return @pillars;
}

1;
