package Front::Controller::Users;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub get_users_list {
  my $self = shift;

  $self->render();
}

sub get_user_info {
    my $self = shift;

    $self->render();
}

1;
