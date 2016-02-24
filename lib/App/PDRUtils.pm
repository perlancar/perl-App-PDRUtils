package App::PDRUtils;

# DATE
# VERSION

use 5.010001;

our %Common_CLI_Attrs = (
    config_filename => ['pdrutils.ini'],
);

1;
# ABSTRACT: Collection of CLI utilities for perl dist repos

=head1 SYNOPSIS

This distribution provides the following command-line utilities related to
perl dist repos:

#INSERT_EXECS_LIST


=head1 DESCRIPTION

If you have one or more CPAN (or DarkPAN) perl distribution repos on your
filesystem, then this suite of CLI utilities might be useful for you. Currently
only the combination of L<Dist::Zilla>-based Perl distributions managed by git
version control is supported.

To use this suite of utilities, first create a configuration C<~/pdrutils.ini>
containing at the very least something like:

 repos = !paths ~/repos/perl-*

You can change the C<~/repos/perl-*> part to a wildcard of where you put your
perl dist repos. If you prefer to specify the repos individually:

 repos = /home/budi/Foo-Bar
 repos = /home/budi/Foo-Baz
 repos = /home/budi/Qux
 repos = !path ~/perl-Module-Zap

(Note that if you want C<~> to be expanded into your home directory, like in a
Unix shell, you need to put C<!path> encoding as the prefix for the value. See
L<IOD> for more details on the configuration format.)

A few things that you can do with the utilities:

=over

=item * List distributions based on various criteria (L<pdrutil-list>)

List the names of all distributions:

 % pdrutil-list

List the names as well as other details of all distributions:

 % pdrutil-list -l

List distributions that have unclean git status (needs to be committed, etc):

 % pdrutil-list --no-git-clean

List distributions that specify prereq to a certain module:

 % pdrutil-list --depends Foo::Bar
 % pdrutil-list --depends 'Foo::Bar >= 0.12'
 % pdrutil-list --depends 'Foo::Bar = 0.12'
 % pdrutil-list --depends 'Foo::Bar < 0.12'

List distributions that depend on certain prereq in a certain phase/relationship
only:

 % pdrutil-list --depends 'Test::More < 0.98' --phase test

List distributions that does I<not> depend on a certain module:

 % pdrutil-list --depends-not Baz

=item * Modify prereqs (L<pdrutil-modify-prereq>)

For example, you want to increase the minimum prereq version for all your
distributions, e.g. L<Bencher> to 0.30:

 % pdrutil-modify-prereq inc-version Bencher 0.30

All distributions which do not list L<Bencher> as a prereq in their F<dist.ini>,
or distributions which already list L<Bencher> version 0.30 or later, won't be
modified.

Some other examples:

 % pdrutil-modify-prereq delete Some::Module ;# delete prereq
 % pdrutil-modify-prereq add Some::Module
 % pdrutil-modify-prereq add Some::Module 0.12

=item * Increase or decrease version

TBD

=back

=cut
