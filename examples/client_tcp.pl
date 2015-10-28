#! /usr/bin/perl

use Device::Modbus::Client;
use Device::Modbus::TCP::Client;
use Data::Dumper;
use Modern::Perl;

my $client = Device::Modbus::TCP::Client->new();

my $req = $client->read_holding_registers(
    unit     => 3,
    address  => 2,
    quantity => 1
);



say Dumper $req;
$client->send_request($req) || die "Send error: $!";
my $response = $client->receive_response;
say Dumper $response;

$client->disconnect;
