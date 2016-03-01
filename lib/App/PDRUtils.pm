package App::PDRUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use File::chdir;
use Perinci::Object;
use Version::Util qw(version_eq version_gt version_lt);

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

our %mod_ver_args = (
    module_version => {
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
    my ($parent_args, $callback) = @_;
    local $CWD = $CWD;
    my $envres = envresmulti();
  REPO:
    for my $repo (@{ $parent_args->{repos} }) {
        $log->tracef("Processing repo %s ...", $repo);
        # XXX filter
        eval { $CWD = $repo };
        if ($@) {
            $log->warnf("Can't cd to repo %s, skipped", $repo);
            $envres->add_result(500, "Can't cd to repo", {item_id=>$repo});
            next REPO;
        }
        my $res = $callback->(
            parent_args => $parent_args,
            repo => $repo,
        );
        $log->tracef("Result for repo '%s': %s", $repo, $res);
        if ($res->[0] != 200 && $res->[0] != 304) {
            $log->warnf("Processing repo %s failed: %s", $repo, $res);
        }
        $envres->add_result(@$res, {item_id=>$repo});
    }
    $envres->as_struct;
}

sub _for_each_dist_ini_in_repo {
    require Config::IOD;
    require File::Slurper;

    my ($parent_args, $callback) = @_;

    my $ciod = Config::IOD->new(
        ignore_unknown_directive => 1,
    );

    _for_each_repo(
        $parent_args,
        sub {
            my %cbargs = @_;
            my $repo = $cbargs{repo};
            return [412, "No dist.ini in repo"] unless (-f "dist.ini");
            my $raw = File::Slurper::read_text("dist.ini");
            my $iod;
            eval { $iod = $ciod->read_string($raw) };
            return [412, "Can't parse dist.ini: $@"] if $@;

            $callback->(
                parent_args => $parent_args,
                repo => $repo,
                dist_ini => $raw,
                parsed_dist_ini => $iod,
            );
        },
    );
}

sub _set_prereq_version {
    require Config::IOD;
    require File::Slurper;

    my $which = shift;
    my %fargs = @_;

    _for_each_dist_ini_in_repo(
        \%fargs,
        sub {
            my %cbargs = @_;
            my $pargs = $cbargs{parent_args};
            my $iod = $cbargs{parsed_dist_ini};
            my $mod = $pargs->{module};
            my $found;
            my $modified;
          SECTION:
            for my $section ($iod->list_sections) {
                next unless $section =~ m!\APrereqs(?:\s*/\s*\w+)?\z!;
                for my $param ($iod->list_keys($section)) {
                    next unless $param eq $mod;
                    my $v = $iod->get_value($section, $param);
                    return [412, "Prereq '$mod' is specified multiple times"]
                        if ref($v) eq 'ARRAY';
                    $found++;
                    if ($which eq 'set_to') {
                        my $target_v = $pargs->{module_version};
                        if (version_eq($v, $target_v)) {
                            return [304, "Version of '$mod' already the same ($v)"];
                        }
                        $iod->set_value({all=>1}, $section, $param, $target_v);
                        $modified++;
                    } elsif ($which eq 'inc_to') {
                        my $target_v = $pargs->{module_version};
                        unless (version_gt($target_v, $v)) {
                            return [304, "Version of '$mod' ($v) already >= $target_v"];
                        }
                        $iod->set_value({all=>1}, $section, $param, $target_v);
                        $modified++;
                    } elsif ($which eq 'dec_to') {
                        my $target_v = $pargs->{module_version};
                        unless (version_lt($target_v, $v)) {
                            return [304, "Version of '$mod' ($v) already <= $target_v"];
                        }
                        $iod->set_value({all=>1}, $section, $param, $target_v);
                        $modified++;
                    } else {
                        return [500, "BUG: Unknown which '$which'"];
                    }
                }
            }
            if ($found) {
                if ($modified) {
                    if ($pargs->{-dry_run}) {
                        return [304, "Modified (dry run)"];
                    } else {
                        eval {
                            File::Slurper::write_text(
                                "dist.ini", $iod->as_string);
                        };
                        return [500, "Can't write dist.ini: $@"] if $@;
                        return [200, "Modified"];
                    }
                } else {
                    return [304, "Not modified"];
                }
            } else {
                return [304, "No prereq to '$mod' specified"];
            }
        },
    );
}

$SPEC{inc_prereq_version_by} = {
    v => 1.1,
    summary => 'Increase prereq version by a certain increment',
    args => {
        %common_args,
        %mod_args,
        %by_ver_args,
    },
    features => {dry_run=>1},
};
sub inc_prereq_version_by {
    return [501, "Not yet implemented"];
    _set_prereq_version('inc_by', @_);
}

$SPEC{dec_prereq_version_by} = {
    v => 1.1,
    summary => 'Decrease prereq version by a certain decrement',
    args => {
        %common_args,
        %mod_args,
        %by_ver_args,
    },
    features => {dry_run=>1},
};
sub dec_prereq_version_by {
    return [501, "Not yet implemented"];
    _set_prereq_version('dec_by', @_);
}

$SPEC{inc_prereq_version_to} = {
    v => 1.1,
    summary => 'Increase prereq version to a specified version',
    args => {
        %common_args,
        %mod_args,
        %mod_ver_args,
    },
    features => {dry_run=>1},
};
sub dec_prereq_version_to {
    _set_prereq_version('dec_to', @_);
}

$SPEC{dec_prereq_version_to} = {
    v => 1.1,
    summary => 'Decrease prereq version to a specified version',
    args => {
        %common_args,
        %mod_args,
        %mod_ver_args,
    },
    features => {dry_run=>1},
};
sub inc_prereq_version_to {
    _set_prereq_version('inc_to', @_);
}

$SPEC{set_prereq_version_to} = {
    v => 1.1,
    summary => 'Set prereq version to a specified version',
    args => {
        %common_args,
        %mod_args,
        %mod_ver_args,
    },
    features => {dry_run=>1},
};
sub set_prereq_version_to {
    _set_prereq_version('set_to', @_);
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
