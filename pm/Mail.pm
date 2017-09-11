package Mail;

use strict;
use FileHandle;

my $scriptDir;

BEGIN
{
    use File::Basename;
    use Cwd;
    my $orignalDir = getcwd();
    $scriptDir = dirname($0);
    chdir($scriptDir);
    $scriptDir = getcwd();
    # add $scriptDir into INC
    unshift (@INC, "$scriptDir/../pm");
    chdir($orignalDir);
}

#my $drenv = [
#         {"TAS Central" =>
#           [
#            {TASC_HOST => "Host"},
#            {TAS_DB_HOST => "Database Host"},
#            {TAS_DB_CONNECT_STRING => "Database Connect String",},
#            {TAS_DB_CREDS => "Database Credentials"}
#           ],
#         },
#        ];
# Builds html tables from above structure, picks the values from $vals
sub build_html_tables
{
    my ($html, $vals) = @_;

    my $html_string = "";
    foreach my $table (@$html)
    {
        foreach my $head (keys %$table)
        {
            $html_string .= "<font class=\"OraHeaderSub\">$head</font><hr>";
            foreach my $row ( @{$table->{$head}})
            {
                $html_string .= "<table width=\"60%\">";
                foreach my $k (keys %$row)
                {
                    $html_string .= "<tr><th align=\"left\" width=\"40%\">".$row->{$k}."</th><td align=\"left\">".$vals->{$k}."</td></tr>";
                }
                $html_string .= "</table>";
            }
        }
    }

    return $html_string;
}

# gets the css style
sub get_email_style
{
    my ($css_file) = @_;

    my @css_content = ();
    my $css_fh = new FileHandle($css_file, "r");
    @css_content = $css_fh->getlines();
    $css_fh->close();

    return "<style type=text/css>
<!--
@css_content
// -->
</style>
";
}

# sends mail
sub sendmail
{
    my ($mailto, $header_ref, $msg, $default_reply_to) = @_;

    my %header = %{$header_ref};
    $header{Subject} =~ s/(^\s+|\s+$)//g;

    $default_reply_to ||= 'saasqa_do_not_reply@oracle.com';
    if ($header{From} && $header{From} !~ /@|<.*>/)
    {
        my $from = $header{From};
        $header{From} = "$from <$default_reply_to>";
    }

    my $return_path;
    while (my ($key, $value) = each(%header))
    {
        #
        # In some places, "Reply-To" and in others "Reply-to" is used
        # So, ignore the case and check. See bug # 3361638
        #
        if ($key =~ /Reply-To/i)
        {
            $return_path = $header{$key};
        }
    }
    unless ($return_path)
    {
        $return_path = $header{"Reply-To"} = $default_reply_to;
    }

    my $msgref   = ref($msg) ? $msg : \$msg;
    my $maillist = ref($mailto) ? join(",", @$mailto) : $mailto;
    $maillist =~ s/\s//g;
    open(MAIL, "| /usr/lib/sendmail -t -f '$return_path'");

    $header{"Content-type"} ||= "text/plain";

    if($header{"Content-type"} =~ /html/i)
    {
        my $style = get_email_style("$scriptDir/../../pm/custom.css");
        $$msgref =  << "END_OF_MAIL";
<html>
<head>
<title> $header{Subject} </title>
</head>
$style
$$msgref
</html>
END_OF_MAIL
    }

    my $test_msg = "";

    my $header_txt = "To: $maillist\n";
    while ( my ($key, $value) = each %header)
    {
        $header_txt .= "$key: $value\n";
    }

    print MAIL $header_txt, "\n", $test_msg, $$msgref;
    close MAIL;
    return $header_txt;
}

1;
