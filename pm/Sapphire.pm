package Sapphire;

use strict;
use Options;

#
# Package to generate GTLF file and upload the results to Sapphire TESTNAME
# Input hash
# SRC_DIR => Source directory where suc and diff files are placed.
# DEST_DIR => Destination directory where GTLF has to be created.
# TESTNAME => Sapphire test unit to which results needs to be uploaded.
# stage => Drop name of the Fusion Release
# pillar => Product pillar (HCM,GSI,CRM)
# JAVA_HOME => JAVA_HOME to execute jdk, takes a default value if not passed
# RUN_ID => To uniquely identify the sapphire upload,
#           if not passed, creates a unique value based on date.
# AUTO_HOME => To pickup the DTE executables, has a default value if not passed
#
sub generate_and_upload_gtlf
{
    my (%options) = @_;

    $options{JAVA_HOME} = "/ade_autofs/gd29_3rdparty/nfsdo_generic/JDK6/MAIN/LINUX.X64/140519.1.6.0.81.0B08/jdk6/jre" unless (exists $options{JAVA_HOME});

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime(time);
    my $run_id = sprintf("FA%02d%02d%02d%02d%02d", $year-100,
                         $mon+1,
                         $mday,
                         $hour,
                         $min);

    $options{RUN_ID} = $run_id unless (exists $options{RUN_ID});
    $options{AUTO_HOME} = "/usr/local/packages/aime/dte/DTE3" unless(exists $options{AUTO_HOME});

    die("SRC_DIR is not defined.") unless(exists $options{SRC_DIR});
    die("DEST_DIR is not defined.") unless(exists $options{DEST_DIR});
    die("TESTNAME is not defined.") unless(exists $options{TESTNAME});

    generate_gtlf(%options);
    upload_gtlf(%options);
    sendmail(%options);
}

sub generate_gtlf
{
    my (%opts) = @_;

    Options::check_stage_pillar(\%opts);
    my $sf_release = Conf::get_sf_release();
    my $runkey = $opts{TESTNAME};
    $runkey .= "::$opts{RunKey}";
    my $gtlf = "$opts{RUN_ID}.gtlf.xml";

    my $cmd = "$opts{JAVA_HOME}/bin/java -Xms512m -Xmx512m".
        " -classpath $opts{AUTO_HOME}/users/tlt-gtlfutils-0.7/lib/gtlfutils-core.jar".
        " org.testlogic.toolkit.gtlf.converters.file.Main -destdir $opts{DEST_DIR}".
        " -srcdir $opts{SRC_DIR} -testunit $opts{TESTNAME}".
        " -filename $gtlf  -Dgtlf.product=fusionapps".
        " -Dgtlf.release=$sf_release -Dgtlf.load=$opts{stage}".
        " -Dgtlf.branch=main -Dgtlf.toptestfile=unknown".
        " -Dgtlf.testruntype=unknown -Dgtlf.string=4 -Dgtlf.runid=$opts{RUN_ID}".
        " -Dgtlf.env.RunKey=$runkey -Dgtlf.env.NativeIO=true ".
        " -Dgtlf.env.Secondary_Config=$opts{pillar}".
        " -Dgtlf.env.RunKey=$runkey".
        " -Dgtlf.env.Primary_Config=LINUX.X64 $opts{DEST_DIR}/$gtlf";

    my @output = `$cmd`;
    print @output;

}

sub upload_gtlf
{
    my (%opts) = @_;

    my $gtlf = "$opts{RUN_ID}.gtlf.xml";
    my $cmd = "$opts{JAVA_HOME}/bin/java  -Xms512m -Xmx512m ".
        " -Dtestmgr.validate=false -Dtestmgr.ftphost=rashomon.us.oracle.com".
        " -classpath \"$opts{AUTO_HOME}/users/tlt-gtlfutils-0.7/lib/gtlf-uploader.jar:$opts{AUTO_HOME}/users/tlt-gtlfutils-0.7/lib/gtlf-libs.jar:$opts{AUTO_HOME}/users/tlt-gtlfutils-0.7/lib/mail.jar:$opts{AUTO_HOME}/users/tlt-gtlfutils-0.7/lib/jsch-0.1.41.jar\"".
        " weblogic.coconutx.WLCustomGTLFUploader $opts{DEST_DIR}/$gtlf";

    my @output = `$cmd`;
    print "@output";
}

sub sendmail
{
    my (%opts) = @_;

    my $sf_release = Conf::get_sf_release();
    my $to = $opts{e};

    my $subject = "$opts{TESTNAME} Results uploaded to Sapphire $sf_release";
    my $message = "$opts{TESTNAME} results have been upload to Sapphire Release $sf_release.
Results are at http://sapphire.us.oracle.com/toucan/engineer/import/simpleSearch.jsp?runid=$opts{RUN_ID}

Results Collected from : $opts{SRC_DIR}
GTLF File: $opts{HOSTNAME}:$opts{DEST_DIR}/$opts{RUN_ID}.gtlf.xml";

    my @dfiles = `find $opts{SRC_DIR} -name "*.dif"`;
    $message .= "\n\nFailures : " .scalar(@dfiles) ."\n";
    $message .=     "---------------\n";
    foreach my $df (sort @dfiles)
    {
        $message .= $df;
    }

    my @sfiles = `find $opts{SRC_DIR} -name "*.suc"`;
    $message .= "\n\nSuccess : " .scalar(@sfiles) ."\n";
    $message .=     "----------------\n";
    foreach my $sf (sort @sfiles)
    {
        $message .= $sf;
    }

    $message .= "\n\nNote: This is an auto generated message.";


    open(MAIL, "|/usr/sbin/sendmail -t");

    # Email Header
    print MAIL "To: $to\n";
    print MAIL "From: hari.pashikanti\@oracle.com\n";
    print MAIL "Subject: $subject\n\n";
    # Email Body
    print MAIL $message;

    close(MAIL);
    print "Email Sent Successfully\n";
}

1;
