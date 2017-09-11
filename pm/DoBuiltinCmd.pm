# 
# $Header: dte/DTE/scripts/fusionapps/cli/pm/DoBuiltinCmd.pm /main/1 2015/12/21 02:15:22 ljonnala Exp $
#
# DoBuiltinCmd.pm
# 
# Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      DoBuiltinCmd.pm - DoBuiltinCmd Package
#
#    DESCRIPTION
#       This package serves a convenience layer for interacting with the
#       Perl builting commands.  All methods begin with a "do_" and perform some
#       action on the system such as deleting a file (do_unlink), copying a
#       file (do_copy), making a directory (do_mkdir), etc.
#
#       It logs output to a specified filehandle.  It logs to STDERR if no
#       filehandle is specified or if the 'stderr' debugging option is set.
#       It also saves all output into a log buffer.
#
#       It checks for errors and allows you to handle them in one of two ways.
#       The default is to die whenever an error is encounterd.  The
#       other just returns a defined value indicating the error.  Errors
#       are always logged and put into the output buffer.
#
#    MODIFIED   (12/21/15)
#    ljonnala    12/21/15 - Add builtincmd file
#    ljonnala    12/21/15 - Creation
#

package DoBuiltinCmd;
require 5.004;
use     strict;
use     FileHandle;
use     File::Path;
use     Debug;

#
# Create A DoBuiltinCmd object.
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
#
sub new
{
    my ($class, $options) = @_;

    my $self = bless {}, $class;

    #
    # Open a log file.
    #
    if ($options->{filename} and !$options->{filehandle})
    {
        $options->{filehandle} = new FileHandle(">$options->{filename}") ||
            die("Can not open $options->{filename}: $!");
    }

    #
    # If a file handle is not specified or "stderr" is defined in the
    # debugging parameters, logging output goes to STDERR.
    #
    if (Debug::is_on_if('stderr') or !$options->{filehandle})
    {
        $options->{filehandle} = new FileHandle;
        $options->{filehandle}->fdopen(\*STDERR, "w");
        $options->{filehandle}->autoflush(1);
    }

    $self->{DOCMD_FILEHANDLE}      = $options->{filehandle};
    $self->{DOCMD_NO_DIE_ON_ERROR} = $options->{no_die_on_error} || 0;
    $self->{DOCMD_NO_ERROR_OUTPUT} = $options->{no_error_output} || 0;
    $self->{DOCMD_NO_STACK_TRACE}  = $options->{no_stack_trace} || 0;
    $self->{DOCMD_OUTPUT}          = [];

    return $self;
}

#
# Return the value of a given option, such as "filehandle".  If the
# value of the option is a reference, be careful not to change its
# contents or weird things can happen!
#
sub get_option
{
    my($self, $option_name) = @_;
    return $self->{uc("DOCMD_$option_name")};
}

#
# A wrapper to print output to the output file.
#
sub output
{
    my ($self, @output) = @_;

    return $self->_output(@output);
}


#
# Prints output to the output file.
#
sub _output
{
    my ($self, @output) = @_;

    $self->{DOCMD_FILEHANDLE}->print(@output) if $self->{DOCMD_FILEHANDLE};

    return ();
}


#
# Outputs the error and dies with the error message
#
sub error
{
    my ($self, $error) = @_;

    unless ($self->{DOCMD_NO_ERROR_OUTPUT}) {
        $self->_output($error);
        unless ($self->{DOCMD_NO_STACK_TRACE})
        {
            my $stack = join("\n", "\n", Debug::stack_trace(), "\n");
            $self->{DOCMD_FILEHANDLE}->print($stack)
                if $self->{DOCMD_FILEHANDLE};
        }
    }

    if ($self->{DOCMD_NO_DIE_ON_ERROR}) {
        return $error;
    }
    else {
        die($error);
    }
}


#
# Clears the output buffer *unless* $self->{DOCMD_CLEAR_OUTPUT} is set.
#
sub clear_output
{
    my ($self) = @_;
    return if $self->{DOCMD_CLEAR_OUTPUT};

    $self->{DOCMD_OUTPUT} = [];
    $self->{DOCMD_BEGIN_OUTPUT} = $self->{DOCMD_END_OUTPUT} = 0;
}


