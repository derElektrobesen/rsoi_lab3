package Session::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use DB qw( :all );
use Digest::MD5 qw( md5_hex );

use Data::Dumper::OneLine;

sub check_session {
	my $self = shift;

	return $self->render(json => { error => 'session_id not specified' }) unless $self->param('session_id');

	my $r = select_row($self, 'select user_id from sessions where session_id = ?', $self->param('session_id'));
	return $self->render(json => { error => 'unauthorized' }) unless $r and $r->{user_id};

	return $self->render(json => { ok => 1, uid => $r->{user_id} });
}

sub login {
	my $self = shift;

	my $came = $self->req->json();

	my ($login, $pass) = @$came{qw( login password )};
	return $self->render(json => { error => 'login or password is not specified' }) unless $login and $pass;

	my $r = select_row($self, 'select id, password from users where login = ?', $login);
	return $self->render(json => { error => 'invalid login or password' }) if not $r or $r->{password} ne $pass;

	my $sum = md5_hex("$r->{id}" . time . rand 100500);
	return $self->renser(json => { error => 'Internal error: mysql' })
		unless execute_query($self, 'insert into sessions(session_id, user_id) values (?,?)', $sum, $r->{id});

	return $self->render(json => { session_id => $sum });
}

sub logout {
	my $self = shift;

	my $came = $self->req->json();
	return $self->render(json => { error => 'session_id not specified' }) unless $came->{session_id};

	execute_query($self, 'delete from sessions where session_id = ?', $came->{session_id});
	return $self->render(json => { ok => 1 });
}

1;
