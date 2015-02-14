package AccessDispatcher;

use strict;
use warnings;

use Carp qw(croak);
use Mojo::UserAgent;
use Data::Dumper::OneLine;

use RequestSender qw( :all );
use MainConfig qw( :all );

use base qw(Exporter);

our @EXPORT_OK = qw(
	check_access
);

our %EXPORT_TAGS = (
	all => [@EXPORT_OK],
);

my %access_control = (
	'login' => {
		method => 'post',
		access => 'all',
	},

	'logout' => {
		method => 'any',
		access => 'authorized',
	},

	'register' => {
		method => 'put',
		access => 'all',
	},

	'user' => {
		method => 'get',
		access => 'authorized',
	},

	'send_message' => {
		method => 'get',
		access => 'authorized',
	},

	'users' => {
		method => 'get',
		access => 'partial_access',
	},

	'messages' => {
		method => 'any',
		access => 'authorized',
	},

	'session' => {
		method => 'any',
		access => 'all',
	},
);

sub check_access {
	my $inst = shift;

	my $method = $inst->req->method;
	my $url = $inst->req->url->path->parts->[0];

	$inst->app->log->debug("Checking access for url '$url', method '$method'");

	return $inst->reply->not_found && undef unless defined $access_control{$url};

	my $r = $access_control{$url};
	return $inst->reply->exception("Unsupported request method for $url") && undef
		if $r->{method} ne 'any' and uc($r->{method}) ne uc($method);

	return $inst->app->log->debug("Access granted") && 1 if $r->{access} eq 'all';

	if ($r->{access} eq 'authorized' || $r->{access} eq 'partial_access') {
		my $resp = send_request($inst,
			url => 'session',
			method => 'get',
			port => SESSION_PORT,
			args => {
				session_id => $inst->param('session_id') || $inst->req->json()->{session_id},
			});

		return $inst->reply->exception("Internal error: session") && undef unless $resp;

		if (defined $resp->{error} && $r->{access} eq 'authorized') {
			$inst->session(expires => 1);
			return $inst->render(json => { error => $resp->{error} }) && undef;
		} else {
			$inst->app->log->warn("Session returns (partial access): " . Dumper $resp);
		}

		$inst->stash(uid => $resp->{uid}) if $resp->{uid};
	} else {
		$inst->app->log->warn("Unknown access type found: $r->{access} [url: $url]");
		return $inst->reply->exception("Internal error: access type") && undef;
	}

	$inst->app->log->debug("Access granted");
	return 1;
}

1;
