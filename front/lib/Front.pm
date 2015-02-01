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
  $r->get('/users')->to('users#get_users_list');
  $r->get('/user')->to('users#get_user_info');
  $r->get('/messages')->to('messages#get_messages_list');
  $r->get('/user_messages')->to('messages#get_user_messages');
  $r->get('/index.html')->to('index#index');
}

1;
