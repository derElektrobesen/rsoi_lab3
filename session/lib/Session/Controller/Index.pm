package Session::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use DB qw( :all );
use Digest::MD5 qw( md5_hex );

use Data::Dumper::OneLine;
use Cache::Memcached;

sub open_memc {
	my $self = shift;
	$self->{memc} = Cache::Memcached->new({
		servers => ['127.0.0.1:11211'],
	}) unless defined $self->{memc};

	$self->app->log->error("Can't open connection to Memcached") unless $self->{memc};
}

sub check_session {
	my $self = shift;

	$self->open_memc;

	return $self->render(json => { error => 'session_id not specified' }) unless $self->param('session_id');
	return $self->render(json => { error => 'user_agent not specified' }) unless $self->param('user_agent');

	my $r = $self->{memc}->get('session_' . $self->param('session_id'));
	return $self->render(json => { error => 'unauthorized' })
		unless $r and $r->{user_id} and ($r->{user_agent} eq md5_hex($self->param('user_agent')));

	return $self->render(json => { ok => 1, uid => $r->{user_id} });
}

sub login {
	my $self = shift;

	$self->open_memc;
	my $came = $self->req->json();

	my ($login, $pass, $ua) = @$came{qw( login password user_agent )};
	return $self->render(json => { error => 'login or password or user_agent is not specified' }) unless $login and $pass and $ua;

	my $r = select_row($self, 'select id, password from users where login = ?', $login);
	return $self->render(json => { error => 'invalid login or password' }) if not $r or $r->{password} ne $pass;

	my $sum = md5_hex("$r->{id}" . time . rand(100500) . "$ua");

	$self->{memc}->set("session_$sum", { user_id => $r->{id}, user_agent => md5_hex($ua) }, 10 * 60);

	return $self->render(json => { session_id => $sum });
}

sub logout {
	my $self = shift;

	$self->open_memc;
	my $came = $self->req->json();
	return $self->render(json => { error => 'session_id not specified' }) unless $came->{session_id};

	$self->{memc}->delete("session_$came->{session_id}");

	return $self->render(json => { ok => 1 });
}

1;
