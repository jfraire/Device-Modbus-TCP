#! /usr/bin/env perl

use Device::Modbus::Request;
use Test::More tests => 16;
use strict;
use warnings;

BEGIN {
    use_ok 'Device::Modbus::TCP::ADU';
}

# Test simple accessors
{
    my $adu = Device::Modbus::TCP::ADU->new;
    isa_ok $adu, 'Device::Modbus::ADU';

    my @fields = qw(id length);

    # These should die
    foreach my $field (@fields) {
        eval {
            $adu->$field;
        };
        ok defined $@, "$field accessor dies with undefined value";
        like $@, qr/not been declared/,
            "Accessor die message for undefined $field is correct";
    }

    # But these should live
    foreach my $field (@fields) {
        $adu->$field('tested OK');
        is $adu->$field, 'tested OK',
            "Accessor/mutator for $field works correctly";
    }
}

{
    my $adu = Device::Modbus::TCP::ADU->new(
        id      => 3,
        unit    => 4,
        message => Device::Modbus::Request->new(
            function => 'Write Single Coil',
            address  => 24,
            value    => 1
        )
    );
    isa_ok $adu, 'Device::Modbus::ADU';

    is $adu->id,   3, 'ID set correctly by object constructor';
    is $adu->unit, 4, 'Unit set correctly by object constructor';

    is_deeply [unpack 'nnnC', $adu->build_header], [3, 0, 6, 4],
        'Header calculated correctly';

    is_deeply [unpack 'nnnCCnn', $adu->binary_message],
        [3, 0, 6, 4, 5, 24, 0xFF00 ],
        'Binary message was calculated correctly';
}

# This one dies
{
    my $adu = Device::Modbus::TCP::ADU->new(
        id      => 3,
        message => Device::Modbus::Request->new(
            function => 'Write Single Coil',
            address  => 24,
            value    => 1
        )
    );
    isa_ok $adu, 'Device::Modbus::ADU';
    eval { $adu->binary_message };
    ok defined $@, 'Binary message dies if unit number is not defined';
    like $@, qr/Please include a unit/,
        'And the error message is correct';
}

done_testing();
