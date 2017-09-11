# 
# $Header: dte/DTE/scripts/fusionapps/cli/pm/Debug.pm /main/1 2015/12/21 02:15:22 ljonnala Exp $
#
# Debug.pm
# 
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      Debug.pm - Debugging facilities
#
#    DESCRIPTION
#      Debugging facilities
#
#    MODIFIED   (12/21/15)
#    ljonnala    12/21/15 - Add debug package
#    ljonnala    12/21/15 - Creation
#

package Debug;
require 5.003;
use     strict;
use     vars qw($PreDieHandler $PostDieHandler);

my $DebugFlags = undef;
my $DebugOn    = 0;
my $DebugOff   = 1;


#
# Debuging is turned off by default.  This activates debugging
# if it is passed a defined value.
#
sub activate
{
    my ($debug_flags) = @_;

    return unless $debug_flags;

    $DebugOn    = 1;
    $DebugOff   = 0;
    $DebugFlags = "$debug_flags";
}


#
# Turns off debuging.  Returns the original debug flags so you can
# restore them later with the activate.  Be aware that you can die in
# between the time you deactivate and reactivate.  This would only be a
# problem in a non production environment.
#
sub deactivate
{
    my $debug_flags = $DebugFlags;

    $DebugOn    = 0;
    $DebugOff   = 1;
    $DebugFlags = undef;

    return $debug_flags;
}


#
# Returns true if debugging is on
#
sub is_on()
{
    my ($flag) = @_;

    return $DebugOn;
}


#
# Returns true if debugging is on and IF $flag matches the debugging
# flags initialized in activate().  The comparison is case insensitive.
#
sub is_on_if($)
{
    my ($flag) = @_;

    return ($DebugOn and $DebugFlags =~ /\b$flag\b/i);
}


#
# Returns true if debugging is on UNLESS $flag matches the debugging
# flags initialized in activate().  The comparison is case insensitive.
#
sub is_on_unless($)
{
    my ($flag) = @_;

    return ($DebugOn and $DebugFlags !~ /\b$flag\b/i);
}


#
# method for printing debugging messages to STDERR
#
sub print
{
    print STDERR @_ if $DebugOn;
}


#
# method for printing debugging messages to STDERR
#
sub println
{
    print STDERR @_, "\n" if $DebugOn;
}


#
# Returns a string containing the environment.  If an env variable
# ends with "_CONNECT" assume it is a db connect string and try to
# hide the password.
#
sub get_env
{
    my $env = '';

    #
    # Some of the env variables may not be populated to ENV hash until
    # content response phase. However this method can get invoked much
    # before the content response phase. Hence populate ENV from the current
    # request, so that we don't miss any of the env variable set by the Apache
    # see bug 4428422 for details.
    #
    # This has to be done only for a HTTP Application. Hence wrap this code
    # inside an eval.
    #
    {
        local $SIG{'__DIE__'} = 'IGNORE';
        eval { Apache2::RequestUtil->request->subprocess_env };
    }

    foreach my $key (sort(keys(%ENV)))
    {
        my $val = $ENV{$key} || "";

        if ($key =~ /_CONNECT/)
        {
            $val =~ s#/[^@]*(\@|$)#/<hidden>$1#;
        }
        elsif ($key =~ /PASSWORD/)
        {
            $val = '<hidden>';
        }

        $env .= "ENV{$key}=$val\n";
    }

    return $env;
}


#
# Gets the die message from $@ and strips of the "at line" part.  Truncates
# it to the specified length and replaces newlines with spaces if the length
# is non-zero.  If $error is specified then it is used instead of $@.
#
sub get_die_msg
{
    my ($len, $error) = @_;

    #
    # Grab the die message and strip off the "at foo.pl line n" ending.
    #
    $error ||= $@;
    $error   =~ s/ at \S+ line \d+.*//;
    $error   =~ s/\s*$//;

    #
    # Truncate the error message if desired.  Replace all whitespace
    # (new line characters, carriage returns, linefeeds, etc.) with
    # spaces.  Remove leading & trailing whitespace.
    #
    $len ||= 0;
    $len  -= 3;
    if ($len > 0 and length($error) > $len)
    {
        $error =  substr($error, 0, $len)  . "...";
        $error =~ s/\s+/ /g;
        $error =~ s/^\s+|\s+$//g;
    }

    return $error;
}

