package AccessDispatcher;

use strict;
use warnings;

use Carp qw(croak);
use Mojo::UserAgent;
use Data::Dumper::OneLine;

use MainConfig qw( :all );

use base qw(Exporter);

our @EXPORT_OK = qw(
	check_access
	check_session
	send_request
);

our %EXPORT_TAGS = (
	all => [@EXPORT_OK],
);

my %access_control = (
	'login' => {
		method => 'post',
		access => 'full',
	},

	'logout' => {
		method => 'any',
		access => 'Authorized',
	},

	'register' => {
		method => 'post',
		access => 'full',
	},

	'user' => {
		method => 'get',
		access => 'Authorized',
	},

	'send_message' => {
		method => 'get',
		access => 'Authorized',
	},

	'users' => {
		method => 'get',
		access => 'Partial',
	},

	'messages' => {
		method => 'any',
		access => 'Authorized',
	},

	'session' => {
		method => 'any',
		access => 'full',
	},
);

sub check_session {
	my $inst = shift;
	my $recursion_depth = shift;

	my $sid = $inst->session('session');
	return { logged => 0 } unless $sid;

	my $ua = $inst->req->headers->user_agent;

	$inst->app->log->debug("Check session ($ua)");
	my $resp = send_request($inst,
		url => 'session',
		method => 'get',
		port => SESSION_PORT,
		recursion_depth => $recursion_depth + 1,
		args => { session_id => $sid, user_agent => $ua });

	return { error => 'Internal: check_session' } unless $resp;
	return { error => $resp->{error} } if defined $resp->{error};

	return { logged => 1, uid => $resp->{uid} };
}

sub check_access {
	my $inst = shift;
	my %args = (
		recursion_depth => 1,
		method => 'get',
		url => undef,
		check_session => 1,
		@_,
	);

	my ($url, $method) = @args{qw( url method )};
	$inst->app->log->debug("Check access for url '$url', method '$method'");

	return { error => "Can't find access rules for $url" } unless defined $access_control{$url};

	my $r = $access_control{$url};
	return { error => "Unsupported request method for $url" }
		if $r->{method} ne 'any' and uc($r->{method}) ne uc($method);

	my $ret = {};
	$ret = check_session($inst, $args{recursion_depth}) if $args{check_session};
	$inst->session(expires => 1) if $ret->{error};
	return $ret if $ret->{error} && $ret->{error} ne 'unauthorized';

	$ret->{granted} = 1;
	return $inst->app->log->debug("Access granted") && (delete($ret->{error}) || 1) && $ret if $r->{access} eq 'full';

	if ($r->{access} !~ /^(Authorized|Partial)$/) {
		$ret = { error => "Unknown access type found: $r->{access} [url: $url]" };
	}

	if ($ret->{error}) {
		$inst->app->log->debug("Access denied");
		return { error => "unauthorized" };
	}

	$inst->app->log->debug("$r->{access} access granted");
	return $ret;
}

sub send_request {
	my $inst = shift;
	my %args = (
		method => 'get',
		url => undef,
		port => undef,
		check_session => 1,
		recursion_depth => 1,
		args => {},
		@_,
	);

	my $url = $args{url};
	$args{check_session} = 0 if $args{url} && $args{url} eq 'session';

	$args{url} = "http://localhost/$args{url}" if defined $args{url};

	croak 'url not specified' unless $args{url};
	croak 'max recursion depth reached' if $args{recursion_depth} > 3;

	my $ret = check_access($inst,
		url => $url,
		map { $_ => $args{$_} } qw( method recursion_depth check_session ),
	);
	return $ret unless $ret->{granted};

	$url = Mojo::URL->new($args{url});
	$url->port($args{port}) if defined $args{port};

	my $ua = Mojo::UserAgent->new();

	$args{args}->{uid} = $ret->{uid} unless $args{args}->{uid};

	map { delete $args{args}->{$_} unless defined $args{args}->{$_} } keys %{$args{args}};
	$inst->app->log->debug(sprintf "Sending request [method: %s] [url: %s] [port: %d] [args: %s]",
		uc($args{method}), $args{url}, $args{port}, Dumper $args{args});

	my @ua_args = ($url => json => $args{args});
	my %switch = (
		get	=> sub { $url->query(%{$args{args}}); return $ua->get($url); },
		post	=> sub { return $ua->post(@ua_args); },
		put	=> sub { return $ua->put(@ua_args); },
		delete	=> sub { return $ua->delete(@ua_args); },
	);

	my $s = $switch{$args{method}};
	croak "unknown metod specified" unless defined $s;

	my $resp = $s->()->res->json();
	unless (defined $resp) {
		$inst->app->log->warn("Response is undefined");
	} else {
		$inst->app->log->debug("Response: " . Dumper($resp));
	}

	return wantarray ? ($resp, $args{args}->{uid}) : $resp;
}

1;
