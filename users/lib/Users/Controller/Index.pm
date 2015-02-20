package Users::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw( decode_json );

use DB qw( :all );
use MainConfig qw( MAX_USERS_PER_QUERY );
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

	my $uid = $self->param('uid');
	return $self->render(json => { error => 'uid is not specified' }) unless $uid;

	my $row = select_row($self, 'select login, name, lastname, surname, email, phone from users where id = ?', $uid);

	return $self->render(json => { error => 'DB error' }) unless $row;
	return $self->render(json => $row);
}

sub get_users_list {
	my $self = shift;

	my $count = 2;
	my $page = $self->param('page');
	my $u = $self->param('user');
	my $short = $self->param('short');
	my $uid = $self->param('uid');
	my $users_uids = $self->param('users');

	$page = undef if defined $u;

	my $fields = "name, lastname, surname, email, phone";
	unless ($uid) {
		$fields = "name, email";
	}

	my $users_list;
	if (defined $users_uids) {
		$users_list = decode_json($users_uids);
		my %u;
		map { $u{$_} = 1 } @$users_list;
		$users_list = [ keys %u ];
		my $max = MAX_USERS_PER_QUERY;
		return $self->render(json => { error => "Too many users found in request (maximum $max)" }) if scalar(@$users_list) > $max;
	}

	my @args;
	my $req = sprintf('select id, login%s from users%s%s order by login%s',
		$short ? "" : ", $fields",
		$u ? push(@args, $u) && " where login = ?" : "",
		$users_list ? push(@args, @$users_list) && (($u ? " " : " where") . " id in (" . join(',', map { '?' } @$users_list)) . ')' : "",
		$page ? push(@args, $count, ($page - 1) * $count) && " limit ? offset ?" : "");

	my $content = select_all($self, $req, @args);
	my $copy = $content;

	return $self->render(json => { error => ($u ? "User $u not found in DB" : "No users found in DB") }) unless $content;

	$content = [ map { $_->{login} } @$content ] if $short and not $users_uids;
	return $self->render(json => {
			data => $content,
			($page ? (page => $page) : ()),
			count => scalar @$content,
			($u ? (uid => $copy->[0]->{id}) : ()),
		});
}

1;
