package Front::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use MainConfig qw( :all );
use RequestSender qw( send_request );

use Data::Dumper::OneLine;

# This action will render a template
sub index {
	my $self = shift;

	$self->render(template => 'index');
}

sub login {
	my $self = shift;

	my $login = $self->param('login');
	my $pass = $self->param('password');

	return $self->redirect_to('login') unless $login or $pass;

	$self->app->log->debug("Trying to login");
	my $r = send_request($self,
		method => 'post',
		url => 'http://localhost/sessions',
		port => SESSION_PORT,
		args => {
			login => $login,
			password => $pass,
		});

	$self->app->log->debug("Response: " . Dumper $r);

	if ($r && $r->{session_id}) {
		$self->session(session => $r->{session_id});
		return $self->redirect_to('index');
	}

	$self->redirect_to('login');
}

1;
