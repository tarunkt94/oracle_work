package RemoteCmd;

use strict;
use warnings;

use Logger;
require DoSystemCmd;
my $system = DoSystemCmd->new({filehandle => \*STDOUT});


#Constructor
sub new {

    my ($class, %args) = @_;

    my $self = {
        user => $args{user},
        passwd => $args{passwd},
        logObj => $args{logObj},
    };

    bless ($self, $class);

    return $self;
}


#
# Run commands with ssh connection
# Input:
#     cmd => command
#     filter => filter
#     host => host name
# Return output of command
#
sub executeCommandsonRemote {

    my ($self, %params) = @_;

    my $ssh_cmd = "expect -c \'spawn ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $self->{user}\@$params{host} $params{cmd};
                   expect \"password:\" ;
                   send \"$self->{passwd}\\r\";
                   send \"exit\\r\";
                   interact\'";

    if (exists $params{filter}) {
        $ssh_cmd .= " | $params{filter}";
    }

    $self->{'logObj'}->info(["Running Command: $ssh_cmd"]);

    my $out;

    if($ssh_cmd =~ /asm/i){
        $out = $system->do_cmd_get_output($ssh_cmd, no_die_on_error => 1 , timeout => 60 );
    }
    else{
    	$out = $system->do_cmd_get_output($ssh_cmd);
    }

    if (grep(/error|no such|failed|fail/i, @$out) and
        !grep(/untrusted X11 forwarding setup failed: xauth key data not generated/i, @$out)) {
        $self->{'logObj'}->error([@$out]);
    } else{
        $self->{'logObj'}->info([@$out]);
    }

    return $out;
}

#
# Copy src file to dest file
# Input:
#     file => file name
#     host => host name
#     dest => destination file name
# Return destfile
#
sub copyFileToHost {

    my ($self, %params) = @_;

    my $ssh_cmd = "expect -c \'spawn scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $params{file} $self->{user}\@$params{host}:$params{dest};
                   expect Password: ;
                   send \"$self->{passwd}\\r\";
                   send \"exit\\r\";
                   interact\'";

    my $out = $system->do_cmd_get_output($ssh_cmd);

    return $params{destfile};
}


#
# Copy src file to dest file
# Input:
#     file => file name
#     host => host name
#     dest => destination file name
# Return destfile
#
sub copySrcToDest {

    my ($self, %params) = @_;

    my $ssh_cmd = "expect -c \'spawn scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $self->{user}\@$params{host}:$params{file} $params{username}\@$params{hostname}:$params{destdir};
		   expect $params{host} ;
                   send \"$self->{passwd}\\r\";
                   expect $params{hostname};
                   send \"$params{hostpasswd}\\r\";
                   send \"exit\\r\";
                   interact\'";

    my $out = $system->do_cmd_get_output($ssh_cmd);

    return $params{destfile};
}

#
# Copy src file to destination directory
# Input:
#     file => file name
#     host => host name
#     destdir => destination directory name
# Return destdir
#
sub copyFileToDir {

    my ($self, %params) = @_;

    my $ssh_cmd = "expect -c \'spawn scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $self->{user}\@$params{host}:$params{file} $params{destdir};
                   expect Password: ;
                   send \"$self->{passwd}\\r\";
                   send \"exit\\r\";
                   interact\'";

    my $out = $system->do_cmd_get_output($ssh_cmd);

    return $params{destdir};
}


#
# Create and Run SH script on Remote host
# Input:
#     oracle_home => oracle home
#     db_sid => oracle sid
#     test => test case name
#     host => host name
# Return output of sh script
#
sub createAndRunScript {

    my ($self, %params) = @_;

    my $FILE = "/tmp/$params{host}.script.$$.sh";

    open ( EXPFILE, "> $FILE" ) or die "cannot create $FILE";
    print EXPFILE <<"END";

$params{cmd};

END

    close (EXPFILE);
    chmod 0755, $FILE;

    my $out = copyFileToHost($self, host => $params{host},
                             dest => "/tmp", file => "$FILE");

    if (exists $params{filter}) {
        $out = executeCommandsonRemote($self, host => $params{host},
                                       cmd => $FILE,
                                       filter => $params{filter});
    } else {
        $out = executeCommandsonRemote($self, host => $params{host},
                                       cmd => $FILE);
    }

    if (grep(/error|no such|failed|Fail/i, @$out)) {
        return 1, "@$out";
    }

    $out = `rm -rf $FILE`;
    my $rm_cmd = "rm -rf $FILE";

    if (exists $params{filter}) {
        $out = executeCommandsonRemote($self, host => $params{host},
                                       cmd => "$rm_cmd",
                                       filter => $params{filter});
    } else {
        $out = executeCommandsonRemote($self, host => $params{host},
                                       cmd => "$rm_cmd");
    }

    if (grep(/error|no such|failed|Fail/i, @$out)) {
        return 1, "@$out";
    }

    return 0, "@$out";
}

1;
