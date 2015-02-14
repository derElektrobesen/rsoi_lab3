package DB;

use strict;
use warnings;

use DBI;
use Carp;

use base qw(Exporter);

our @EXPORT_OK = qw(
	select_row
	select_all
	execute_query
);

our %EXPORT_TAGS = (
	all => [@EXPORT_OK],
);

my $dbh;

BEGIN {
	$dbh = DBI->connect(
		'dbi:mysql:dbname=test',
		'user', 'password',
		{
			AutoCommit => 1,
			RaiseError => 1
		}
	) or croak "Can't connect to 'test' database: " . DBI::errstr();
}

sub select_row {
	my ($ctl, $query, @args) = @_;

	$ctl->app->log->debug(sprintf "SQL query: '%s'. [args: %s]", $query, join(',', @args));
	my $sth = $dbh->prepare($query);
	$sth->execute(@args) or croak $dbh->errstr();

	return $sth->fetchrow_hashref();
}

sub select_all {
	my ($ctl, $query, @args) = @_;
	$ctl->app->log->debug(sprintf "SQL query: '%s'. [args: %s]", $query, join(',', @args));
	return $dbh->selectall_arrayref($query, { Slice => {} }, @args) or croak $dbh->errstr();
}

sub execute_query {
	my ($ctl, $query, @args) = @_;
	$ctl->app->log->debug(sprintf "SQL query: '%s'. [args: %s]", $query, join(',', @args));
	return $dbh->do($query, undef, @args) or croak $dbh->errstr();
}
