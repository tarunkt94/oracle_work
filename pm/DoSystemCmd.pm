# 
# $Header: dte/DTE/scripts/fusionapps/cli/pm/DoSystemCmd.pm /main/1 2015/12/21 02:15:22 ljonnala Exp $
#
# DoSystemCmd.pm
# 
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      DoSystemCmd.pm - DoSystemCmd Package
#
#    DESCRIPTION
#      It provides a method do_cmd() for running general external programs
#      and trapping their output.  It checks the error code for success.  You
#      also can define a regular experssion as an error pattern.  All output
#      from the command will be compared to this regular expression.  If it is
#      matched, an error is returned.
#
#      It also inherits from DoBuiltinCmd and has all of its methods available.
#
#    MODIFIED   (12/21/15)
#    ljonnala    12/21/15 - Add system cmd file
#    ljonnala    12/21/15 - Creation
#

package DoSystemCmd;
require 5.004;

use POSIX ();

use     DoBuiltinCmd;
use     strict;
use     IO::Select;
use     IO::Handle;
use     FileHandle;
use     vars qw(@ISA);

@ISA = qw(DoBuiltinCmd);

my $TIMEOUT = $ENV{DOSYSTEMCMD_TIMEOUT};

#
# Create A DoSystemCmd object.  Options:
#
# Options:
#   * filehandle      : The filehandle to log output to.
#   * no_die_on_error : By default, the object will die whenever it
#                       encounters an error.  When this option is set,
#                       it will return an error message on failure or
#                       undef on success.
#   * no_error_output : If true, it disables logging the error messages
#                       and stack traces on failure.  This may useful
#                       to avoid redundant error messages in the logfile.
#   * no_stack_trace  : When there is an error and no_error_output is not true,
#                       a stack trace is printed in addition to the error text.
#                       Setting this option will suppress the stack trace
#                       while keeping the error messages in tact.
#   * timeout         : Kills a command if it runs longer than the timeout.
#   * uptime_on_timeout : Flag when set to 1, executes uptime command to find
#                         out the load average on the machine, returns it as
#                         part of error message.
#   * error_pattern   : A regular expression to look for in the command output.
#                       If seen, the command is considered to have failed.
#   * replace_output  : A hash mapping regexp patterns to replacement text.
#                       Any matches in the logging output are replaced with
#                       the text specified.
#   * keep_output     : If true, it enables logging the command output.
#   * retry           : An array reference containing hash references,
#                       each of which contains the following keys:
#       * pattern       : Regexp object to match (qr// or string)
#       * maximum       : Max number of retries before giving up
#       * delay         : Time (seconds) between tries (optional)
#       * handler       : Coderef to call before retrying (optional)
#       * retry_message : Message to display on retry (optional)
#       * error_message : Message to display on error (optional)
#
sub new {
    my ($class, $options) = @_;

    my $self = new DoBuiltinCmd($options);
    bless $self, $class;

    #
    # Save a copy of the constructor's original arguments list
    #
    $self->{DOCMD_CONSTRUCTOR_ARGS} =
        $options->{constructor_args} || { %$options };

    $self->{DOCMD_TIMEOUT}           = $options->{timeout}         || $TIMEOUT;
    $self->{DOCMD_UPTIME_ON_TIMEOUT} = $options->{uptime_on_timeout} || 0;
    $self->{DOCMD_CLEAR_OUTPUT}      = $options->{clear_output}    || 0;
    $self->{DOCMD_ERROR_PATTERN}     = $options->{error_pattern};
    $self->{DOCMD_REPLACE_OUTPUT}    = $options->{replace_output};
    $self->{DOCMD_PID}               = 0;
    $self->{DOCMD_DESCRIPTION}       = "Executing External Program";
    $self->{DOCMD_KEEP_OUTPUT}       = $options->{keep_output}       || 0;
    $self->{DOCMD_REPORT_ERROR}      = 0;
    $self->{DOCMD_UNIQUE_REPLACE}    = $options->{unique_replace};
    $self->{DOCMD_SUDO}              = $options->{sudo};


    #
    # Check value of retry option and set DOCMD_RETRY
    #
    if ($options->{retry})
    {
        my $r = $options->{retry};
        $self->check_retry_args($r);
        $self->{DOCMD_RETRY}{CONFIG} = $r;
    }


    return $self;
}


#
# Checks that the parameters to the retry argument are valid
#
sub check_retry_args
{
    my($self, $r) = @_;
    die "retry should be an array reference"
        unless ref($r) eq "ARRAY";
    foreach my $h (@$r)
    {
        die "argument in retry list should be hash reference"
            unless ref($h) eq "HASH";
        die "{pattern} must be specified in retry hash"
            unless exists $h->{pattern};
        die "{maximum} must be specified in retry hash"
            unless exists $h->{maximum};
        die "{maximum} must be positive or zero"
            unless $h->{maximum} >= 0;
        die "{handler} must be subroutine reference"
            if exists($h->{handler}) && ref($h->{handler}) ne "CODE";
        die "{delay} must not be negative"
            if exists($h->{delay}) && $h->{delay} < 0;
    }
}


