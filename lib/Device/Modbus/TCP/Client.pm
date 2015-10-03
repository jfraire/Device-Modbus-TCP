package Device::Modbus::TCP::Client;

use parent 'Device::Modbus::Client';
use Role::Tiny::With;
use Carp;
use strict;
use warnings;
use v5.10;

with 'Device::Modbus::TCP';

sub new {
    my ($class, %args) = @_;

    $args{host}    //= '127.0.0.1';
    $args{port}    //= 502;
    $args{timeout} //= 2;

    return bless \%args, $class;
}

sub socket {
    my $self = shift;
    if (@_) {
        $self->{socket} = shift;
    }
    if (!defined $self->{socket}) {
        $self->_build_socket || croak "Unable to open a connection";
    }
    return $self->{socket};
}

sub _build_socket {
    my $self = shift;
    my $sock = IO::Socket::INET->new(
        PeerAddr  => $self->{host},
        PeerPort  => $self->{port},
        Blocking  => $self->{blocking},
        Timeout   => $self->{timeout},
        Proto     => 'tcp',
    );
    return undef unless $sock;
    $self->socket($sock);
    return 1;
}

#### Transaction ID
my $trans_id = 0;

sub next_trn_id {
    my $self = shift;
    $trans_id++;
    $trans_id = 1 if $trans_id > 65_535;
    return $trans_id;
}

1;
