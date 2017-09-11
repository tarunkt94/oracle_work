#!/usr/bin/perl

use strict;
use warnings;
use Carp qw( croak );
use Getopt::Long;
use Pod::Usage;
use Switch;
BEGIN
{
    use File::Basename;
    use Cwd;
    my $orignalDir = getcwd();
    my $scriptDir = dirname($0);
    chdir($scriptDir);
    $scriptDir = getcwd();
    # add $scriptDir into INC
    unshift (@INC, "$scriptDir/../pm");
    chdir($orignalDir);
}
require Mail;
require RemoteCmd;
use Util;
use Logger;
    my ( $starttime, $endtime, $path, $hostname, $host_user, $host_password, $log_file_out, $help, $mail_id, $Workdir, $key_path, $InputFile, $match_string, $cmd, $mail_sub, $host_fadr, %data );
    chomp( my $date = `date +%y-%d-%b-%H-%M-%S` );
    my $filename = "parsing_log_data.pl";
    my $execute_hostname = `hostname`;

   GetOptions("start_time=s"      => \$starttime,
             "end_time=s"         => \$endtime,
             "ovm_file_path=s"    => \$path,
             "mail_id=s"          => \$mail_id,
             "work_dir=s"         => \$Workdir,
             "log_file_path=s"    => \$InputFile,
             "match=s"            => \$match_string,
             "help=s"             => \$help)or pod2usage(q(-verbose) => 1);

   if (!($starttime and $endtime and $path and $mail_id and $Workdir and $InputFile)) {
        pod2usage(-verbose => 0, -message => "$0: argument required\n")
    }

    pod2usage(q(-verbose) => 2) if ($help);

    die " \"$InputFile\" does not exists \n" unless ( -f $InputFile );

    #Change the match string 
    $match_string =~ s/,/|/ if ($match_string);
    
    #parse the Inputfile data and create hash accordingly
    my %Files_path = parse_inputfile($InputFile);

    #Get the list of files for all the respective paths
    foreach $key_path (keys %Files_path)
    {
        my $href_text;
        my $flag = 0;

        #Get the hostname for the respective paths
        chomp ( ( $hostname, $host_fadr ) = get_hostname(host_value => $key_path, path => $path) );

        #as exexuteCommandsonRemote method needs Logobj where cmd output will be store in a file
        #pass it to dev/null as we are not concentrating on file
        my $logObj = new Logger ( {'loggerLogFile' => "/dev/null", 'maxLogLevel' => 4 });

        my $credentials = new RemoteCmd('user' => $Files_path{$key_path}{"user"}, 'passwd' => $Files_path{$key_path}{"password"}, logObj => $logObj);

        #copy the perl script into respective hostname
        my $dest_file = $credentials -> copyFileToHost( host => $hostname, file => $filename, dest => "/tmp" );

        print " key value is $key_path \n";

        FOR:for my $i ( 0 .. $#{ $Files_path{$key_path}{"paths"} }) {
            print "Current path is : $Files_path{$key_path}{\"paths\"}[$i]\n";

            #modify the cmd according to the user inpput on Match option
            if ( $match_string ) {
                $cmd = " perl /tmp/$filename --path $Files_path{$key_path}{\"paths\"}[$i] --starttime \"$starttime\"  --endtime \"$endtime\" --match \"$match_string\" > /tmp/logdata_$$.txt & echo \$!";
           }  else {
               $cmd = "perl /tmp/$filename --path $Files_path{$key_path}{\"paths\"}[$i] --starttime \"$starttime\"  --endtime \"$endtime\" > /tmp/logdata_$$.txt & echo \$!" ;
                }
            #create a shell script which will hold perl script execution processID and redirects the output to log file to avoid time out issues on the respective machine
            my $shell_script =<<"EOF";
PID=`$cmd`
while [ 1 ]
do
GREP=`ps aux | grep \$PID | wc -l`
if [ \$GREP -ne 1 ];
then
echo log data parser is still running, The PID is \$PID
sleep 30
else
exit 0;
fi
done
EOF
            my $shell_log_file_out = $credentials->createAndRunScript( host => $hostname, cmd => $shell_script );

            $log_file_out = $credentials->executeCommandsonRemote( host => $hostname, cmd => "cat /tmp/logdata_$$.txt" );

            #if the lines has been found, create_log_file repective to the grepped data
            if ( @$log_file_out > 4 ) {
            $flag++;
            my $tmp = create_parsed_log_file ( data => \@$log_file_out , dir_path => "$key_path" );
            $href_text .= $tmp unless (!$tmp);
            }
        }
        #delete the logdata_SS.txt file and perl file on the repective machine
        my $delete_file = $credentials->executeCommandsonRemote( host => $hostname, cmd => "rm /tmp/$filename /tmp/logdata_$$.txt");

        if ( $flag > 0 ) {
        #put the data into hash for html page creation
        $data{ $Files_path{$key_path}{'name'} } =  $href_text;
        }
    } #END of foreach loop

    my $html_text = generate_html_text ( %data );
    $html_text =~ s/:::/$host_fadr/;

    if ($match_string){
    $mail_sub = "$host_fadr: Log Parser Trace From $starttime to $endtime with \"$match_string\"";
    } else {
    $mail_sub = "$host_fadr: Log Parser Trace From  $starttime to $endtime";
    }

    Mail::sendmail($mail_id,
    {
          Subject => $mail_sub,
          'From' => 'hari.pahikanti',
          'Content-type' => "text/html"
    }, $html_text);

    #execute the python cmd to for creating html server
    my $PID = `cd $Workdir ; python -m SimpleHTTPServer 7777 > /dev/null & echo \$!`;
    print "HTTP server has been created and PID is $PID \n";
    exit 0;