#
# Check the retry settings to see if a retry is warranted.  Returns 1 if so.
#
sub check_for_retry
{
    my($self, $error, $retry_args, %override) = @_;

    my $retry_attr = $retry_args->{retry_attr}             || 'DOCMD_RETRY';
    my $constructor_args = $retry_args->{constructor_args}
        || 'DOCMD_CONSTRUCTOR_ARGS';

    #
    # Get the appropriate module name so that we can mention it in the
    # error.
    #
    my $module = $retry_args ? caller() : __PACKAGE__;


    $self->{$retry_attr}{COUNT}++;
    my $retry = $self->{$retry_attr};
    foreach my $conf (@{ $retry->{CONFIG} })
    {
        if (defined $error and $error =~ $conf->{pattern})
        {
            #
            # Convert Regexp object to string without the
            # "(?-xism:" and ")" being added
            #
            my $pat = "$conf->{pattern}";
            $pat =~ s/^\Q(?-xism:\E(.*)\)$/$1/;
            $self->output("\nError matched /$pat/\n");

            if ($retry->{COUNT} > $conf->{maximum})
            {
                my $error_message;
                if ($conf->{maximum})
                {
                    $error_message = "Too many retry attempts";
                }
                else
                {
                    $error_message = "No retry, maximum=0";
                }

                if ($conf->{error_message})
                {
                    my $custom_message = $conf->{error_message};
                    chomp $custom_message;
                    $error_message = "$custom_message ($error_message)";
                }

                $error_message .= $self->_get_uptime_if_timeout($error,
                                                                %override);
                die($module . ": $error_message\n");
            }

            $self->output($conf->{retry_message}."\n")
                if $conf->{retry_message};

            my $args = $self->{$constructor_args};
            $conf->{handler}->($retry, $error, $args)
                if $conf->{handler};

            if ($conf->{delay})
            {
                my $seconds =
                    ($conf->{delay} > 0 && $conf->{delay} <= 1)
                        ? "second" : "seconds";
                $self->output("\nRetry #$retry->{COUNT} ".
                    "after $conf->{delay} $seconds...\n");
                sleep $conf->{delay};
            }

            local($self->{DOCMD_NO_REINIT});

            $self->_initialize_copro() if $self->can('_initialize_copro');
            return 1;
        }
    }
    return 0;
}


#
# Tells the object to search the command output for errors matching a
# regular expression after running do_cmd in addition to checking
# do_cmd's return value (unless that value already indicates an error)
#
sub set_error_pattern {
    my ($self, $error_pattern) = @_;

    $self->{DOCMD_ERROR_PATTERN} = $error_pattern;
}

#
# Sets the filehandle.  Setting it to undef will supress output.
#
sub set_filehandle {
    my ($self, $filehandle) = @_;
    $self->{DOCMD_FILEHANDLE} = $filehandle;
}

#
# Sets the file handle to default i.e. STD ERR.
#
sub set_default_filehandle{
    my ($self) = @_;
    my $filehandle = new FileHandle;
    $filehandle->fdopen(\*STDERR, "w");
    $filehandle->autoflush(1);
    $self->{DOCMD_FILEHANDLE} = $filehandle;
}



