package Messages;
use Mojo::Base 'Mojolicious';

use AccessDispatcher qw( :all );

sub startup {
	my $self = shift;

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer');
	$self->secrets([qw( messages_secret_passphrase )]);

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->post('/messages')->to('index#add_message');
	$r->get('/messages')->to('index#get_messages');
}

1;
