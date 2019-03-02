package HTTP::AnyUA::Middleware;
# ABSTRACT: A base class for HTTP::AnyUA middleware

=head1 SYNOPSIS

    package HTTP::AnyUA::Middleware::MyMiddleware;

    use parent 'HTTP::AnyUA::Middleware';

    sub request {
        my ($self, $method, $url, $args) = @_;

        # Maybe do something with the request args here.

        # Let backend handle the response:
        my $response = $self->backend->request($method, $url, $args);

        my $handle_response = sub {
            my $response = shift;

            # Maybe do something with the response here.

            return $response;
        };

        if ($self->response_is_future) {
            $response->transform(
                done => $handle_response,
                fail => $handle_response,
            );
        }
        else {
            $response = $handle_response->($response);
        }

        return $response;
    }

=head1 DESCRIPTION

This module provides an interface for an L<HTTP::AnyUA> "middleware," which is a component that sits
between an L<HTTP::AnyUA> object and the L<backend|HTTP::AnyUA::Backend> (which may in fact be
another middleware).

The easiest way to use middleware is to use L<HTTP::AnyUA/apply_middleware>.

The middleware mechanism can be used to munge or react to requests and responses to and from the
backend user agent. Middlewares are a completely optional part of L<HTTP::AnyUA>. They can be
wrapped around each other to create multiple layers and interesting possibilities. The functionality
provided by middleware may be alternative to features provided by some of the supported user agents,
themselves, but implementing functionality on this layer makes it work for I<all> the user agents.

=cut

use warnings;
use strict;

our $VERSION = '9999.999'; # VERSION

sub _croak { require Carp; Carp::croak(@_) }
sub _usage { _croak("Usage: @_\n") }


=method new

    $middleware = HTTP::AnyUA::Middleware::MyMiddleware->new($backend);
    $middleware = HTTP::AnyUA::Middleware::MyMiddleware->new($backend, %args);

Construct a new middleware.

=cut

sub new {
    my $class   = shift;
    my $backend = shift or die 'Backend is required';
    my $self = bless {backend => $backend}, $class;
    $self->init(@_);
    return $self;
}

=method init

Called by the default constructor with the middleware arguments.

This may be overridden by implementations instead of the constructor.

=cut

sub init {}

=method wrap

    $middleware = HTTP::AnyUA::Middleware::MyMiddleware->wrap($backend, %args);
    $middleware->wrap($backend);

Construct a new middleware or, when called on an instance, set a new backend on an existing
middleware.

=cut

sub wrap {
    my $self    = shift;
    my $backend = shift or _usage($self . q{->wrap($backend, %args)});

    if (ref $self) {
        $self->{backend} = $backend;
    }
    else {
        $self = $self->new($backend, @_);
    }

    return $self;
}

=method request

    $response = $middleware->request($method => $url, \%options);

Make a request, get a response.

This should be overridden by implementations to do whatever they want with or to the request and/or
response.

=cut

sub request { shift->backend->request(@_) }

=attr backend

Get the current backend that is wrapped.

=cut

sub backend { shift->{backend} }

=attr ua

Get the backend user agent.

=cut

sub ua { shift->backend->ua(@_) }

=attr response_is_future

Get whether or not responses are L<Future> objects. Default is whatever the backend returns.

This may be overridden by implementations.

=cut

sub response_is_future { shift->backend->response_is_future(@_) }

1;
