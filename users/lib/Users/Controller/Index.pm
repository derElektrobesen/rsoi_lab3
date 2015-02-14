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

	my $count = 2;
	my $page = $self->param('page');
	my $u = $self->param('user');
	my $short = $self->param('short');

	$page = undef if defined $u;

	my $fields = "name, lastname, surname, email, phone";
	unless ($self->stash('uid')) {
		$fields = "name, phone";
	}

	my @args;
	my $req = sprintf('select id, login%s from users%s order by login%s',
		$short ? "" : ", $fields",
		$u ? push(@args, $u) && " where login = ?" : "",
		$page ? push(@args, $count, ($page - 1) * $count) && " limit ? offset ?" : "");

	my $content = select_all($self, $req, @args);
	my $copy = $content;

	return $self->render(json => { error => ($u ? "User $u not found in DB" : "No users found in DB") }) unless $content;

	$content = [ map { $_->{login} } @$content ] if $short;
	return $self->render(json => {
			data => $content,
			($page ? (page => $page) : ()),
			count => scalar @$content,
			($u ? (uid => $copy->[0]->{id}) : ()),
		});
}

1;
