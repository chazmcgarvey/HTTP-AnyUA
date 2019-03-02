package HTTP::AnyUA::Middleware::RequestHeaders;
# ABSTRACT: Middleware to add custom request headers

=head1 SYNOPSIS

    $any_ua->apply_middleware('RequestHeaders',
        headers  => {connection => 'close'},
        override => 0,
    );

=head1 DESCRIPTION

This middleware adds custom headers to each request.

=head1 SEE ALSO

=for :list
* L<HTTP::AnyUA::Middleware>

=cut

use warnings;
use strict;

our $VERSION = '9999.999'; # VERSION

use parent 'HTTP::AnyUA::Middleware';

use HTTP::AnyUA::Util;


sub init {
    my $self = shift;
    my %args = @_;
    $self->{override} = !!$args{override};
    $self->{headers}  = HTTP::AnyUA::Util::normalize_headers($args{headers});
}

sub request {
    my $self = shift;
    my ($method, $url, $args) = @_;

    if ($self->override) {
        $args->{headers} = {
            %{HTTP::AnyUA::Util::normalize_headers($args->{headers})},
            %{$self->headers},
        };
    }
    else {
        $args->{headers} = {
            %{$self->headers},
            %{HTTP::AnyUA::Util::normalize_headers($args->{headers})},
        };
    }

    return $self->backend->request($method, $url, $args);
}

=attr headers

Get the custom headers.

=cut

sub headers { shift->{headers} }

=attr override

When true, custom headers overwrite headers in the request. The default is false (the request
headers take precedence when defined).

=cut

sub override { shift->{override} }

1;
