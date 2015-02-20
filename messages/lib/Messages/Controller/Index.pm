package Messages::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use DB qw( :all );

sub add_message {
	my $self = shift;

	my $args = $self->req->json();

	return $self->render(json => { error => 'message is empty' }) unless $args->{message};
	return $self->render(json => { error => 'unknown uid' }) unless $args->{to};

	my $r = execute_query($self, 'insert into messages(msg, user_from, user_to) values (?, ?, ?)',
		$args->{message}, $args->{uid}, $args->{to});

	return $self->render(json => { error => "DB error" }) unless $r;
	return $self->render(json => { ok => 1 });
}

sub get_messages {
	my $self = shift;

	my $count = 2;
	my $page = $self->param('page');
	my $uid = $self->param('from');

	my @a;
	my $r = select_all($self, sprintf("select m.msg, m.date, u.login as user_from, u1.login as user_to from messages m " .
		"join users u on u.id = m.user_from join users u1 on u1.id = m.user_to %s order by m.date desc %s",
		($uid ? push(@a, $uid) && "where u.id = ?" : ""),
		($page ? push (@a, $count, ($page - 1) * $count) && "limit ? offset ?" : "")), @a);

	return $self->render(json => { error => "DB error" }) unless $r;
	return $self->render(json => { count => scalar(@$r), data => $r, ($page ? (page => $page) : ()) });
}

1;