#
# Performs a generic system command.  If the command returns a defined
# nonzero status code, an error is occurred.  If an error pattern has
# been set, then each line of output from the command will be compared
# to the pattern.  If there is a match, an error will be returned.
#
# The %override hash allows you to override certain parameters that are
# set when the object is instantiated.  The override applies only to this
# command and reset for all subsequent commands.
#
# If inheriting from this class (like DoCoPro.pm), look at over-riding
# the _do_cmd for class specific behavior.
#
sub do_cmd {
    my ($self, $cmd, %override) = @_;

    #
    # Use local() to override the specified parameter values for this
    # call to do_cmd() only.
    #

    exists($override{filehandle}) and
        local($self->{DOCMD_FILEHANDLE}) = $override{filehandle};

    defined($override{timeout}) and
        local($self->{DOCMD_TIMEOUT}) = $override{timeout};

    defined($override{error_pattern}) and
        local($self->{DOCMD_ERROR_PATTERN}) = $override{error_pattern};

    defined($override{replace_output}) and
        local($self->{DOCMD_REPLACE_OUTPUT}) = $override{replace_output};

    defined($override{unique_replace}) and
        local($self->{DOCMD_UNIQUE_REPLACE}) = $override{unique_replace} and
            local($self->{UNIQUE_REPLACE_ELEMENTS}) = {};

    defined($override{parser_object}) and
        local($self->{PARSER_OBJECT}) = $override{parser_object};

    defined($override{no_die_on_error}) and
        local($self->{DOCMD_NO_DIE_ON_ERROR}) = $override{no_die_on_error};

    defined($override{no_error_output}) and
        local($self->{DOCMD_NO_ERROR_OUTPUT}) = $override{no_error_output};

    defined($override{no_stack_trace}) and
        local($self->{DOCMD_NO_STACK_TRACE}) = $override{no_stack_trace};

    defined($override{report_error}) and
        local($self->{DOCMD_REPORT_ERROR}) = $override{report_error};

    defined($override{keep_output}) and
        local($self->{DOCMD_KEEP_OUTPUT}) = $override{keep_output};

    #
    # Override for retry parameter.
    #
    my $r;

    if ($override{retry})
    {
        $r = $override{retry};
        $self->check_retry_args($r);
    }

    local($self->{DOCMD_RETRY}) ||= {} and
    local($self->{DOCMD_RETRY}{CONFIG}) = $r and
    local($self->{DOCMD_RETRY}{DO_CMD_COUNT}) = 0 if $r;

    $self->_print_log_head($cmd);

    RESTART: {

        delete $self->{ERROR_MESSAGE};
        delete $self->{DIE_MESSAGE};


        #
        # Execute _do_cmd in an eval so we can trap any dies.  Turn off the
        # die handler.  We want to handle it in our own way.
        #
        my $success = eval
        {
            #
            # Bug 5997257: Setting die hook to IGNORE is sometimes causing
            # failure in timeout commands. Overriding the usual handler.
            #
            # Bug 8261820: Relying on ERROR_MESSAGE seems to not work in
            # some cases where the timeout event occurs.  Setting
            # DIE_MESSAGE as a way of capturing the error message.
            #
            # Note: use of SIG{__DIE__} inside eval is deprecated,
            # according to the "perlvar" manpage.  Future versions of Perl
            # may not support this.  This works up to 5.8.8 at least.
            #
            local($SIG{__DIE__}) = sub { $self->{DIE_MESSAGE} = $_[0]; };
            $self->_do_cmd($cmd);

            return 1;
        };

        #
        # Strip out the context info that Perl adds to die statements
        #
        if ($self->{DIE_MESSAGE})
        {
            $self->{DIE_MESSAGE}
                =~ s/ at \S+ line \d+(?:, \S+ line \d+)?\.\n$//;
            $self->{DIE_MESSAGE} =~ s/\s+$//;
        }

        my $err_msg = $self->{ERROR_MESSAGE} || $self->{DIE_MESSAGE};

        redo RESTART if $self->check_for_retry($err_msg, undef, %override);

        if ($self->{DOCMD_RETRY})
        {
            $self->{DOCMD_RETRY}{COUNT} = 0;
            $self->{DOCMD_RETRY}{DO_CMD_COUNT}++;
        }

        if (not $success)
        {
            $self->_do_cmd_cleanup()
                unless $self->{DOCMD_NO_DIE_ON_ERROR};
            $err_msg ||= Debug::get_die_msg;
        }

        if ($err_msg)
        {
            $err_msg .= $self->_get_uptime_if_timeout($err_msg, %override);

            $self->_print_log_tail($err_msg);

            $cmd = $self->_do_cmd_replace($cmd);

            my $error = "ERROR: $err_msg ($cmd)";
            return $self->error($self->_make_error_message($error));
        }
        else
        {
            #
            # Only if we get here, was the command completely successful.
            #
            $self->_print_log_tail("command successful");
            return undef;
        }
    }

}

#
# If the do_cmd failed due to timeout, then api gets the uptime and
# returns it.
#
sub _get_uptime_if_timeout
{
    my ($self, $err_msg, %override) = @_;

    #
    # Set this variable so that it is visible to other classes like DoCoproCmd
    #
    if (defined $self->{is_uptime_on_timeout} and
        $self->{is_uptime_on_timeout} )
    {
        $self->{is_uptime_on_timeout} = 0;
        return "";
    }
    else
    {
        $self->{is_uptime_on_timeout} = 1;
    }

    #
    # If the command failed due to a timeout then execute
    # uptime cmd to find the load avg.
    #
    if (($self->{DOCMD_UPTIME_ON_TIMEOUT} or $override{uptime_on_timeout}) and
        $err_msg and
        $err_msg =~ /(process \d+ timed out|exited unexpectedly)/is
        )
    {
        my $uptime = [];
        eval {
        $uptime  = $self->do_cmd_get_output("uptime",
                                             timeout => 10,
                                             retry => [ {maximum => 0,
                                                         pattern => '.'}],
                                             no_die_on_error => 1);
        };

        $uptime = join (" " , @$uptime);
        chomp($uptime);
        $self->{is_uptime_on_timeout} = 0;
        return "\nuptime: $uptime\n" if ($uptime);
    }

    $self->{is_uptime_on_timeout} = 0;
    return "";
}

#
# do_cmd_get_output is the same as do_cmd except it returns a reference
# to @output instead of printing it.  It still appends @output to
# $self->{DOCMD_OUTPUT}.
#
# The %override hash allows you to override certain parameters that are
# set when the object is instantiated.  The override applies only to this
# command and reset for all subsequent commands.
#
sub do_cmd_get_output {
    my ($self, $cmd, %override) = @_;

    %override = (%override);

    $override{keep_output} = 'YES';

    $self->do_cmd($cmd, %override);

    return [$self->get_last_do_cmd_output()];
}


#
# Die when this obsoleted function is called.
#
sub do_cmd_ignore_error_pattern
{
    my ($self, $cmd, %override) = @_;

    return $self->error
        ("This function is not supported and will be obsoleted soon.");
}