######################################################################
#
# The following methods are for executing perl built in
# commands that create/delete directories, copy files, etc.
#
######################################################################

sub do_chdir
{
    my ($self, $dir) = @_;

    unless (chdir("$dir"))
    {
        return $self->error("ERROR: Failed to chdir $dir: $!\n");
    }

    $self->_output("chdir $dir\n");
}


sub do_mkdir
{
    my ($self, $dir, $perm) = @_;

    unless (-d $dir)
    {
        #
        # mkdir "x/." will fail because it will create the directory "x" and
        # then it will try to create "." which will fail.  Instead of failing,
        # let's try to be smart about it and remove the "/.".  This enhancemt
        # was for APF.
        #
        $dir =~ s@[/\\]\.(/|$)@$1@;

        $perm ||= 0775;
        my $old_umask = umask;
        umask(0777 & ~$perm);
        if ( mkpath("$dir", 0, $perm) == 0)
        {
           return $self->error("ERROR: Failed to create directory $dir: $!\n")
               unless -d $dir;
        }
        else
        {
            $self->_output("mkdir $dir\n");
        }
        umask $old_umask;
    }

    return ();
}


sub do_rmdir
{
    my ($self, @dirs) = @_;

    foreach my $dir (@dirs)
    {
        if (-e $dir)
        {
            if (rmdir($dir))
            {
                $self->_output("rmdir $dir\n");
            }
            else
            {
                return $self->error("ERROR: Failed to remove $dir: $!\n");
            }
        }
    }
    return ();
}


#
# Equivalent to "rm -rf"
#
# If the error message is "Invalid argument", it may mean the
# current directory the patch being removed.  Unfortunately the
# Perl package does not give a better error message.
#
sub do_rmtree {
    my ($self, $dir, $verbose_filehandle) = @_;

    #
    # $verbose_filehandle is an optional argument that may be passed
    # if the caller wishes to log the files that are deleted when
    # the directory tree is removed.  It should be a FileHandle
    # object, as opposed to a Log object, that is associated with an
    # output file.
    #

    if (-e $dir)
    {
        #
        # If directory contains "/" at the end, remove it
        #
        $dir =~ s/\/+$//;

        $self->_output("rmtree $dir\n");

        #
        # Move element to ".time().delete" to be unique before actual removal.
        #
        my $dir_del = "$dir.$$." . time() . ".delete";
        $self->do_rename($dir, $dir_del);

        #
        # This is to workaround what seems to be a bug in
        # File::Path::rmtree().  There are cases in ARU Checkin when
        # it does not have permission to delete a file.  It loops
        # endlessly "carp"ing about the file.  carp() only seems to do
        # a warn not a die.  Also sometimes rmtree doesnot delete the
        # directory tree in one shot, it just deletes the elements
        # under the directory tree and warns.  The workaround for the
        # former case is to die and for the latter is to ignore the
        # warning and issue rmtree again.
        #
        local($SIG{__WARN__}) =
            sub
            {
                my $error = join ' ', @_;

                #
                # Ignore "Directory not empty" warning.
                #
                die (@_)
                    unless ($error =~ m/Directory not empty/);
            };

        #
        # Must select and restore the proper filehandle because rmtree
        # just prints to the currently selected filehandle.
        # Only do this if the caller wishes to print a list of files
        # that are examined to a log file.
        #
        my $fh = select($verbose_filehandle) if ($verbose_filehandle);

        #
        # In Development, when run under a clearcase view, sometimes
        # rmtree does not delete the directory on first
        # invocation. This is intermittent and as a workaround we
        # issue rmtree once again.
        #
        my ($try, $max_tries, $rc) = (1,2);
        while ($try <= $max_tries)
        {
            #
            # Wrap the rmtree in an eval incase it dies so we can grab
            # control and and restore the proper filehandle.  The
            # second argument to rmtree is a boolean value which if
            # true, or not null in this case, will cause rmtree to
            # print a message each time it examines a file.
            #
            $rc = eval { return rmtree($dir_del, $verbose_filehandle, 0) };

            if (-d $dir_del)
            {
                $self->output("Failed to delete $dir_del\n".
                              "Trying again ...\n");
                sleep(1);
                $try++;
            }
            else
            {
                last;
            }
        }

        #
        # Restore the filehandle if necessary.
        #
        select($fh) if ($verbose_filehandle);

        if ($try <= $max_tries)
        {
            return $rc;
        }
        else
        {
            #
            # The directory still exists, so error out. If the error
            # message is "Invalid argument", it may mean the current
            # directory is the part of the path being removed.
            #
            $self->error("ERROR: Unable to remove tree under $dir_del:$!\n");
        }
    }

    return ();
}


