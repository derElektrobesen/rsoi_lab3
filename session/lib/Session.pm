package Session;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
	my $self = shift;

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer');
	$self->secrets([qw( session_secret_passphrase )]);

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->get('/session')->to('index#check_session');
	$r->post('/login')->to('index#login');
	$r->route('/logout')->via('DELETE')->to('index#logout');
}

1;
