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
	my $r = select_all($self, sprintf("select msg, date, user_from, user_to from messages %sorder by date desc%s",
		($uid ? push(@a, $uid) && "where user_from = ? " : ""),
		($page ? push (@a, $count, ($page - 1) * $count) && " limit ? offset ?" : "")), @a);

	return $self->render(json => { error => "DB error" }) unless $r;
	return $self->render(json => { count => scalar(@$r), data => $r, ($page ? (page => $page) : ()) });
}

1;