#
# Bug 5090882 - new method to return the die msg with the line number at which
# the error/warning occured. This text is displayed above the stack trace.
#
sub get_die_msg_line_num
{
    my ($len, $error) = @_;

    my $msg = "\nOUTPUT: " . get_die_msg($len, $error);
    my $line_num = $error;
    $line_num =~ s/.*(at \S+ line \d+).*/$1/s;
    $msg .= "\nthrown ".$line_num;
    return $msg;
}

#
# This function creates a flexible global die handler that easily
# allows you to alert an appropriate contact with a customized
# message.
#
# Options:
#    pre_die_handler  => subroutine reference
#    post_die_handler => subroutine reference
#    application_name => defaults to $0
#    sendmail         => string of comma separated email addresses
#    sender           => string containing the sender for the -f sendmail
#                        option.
#
# The die handler created follows these actions:
#    o If pre_die_handler is defined, it will be called first with the
#      die message as its argument.  It may return a text string that
#      will be appended to the email message.
#    o A detailed message is created from the die message, stack trace,
#      and output from pre_die_handler.
#    o If sendmail is defined and debugging is off, the detailed
#      message is mailed to the email addresses defined by sendmail.
#      This is on valid on UNIX because it uses the UNIX sendmail program.
#    o If post_die_handler is defined, it will be called with the die
#      message as its argument.  For web applications, this handler
#      should print off a nice html error page.  If the subroutine returns
#      a defined value, that value will replace the original die message.
#
# Note: If debugging is on, it does not email the message.  It only
# prints it to STDERR.
#
# Use "local($SIG{__DIE__}) = sub { ... };" to disable the die hanlders
# within a block of code.
#
sub activate_die_handler
{
    my (%options) = @_;

    $options{application_name} ||= $0;
    ($options{sendmail} and $options{sendmail} !~ /^[\w.@,]+$/) and
        die("sendmail option must be a comma separted email address list");

    $PreDieHandler  = $options{pre_die_handler}  if $options{pre_die_handler};
    $PostDieHandler = $options{post_die_handler} if $options{post_die_handler};

    $SIG{__DIE__} = sub {
        my ($msg) = @_;

        #
        # Convention: If a die is called without an error message,
        # then the die does not need to be handled.  It has already
        # been handled by the program and the die is a way to return
        # control to upper levels
        #
        # The default message for a die called with no arguments
        # is "Died at ..."  Ignore these die messages
        #
        ($msg =~ /^Died/) && return;

        #
        # Bug 12530245
        #
        ($msg =~ /Software caused connection abort/) && return;

        #
        # Bug 17428726
        # This is an exception handler to skip the warning message
        # that was occured while introducing Math::BigInt in our code
        # since FastCalc is not included in BigInt.
        #
        ($msg =~ /Can\'t locate Math\/BigInt\/FastCalc\.pm/) && return;

        # Ignore errors -
        # '70007: The timeout specified has expired'.
        # '(104) Connection reset by peer'.
        #
        if (exists $ENV{MOD_PERL_API_VERSION} and
                   $ENV{MOD_PERL_API_VERSION} >= 2)
        {
            #
            # Holding the $@ value in temp variable as APR::Const->import might
            # change value. Aslo forcing numeric context for $@ , as $@ can
            # return error string in scalar context.
            #
            my $error_no = 0 + $@;
            require APR::Const;
            APR::Const->import(qw(ECONNABORTED TIMEUP));

            return if ($error_no &&
                       ($error_no == APR::Const::TIMEUP() ||
                        $error_no == APR::Const::ECONNABORTED()) &&
                        trace_has_function('CGI::new'));

        }

        #
        # Call the Pre Die Handler
        #
        my $pre_text = "";
        if ($PreDieHandler)
        {
            ($pre_text) = &$PreDieHandler($msg);
        }

        #
        # Prepare a time stamp.
        #
        my ($sec, $min, $hour, $mday, $mon, $year, @other) = localtime(time);
        my $time = sprintf ("Timestamp: %02d/%02d/%02d %02d:%02d:%02d\n",
                            $year%100,$mon+1,$mday,$hour,$min,$sec);

        #
        # Create the detailed die message
        #
        my $die_msg = "$pre_text\n\n$msg\n" . stack_trace() . "\n$time\n";

        #
        # Print the error message to STDERR just to be extra sure it
        # is seen.  This is also convenient for development
        #
        print STDERR $die_msg;

        #
        # Call the main Die Handler
        # Send a mail message to the contact unless debugging is on
        #
        if ($options{sendmail} and $DebugOff)
        {
            my $subject = get_die_msg
                (80, "Subject: $options{application_name} Error:$msg");

            my $sender_option = ($options{sender}) ? "-f $options{sender}" :
                                 $options{sendmail};

            open  MAIL, "| /usr/lib/sendmail -t $sender_option";
            print MAIL "$subject\nTo: $options{sendmail}\n\n", $die_msg;
            close MAIL;
        }

        #
        # Remove the "at line xyz" message that gets appended.
        # It is unneccessary since we have the stack trace.
        #
        $msg =~ s@at [/.\d\w]+ line \d+.*$@@;

        #
        # Call the Post Die Handler
        #
        if ($PostDieHandler)
        {
            my ($post_text) = &$PostDieHandler($msg);
            die($post_text) if $post_text;
        }
    };

    #
    # Throw away annoying warnings when not in debug mode so they don't
    # clutter up any log files.
    #
    $SIG{__WARN__} = sub {
        my ($msg) = @_;

        #
        # mvfs driver on Linux has a bug that causes a 'exec grantpt'
        # warning message. We want to ignore this message until clearcase
        # fixes the problem. See bug 3001683 for details.
        # Easiest way to check if this issue still exist, is to run
        # unsetenv CLEARCASE_VIEW; /m/isd_qa/bin/FTP.pl -user <u> -password <p>
        # on Linux, from within a view, and check for this warning in the o/p.
        # Of late, new warning messages started appearing apart from
        # 'exec grantpt' message. So suppressing all of them here.
        #
        my @error_msgs;
        push (@error_msgs, 'IO::Tty::pty_allocate\(nonfatal\): grantpt\(\):'.
              ' Exec format');
        push (@error_msgs, 'IO::Tty::open_slave\(nonfatal\): open');
        push (@error_msgs,  'pty_allocate\(nonfatal\): getpt\(\):');
        push (@error_msgs, 'pty_allocate\(nonfatal\): openpty\(\): Exec ' .
              'format');
        push (@error_msgs, 'pty_allocate\(nonfatal\): open\(/dev/ptmx\):');
        push (@error_msgs, 'pt_chown:');
        my $pattern = join ("|", @error_msgs);

        return if ($DebugOn and
                   defined($ENV{CLEARCASE_VIEW}) and $^O =~ /linux/ and
                   $msg =~ /$pattern/);

        if ( $DebugOn )
        {
            #
            # Subroutine redefined warnings result from dyanmic
            # reloading of packages.  This is a feature used by some
            # applications when debug mode is on.  So we don't want to
            # report these warnings.
            # Also ignore parser errors introduced after using
            # XML::LibXML::Parser. The Html parser throws a lot of warnings
            #  once it finds an '&' anywhere in the tags
            #
            if ($msg !~ /^Subroutine \S+ redefined/ and
                $msg !~ /HTML parser error/ )
            {
                print STDERR "\nWarning:\n$msg\n" . stack_trace() . "\n\n";
            }
        }
        else
        {
            #
            # With debug off (production mode), we want to avoid these
            # warnings.  "Use of uninitialized ..." are inevitable no
            # matter how hard we try to get them out.  "Attempt to
            # free ...." happens when a program exits.  There does not
            # seem to be any way to track it down and fix it.
            # Also ignore parser errors introduced after using
            # XML::LibXML::Parser. The Html parser throws a lot of warnings
            #  once it finds an '&' anywhere in the tags
            #
            if ($msg !~ /Use of uninitialized/   and
                $msg !~ /^Attempt to free unreferenced scalar/i and
                $msg !~ /HTML parser error/)
            {
                print STDERR "\nWarning:\n$msg\n" . stack_trace() . "\n\n";
            }
        }
    };
}


#
# This method allows us to print stack trace of a process at any time by
# sending a specified signal.  This should be used with a signal like
# USR1 or USR2.  A typical use of this method is to locate the code in a
# hanging process from the stack trace after sending the signal..
#
sub activate_stack_trace_signal_handler
{
    my ($sig_name) = @_;

    $SIG{$sig_name} = sub {
        print STDERR "\n\nProcess $$ received stack trace signal $sig_name:\n";
        print STDERR stack_trace();
    };
}


#
# This method allows us to reload changed packages by sending a specified
# signal.  This should be used with a signal like USR1 or USR2.  A typical
# use of this is in development to be able to reload changed packages
# without restarting the program.
#
sub activate_reload_packages_signal_handler
{
    my ($sig_name) = @_;

    $SIG{$sig_name} = sub {
        print STDERR "\n\nProcess $$ received reload packages signal ".
                     "$sig_name\n";
        reload_packages();
    };
}


#
# Returns a list of lines containing a nicely formated stack trace.
# The first line in the array will be the call to this routine.
#
my $Stack_Format = "%4s %-20s %-45s %s %s\n";
my $Stack_Title  =
    sprintf($Stack_Format, "\nLine", "File", "Sub Called", "Arg", "WntA") .
    sprintf($Stack_Format, "-"x4, "-"x4, "-"x10, "-"x3, "-"x4);

sub stack_trace
{
    use File::Basename;

    my $i = 0;
    my $trace = $Stack_Title;

    while (my ($pack, $file, $line, $sub, $args, $wantarray) = caller($i++))
    {
        $file = basename($file);
        $trace .= sprintf($Stack_Format, $line, $file, $sub,
                          ($args ? " Y" : " N"), ($wantarray ? "  Y" : "  N"));
    }

    return $trace . "\n";
}

#
# Check if stack trace has a function
#
sub trace_has_function
{
    my ($function) = @_;

    my $i = 0;

    while (my $sub = (caller($i++))[3])
    {
        return 1 if ($sub eq $function);
    }

    return 0;
}

#
# This function will look to see if the source code for any packages
# loaded into the Perl interpreter have changed since the program
# started or since the last time this function was called.  If the
# source has changed, it will reload the package.
#
# This can be very useful when developing an application.  For
# example, invoke this method before every request in a web
# application to avoid having to shutdown and startup the webserver
# everytime you make a simple change to a file.
#
# Beware that global or package variables may be reset.  Note that
# this function changes the time the application started.
#
sub reload_packages
{
    my ($pattern) = @_;
    while (my ($module, $file) = each(%INC))
    {
        $file ||= "";
        if (($file ne "") and
            (-e $file ) and
            (-M $file < 0) and
                ((!defined $pattern) or $file =~ /$pattern/))
        {
            delete($INC{$module});
            $module =~ s/\.pm$//;
            $module =~ s/\//::/g;
            print STDERR "RELOADING $module->$file\n";
            eval("require($module)");
        }
    }

    #
    # reset the start time of the application so it only reloads
    # modules that have been changed from now instead of from when the
    # app started
    #
    $^T = time();
}

#
# Dumps out a list of all packages loaded by the current application.
#
sub dump_packages
{
    my ($file) = @_;

    open(DEBUG_DUMP_PACKAGES, ">$file") || die("Can not open $file: $!");

    my @keys = sort(keys(%INC));

    foreach my $module (@keys)
    {
        print DEBUG_DUMP_PACKAGES "$INC{$module}\n";
    }

    close(DEBUG_DUMP_PACKAGES);
}


1; 
