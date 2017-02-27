package HTTP::AnyUA::Backend::HTTP::AnyUA;
# ABSTRACT: A unified programming interface for HTTP::AnyUA

=head1 DESCRIPTION

This module adds support for the HTTP client L<HTTP::AnyUA> to be used with the unified programming
interface provided by L<HTTP::AnyUA>.

Mind blown.

=head1 SEE ALSO

=for :list
* L<HTTP::AnyUA::Backend>

=cut

use warnings;
use strict;

our $VERSION = '9999.999'; # VERSION

use parent 'HTTP::AnyUA::Backend';


sub response_is_future {
    my $self = shift;

    return $self->ua->response_is_future;
}

sub request {
    my $self = shift;

    return $self->ua->request(@_);
}

1;
