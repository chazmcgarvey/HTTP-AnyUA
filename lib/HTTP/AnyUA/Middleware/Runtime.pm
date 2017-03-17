package HTTP::AnyUA::Middleware::Runtime;
# ABSTRACT: Middleware to determine response time

=head1 SYNOPSIS

    $any_ua->apply_middleware('Runtime');

=head1 DESCRIPTION

This middleware adds a "runtime" field to the response, the value of which is the number of seconds
it took to make the request and finish the response.

=head1 SEE ALSO

=for :list
* L<HTTP::AnyUA::Middleware>

=cut

use warnings;
use strict;

our $VERSION = '9999.999'; # VERSION

use parent 'HTTP::AnyUA::Middleware';

use Time::HiRes;


sub request {
    my $self = shift;
    my ($method, $url, $args) = @_;

    my $start = [Time::HiRes::gettimeofday];

    my $resp = $self->backend->request($method, $url, $args);

    my $handle_response = sub {
        my $resp = shift;

        $resp->{runtime} = sprintf('%.6f', Time::HiRes::tv_interval($start));

        return $resp;
    };

    if ($self->response_is_future) {
        $resp->transform(
            done => $handle_response,
            fail => $handle_response,
        );
    }
    else {
        $resp = $handle_response->($resp);
    }

    return $resp;
}

1;
