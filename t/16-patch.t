#!perl

use warnings;
use strict;

use lib 't/lib';

use HTTP::AnyUA;
use Test::More;
use Util qw(:server :test :ua);

my $server = start_server('t/app.psgi');

plan tests => scalar user_agents;

test_all_user_agents {
    plan tests => 8;

    my $ua      = shift;
    my $any_ua  = HTTP::AnyUA->new(ua => $ua, response_is_future => 1);

    my $path    = '/modify-document';
    my $url     = $server->url . $path;
    my $future  = $any_ua->patch($url, {
        headers => {'content-type' => 'text/plain'},
        content => 'some document',
    });

    $future->on_ready(sub {
        my $self    = shift;
        my $resp    = $self->is_done ? $self->get : $self->failure;
        my $env     = $server->read_env;

        note explain 'RESPONSE: ', $resp;
        note explain 'ENV: ', $env;

        SKIP: {
            skip 'unexpected env', 3 if ref($env) ne 'HASH';
            is($env->{REQUEST_METHOD}, 'PATCH', 'correct method sent');
            is($env->{REQUEST_URI}, $path, 'correct url sent');
            is($env->{content}, 'some document', 'correct body sent');
        }

        is_response_reason($resp, 'No Content');
        is_response_status($resp, 204);
        is_response_success($resp, 1);
        is_response_url($resp, $url);
        response_protocol_ok($resp);
    });

    return $future;
};
