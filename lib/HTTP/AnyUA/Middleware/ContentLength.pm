package HTTP::AnyUA::Middleware::ContentLength;
# ABSTRACT: Middleware to add Content-Length header automatically

=head1 SYNOPSIS

    $any_ua->apply_middleware('ContentLength');

=head1 DESCRIPTION

This middleware adds a Content-Length header to the request if the content is known (i.e. the
"content" field of the request options is a string instead of a coderef) and if the header is not
already set.

=head1 SEE ALSO

=for :list
* L<HTTP::AnyUA::Middleware>

=cut

use warnings;
use strict;

our $VERSION = '9999.999'; # VERSION

use parent 'HTTP::AnyUA::Middleware';

use HTTP::AnyUA::Util;


sub request {
    my $self = shift;
    my ($method, $url, $args) = @_;

    $args->{headers} = HTTP::AnyUA::Util::normalize_headers($args->{headers});

    if (!defined $args->{headers}{'content-length'} && $args->{content} && !ref $args->{content}) {
        $args->{headers}{'content-length'} = length $args->{content};
    }

    return $self->backend->request($method, $url, $args);
}

1;
