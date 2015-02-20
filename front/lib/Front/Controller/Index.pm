package Front::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw( encode_json );

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
			user_agent => $self->req->headers->user_agent,
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
	return $self->_err('users', "No users found") unless $r->{count};
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

	my %extra_args;
	my $u_param = $self->param('user');

	return $self->stash(not_logged_in => 1)->render(template => 'messages_list') unless $self->session('session');

	my $uid;
	my %users_names;
	if ($u_param) {
		my $r;
		($r, $uid) = send_request($self,
			method => 'get',
			url => 'users',
			port => USERS_PORT,
			args => { user => $u_param });

		return $self->_err('messages_list', 'Internal error: get_messages_list') unless $r;
		return $self->_err('messages_list', $r->{error}) if $r->{error};
		return $self->_err('messages_list', "User $u_param not found") unless $r->{count};
		return $self->_err('messages_list', sprintf 'Invalid user: "%s"', $u_param) unless $r->{uid};
		$extra_args{from} = $r->{uid};
		my $u = $r->{data}->[0];
		$users_names{$u->{id}} = $u->{login};
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

	if ($r->{count} == 0) {
		return $self->_err('messages_list', "User $u_param have no messages") if $u_param;
		return $self->_err('messages_list', "No messages found");
	}

	my %users;
	for my $m (@{$r->{data}}) {
		$users{$m->{user_from}} = 1;
		$users{$m->{user_to}} = 1;
	}

	if (scalar %users_names) {
		delete $users{(keys %users_names)[0]};
	}
	my @users = keys %users;
	my $users_count = scalar @users;
	my $off = 0;
	while ($off < $users_count) {
		my $count = ($off + MAX_USERS_PER_QUERY > $users_count ? $users_count - $off : MAX_USERS_PER_QUERY);
		my @uids = @users[$off .. $off + $count - 1];

		my $users_names = send_request($self,
			method => 'get',
			url => 'users',
			port => USERS_PORT,
			check_session => 0,
			args => { short => 1, users => encode_json([ @uids ]) });

		return $self->_err('messages_list', 'Internal error: get_messages_list (msg)') unless $users_names;
		return $self->_err('messages_list', $users_names->{error}) if $users_names->{error};
		return $self->_err('messages_list', 'Internal error: unknown response') unless $users_names->{data};

		map { $users_names{$_->{id}} = $_->{login} } @{$users_names->{data}};

		$off += $count;
	}

	for my $m (@{$r->{data}}) {
		$m->{user_from} = $users_names{$m->{user_from}};
		$m->{user_to} = $users_names{$m->{user_to}};
	}

	return $self->stash(messages => $r->{data})->render(template => 'messages_list');
}

1;
