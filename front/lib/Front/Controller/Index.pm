package Front::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use MainConfig qw( :all );
use AccessDispatcher qw( send_request );

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
		method => 'post',
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

	return $self->_err('login', $r->{error}) if $r && $r->{error};
	return $self->_err('login', "Internal error");
}

sub logout {
	my $self = shift;

	my $sid = $self->session('session');
	$self->session(expires => 1);
	return $self->stash(not_login => 1)->render(template => 'logout') unless $sid;

	my $r = send_request($self,
		method => 'delete',
		url => 'logout',
		port => SESSION_PORT,
		args => { session_id => $sid });

	return $self->stash(error => $r ? $r->{error} : "Internal error") if not $r or not defined $r->{ok};
	return $self->stash(done => 1)->render(template => 'logout');
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
		check_session => 0,
		args => {
			login => $params{login},
			password => $params{password},
		});

	return $self->_err('register', "Registration ok, but can't login: internal server error") if not $r or not $r->{session_id};
	return $self->_err('register', $r->{error}) if $r->{error};

	$self->session(session => $r->{session_id});
	return $self->redirect_to('index');
}

sub get_user_info {
	my $self = shift;

	my $sid = $self->session('session');
	return $self->stash(need_login => 1)->render(template => 'me') unless $sid;

	my $r = send_request($self,
		method => 'get',
		url => 'user',
		port => USERS_PORT);

	return $self->_err('me', "Internal error: get_user_info") unless $r;
	return $self->_err('me', $r->{error}) if $r->{error};
	return $self->stash(user_info => $r)->render(template => 'me');
}

sub get_users_list {
	my $self = shift;

	my $sid = $self->session('session') || "obviously_false";

	my %params = (
		($self->param('page') ? (page => $self->param('page')) : ()),
		($self->param('user') ? (user => $self->param('user')) : ()),
	);

	my $r = send_request($self,
		method => 'get',
		url => 'users',
		port => USERS_PORT,
		args => { %params });

	return $self->_err('users', "Internal error: get_user_info") unless $r;
	return $self->_err('users', $r->{error}) if $r->{error};
	return $self->stash(users_info => $r->{data})->render(template => 'users');
}

sub add_message {
	my $self = shift;

	my ($r, $uid) = send_request($self,
		method => 'get',
		url => 'users',
		port => USERS_PORT,
		args => { short => 1, user => $self->param('user') });

	return $self->_err('add_message', 'Internal error: get_user_id') unless $r;
	return $self->_err('add_message', $r->{error}) if $r->{error};
	return $self->_err('add_message', sprintf 'Invalid user: "%s"', $self->param('user')) unless $r->{uid};

	my $data = { to => $r->{uid}, message => $self->param('message') };

	$r = send_request($self,
		method => 'post',
		url => 'messages',
		port => MESSAGES_PORT,
		check_session => 0,
		args => { uid => $uid, %$data });

	return $self->_err('add_message', 'Internal error: add_message') unless $r;
	return $self->_err('add_message', $r->{error}) if $r->{error};
	return $self->stash(done => 1)->render(template => 'add_message');
}

sub get_add_message {
	my $self = shift;

	my ($r, $uid) = send_request($self,
		method => 'get',
		url => 'users',
		port => USERS_PORT,
		args => { short => 1 });

	return $self->stash(not_logged_in => 1)->render(template => 'add_message') if not $r or not $r->{data} or not $uid;

	$self->stash(users => $r->{data})->render(template => 'add_message');
}

sub get_messages_list {
	my $self = shift;

	my $sid = $self->session('session');
	my %extra_args;

	return $self->stash(not_logged_in => 1)->render(template => 'messages_list') unless $sid;

	my $uid;
	if ($self->param('user')) {
		my $r;
		($r, $uid) = send_request($self,
			method => 'get',
			url => 'users',
			port => USERS_PORT,
			args => { session_id => $sid, short => 1, user => $self->param('user') });

		return $self->_err('messages_list', 'Internal error: get_messages_list') unless $r;
		return $self->_err('messages_list', $r->{error}) if $r->{error};
		return $self->_err('messages_list', sprintf 'Invalid user: "%s"', $self->param('user')) unless $r->{uid};
		$extra_args{from} = $r->{uid};
	}

	if ($self->param('page')) {
		$extra_args{page} = $self->param('page');
	}

	my $r = send_request($self,
		method => 'get',
		url => 'messages',
		port => MESSAGES_PORT,
		check_session => (not defined $uid),
		args => { uid => $uid, %extra_args });

	return $self->_err('messages_list', 'Internal error: get_messages_list (msg)') unless $r;
	return $self->_err('messages_list', $r->{error}) if $r->{error};
	return $self->stash(messages => $r->{data})->render(template => 'messages_list');
}

1;
