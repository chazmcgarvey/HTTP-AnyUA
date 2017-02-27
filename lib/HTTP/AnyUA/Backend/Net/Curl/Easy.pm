package HTTP::AnyUA::Backend::Net::Curl::Easy;
# ABSTRACT: A unified programming interface for Net::Curl::Easy

=head1 DESCRIPTION

This module adds support for the HTTP client L<Net::Curl::Easy> to be used with the unified
programming interface provided by L<HTTP::AnyUA>.

=head1 CAVEATS

=for :list
* The C<redirects> field in the response is currently unsupported.

=head1 SEE ALSO

=for :list
* L<HTTP::AnyUA::Backend>

=cut

use warnings;
use strict;

our $VERSION = '9999.999'; # VERSION

use parent 'HTTP::AnyUA::Backend';

use HTTP::AnyUA::Util;
use Scalar::Util;


sub request {
    my $self = shift;
    my ($method, $url, $args) = @_;

    my $ua = $self->ua;

    # reset
    $ua->setopt(Net::Curl::Easy::CURLOPT_HTTPGET(), 0);
    $ua->setopt(Net::Curl::Easy::CURLOPT_NOBODY(), 0);
    $ua->setopt(Net::Curl::Easy::CURLOPT_READFUNCTION(), undef);
    $ua->setopt(Net::Curl::Easy::CURLOPT_POSTFIELDS(), undef);
    $ua->setopt(Net::Curl::Easy::CURLOPT_POSTFIELDSIZE(), 0);

    if ($method eq 'GET') {
        $ua->setopt(Net::Curl::Easy::CURLOPT_HTTPGET(), 1);
    }
    elsif ($method eq 'HEAD') {
        $ua->setopt(Net::Curl::Easy::CURLOPT_NOBODY(), 1);
    }

    if (my $content = $args->{content}) {
        if (ref($content) eq 'CODE') {
            my $content_length;
            for my $header (keys %{$args->{headers} || {}}) {
                if (lc($header) eq 'content-length') {
                    $content_length = $args->{headers}{$header};
                    last;
                }
            }

            if ($content_length) {
                my $chunk;
                $ua->setopt(Net::Curl::Easy::CURLOPT_READFUNCTION(), sub {
                    my $ua      = shift;
                    my $maxlen  = shift;

                    if (!$chunk) {
                        $chunk = $content->();
                        return 0 if !$chunk;
                    }

                    my $part = substr($chunk, 0, $maxlen, '');
                    return \$part;
                });
                $ua->setopt(Net::Curl::Easy::CURLOPT_POSTFIELDSIZE(), $content_length);
            }
            else {
                # if we don't know the length we have to just read it all in
                $content = HTTP::AnyUA::Util::coderef_content_to_string($content);
            }
        }
        if (ref($content) ne 'CODE') {
            $ua->setopt(Net::Curl::Easy::CURLOPT_POSTFIELDS(), $content);
            $ua->setopt(Net::Curl::Easy::CURLOPT_POSTFIELDSIZE(), length $content);
        }
    }

    $ua->setopt(Net::Curl::Easy::CURLOPT_URL(), $url);
    $ua->setopt(Net::Curl::Easy::CURLOPT_CUSTOMREQUEST(), $method);

    # munge headers
    my @headers;
    for my $header (keys %{$args->{headers} || {}}) {
        my $value  = $args->{headers}{$header};
        my @values = ref($value) eq 'ARRAY' ? @$value : $value;
        for my $v (@values) {
            push @headers, "${header}: $v";
        }
    }
    $ua->setopt(Net::Curl::Easy::CURLOPT_HTTPHEADER(), \@headers) if @headers;

    my @hdrdata;

    $ua->setopt(Net::Curl::Easy::CURLOPT_HEADERFUNCTION(), sub {
        my $ua      = shift;
        my $data    = shift;
        my $size    = length $data;

        my %headers = _parse_header($data);

        if ($headers{Status}) {
            push @hdrdata, {};
        }

        my $resp_headers = $hdrdata[-1];

        for my $key (keys %headers) {
            if (!$resp_headers->{$key}) {
                $resp_headers->{$key} =  $headers{$key};
            }
            else {
                if (ref($resp_headers->{$key}) ne 'ARRAY') {
                    $resp_headers->{$key} = [$resp_headers->{$key}];
                }
                push @{$resp_headers->{$key}}, $headers{$key};
            }
        }

        return $size;
    });

    my $resp_body = '';

    my $data_cb = $args->{data_callback};
    my $copy = $self;
    Scalar::Util::weaken($copy);
    $ua->setopt(Net::Curl::Easy::CURLOPT_WRITEFUNCTION(), sub {
        my $ua      = shift;
        my $data    = shift;
        my $fh      = shift;
        my $size    = length $data;

        if ($data_cb) {
            my $resp = $copy->_munge_response(undef, undef, [@hdrdata], $data_cb);
            $data_cb->($data, $resp);
        }
        else {
            print $fh $data;
        }

        return $size;
    });
    open(my $fileb, '>', \$resp_body);
    $ua->setopt(Net::Curl::Easy::CURLOPT_WRITEDATA(), $fileb);

    eval { $ua->perform };
    my $ret = $@;

    return $self->_munge_response($ret, $resp_body, [@hdrdata], $data_cb);
}


sub _munge_response {
    my $self    = shift;
    my $error   = shift;
    my $body    = shift;
    my $hdrdata = shift;
    my $data_cb = shift;

    my %headers = %{pop @$hdrdata || {}};

    my $code    = delete $headers{Status} || $self->ua->getinfo(Net::Curl::Easy::CURLINFO_RESPONSE_CODE()) || 599;
    my $reason  = delete $headers{Reason};
    my $url     = $self->ua->getinfo(Net::Curl::Easy::CURLINFO_EFFECTIVE_URL());

    my $resp = {
        success => 200 <= $code && $code <= 299,
        url     => $url,
        status  => $code,
        reason  => $reason,
        headers => \%headers,
    };

    my $version = delete $headers{HTTPVersion} || _http_version($self->ua->getinfo(Net::Curl::Easy::CURLINFO_HTTP_VERSION()));
    $resp->{protocol} = "HTTP/$version" if $version;

    # We have the headers for the redirect chain in $hdrdata, but we don't have the contents, and we
    # would also need to reconstruct the URLs.

    if ($error) {
        my $err = $self->ua->strerror($error);
        return HTTP::AnyUA::Util::internal_exception($err, $resp);
    }

    $resp->{content} = $body if $body && !$data_cb;

    return $resp;
}

# get the HTTP version according to the user agent object
sub _http_version {
    my $version = shift;
    return $version == Net::Curl::Easy::CURL_HTTP_VERSION_1_0() ? '1.0' :
           $version == Net::Curl::Easy::CURL_HTTP_VERSION_1_1() ? '1.1' :
           $version == Net::Curl::Easy::CURL_HTTP_VERSION_2_0() ? '2.0' : '';
}

# parse a header line (or status line) and return as key-value pairs
sub _parse_header {
    my $data = shift;

    $data =~ s/[\x0A\x0D]*$//;

    if ($data =~ m!^HTTP/([0-9.]+) [\x09\x20]+ (\d{3}) [\x09\x20]+ ([^\x0A\x0D]*)!x) {
        return (
            HTTPVersion => $1,
            Status      => $2,
            Reason      => $3,
        );
    }

    my ($key, $val) = split(/:\s*/, $data, 2);
    return if !$key;
    return (lc($key) => $val);
}

# no Net::Curl::Easy;

1;
