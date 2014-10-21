package File::pushd;

$VERSION = "0.30";
@EXPORT  = qw (pushd tempd);

use strict;
use warnings;
use Carp;

use base        qw( Exporter );
use Cwd         qw( cwd abs_path );
use File::Path  qw( rmtree );
use File::Temp  qw();
use File::Spec;

use overload 
    q{""} => sub { File::Spec->canonpath( $_[0]->{_pushd} ) },
    fallback => 1;

#--------------------------------------------------------------------------#
# main pod documentation 
#--------------------------------------------------------------------------#

=head1 NAME

File::pushd - change directory temporarily for a limited scope

=head1 SYNOPSIS

 use File::pushd;

 chdir $ENV{HOME};
 
 # change directory again for a limited scope
 {
     my $dir = pushd( '/tmp' );
     # working directory changed to /tmp
 }
 # working directory has reverted to $ENV{HOME}

 # tempd() is equivalent to pushd( File::Temp::tempdir )
 {
     my $dir = tempd();
 }

 # object stringifies naturally as an absolute path
 {
    my $dir = pushd( '/tmp' );
    my $filename = File::Spec->catfile( $dir, "somefile.txt" );
    # gives /tmp/somefile.txt
 }
    
=head1 DESCRIPTION

File::pushd does a temporary C<chdir> that is easily and automatically
reverted, similar to C<pushd> in some Unix command shells.  It works by
creating an object that caches the original working directory.  When the object
is destroyed, the destructor calls C<chdir> to revert to the original working
directory.  By storing the object in a lexical variable with a limited scope,
this happens automatically at the end of the scope.

This is very handy when working with temporary directories for tasks like
testing; a function is provided to streamline getting a temporary
directory from L<File::Temp>.

For convenience, the object stringifies as the canonical form of the absolute
pathname of the directory entered.

=head1 USAGE

 use File::pushd;

Using File::pushd automatically imports the C<pushd> and C<tempd> functions.

=cut

#--------------------------------------------------------------------------#
# pushd()
#--------------------------------------------------------------------------#

=head2 pushd

 {
     my $dir = pushd( $target_directory );
 }

Caches the current working directory, calls C<chdir> to change to the target
directory, and returns a File::pushd object.  When the object is
destroyed, the working directory reverts to the original directory.

The provided target directory can be a relative or absolute path. If
called with no arguments, it uses the current directory as its target and
returns to the current directory when the object is destroyed.

=cut

sub pushd {
    my ($target_dir) = @_;
    
    my $orig = cwd;
    
    my $dest;
    eval { $dest   = $target_dir ? abs_path( $target_dir ) : $orig };
    
    croak "Can't locate directory $dest: $@" if $@;
    
    if ($dest ne $orig) { 
        chdir $dest or croak "Can't chdir to $dest: $!";
    }

    my $self = bless { 
        _pushd => $dest,
        _original => $orig
    }, __PACKAGE__;

    return $self;
}

#--------------------------------------------------------------------------#
# tempd()
#--------------------------------------------------------------------------#

=head2 tempd

 {
     my $dir = tempd();
 }

This function is like C<pushd> but automatically creates and calls C<chdir> to
a temporary directory as created by L<File::Temp>. Unlike normal L<File::Temp>
cleanup which happens at the end of the program, this temporary directory is
removed when the object is destroyed. (But also see C<preserve>.)  A warning
will be issued if the directory cannot be removed.

=cut

sub tempd {
    my $dir = pushd( File::Temp::tempdir() );
    $dir->{_tempd} = 1;
    return $dir;
}

=head2 preserve 

 {
     my $dir = tempd();
     $dir->preserve;      # mark to preserve at end of scope
     $dir->preserve(0);   # mark to delete at end of scope
 }

Controls whether a temporary directory will be cleaned up when the object is
destroyed.  With no arguments, C<preserve> sets the directory to be preserved.
With an argument, the directory will be preserved if the argument is true, or
marked for cleanup if the argument is false.  Only C<tempd> objects may be
marked for cleanup.  (Target directories to C<pushd> are always preserved.)
C<preserve> returns true if the directory will be preserved, and false
otherwise.

=cut

sub preserve {
    my $self = shift;
    return 1 if ! $self->{"_tempd"};
    if ( @_ == 0 ) {
        return $self->{_preserve} = 1;
    }
    else {
        return $self->{_preserve} = $_[0] ? 1 : 0;
    }
}
    
#--------------------------------------------------------------------------#
# DESTROY()
# Revert to original directory as object is destroyed and cleanup
# if necessary
#--------------------------------------------------------------------------#

sub DESTROY {
    my ($self) = @_;
    my $orig = $self->{_original};
    chdir $orig if $orig; # should always be so, but just in case...
    if ( $self->{_tempd} && 
        !$self->{_preserve} ) {
        eval { rmtree( $self->{_pushd} ) };
        carp $@ if $@;
    }
}

1; #this line is important and will help the module return a true value
__END__

=head1 SEE ALSO

L<File::chdir>

=head1 BUGS

Please report bugs using the CPAN Request Tracker at 
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=File-pushd>

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

=head1 AUTHOR

David A Golden (DAGOLDEN)

dagolden@cpan.org

L<http://dagolden.com/>

=head1 COPYRIGHT

Copyright (c) 2005 by David A Golden

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
