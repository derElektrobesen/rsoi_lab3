package Users::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use DB qw( :all );
use Data::Dumper::OneLine;

sub register {
	my $self = shift;
	$self->app->log->debug("Registration process started");

	my @args = qw( email lastname login name password phone surname );
	my $came = $self->req->json();
	for (@args) {
		return $self->render(json => { error => "$_ arg is not specified" }) unless $came->{$_};
	}

	my $u = select_row($self, 'select id from users where login = ?', $came->{login});
	if (defined $u) {
		return $self->render(json => { error => 'User already exists' });
	}

	my $q = join '', map { '?,' } 1 .. scalar @args;
	$q =~ s/,$//;
	execute_query($self, sprintf("insert into users (%s) values (%s)", join(',', @args), $q), @$came{@args});

	$self->render(json => { ok => 1 });
}

sub get_user_info {
	my $self = shift;

	my $sid = $self->param('session_id');
	return $self->render(json => { error => 'session_id is not specified' }) unless $sid;

	my $row = select_row($self, 'select u.login, u.name, u.lastname, u.surname, u.email, u.phone, s.session_id ' .
		'from sessions s join users u on s.user_id = u.id where s.session_id = ?', $sid);

	return $self->render(json => { error => 'DB error' }) unless $row;

	delete $row->{session_id};
	return $self->render(json => $row);
}

sub get_users_list {
	my $self = shift;

	my $content = select_all($self, 'select login, name, lastname, surname, email, phone from users order by login');

	return $self->render(json => { error => 'DB error' }) unless $content;

	return $self->render(json => { data => $content });
}

1;
