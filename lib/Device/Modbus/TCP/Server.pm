package Device::Modbus::TCP::Server;

use Device::Modbus;
use Device::Modbus::TCP::ADU;
use Device::Modbus::Exception;
use Try::Tiny;
use Role::Tiny::With;
use Carp;
use strict;
use warnings;

use parent qw(Device::Modbus::Server Net::Server::PreFork);
with  'Device::Modbus::TCP';

sub new {
    my ($class, %args) = @_;
    return bless { server => \%args, %{ $class->proto() }}, $class;
}

sub default_values {
    return {
        log_level   => 2,
        log_file    => undef,
        port        => 502,
        host        => '*',
        ipv         => 4,
        proto       => 'tcp',
    };
}

sub post_accept_hook {
    my $self = shift;
    $self->{socket} = $self->{server}->{client};
}

sub socket {
    my $self = shift;
    croak "Connection is unavailable" unless defined $self->{socket};
    return $self->{socket};
}

# Return exception if unit is not supported by server
sub request_for_others {
    my ($self, $adu) = @_;
    return Device::Modbus::Exception->new(
            function       => $Device::Modbus::function_for{$adu->code},
            exception_code => 2,
            unit           => $adu->unit
    );
}

use Data::Dumper;
sub process_request {
    my $self = shift;

    while ($self->socket->connected) {
        my $req_adu;
        try {
            $req_adu = $self->receive_request;
        }
        catch {
            unless (/Connection timed out/) {
                $self->log(2, "Error while waiting for request: $_");
            }
        };
        next unless $req_adu;
        

        $self->log(4, 'Received message from ' . $self->socket->peerhost);
        $self->log(4, 'Request: ' . Dumper $req_adu);
        
        # If it is an exception object, we're done
        if ($req_adu->message->isa('Device::Modbus::Exception')) {
            $self->log(3, "Exception while waiting for requests: $_");
            $self->write_port($req_adu);
            next;
        }

        # Process request
        my $resp = $self->modbus_server($req_adu);
        my $resp_adu = $self->new_adu;
        $resp_adu->message($resp);
        $resp_adu->id($req_adu->id);
        $resp_adu->unit($req_adu->unit);
    
        # And send the response!
        $self->write_port($resp_adu);
        $self->log(4, "Response: " . Dumper $resp_adu);
        $self->log(4, "Binary response: " . join '-', unpack 'C*', $resp_adu->binary_message);
    }
    $self->log(3, 'Client disconnected');
}

sub start {
    my $self = shift;
    $self->log(2, 'Starting server');
    $self->run;
}
 
1;

__END__

=head1 NAME Device::Modbus::Server::TCP -- Modbus TCP server class

=head1 SYNOPSIS

    use My::Unit;
    use Device::Modbus::Server::TCP;
    use strict;
    use warnings;

    my $server = Device::Modbus::Server::TCP->new(
        log_level         =>  2,
        min_servers       => 10,
        max_servers       => 30,
        min_spare_servers => 5,
        max_spare_servers => 10,
        max_requests      => 1000,
    );

    $server->add_server_unit('My::Unit', 1);
    $server->start;

=head1 DESCRIPTION

One of the goals for L<Device::Modbus> is to have the ability to write Modbus servers that execute arbitrary code. This class defines the Modbus TCP version of such servers. Please see the documentation in L<Device::Modbus::Server> for a thorough description of the interface; refer to this document only for the details inherent to Modbus TCP.

=head1 USAGE

Besides the description in L<Device::Modbus::Server>, this server obtains its functionality from L<Net::Server::PreFork>, from which it inherits. Be sure to read carefully their documentation.

Device::Modbus::Server::TCP binds to the given port (502 by default) and then forks C<min_servers> child processes. The server will make sure that at any given time there are C<min_spare_servers> available to receive a client request, up to C<max_servers>. Each of these children will process up to C<max_requests> client connections. This should allow for a heavily hit server.

=head1 CONFIGURATION

All the configuration possibilities found in L<Net::Server::PreFork> are available. The default parameters for Device::Modbus::Server::TCP are:

    log_level   => 2,
    log_file    => undef,
    port        => 502,
    host        => '*',
    ipv         => 4,
    proto       => 'tcp',

=head1 Net::Server::PreFork METHODS USED

The methods defined by Net::Server::PreFork and used by Device::Modbus::Server::TCP are:

=head2 default_values

This is used only to pass the default parameters of the server. Note that this is the lowest priority form of configuration; these values can be overwritten by passing arguments to C<new>, by passing command-line arguments, by passing arguments to C<run>, or by using a configuration file. You can, of course, write your own C<default_values> method in a sub-class.

=head2 process_request

This is where the generic Modbus server method is called. It listens for requests, processes them, and returns the responses.

=head1 NOTES

In the examples directory, there is a program called LoadTester.pl which is a modified version of the one which comes with Net::Server. It uses a pre-forking client to issue as many requests as possible to a server and then reports its failure rate and load. This program was modified to work against the example server. It would be interesting to run the program in one computer and the server in another one to test server performance.

While Modbus RTU processes are single-process, this server is not. It is important to notice that, because of its forking nature, each process has its own copy of the units you defined. While there are indeed mechanisms for them to communicate (see Net::Server), in general they are completely independent. Global variables are then global by process only and not accross the whole process group. This boils down to the fact that the example server in this distribution, which keeps register values in a per-process global variable, will not work in a real work scenario. It would be necessary to persist registers outside of the server, like in a database.

Net::Server::PreFork is also at the heart of L<Starman>, a high-performance, Perl-based web server.

=head1 SEE ALSO

The documentation of the distribution is split among these different documents:

=over

=item L<Device::Modbus>

=item L<Device::Modbus::Client>

=item L<Device::Modbus::Server>

=item L<Device::Modbus::Server::TCP>

=item L<Device::Modbus::Server::RTU>

=item L<Device::Modbus::Spy>

=back

=head1 GITHUB REPOSITORY

You can find the repository of this distribution in L<GitHub|https://github.com/jfraire/Device-Modbus>.

=head1 AUTHOR

Julio Fraire, E<lt>julio.fraire@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Julio Fraire

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

614 4 11 01 79

=cut

