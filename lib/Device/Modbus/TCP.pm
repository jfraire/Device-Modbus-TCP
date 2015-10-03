package Device::Modbus::TCP;

use Device::Modbus::TCP::ADU;
use IO::Socket::INET;
use Errno qw(:POSIX);
use Time::HiRes qw(time);
use Try::Tiny;
use Role::Tiny;
use Carp;
use strict;
use warnings;
use v5.10;

our $VERSION = '0.020';

####

sub read_port {
    my ($self, $bytes, $pattern) = @_;

    my $sock = $self->socket;
    croak "Disconnected" unless $sock->connected;

    local $SIG{'ALRM'} = sub { croak "Connection timed out\n" };

    my $msg;
    RECEIVE : {
        alarm $self->{timeout};
        my $rc = $self->socket->recv($msg, $bytes);
        alarm 0;
        if (exists $!{EINTR} && $!{EINTR} || length($msg) == 0) {
            redo RECEIVE;
        }
        if (!defined $rc) {
                croak "Communication error while reading request: $!";
        }
    }

#    say STDERR "Bytes: " . length($msg) . " MSG: " . join '-', unpack $pattern, $msg;
    return unpack $pattern, $msg;
}

sub write_port {
    my ($self, $adu) = @_;

    local $SIG{'ALRM'} = sub { die "Connection timed out\n" };
    my $attempts = 0;
    my $rc;
    SEND: {
        my $sock = $self->socket;
        try {
            alarm $self->{timeout};
            $rc = $sock->send($adu->binary_message);
            alarm 0;
            if (!defined $rc) {
                die "Communication error while sending request: $!";
            }
        }
        catch {
            if ($_ =~ /timed out/) {
                $sock->close;
                $self->_build_socket;
                $attempts++;
            }
            else {
                croak $_;
            }
        };
        last SEND if $attempts >= 5 || $rc == length($adu->binary_message);
        redo SEND;
    }
    return $rc;
}

sub disconnect {
    my $self = shift;
    $self->socket->close;
}

sub new_adu {
    my ($self, $msg) = @_;
    my $adu = Device::Modbus::TCP::ADU->new;
    if (defined $msg) {
        $adu->message($msg);
        $adu->unit($msg->{unit}) if defined $msg->{unit};
        $adu->id( $self->next_trn_id );
    }
    return $adu;
}

### Parsing a message

sub parse_header {
    my ($self, $adu) = @_;
    my ($id, $proto, $length, $unit) = $self->read_port(7, 'nnnC');
    
    $adu->id($id);
    $adu->length($length);
    $adu->unit($unit);

    return $adu;
}

sub parse_footer {
    my ($self, $adu) = @_;
   return $adu;
}

1;
