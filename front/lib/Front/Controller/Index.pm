package Front::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use MainConfig qw( :all );
use RequestSender qw( send_request );

use Data::Dumper::OneLine;

sub _err {
	my $self = shift;
	my $tmpl = shift;
	my $err = shift;
	return $self->stash(error => $err)->render(template => $tmpl);
}

# This action will render a template
sub index {
	my $self = shift;

	$self->render(template => 'index');
}

sub get_login {
	my $self = shift;

	my $sid = $self->session('session');
	if ($sid) {
		my $r = send_request($self,
			method => 'get',
			url => 'session',
			port => SESSION_PORT,
			args => { session_id => $sid });
		return $self->stash(logged_in => 1)->render(template => 'login') if $r && $r->{ok};
		$self->session(expires => 1);
	}
	$self->render(template => 'login');
}

sub login {
	my $self = shift;

	my $login = $self->param('login');
	my $pass = $self->param('password');

	return $self->_err('login', 'Empty login or password') unless $login or $pass;

	$self->app->log->debug("Trying to login");
	my $r = send_request($self,
		method => 'put',
		url => 'login',
		port => SESSION_PORT,
		args => {
			login => $login,
			password => $pass,
		});

	if ($r && $r->{session_id}) {
		$self->session(session => $r->{session_id});
		return $self->redirect_to('index');
	}

	return $self->_err('login', 'Invalid login or password');
}

sub register {
	my $self = shift;

	my %params;
	for (qw( login password r_password name surname lastname email phone )) {
		$params{$_} = $self->param($_);
		next if /r_password/;
		return $self->_err('register', sprintf "%s field is required", ucfirst) unless $params{$_};
	}

	return $self->_err('register', 'Passwords do not match') if $params{password} ne $params{r_password};

	my $r = send_request($self,
		method => 'put',
		url => 'register',
		port => USERS_PORT,
		args => \%params);

	return $self->_err('register', "Can't register: internal server error") unless $r;
	return $self->_err('register', $r->{error}) if $r->{error};

	$r = send_request($self,
		method => 'put',
		url => 'login',
		port => SESSION_PORT,
		args => {
			login => $params{login},
			password => $params{password},
		});

	return $self->_err('register', "Registration ok, but can't login: internal server error") if not $r or not $r->{session_id};
	return $self->_err('register', $r->{error}) if $r->{error};

	$self->session(session => $r->{session_id});
	return $self->redirect_to('index');
}

1;
