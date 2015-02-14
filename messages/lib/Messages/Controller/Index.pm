package Messages::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use DB qw( :all );

sub add_message {
	my $self = shift;

	my $args = $self->req->json();

	return $self->render(json => { error => 'message is empty' }) unless $args->{message};
	return $self->render(json => { error => 'unknown uid' }) unless $args->{to};

	my $r = execute_query($self, 'insert into messages(msg, user_from, user_to) values (?, ?, ?)',
		$args->{message}, $self->stash('uid'), $args->{to});

	return $self->render(json => { error => "DB error" }) unless $r;
	return $self->render(json => { ok => 1 });
}

sub get_messages {

}

1;
