package Plack::Util;
use strict;
use Carp ();
use Scalar::Util;
use IO::Handle;

sub TRUE()  { 1==1 }
sub FALSE() { !TRUE }

sub load_class {
    my($class, $prefix) = @_;

    if ($class !~ s/^\+// && $prefix) {
        $class = "$prefix\::$class";
    }

    my $file = $class;
    $file =~ s!::!/!g;
    require "$file.pm"; ## no critic

    return $class;
}

sub is_real_fh {
    my $fh = shift;

    if ( Scalar::Util::reftype($fh) eq 'GLOB' &&
         do { my $fileno = fileno $fh; defined($fileno) && $fileno >= 0 } ) {
        return TRUE
    } else {
        return FALSE;
    }
}

sub foreach {
    my($body, $cb) = @_;

    if (ref $body eq 'ARRAY') {
        for my $line (@$body) {
            $cb->($line);
        }
    } else {
        local $/ = \4096 unless ref $/;
        while (defined(my $line = $body->getline)) {
            $cb->($line);
        }
        $body->close;
    }
}

sub run_app($$;$) {
    my($app, $env) = (shift, shift);

    local $@; my $res = eval { $app->($env, @_) };
    if ($@) {
        my $body = "Internal Server Error";
        $env->{'psgi.errors'}->print($@);
        return [ 500, [ 'Content-Type' => 'text/plain', 'Content-Length' => length($body) ], [ $body ] ];
    }

    return $res;
}

sub inline_object {
    my %args = @_;
    bless {%args}, 'Plack::Util::Prototype';
}

package Plack::Util::Prototype;

our $AUTOLOAD;
sub can {
    exists $_[0]->{$_[1]};
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*://;
    if (ref($self->{$attr}) eq 'CODE') {
        $self->{$attr}->(@args);
    } else {
        Carp::croak(qq/Can't locate object method "$attr" via package "Plack::Util::Prototype"/);
    }
}

sub DESTROY { }

package Plack::Util;

1;

__END__

=head1 NAME

Plack::Util - Utility subroutines for Plack server and framework developers

=head1 FUNCTIONS

=over 4

=item TRUE, FALSE

  my $true  = Plack::Util::TRUE;
  my $false = Plack::Util::FALSE;

Utility constants to include when you specify boolean variables in C<$env> hash (e.g. C<psgi.multithread>).

=item load_class

  my $class = Plack::Util::load_class($class [, $prefix ]);

Constructs a class name and C<require> the class. Throws an exception
if the .pm file for the class is not found, just with the built-in
C<require>.

If C<$prefix> is set, the class name is prepended to the C<$class>
unless C<$class> begins with C<+> sign, which means the class name is
already fully qualified.

  my $class = Plack::Util::load_class("Foo");                   # Foo
  my $class = Plack::Util::load_class("Baz", "Foo::Bar");       # Foo::Bar::Baz
  my $class = Plack::Util::load_class("+XYZ::ZZZ", "Foo::Bar"); # XYZ::ZZZ

=item is_real_fh

  if ( Plack::Util::is_real_fh($fh) ) { }

returns true if a given C<$fh> is a real file handle that has a file
descriptor. It returns false if C<$fh> is PerlIO handle that is not
really related to the underlying file etc.

=item foreach

  Plack::Util::foreach($body, $cb);

Iterate through I<$body> which is an array reference or
IO::Handle-like object and pass each line (which is NOT really
guaranteed to be a I<line>) to the callback function.

It internally sets the buffer length C<$/> to 4096 in case it reads
the binary file, unless otherwise set in the caller's code.

=item run_app

  my $res = Plack::Util::run_app $app, $env [, $start_response ];

Runs the I<$app> by wrapping errors with I<eval> and if an error is
found, logs it to C<< $env->{'psgi.errors'} >> and returns the
template 500 Error response.

=item inline_object

  my $o = Plack::Util::inline_object(
      write => sub { $h->push_write(@_) },
      close => sub { $h->push_shutdown },
  );
  $o->write(@stuff);
  $o->close;

Creates an instant object that can react to methods passed in the
constructor. Handy to create when you need to create an IO stream
object for input or errors, as well as respone writer object for
L<PSGI::Async> extension.

=back

=cut



