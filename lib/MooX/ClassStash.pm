package MooX::ClassStash;
# ABSTRACT: 

use Moo;
use Package::Stash;
use Class::Method::Modifiers qw(:all);

my %stash_cache;

sub import {
	my ( $class, @args ) = @_;
	my $target = caller;
	return if defined $stash_cache{$target};
	$stash_cache{$target} = $class->new($target);
}

has class => (
	is => 'ro',
	required => 1,
);

has package_stash => (
	is => 'ro',
	lazy => 1,
	builder => 1,
);

sub _build_package_stash { Package::Stash->new(shift->class) }

has attributes => (
	is => 'ro',
	default => sub {{}},
);

has data => (
	is => 'ro',
	default => sub {{}},
);

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

sub add_keyword_functions { push @{shift->keyword_functions}, @_ }

sub BUILDARGS {
	my ( $class, @args ) = @_;
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
		for (ref $method eq 'ARRAY' ? @{$method} : ($method)) {
			$self->attributes->{$_} = { @_ };
		}
		$orig->($method, @_);
	})
}

sub add_data {
	my $self = shift;
	my $target = caller;
	$self->data->{$target} = {} unless defined $self->data->{$target};
	my $key = shift;
	$self->data->{$target}->{$key} = shift;
}

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

sub remove_data {
	my $self = shift;
	my $target = caller;
	return unless defined $self->data->{$target};
	my $key = shift;
	delete $self->data->{$target}->{$key} if defined $self->data->{$target}->{$key};
}

sub add_keyword { 
	my $self = shift;
	my $keyword = shift;
	push @{$self->keyword_functions}, $keyword;
	$self->package_stash->add_symbol('&'.$keyword,@_);
}
# so far no check if its not a keyword
sub get_keyword { shift->get_method(@_) }
sub has_keyword { shift->has_method(@_) }
sub remove_keyword { shift->remove_method(@_) }
sub get_or_add_keyword { shift->get_or_add_method(@_) }
sub list_all_keywords {
	my $self = shift;
	my %keywords = map { $_ => 1 } @{$self->keyword_functions};
	return
		sort { $a cmp $b }
		grep { $keywords{$_} }
		$self->package_stash->list_all_symbols('CODE');
}

sub add_method { shift->package_stash->add_symbol('&'.(shift),@_) }
sub get_method { shift->package_stash->get_symbol('&'.(shift),@_) }
sub has_method { shift->package_stash->has_symbol('&'.(shift),@_) }
sub remove_method { shift->package_stash->remove_symbol('&'.(shift),@_) }
sub get_or_add_method { shift->package_stash->get_or_add_symbol('&'.(shift),@_) }
sub list_all_methods {
	my $self = shift;
	my %keywords = map { $_ => 1 } @{$self->keyword_functions};
	return
		sort { $a cmp $b }
		grep { !$keywords{$_} }
		$self->package_stash->list_all_symbols('CODE');
}

sub after_method { install_modifier(shift->package_stash->name,'after',@_) }
sub before_method { install_modifier(shift->package_stash->name,'before',@_) }
sub around_method { install_modifier(shift->package_stash->name,'around',@_) }

1;
