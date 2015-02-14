package Front;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
	my $self = shift;

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer');
	$self->secrets([qw( test_secret_passphrase )]);

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->get('/')->to('index#index');
	$r->get('/index')->to('index#index');

	$r->get('/login')->to('index#get_login');
	$r->post('/login')->to('index#login');

	$r->any('/logout')->to('index#logout');

	$r->get('/register')->name('register');
	$r->post('/register')->to('index#register');

	$r->get('/me')->to('index#get_user_info');

	$r->get('/send_message')->to(template => 'add_message')->name('add_message');
	$r->post('/send_message')->to('index#add_message');

	$r->get('/users')->to('index#get_users_list');
	$r->get('/messages')->to('index#get_messages_list');

	$r->any('/*any' => { any => '' } => sub {
		my $r = shift;
		my $page_name = $r->param('any');
		$r->render(text => "error: $page_name not found", status => 404);
	});
}

1;