########################################################################################
#Parse_inputfile
#This method will take the source path data as file and returns hash
########################################################################################
sub parse_inputfile {
    my ($option_file) = @_;
    my ( @value, %hash );
    open (FH,"<$option_file") or croak "can not open the file for reading $!\n";
    while (<FH>){
        #ignore the commented and blank lines
        next if ( $_ =~ /^#/ || /^$/ );
        #split the line accordingly and put the data into hash
        chomp ( my @array = split "::", $_ );
        ( my $tmp ) = $array[0] =~ /\[(.*)\]/;
        unless ( $tmp ){
           $hash{$array[0]}{"name"} = $tmp;
        } else {
           $hash{$array[0]}{"name"} = $array[0];
        }
        $hash{$array[0]}{"paths"} = [ grep defined, split ',', $array[3] ];
        $hash{$array[0]}{"user"} = $array[1];
        $hash{$array[0]}{"password"} = $array[2];
   }
    close FH;
    return %hash;
}
#####################################################################################
#get_hostname : This Method is used to get the required hostname for the Files_paths
#                               keys, this will fetch the details from deployproperties
# Input: hash key
# Output: hostname
######################################################################################
sub get_hostname {
    my ( %options ) = @_;

    #faovm.ha.HOST_FA[BI_System_Components] => faovm.ha.HOST_FA to fetch the required hostname details
    $options{host_value} =~ s/\[(.*)\]// if ( $options{host_value} =~ m/\[.*\]/ );

    #create hash by sending deploy properties file
    chomp ( my %output_hash = getFaEnv($options{path}) );

    #fetch Domain_Id Info for html_page
    $output_hash{'faovm.storage.sun.project'} =~ s/^.{3}//s;
    if ( defined $output_hash{$options{host_value}} ){
        return ( $output_hash{$options{host_value}}, $output_hash{'faovm.storage.sun.project'} );
    } else {
        croak "The host info you entered is not matched in the properties file $! \n";
    }
}
##########################################################################################
#create_parsed_log_file : Method will be used to create href file
#data => @$copy_data_array, dir_path => "/tmp/$key_path"
##########################################################################################
sub create_parsed_log_file {
    my %options = @_;
    my ( %file_data, $href_text, @array );
    my $data = $options{'data'};
    chomp ( my $host = `hostname` );

    foreach $_ ( @$data ) {
        if ( $_ =~ m/@@@@/ ) {
        my $dir = "$Workdir/$date/$options{dir_path}";
        unless ( -d $dir ) { `mkdir -p $dir`;  }
        my ( $key, $value ) = split ("@@@@",$_);
        $file_data{$key} = $value;
        my $key_tmp = $key;
        $key_tmp =~ s/\//_/g;
        $file_data{$key} =~ s/&&&/\n/g;
        $href_text.= "<a href=\"http://$host.us.oracle.com:7777/$date/$options{dir_path}/$key_tmp.txt\">$key</a> </td></tr><tr><td>\n";
        #create file and store the log data into the machine
        open ( FILE, ">$Workdir/$date/$options{dir_path}/$key_tmp.txt" ) or croak "can not create the file $!\n";
        print FILE "File_name: $key \nStarttime: $starttime\nEndtime: $endtime \n\nParsedInfo:\n$file_data{$key}";
        close FILE;
        }
   }
    return $href_text ;
}
##########################################################################################
#generate_html_text : this method is used to create html page for notifications
##########################################################################################
sub generate_html_text {
    my %options = @_;
    my $html_text =<<EOF;
<table><tr><th> Identity Domain   </th><td>:::</td></tr>
<tr><th>Start time</th><td> $starttime </td></tr>
<tr><th>End time</th><td> $endtime </td></tr>
</table>
EOF
    my $head_text ; 

    foreach my $key ( keys(%options) ) {
        chomp ( $key );
        $head_text .="<tr><td> ".$key." </td><td><table><tr><td> ".$options{$key}." </td></tr></table></td></tr> \n" if ($options{$key});
    }
    if ( $head_text ){
	$html_text .= "<h4>  Log Parser Information </h4> \n <table bordercolor=\"red\"><tr><th> Source </th><th> Log data </th></tr>".$head_text."</table> <font > Note: \n  Please execute the below steps, if the above links are not accessible! <br>1. login to the machine \"$execute_hostname\" <br>2. cd $Workdir <br>3.python -m SimpleHTTPServer 7777 > /dev/null </font>";
    } else {
         $html_text .= "\n <br> <font color=\"red\"> No Data has found with in the start and end time </font>";
         }
return $html_text;
}

__END__
=head1 NAME

        GET THE LOG DATA FROM START TIME TO END TIME

=head1 SYNOPSIS

        fa_log_parser.pl
options:-
      ovm_file_path : Directory path containing ovm-ha-deploy.properties file
                        Ex: /fa_template/REL10_ST17/DedicatedIdm/paid/HCM/deployments/fadrsdihcmser1010101/ser1010101/deployfw/

         start_time : Start time of the time frame for log extraction in format yyyy-mm-dd HH:MM UTC/PST
                            Ex: starttime: 2016-05-06 23:33 PST

           end_time : End time of the time frame for log extraction in format yyyy-mm-dd HH:MM UTC/PST
                            Ex:endtime : 2016-05-06 23:33 PST

           work_dir : Writable directory to store generated log files

      log_file_path : The script can connect to any of the FA Node's(specified as per the convention followed in ovm-ha-deploy.properties file eg faovm.ha.HOST_FA) and parse any no of directory paths to grep interested log files. This parameter must point to a text file which details the FA Nodes, User Credentials to connect, coma separated log paths. For the FA Node a custom name can be provided in square brackets to be displayed in the logs.
			    Format :
				Name[Description]::username::password::<log dir1>,<log dir2>...,<log dirN>
                            Ex: faovm.ha.HOST_FA[ManageServer]::oracle::Welcome1::/u01/APPLTOP/instance/lcm/logs/,/u01/APPLTOP/instance/nodemanager/,/u01/APPLTOP/instance/BIInstance/diagnostics/logs/

            mail_id : Mail-ID seperated with (,)

     match(optional): Coma seperated list of mail-ids.
                            EX: error,warning

     Below is the command example :-
        perl fa_log_parser.pl --ovm_file_path /home/ppriyasr/scripts/ovm-ha-deploy.properties --start_time "2016-03-22 10:55 PST" --end_time "2016-03-23 12:55 PST" --work_dir /tmp --log_file_path Input_path.txt --mail_id pagidimarry.priyasee@oralce.com

=cut