sub do_copy
{
    my($self, $src, $dest) = @_;

    use File::Copy;
    unless (copy($src, $dest))
    {
        return $self->error("ERROR: Failed to copy $src to $dest: $!\n");
    }

    $self->_output("copy $src $dest\n");
}


sub do_rename
{
    my ($self, $src, $dest) = @_;

    unless (rename($src, $dest))
    {
        return $self->error("ERROR: Failed to rename $src to $dest: $!\n");
    }

    $self->_output("rename $src $dest\n");
}


sub do_link
{
    my ($self, $src, $dest) = @_;

    unless (link($src, $dest))
    {
        return $self->error("ERROR: Failed to link $src to $dest: $!\n");
    }

    $self->_output("link $src $dest\n");
}


sub do_symlink
{
    my ($self, $src, $dest) = @_;

    unless (symlink($src, $dest))
    {
        return $self->error("ERROR: Failed to symlink $src to $dest: $!\n");
    }

    $self->_output("symlink $src $dest\n");
}


sub do_unlink
{
    my ($self, @files) = @_;

    foreach my $file (@files)
    {
        if (-e $file or -l $file)
        {
            if (unlink($file))
            {
                $self->_output("unlink $file\n");
            }
            else
            {
                return $self->error("ERROR: Failed to remove $file: $!\n");
            }
        }
    }

    return ();
}


sub do_chmod
{
    my ($self, $perm, @files) = @_;

    my $oct_perm = sprintf "%04o", $perm;

    foreach my $file (@files)
    {
      if ( -e $file)
      {
        if (chmod $perm, $file)
        {
            #
            # For some reason the permission that is printed does not
            # match what was passed in.  Must be a wierd perl thing.
            #
            $self->_output("chmod $oct_perm $file\n");
        }
        else
        {
            return
                $self->error("ERROR: Failed to chmod $oct_perm, $file: $!\n");
        }
      }
    }
    return ();
}


sub do_chown
{
    my ($self, $user, @files) = @_;

    foreach my $file (@files)
    {
        if (-e $file)
        {
            if ( chown((getpwnam($user))[2,3], $file) )
            {
                $self->_output("chown $user $file\n");
            }
            else
            {
                return
                    $self->error("ERROR: Failed to chown $user, $file: $!\n");
            }
        }
    }
    return ();
}

#
# Change the group of one or more files.  Give it a group name and a
# list of filenames.
#
sub do_chgrp
{
    my ($self, $group, @files) = @_;

    #
    # Get the numeric group ID based on the group name
    #
    my $gid = getgrnam($group);
    unless ($gid)
    {
        return $self->error("ERROR: Invalid group $group\n");
    }

    #
    # Use the chown command with a uid of -1 to affect only the group
    # ID of each file
    #
    foreach my $file (@files)
    {
        if (-e $file)
        {
            if ( chown(-1, $gid, $file) )
            {
                $self->_output("chgrp $group $file\n");
            }
            else
            {
                return
                    $self->error("ERROR: Failed to chgrp $group, $file: $!\n");
            }
        }
    }
    return ();
}


#
# Does something similar to the unix command "touch".
#
sub do_utime
{
    my ($self, $file, $time) = @_;

    $time ||= time;

    if (utime $time, $time, $file)
    {
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
            localtime($time);

        $self->_output(sprintf("utime %02d/%02d/%02d %02d:%02d:%02d $file\n",
                               $year%100, $mon+1, $mday, $hour, $min, $sec));

    }
    else
    {
        return $self->error("ERROR: Failed to utime $time, $file: $!\n");
    }

    return ();
}

1; 
