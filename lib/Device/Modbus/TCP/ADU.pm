package Device::Modbus::TCP::ADU;

use parent 'Device::Modbus::ADU';
use Carp;
use strict;
use warnings;
use v5.10;

sub id {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{id} = $value;
    }
    croak "ID has not been declared"
        unless exists $self->{id};
    return $self->{id};
}

sub length {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{length} = $value;
    }
    croak "PDU length has not been declared"
        unless exists $self->{length};
    return $self->{length};
}

sub binary_message {
    my $self = shift;
    croak "Please include a unit number in the ADU."
        unless $self->{unit};
    my $header = $self->build_header;
    my $pdu    = $self->message->pdu();
    return $header . $pdu;
}

#### APU building

sub build_header {
    my $self   = shift;
    my $header = pack 'nnnC',
        $self->id,                                # Transaction id
        0x0000,                                   # Protocol number (Modbus)
        CORE::length($self->message->pdu) + 1,    # Length of PDU + 1 byte for unit
        $self->unit;                              # Unit number
    return $header;
}

1;
