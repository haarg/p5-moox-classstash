package MooX::ClassStash;
# ABSTRACT: Extra class information for Moo 

=head1 SYNOPSIS

  {
    package MyClass;
    use Moo;
    use MooX::ClassStash;

    has i => ( is => 'ro' );

    sub add_own_data { shift->class_stash->add_data(@_) }
    sub get_own_data { shift->class_stash->get_data(@_) }
  }

  my $class_stash = MyClass->class_stash;
  # or MyClass->new->class_stash

  print $class_stash->get_attribute( i => 'is' ); # 'ro'

  $class_stash->add_attribute( j => (
    is => 'rw',
  ));

  print $class_stash->list_all_methods;
  print $class_stash->list_all_keywords;

  $class_stash->add_data( a => 1 ); # caller specific
  MyClass->add_own_data( a => 2 );

  print $class_stash->get_data('a'); # 1
  print MyClass->get_own_data('a'); # 2

=head1 DESCRIPTION

=cut

use Moo;
use Package::Stash;
use Class::Method::Modifiers qw( install_modifier );

my %stash_cache;

sub import {
	my ( $class, @args ) = @_;
	my $target = caller;
	unless ($target->can('has')) {
		warn "Not using ".$class." on a Moo class, doing nothing";
		return;
	}
	return if defined $stash_cache{$target};
	$stash_cache{$target} = $class->new($target);
}

=attr class

The name of the class for the class stash.

=cut

has class => (
	is => 'ro',
	required => 1,
);

=attr class

The L<Package::Stash> object of the given class

=cut

has package_stash => (
	is => 'ro',
	lazy => 1,
	builder => 1,
	handles => [qw(
		name
		namespace
		add_symbol
		remove_glob
		has_symbol
		get_symbol
		get_or_add_symbol
		remove_symbol
		list_all_symbols
		get_all_symbols
	)],
);

sub _build_package_stash { Package::Stash->new(shift->class) }

=attr attributes

HashRef of all the attributes set via L<Moo/has>

=cut

has attributes => (
	is => 'ro',
	default => sub {{}},
);

=attr data

HashRef with all the caller specific data stored.

=cut

has data => (
	is => 'ro',
	default => sub {{}},
);

=attr keyword_functions

ArrayRef which contains all the functions which are marked as keywords.

=cut

has keyword_functions => (
	is => 'ro',
	default => sub {[qw(
		after
		around
		before
		extends
		has
		with
	)]},
);

=method add_keyword_functions

If you dont use L</add_keyword> for installing a keyword, you might need to
call this function to add the names of the keyword functions yourself.

=cut

sub add_keyword_functions { push @{shift->keyword_functions}, @_ }

sub BUILDARGS {
	my ( $class, @args ) = @_;
	return $_[0] if (scalar @args == 1 and ref $_[0] eq 'HASH');
	unshift @args, "class" if @args % 2 == 1;
	return { @args };
}

sub BUILD {
	my ( $self ) = @_;
	$self->add_method('class_stash', sub { return $self });
	$self->add_method('package_stash', sub { return $self->package_stash });
	$self->around_method('has',sub {
		my $orig = shift;
		my $method = shift;
		my $data = { @_ };
		for (ref $method eq 'ARRAY' ? @{$method} : ($method)) {
			$self->attributes->{$_} = $data;
		}
		$orig->($method, @_);
	})
}

=method add_data

Adds data to your, caller specific, data context of the class. First parameter
is the key, second parameter will be the value.

=cut

sub add_data {
	my $self = shift;
	my $target = caller;
	$self->data->{$target} = {} unless defined $self->data->{$target};
	my $key = shift;
	$self->data->{$target}->{$key} = shift;
}

=method get_data

Get your, caller specific, data. If you give a paramter, if will only give
back the value of this key. If none is given, you get a HashRef of all the
data stored.

=cut

sub get_data {
	my $self = shift;
	my $target = caller;
	return unless defined $self->data->{$target};
	my $key = shift;
	if (defined $key) {
		return $self->data->{$target}->{$key} if defined $self->data->{$target}->{$key};
	} else {
		return $self->data->{$target};
	}
}

=method remove_data
=cut

sub remove_data {
	my $self = shift;
	my $target = caller;
	return unless defined $self->data->{$target};
	my $key = shift;
	delete $self->data->{$target}->{$key} if defined $self->data->{$target}->{$key};
}

=method add_keyword
=cut

sub add_keyword { 
	my $self = shift;
	my $keyword = shift;
	push @{$self->keyword_functions}, $keyword;
	$self->add_symbol('&'.$keyword,@_);
}

# so far no check if its not a keyword

=method get_keyword
=cut

sub get_keyword { shift->get_method(@_) }

=method has_keyword
=cut

sub has_keyword { shift->has_method(@_) }

=method remove_keyword
=cut

sub remove_keyword {
	my $self = shift;
	my $keyword = shift;
	$self->keyword_functions([
		grep { $_ ne $keyword }
		@{$self->keyword_functions}
	]);
	$self->remove_method($keyword, @_);
}

=method get_or_add_keyword_keyword
=cut

sub get_or_add_keyword {
	my $self = shift;
	my $keyword = shift;
	push @{$self->keyword_functions}, $keyword;
	$self->get_or_add_method($keyword, @_)
}

=method add_attribute

It is the same like calling L<Moo/has> inside the package.

=cut

sub add_attribute {
	my $self = shift;
	my $has = $self->class->can('has');
	$has->(@_);
}

=method get_attribute
=cut

sub get_attribute {
	my $self = shift;
	my $attribute = shift;
	my $key = shift;
	return unless defined $self->attributes->{$attribute};
	if ($key) {
		return $self->attributes->{$attribute}->{$key};
	} else {
		return $self->attributes->{$attribute};
	}
}

=method has_attribute
=cut

sub has_attribute {
	my $self = shift;
	my $attribute = shift;
	defined $self->attributes->{$attribute} ? 1 : 0;
}

=method remove_attribute

B<Not implemented yet>

=cut

sub remove_attribute { ... }

=method get_or_add_attribute

B<Not implemented yet>

=cut

sub get_or_add_attribute { ... }

=method list_all_keywords
=cut

sub list_all_keywords {
	my $self = shift;
	my %keywords = map { $_ => 1 } @{$self->keyword_functions};
	return
		sort { $a cmp $b }
		grep { $keywords{$_} }
		$self->list_all_symbols('CODE');
}

=method add_method
=cut

sub add_method { shift->add_symbol('&'.(shift),@_) }

=method get_method
=cut

sub get_method { shift->get_symbol('&'.(shift),@_) }

=method has_method
=cut

sub has_method { shift->has_symbol('&'.(shift),@_) }

=method remove_method
=cut

sub remove_method { shift->remove_symbol('&'.(shift),@_) }

=method get_or_add_method
=cut

sub get_or_add_method { shift->get_or_add_symbol('&'.(shift),@_) }

=method list_all_methods
=cut

sub list_all_methods {
	my $self = shift;
	my %keywords = map { $_ => 1 } @{$self->keyword_functions};
	return
		sort { $a cmp $b }
		grep { !$keywords{$_} }
		$self->list_all_symbols('CODE');
}

=method after_method
=cut

sub after_method { install_modifier(shift->class,'after',@_) }

=method before_method
=cut

sub before_method { install_modifier(shift->class,'before',@_) }

=method around_method
=cut

sub around_method { install_modifier(shift->class,'around',@_) }

1;