#
# Performs a do_cmd and ignores any error.
#
sub do_cmd_ignore_error
{
    my ($self, $cmd, %override) = @_;

    $self->_print_log_comment("Ignoring any error in the following command:");

    %override = (%override);
    $override{error_pattern}   = '';
    $override{no_die_on_error} = $override{no_error_output} = 'YES';

    return $self->do_cmd($cmd, %override);
}


#
# Find out all the sudo binaries available in the path,
# evaluate each one of them and find the one that works
# If there is just a single binary or no binaries work, return
# plain "sudo" so that the sudo binary in the path will be used
# If an optional param "sudoed_cmd" is passed, check if the
# value of that param is listed in the allowed commands
#
sub get_working_sudo_binary
{
    my ($self, $options) = @_;
    my $timeout = 30;

    return $self->{SUDO_BINARY}
        if ($self->{SUDO_BINARY} and ! $options->{sudoed_cmd});

    #
    # Find out if there are multiple sudo binaries in path; since do_cmd
    # executes the given command using sh and where command is not available
    # in sh, we specfically use bash to execute the 'type -a' command
    #
    $self->output("Finding an appropriate sudo binary.\n");
    my $output = $self->do_cmd_get_output("bash -c 'type -a sudo'",
                                          no_die_on_error => 1,
                                          no_stack_trace  => 1,
                                          timeout         => $timeout);

    my %binaries;
    foreach my $binary(@$output)
    {
        my ($match) = ($binary =~ qr#^[^/]*([^\s]+)#);
        $binaries{$match}++ if (defined $match ? $match =~ /sudo$/ : undef);
    }

    #
    # If multiple binaries were not found, use the one available in path
    #
    if (keys(%binaries) <= 1)
    {
        $self->{SUDO_BINARY} = "sudo";
        $self->output("Using the default sudo binary.\n");
        return $self->{SUDO_BINARY};
    }

    #
    # Prioritize /usr/local/bin/sudo as it will likely be the one we're after
    #
    my @priority;
    my $preferred_binary = '/usr/local/bin/sudo';
    if (exists $binaries{$preferred_binary})
    {
        push (@priority, $preferred_binary);
        delete $binaries{$preferred_binary};
    }
    push (@priority, sort keys %binaries);

    #
    # Attempt each sudo binary and use the first one that works
    #
    $self->output("Looking for a sudo binary that allows " .
                  $options->{sudoed_cmd} . ".\n")
        if $options->{sudoed_cmd};
    my $preferred_shell = $options->{shell} || "bash";
    foreach my $binary(@priority)
    {
        unless ($self->do_cmd("$preferred_shell -c '$binary -l'",
                              no_die_on_error => 1,
                              no_error_output => 1,
                              keep_output     => 1,
                              timeout         => $timeout))
        {
            my $binary_found = 1;
            if ($options->{sudoed_cmd})
            {
                my @output  = $self->get_last_do_cmd_output();
                my $pattern = qr "\b($options->{sudoed_cmd}|ALL)\b";
                unless (grep { /$pattern/ } @output)
                {
                    $binary_found = 0;
                }
            }

            if ($binary_found)
            {
                $self->{SUDO_BINARY} = $binary;
                $self->output("Found working sudo binary: $binary.\n");
                return $self->{SUDO_BINARY};
            }
        }
    }

    #
    # None of the binaries worked - fall back to the default
    #
    $self->{SUDO_BINARY} = "sudo";
    $self->output("Using the default sudo binary.\n");
    return $self->{SUDO_BINARY};
}

#
# Uses sudo binary to run a given command - finds out the most appropriate
# sudo, then runs the command using a given shell (defaults to bash)
#
sub do_os_sudo_cmd
{
    my ($self, $cmd, %override) = @_;

    my $cmd_shell   = $override{shell} || 'bash';

    #
    # Since we run the given command directly under the given shell, we
    # need to check sudoers for that shell, or bash which is the default
    #
    my $sudo_binary = $self->get_working_sudo_binary
        ({shell          => $cmd_shell,
          sudoed_cmd     => $cmd_shell});

    #
    # Since we execute the given command in single quotes, we need to escape
    # single quotes that may be included in the command - terminate the single
    # quote, escape it with backslash and then resume the single quote again
    #
    $cmd =~ s#'#'\\''#g;

    $self->do_cmd("$sudo_binary $cmd_shell -c '$cmd'", %override);
}

sub do_os_sudo_cmd_get_output
{
    my ($self, $cmd, %override) = @_;

    $override{keep_output} = 'YES';

    $self->do_os_sudo_cmd($cmd, %override);

    return [$self->get_last_do_cmd_output()];
}

sub _do_cmd_unique_replace
{
    my ($self, $cmd) = @_;

    foreach my $replace_pattern (keys(%{$self->{DOCMD_UNIQUE_REPLACE}}))
    {
        my $unique_replace_elements = $self->{UNIQUE_REPLACE_ELEMENTS};
        my $replace_with = $self->{DOCMD_UNIQUE_REPLACE}->{$replace_pattern};
        my $replace_element = $unique_replace_elements->{$replace_pattern};
        if (!defined $replace_element)
        {
            if ($cmd =~ m/$replace_pattern/)
            {
                $unique_replace_elements->{$replace_pattern} =  $1;
                if ($replace_with =~ m/\$\d/)
                {
                    map {s/$replace_pattern/$replace_with/gee} $cmd;
                }
                else
                {
                    map {s/$replace_pattern/$replace_with/g} $cmd;
                }
            }
        }
        else
        {
            if ($cmd =~ m/$replace_pattern/)
            {
                my $match = $1;
                if ($replace_element !~ m/$match/)
                {
                    $unique_replace_elements->{$replace_pattern} = $match;
                    if ($replace_with =~ m/\$\d/)
                    {
                        map {s/$replace_pattern/$replace_with/gee} $cmd;
                    }
                    else
                    {
                        map {s/$replace_pattern/$replace_with/g} $cmd;
                    }
                }
            }
        }
    }
    return $cmd;
}


sub _do_cmd_replace
{
    my ($self, $cmd) = @_;
    foreach my $replace_pattern (keys(%{$self->{DOCMD_REPLACE_OUTPUT}}))
    {
        my $replace_with = $self->{DOCMD_REPLACE_OUTPUT}->{$replace_pattern};

        #
        # handling the condition where $replace_with contains perl expression
        # variables that need interpolation.
        #
        if ($replace_with =~ m/\$\d/)
        {
            map {s/$replace_pattern/$replace_with/gee} $cmd;
        }
        else
        {
            map {s/$replace_pattern/$replace_with/g} $cmd;
        }
    }
    return $cmd;
}

#
# Returns an array of lines that were output by the last command called by
# $self->do_cmd()
#
sub get_last_do_cmd_output {
    my ($self) = @_;

    my $begin = $self->{DOCMD_BEGIN_OUTPUT};
    my $end   = defined($self->{DOCMD_END_OUTPUT}) ?
                $self->{DOCMD_END_OUTPUT} : (@{$self->{DOCMD_OUTPUT}} - 1);

    return ($end < $begin ? () : @{$self->{DOCMD_OUTPUT}}[$begin..$end]);
}

#
# Print a separator line in the log file
#
sub _print_log_separator
{
    my($self) = @_;
    $self->output("#|" . "-"x68 . "\n");
}

#
# Print a comment in the log file as seen in the header or footer
#
sub _print_log_comment
{
    my($self, $text) = @_;
    $text =~ s/^/#| /gm;
    $text =~ s/\n?$/\n/;
    $self->output($text);
}

#
# Prints a header to the log file.  Called before _do_cmd is called
#
sub _print_log_head {
    my ($self, @cmd) = @_;
    my $cmd = join("\n", @cmd);

    $self->clear_output();

    #
    # Get a time stamp
    #
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        localtime(time);

    my $date = sprintf("%02d/%02d/%02d %02d:%02d:%02d",
                       $year%100, $mon+1, $mday, $hour, $min, $sec);

    my $timeout = ($self->{DOCMD_TIMEOUT} ?
                   "$self->{DOCMD_TIMEOUT} sec timeout" :
                   "no timeout");


    $self->output("\n");
    $self->_print_log_separator;
    $self->_print_log_comment("$self->{DOCMD_DESCRIPTION}, $date ($timeout)\n".
                              "$cmd\nProgram Output:");

    $self->{DOCMD_BEGIN_OUTPUT} = @{$self->{DOCMD_OUTPUT}};
}


#
# Prints a trailer to the output from _do_cmd.  A defined value
# indicates an error.  Prints the value returned in the trailer.  Prints
# "command successful" if the return value is undefined
#
sub _print_log_tail {
    my ($self, $result) = @_;

    $self->{DOCMD_END_OUTPUT} = @{$self->{DOCMD_OUTPUT}} - 1;

    $self->_print_log_comment("Result: $result");
    $self->_print_log_separator;
    $self->output("\n");
}

#
# Print a line and also add it to the error buffer
#
sub output_error_line
{
    my($self, $line) = @_;
    $self->output($line);
    $self->_error_buffer_add($line);
}


#
# Prints output to the output file and appends it to $self->{DOCMD_OUTPUT} if
# the flag $self->{DOCMD_KEEP_OUTPUT} is set. Also check the error message if
# nothing has been found.
#
# Now a module can be set which can parse the output and convert it
# appropriately
#
#
sub output
{
    my ($self, @output) = @_;

    #
    # If the parser object is defined, then call the parse method on it,
    # if output is nothing then just return from here
    #
    if ($self->{PARSER_OBJECT})
    {
        @output = $self->{PARSER_OBJECT}->parse(@output);
        return undef if ( !@output)
    }

    @output = $self->_do_cmd_unique_replace(@output);

    @output = $self->_do_cmd_replace(@output);

    $self->{DOCMD_FILEHANDLE}->print(@output) if $self->{DOCMD_FILEHANDLE};

    push(@{$self->{DOCMD_OUTPUT}}, @output) if $self->{DOCMD_KEEP_OUTPUT};

    unless ( exists $self->{ERROR_MESSAGE}     &&
             exists $self->{DOCMD_KEEP_OUTPUT} )
    {
        $self->extract_error_message(@output);
    }

    return undef;
}


#
# Given lines of text, extract the first error message according to the error
# pattern.
#
sub extract_error_message
{
    my ($self, @output) = @_;
    #
    # Just because a command did not die, does not mean it executed
    # successfully.  If an error pattern has been defined, we need to
    # examine the output to see if any lines match the error pattern.
    #
    my $error_pattern = $self->{DOCMD_ERROR_PATTERN};

    #
    # If an error pattern has been specified, all of the output from the
    # commands is compared against the error pattern.  If a match is made,
    # an error will be raised.
    #
    # The error pattern can be a Perl regular regression.  If the
    # expression contains parentheses, the pattern inside the group
    # will been the error message returned.  Otherwise the error message
    # is the entire matched string.  For example, the error string
    # returned for the error pattern LABEL:(.*) is the string matched
    # without 'LABEL:'.
    #
    if ($error_pattern)
    {
        my $err_msg;
        foreach my $line (@output)
        {
            if ($line =~ /$error_pattern/)
            {
                $err_msg = $1;
                $err_msg ||= $&;
                $err_msg =~ s/\n$//;
                if ($self->{DOCMD_REPORT_ERROR})
                {
                    $self->{DOCMD_FILEHANDLE}->print_error(
                        "$err_msg");
                    next;
                }
                else
                {
                    $self->{ERROR_MESSAGE} = $err_msg;
                    last;
                }
            }
        }
    }
}


#
# This method actually performs the command.  It is separate from do_cmd()
# so that it can be overriden by other classes (specifically DoCoproCmd).
#
sub _do_cmd {
    my($self, $cmd) = @_;


    #
    # Set signal handlers to for the alarm, pipe, and child signals.
    #
    # Note: The CLD handler is deliberately set to an empty sub instead
    # of 'IGNORE'.  For some reason, setting it to 'IGNORE' would cause the
    # subsequent waitpid() call to not see the process when we migrated from
    # Solaris 2.5 to 2.6.
    #
    local($SIG{ALRM}) = sub { $self->_handle_sigalarm() };
    local($SIG{PIPE}) = sub { $self->_handle_sigpipe()  };
    local($SIG{CLD})  = sub { };

    $self->_set_alarm();

    my $pid = $self->_fork_exec($cmd);

    #
    # Read output from the child until the child closes the filehandle or
    # child exits.
    #
    my $status  = undef;
    my $select  = IO::Select->new($self->{DOCMD_READ_FH});
    my $timeout = 5;

    #
    # Without non blocking IO if the child exits during the read()
    # call in getline(), read is restarted later and blocks waiting for
    # input from grandchildren. We want to stop reading as soon as
    # the immediate child exits. Unblocking minimizes the window of
    # time for a blocked read to be restarted due to a child exit. The
    # return value of blocking() is not checked because usually
    # blocking IO works and we can live with a few blocking() failures
    # See bug 6484796 for details.
    # Getline with non blocking read occasionally returns part lines. Code
    # that depends on line formatting breaks when parts of lines are returned.
    # So non blocking is enabled conditionally. See bug 6878320
    #
    my $prev;
    $prev = $self->{DOCMD_READ_FH}->blocking(0)
        unless ($self->{DOCMD_KEEP_OUTPUT});
    $self->_error_buffer_reset;
    while (1)
    {
        my $line = undef;
        my @fd   = $select->can_read($timeout);
        if (@fd && $fd[0] eq $self->{DOCMD_READ_FH})
        {
            $line = $self->{DOCMD_READ_FH}->getline();
        }

        #
        # Sometimes can_read() returns true even though there is nothing
        # to read. So $line will be undef. Code is structured to handle
        # this case.
        #
        if (defined($line))
        {
            $self->output_error_line($line);
        }
        else
        {
            #
            # If there is no data, check if the process is still alive by
            # making a call to waitpid in non-blocking mode.
            #
            my $ret = waitpid($pid, &POSIX::WNOHANG);
            if ($ret == -1 or $ret == $pid)
            {
                $status = $?;

                #
                # Check if the process sent any data before exit/die.
                $line = $self->{DOCMD_READ_FH}->getline();
                $self->output_error_line($line) if (defined($line));

                last;
            }
        }
    }
    $self->{DOCMD_READ_FH}->blocking($prev) if (defined($prev));

    my $rc = 0xffff & $status;

    $self->_reset_alarm();
    $self->_close_ipc_filehandles();

    #
    # Adapted from O'Reilly Perl 2nd Ed. p.230 for handling system() errors.
    #
    if ($rc == 0) {
        return undef; # normal exit
    }
    elsif ($rc == 0xff00) {
        die "command failed: $!";
    }
    elsif ($rc & 127) {
        $rc &= 127;
        die $self->_make_error_message("caught signal $rc");
    }
    else {
        $rc >>= 8;
        die $self->_make_error_message("non-zero exit status $rc");
    }
}

sub _make_error_message
{
    my($self, $message) = @_;
    my $context = $self->_error_buffer_as_string();
    chomp $context if $context;
    $message = $context . "\n" . $message
        if $context && $message !~ /\Q$context\E/;

    #
    # Ensure it has a trailing \n
    #
    $message =~ s/\n?$/\n/;
    return $message;
}

#
# Reset buffer used to hold output; in case of error, last 10 lines of
# output are to be added to the error message.
#
sub _error_buffer_reset
{
    my($self) = @_;
    $self->{DOCMD_ERROR_BUFFER} = [];
}

#
# Add line to the buffer used to hold output; in case of error, last
# 10 lines of output are to be added to the error message.
#
sub _error_buffer_add
{
    my($self, $line) = @_;
    my $buf = $self->{DOCMD_ERROR_BUFFER} ||= [];
    $line =~ s/\r//;      # better than chomp() as DoRemoteCmd adds \r

    #
    # Discovered that sometimes the value returned by getline() is not
    # an entire line.  So when we put the line into the error buffer,
    # don't chomp the \n off, and when a line didn't end in \n the
    # next line is added to that entry in the array instead of pushing
    # it to the end of the array.
    #
    if (@$buf && $buf->[-1] !~ /\n$/)
    {
        $buf->[-1] .= $line;
    }
    else
    {
        push(@$buf, $line);
    }
    @$buf = @$buf[-10..-1] if (@$buf > 10);
}

#
# Return error buffer as a string; in case of error, last 10 lines of
# output are to be added to the error message.
#
sub _error_buffer_as_string
{
    my($self) = @_;
    my $buf = $self->{DOCMD_ERROR_BUFFER} ||= [];
    return "" unless @$buf;
    chomp(my $str = join("", @$buf));
    $str =~ s/\r//g;
    return $str;
}

#
# Cleans up after a command failed to execute.
#
sub _do_cmd_cleanup {
    my ($self) = @_;

    #
    # See if there is any lingering output from a dead child process
    # and print it if there is.
    #
    if ($self->{DOCMD_READ_FH} and $self->{DOCMD_PID} <= 0 ) {
        my @stat = $self->{DOCMD_READ_FH}->stat();
        my $size = $stat[7];
        if ($size > 0) {
            my @linger = $self->{DOCMD_READ_FH}->getlines();
            $self->output(@linger);
        }
    }

    #
    # If the process is no longer active, make sure the IPC filehandles
    # are closed.
    #
    $self->_close_ipc_filehandles();

    #
    # Make sure the alarm is disarmed.
    #
    $self->_reset_alarm();

    # Windows worker changes !!!
    $self->do_chdir("\\") if ($^O =~ /MSWin32/);
}

#
# Forks and execs an external program.  Stores the process id and filehandles
# to the child processes stdin and stdout.
#
sub _fork_exec {
    my ($self, $cmd) = @_;

    my ($chld_read, $chld_write,
        $prnt_read, $prnt_write) = $self->_open_ipc_filehandles();

    my $pid = fork();

    if (defined($pid) && ($pid == 0))
    {
        $prnt_read->close  || die("Unable to close parent read: $!");
        $prnt_write->close || die("Unable to close parent write: $!");

        #
        # Following is required for this part to get working in
        # mod_perl-1.26
        #
        untie(*STDIN)  if tied(*STDIN);
        untie(*STDOUT) if tied(*STDOUT);

        #
        # Under mod_perl2, STDIN and STDOUT are pseudo handles. They don't
        # use the file decriptors 0 and 1 respectively. A spawned program
        # would write to file descriptor 1 and read from 0. The redirection
        # also must happen to these file descriptors. Since STDIN and STDOUT
        # does not use these descriptors under mp2, we need to do this special
        # handling. See bug 7248549 for details.
        #
        my ($stdin, $stdout,$fileno);

        $fileno = fileno(STDIN);

        if ( defined($fileno) and $fileno != 0)
        {
            $stdin = IO::Handle->new();
            $stdin->fdopen(0, "w") ||
                die "Unable to open STDIN using fd 0: $!\n";
        }
        else
        {
            $stdin = \*STDIN;
        }

        $fileno = fileno(STDOUT);

        if (defined($fileno) and $fileno != 1)
        {
            $stdout = IO::Handle->new();
            $stdout->fdopen(1, "r") ||
                die "Unable to open STDOUT using fd 1: $!\n";
        }
        else
        {
            $stdout = \*STDOUT;
        }

        open($stdin,  "<&" . $chld_read->fileno)  || die("open STDIN: $!");
        open($stdout, ">&" . $chld_write->fileno) || die("open STDOUT: $!");
        open(STDERR,  ">&" . $chld_write->fileno) || die("open STDERR: $!");

        select STDERR;

        $chld_read->autoflush;
        $chld_write->autoflush;

        #
        # Use this "if" statement to avoid warnings about the following
        # lines never being reached.
        #
        if (1) { exec $cmd }

        #
        # This may seem really ugly, but using "die" or "exit" just does
        # not kill the process very well.  exec should rarely fail in
        # the production environment.
        #
        print STDERR "exec failure : $!\n";
        kill(9, $$);
    }
    elsif (defined($pid) && ($pid > 0))
    {
        $self->{DOCMD_PID}      = $pid;
        $self->{DOCMD_READ_FH}  = $prnt_read;
        $self->{DOCMD_WRITE_FH} = $prnt_write;

        $chld_read->close  || die("ERROR closing child read filehandle: $!");
        $chld_write->close || die("ERROR closing child write filehandle: $!");

        $prnt_read->autoflush;
        $prnt_write->autoflush;

        return $pid;
    }
    else {
        die("can not fork:$!");
    }
}


#
# Open filehandles to communicate with the child process we are going to
# fork and exec
#
sub _open_ipc_filehandles {
    my ($self) = @_;

    my $chld_read  = new FileHandle;
    my $chld_write = new FileHandle;
    my $prnt_read  = new FileHandle;
    my $prnt_write = new FileHandle;

    pipe $chld_read, $prnt_write || die("ERROR opening IPC filehandles");
    pipe $prnt_read, $chld_write || die("ERROR opening IPC filehandles");

    return ($chld_read, $chld_write, $prnt_read, $prnt_write);
}


#
# Make sure the IPC filehandles are closed.
#
sub _close_ipc_filehandles {
    my ($self) = @_;

    #
    # It is possible we might be called twice because we are called from
    # within pipe signal handler.
    #
    if ($self->{DOCMD_WRITE_FH} and $self->{DOCMD_READ_FH})
    {
        $self->{DOCMD_READ_FH}->close;
        $self->{DOCMD_WRITE_FH}->close;
    }

    $self->{DOCMD_READ_FH}  = undef;
    $self->{DOCMD_WRITE_FH} = undef;
}


#
# If a timeout was specified, set the alarm.  We currently ignore any
# previous alarm that was set.
#
sub _set_alarm {
    my ($self) = @_;

    my $time_left = alarm($self->{DOCMD_TIMEOUT}) if $self->{DOCMD_TIMEOUT};
}


#
# If a timeout was specified, set the alarm.
#
sub _reset_alarm {
    my ($self) = @_;

    alarm(0) if $self->{DOCMD_TIMEOUT};
}

#
# Configuration variable - if set to true, signal handlers won't
# die().  Used to implement retry functionality in DoCoproCmd.
#
our $NO_DIE_ON_SIGNAL = 0;

#
# Private method: Set the alarm signal handler to an anonymous sub
# that calls this method to timeout an external command.
#
sub _handle_sigalarm {
    my ($self) = @_;

    my $pid = $self->{DOCMD_PID};
    $self->{DOCMD_PID} = -1;

    $self->{DOCMD_NO_REINIT} = 0;

    #
    # There is some leak in using ptys, so we try in closing the
    # opened ipc_handles before killing the process.
    #
    # Bug 9044810: doing this in the case of $NO_DIE_ON_SIGNAL causes
    # seg fault!  Since the method is also called in DoCoproCmd::exit,
    # should be OK to skip it here. wward 10/29/2009
    #
    $self->_close_ipc_filehandles()
        unless $NO_DIE_ON_SIGNAL;

    my $line = "Process $pid timed out after $self->{DOCMD_TIMEOUT}s.\n";
    $self->output_error_line($line);

    if($self->{DOCMD_SUDO})
    {
        my $kill_cmd = "kill -9 $pid";
        if( $self->{DOCMD_SUDO}->execute_cmd($kill_cmd,
                    no_die_on_error_force=>'YES'))
        {
            $self->output_error_line("Process $pid killed.\n");
        }
        else
        {
            $self->output_error_line("Failed to kill process $pid: $!\n");
        }

        #
        # Fix for bug 6766883. We need to exit the sudo
        # process which is created to kill another sudo
        # process.
        #
        $self->{DOCMD_SUDO}->exit();
    }
    else
    {
       if (kill 9, $pid)
       {
           $self->output_error_line("Process $pid killed.\n");
       }
       else
       {
           $self->output_error_line("Failed to kill process $pid: $!\n");
       }

    }

    die("process $pid timed out")
        unless $NO_DIE_ON_SIGNAL;
};


sub _handle_sigpipe {
    my ($self) = @_;

    $self->{DOCMD_PID} = -2 ;
    $self->{DOCMD_NO_REINIT} = 0;

    die("broken pipe")
        unless $NO_DIE_ON_SIGNAL;
}


#
# We need to check that the child process that dies was ours.  It is possible
# that a previous coprocess was killed because of a timeout.  We do not want
# to be confused with a SIGCLD from it.  We do not wait for that process after
# killing it because it can take several seconds for the wait.
#
sub _handle_sigchild {
    my ($self) = @_;

    my $pid = wait();

    if ($pid == $self->{DOCMD_PID}) {

        $self->{DOCMD_PID} = -3;
        $self->{DOCMD_NO_REINIT} = 0;

        my $rc = 0xffff & $?;

        if ($NO_DIE_ON_SIGNAL)
        {
            $self->output_error_line("process died with status code $rc");
        }
        else
        {
            die("process died with status code $rc");
        }
    }
}


#
# In APF we have noticed close commands sometimes hang usually when closing
# a filehandle opened with a pipe.
#
# This is a work around to that issue.  If the situation is detected,
# we exit the process.
#
sub hangfree_fclose
{
    my ($fh, $where, $exit_code) = @_;

    local($SIG{ALRM}) = sub
    {
        print STDERR "Abort: Process hung in file close at $where\n";
        exit($exit_code);
    };

    my $time = alarm(60);
    $fh->close();
    alarm($time);
}


#
# Returns the filehandle
#
sub get_filehandle
{
    my ($self) = @_;

    return $self->{DOCMD_FILEHANDLE};
}


1; 
