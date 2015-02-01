package Front::Controller::Messages;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub get_messages_list {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render();
}

sub get_user_messages {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render();
}

1;
