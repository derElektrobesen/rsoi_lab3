package Messages::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use Cache::Memcached;

use DB qw( :all );

sub open_memc {
	my $self = shift;
	$self->{memc} = Cache::Memcached->new({
		servers => ['127.0.0.1:11211'],
	}) unless defined $self->{memc};

	$self->app->log->error("Can't open connection to Memcached") unless $self->{memc};
}

sub add_message {
	my $self = shift;

	$self->open_memc;
	$self->{memc}->delete('messages_pages_count');

	my $args = $self->req->json();

	return $self->render(json => { error => 'message is empty' }) unless $args->{message};
	return $self->render(json => { error => 'unknown uid' }) unless $args->{to};

	my $r = execute_query($self, 'insert into messages(msg, user_from, user_to) values (?, ?, ?)',
		$args->{message}, $args->{uid}, $args->{to});

	return $self->render(json => { error => "DB error" }) unless $r;
	return $self->render(json => { ok => 1 });
}

sub get_messages {
	my $self = shift;

	my $count = 2;

	$self->open_memc;
	my $memc_pages_count = $self->{memc}->get('messages_pages_count');
	unless (defined $memc_pages_count) {
		my $r = select_row($self, "select count(msg) as c from messages");
		return $self->render(json => { error => "DB error" }) unless $r;

		$memc_pages_count = int($r->{c} / $count + 0.99);
		$self->{memc}->set('messages_pages_count', $memc_pages_count);
	}

	my $page = $self->param('page');
	my $uid = $self->param('from');

	my @a;
	my $r = select_all($self, sprintf("select msg, date, user_from, user_to from messages %sorder by date desc%s",
		($uid ? push(@a, $uid) && "where user_from = ? " : ""),
		($page ? push (@a, $count, ($page - 1) * $count) && " limit ? offset ?" : "")), @a);

	return $self->render(json => { error => "DB error" }) unless $r;
	return $self->render(json => { count => scalar(@$r), data => $r, ($page ? (page => $page, total => $memc_pages_count) : ()) });
}

1;
