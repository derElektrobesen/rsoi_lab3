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
	check_session
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
		access => 'partial',
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

sub check_session {
	my $inst = shift;
	my $recursion_depth = shift;

	my $sid = $inst->session('session');
	return { logged => 0 } unless $sid;

	$inst->app->log->debug("Check session");
	my $resp = send_request($inst,
		url => 'session',
		method => 'get',
		port => SESSION_PORT,
		recursion_depth => $recursion_depth + 1,
		args => { session_id => $sid });

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
		@_,
	);

	my ($url, $method) = @args{qw( url method )};
	$inst->app->log->debug("Check access for url '$url', method '$method'");

	return { error => "Can't find access rules for $url" } unless defined $access_control{$url};

	my $r = $access_control{$url};
	return { error => "Unsupported request method for $url" }
		if $r->{method} ne 'any' and uc($r->{method}) ne uc($method);

	my $ret = check_session($inst, $args{recursion_depth});
	return $inst->session(expires => 1) && $ret if $ret->{error};

	$ret->{granted} = 1;
	return $inst->app->log->debug("Access granted") && $ret if $r->{access} eq 'all';

	if ($r->{access} !~ /^(authorized|partial)$/) {
		$ret = { error => "Unknown access type found: $r->{access} [url: $url]" };
	}

	$inst->app->log->debug("Access granted");
	return $ret;
}

1;
