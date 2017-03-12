package HTTP::AnyUA::Backend::Furl;
# ABSTRACT: A unified programming interface for Furl

=head1 DESCRIPTION

This module adds support for the HTTP client L<Furl> to be used with the unified programming
interface provided by L<HTTP::AnyUA>.

=head1 CAVEATS

=for :list
* L<Furl> doesn't keep a list of requests and responses along a redirect chain. As such, the C<url>
  field in the response is always the same as the URL of the original request, and the C<redirects>
  field is never used.

=head1 SEE ALSO

=for :list
* L<HTTP::AnyUA::Backend>

=cut

use warnings;
use strict;

our $VERSION = '9999.999'; # VERSION

use parent 'HTTP::AnyUA::Backend';

use HTTP::AnyUA::Util;


sub request {
    my $self = shift;
    my ($method, $url, $args) = @_;

    local $args->{content} = HTTP::AnyUA::Util::coderef_content_to_string($args->{content});

    my $request = HTTP::AnyUA::Util::native_to_http_request(@_);
    my $ua_resp = $self->ua->request($request);

    return $self->_munge_response($ua_resp, $args->{data_callback});
}

sub _munge_response {
    my $self    = shift;
    my $ua_resp = shift;
    my $data_cb = shift;

    my $resp = {
        success => !!$ua_resp->is_success,
        url     => $ua_resp->request->uri->as_string,
        status  => $ua_resp->code,
        reason  => $ua_resp->message,
        headers => HTTP::AnyUA::Util::http_headers_to_native($ua_resp->headers),
    };

    $resp->{protocol} = $ua_resp->protocol if $ua_resp->protocol;

    if ($resp->{headers}{'x-internal-response'}) {
        HTTP::AnyUA::Util::internal_exception($ua_resp->content, $resp);
    }
    elsif ($data_cb) {
        $data_cb->($ua_resp->content, $resp);
    }
    else {
        $resp->{content} = $ua_resp->content;
    }

    return $resp;
}

1;
