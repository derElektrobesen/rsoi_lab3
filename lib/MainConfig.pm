package MainConfig;

use strict;
use warnings;

use Carp qw(croak);

use Cwd 'abs_path';
use base qw(Exporter);

our @EXPORT_OK = qw(
	FRONT_PORT
	LOGIC_PORT
	USERS_PORT
	MESSAGES_PORT
	SESSION_PORT
);

our %EXPORT_TAGS = (
	all => [@EXPORT_OK],
);

my $path = abs_path($0);
$path =~ s#/\w*$##;
$path .= '/../../config';

my %PORTS;

open my $f, '<', $path or croak "Can't open $path: $!\n";
while (<$f>) {
	/(\w*)\s*=\s*(.*)/;
	$PORTS{$1} = $2;
}

sub FRONT_PORT()	{ return $PORTS{FRONT_PORT} || croak "Can't locate FRONT_PORT in config\n"; }
sub LOGIC_PORT()	{ return $PORTS{LOGIC_PORT} || croak "Can't locate LOGIC_PORT in config\n"; }
sub USERS_PORT()	{ return $PORTS{USERS_PORT} || croak "Can't locate USERS_PORT in config\n"; }
sub MESSAGES_PORT()	{ return $PORTS{MESSAGES_PORT} || croak "Can't locate MESSAGES_PORT in config\n"; }
sub SESSION_PORT()	{ return $PORTS{SESSION_PORT} || croak "Can't locate SESSION_PORT in config\n"; }

1;
