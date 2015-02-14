package Users;
use Mojo::Base 'Mojolicious';

use AccessDispatcher qw( :all );

# This method will run once at server start
sub startup {
	my $self = shift;

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer');
	$self->secrets([qw( users_secret_passphrase )]);

	# Router
	my $r = $self->routes;

	# Normal route to controller
	#$self->app->hook(before_routes => \&check_access);
	my $acc = $r->under('/')->to(cb => \&check_access);
	$acc->put('/register')->to('index#register');
	$acc->get('/user')->to('index#get_user_info');
	$acc->get('/users')->to('index#get_users_list');
}

1;
