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

    #$self->helper(users => sub { state $users = MyApp::Model::Users->new });
    $r->any('/login')->to('login#login')->name('login');

    my $logged_in = $r->under('/')->to('login#logged_in');
    $logged_in->get('/protected')->to('login#protected');

    $r->get('/logout')->to('login#logout');
}

1;
