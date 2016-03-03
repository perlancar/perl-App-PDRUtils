package App::PDRUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use File::chdir;
use Perinci::Object;

our %Common_CLI_Attrs = (
    config_filename => ['pdrutils.conf'],
);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Collection of utilities for perl dist repos',
};

1;
# ABSTRACT:

=head1 SYNOPSIS

This distribution provides the following command-line utilities related to
perl dist repos:

#INSERT_EXECS_LIST


=head1 DESCRIPTION

If you have one or more CPAN (or DarkPAN) perl distribution repos on your
filesystem, then this suite of CLI utilities might be useful for you. Currently
only the combination of L<Dist::Zilla>-based Perl distributions managed by git
version control is supported.

=cut
