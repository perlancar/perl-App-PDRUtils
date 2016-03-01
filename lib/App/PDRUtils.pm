package App::PDRUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use File::chdir;
use Perinci::Object;

our %Common_CLI_Attrs = (
    config_filename => ['pdrutils.conf'],
);

our %common_args = (
    repos => {
        summary => '',
        'x.name.is_plural' => 1,
        'x.name.singular' => 'repo',
        schema => ['array*', of=>'str*'],
    },
);

our %mod_args = (
    module => {
        schema => 'str*',
        req => 1,
        pos => 0,
    },
);

our %ver_args = (
    version => {
        schema => ['str*', match=>qr/\A\d+(\.\d+){0,2}\z/], # XXX perlmod_ver?
        req => 1,
        pos => 1,
    },
);

our %by_ver_args = (
    by => {
        schema => ['str*', match=>qr/\A\d+(\.\d+){0,2}\z/],
        req => 1,
        pos => 1,
    },
);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Collection of CLI utilities for perl dist repos',
};

sub _for_each_repo {
    my %args = @_;
    local $CWD = $CWD;
    for my $repo (@{ $args{dist_dirs} }) {
        eval { $CWD =
    }
}

sub _set_prereq_version {
    my $which = shift;
    %args = @_;


}

$SPEC{inc_prereq_version_by} = {
    v => 1.1,
    summary => 'Increase prereq version by a certain increment',
    args => {
        %mod_args,
        %by_ver_args,
    },
};
sub inc_prereq_version_by {
    _set_prereq_version('inc_by', @_);
}

$SPEC{dec_prereq_version_by} = {
    v => 1.1,
    summary => 'Decrease prereq version by a certain decrement',
    args => {
        %mod_args,
        %by_ver_args,
    },
};
sub dec_prereq_version_by {
    _set_prereq_version('dec_by', @_);
}

$SPEC{inc_prereq_version_to} = {
    v => 1.1,
    summary => 'Increase prereq version to a specified version',
    args => {
        %mod_args,
        %ver_args,
    },
};
sub dec_prereq_version_to {
    _set_prereq_version('dec_to', @_);
}

$SPEC{dec_prereq_version_to} = {
    v => 1.1,
    summary => 'Decrease prereq version to a specified version',
    args => {
        %mod_args,
        %ver_args,
    },
};
sub inc_prereq_version_to {
    _set_prereq_version('inc_to', @_);
}

$SPEC{set_prereq_version_to} = {
    v => 1.1,
    summary => 'Set prereq version to a specified version',
    args => {
        %mod_args,
        %ver_args,
    },
};
sub set_prereq_version_to {
    _set_prereq_version('set', @_);
}

1;
# ABSTRACT:

=head1 SYNOPSIS

This distribution provides the following command-line utilities related to
perl dist repos:

#INSERT_EXECS_LIST


=head1 DESCRIPTION

B<EARLY RELEASE. SOME SUBCOMMANDS NOT YET IMPLEMENTED.>

If you have one or more CPAN (or DarkPAN) perl distribution repos on your
filesystem, then this suite of CLI utilities might be useful for you. Currently
only the combination of L<Dist::Zilla>-based Perl distributions managed by git
version control is supported.

To use this suite of utilities, first create a configuration C<~/pdrutils.conf>
containing at the very least something like:

 repos = !paths ~/repos/perl-*

You can change the C<~/repos/perl-*> part to a wildcard of where you put your
perl dist repos. Another example where you specify multiple wildcard patterns:

 repos = !paths ~/repos/perl-* ~/repos-[12]*/perl-* ~/repos-private/perl-*

Or, if you prefer to specify the repos individually:

 repos = /home/budi/Foo-Bar
 repos = /home/budi/Foo-Baz
 repos = /home/budi/Qux
 repos = !path ~/perl-Module-Zap

(Note that if you want C<~> to be expanded into your home directory, like in a
Unix shell, you need to put C<!path> encoding as the prefix for the value. See
L<IOD> for more details on the configuration format.)

A few things that you can do with the utilities:

=over

=item * List distributions based on various criteria (L<pdrutils ls>)

B<NOT YET IMPLEMENTED.> List the names of all distributions:

 % pdrutils ls

List the names as well as other details of all distributions:

 % pdrutils ls -l

List distributions that have unclean git status (needs to be committed, etc):

 % pdrutils ls --no-git-clean

List distributions that specify prereq to a certain module:

 % pdrutils ls --depends Foo::Bar
 % pdrutils ls --depends 'Foo::Bar >= 0.12'
 % pdrutils ls --depends 'Foo::Bar = 0.12'
 % pdrutils ls --depends 'Foo::Bar < 0.12'

List distributions that depend on certain prereq in a certain phase/relationship
only:

 % pdrutils ls --depends 'Test::More < 0.98' --phase test

List distributions that does I<not> depend on a certain module:

 % pdrutils ls --depends-not Baz

=item * Modify prereqs: set/increase/decrease version

For example, you want to increase the minimum prereq version for all your
distributions, e.g. L<Bencher> to 0.30:

 % pdrutils inc-prereq-version-to Bencher 0.30

All distributions which do not list L<Bencher> as a prereq in their F<dist.ini>,
or distributions which already list L<Bencher> version 0.30 or later, won't be
modified.

Some other examples:

 % pdrutils dec-prereq-version-to Some::Module 1.2
 % pdrutils inc-prereq-version-by Some::Module 0.01
 % pdrutils dec-prereq-version-by Some::Module 0.01
 % pdrutils set-prereq-version Some::Module 1.2

=item * Modify prereqs: add/remove prereqs

TBD

=back

=cut
