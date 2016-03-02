package App::PDRUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use File::chdir;
use Perinci::Object;
use Version::Util qw(version_eq version_gt version_lt
                     add_version subtract_version);

our %Common_CLI_Attrs = (
    config_filename => ['pdrutils.conf'],
);

our %common_args = (
    repos => {
        summary => '',
        'x.name.is_plural' => 1,
        'x.name.singular' => 'repo',
        schema => ['array*', of=>'str*'],
        tags => ['common'],
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
        schema => ['str*', match=>qr/\Av?\d{1,3}(\.\d{1,3}){0,2}\z/], # XXX perlmod_ver?
        req => 1,
        pos => 1,
    },
);

our %opt_mod_ver_args = (
    module_version => {
        schema => ['str*', match=>qr/\Av?\d{1,3}(\.\d{1,3}){0,2}\z/], # XXX perlmod_ver?
        default => "0",
        pos => 1,
    },
);

our %by_ver_args = (
    by => {
        schema => ['str*', match=>qr/\Av?\d{1,3}(\.\d{1,3}){0,2}\z/],
        req => 1,
        pos => 1,
    },
);

our %SPEC;

sub _ciod {
    state $ciod = do {
        require Config::IOD;
        Config::IOD->new(
            ignore_unknown_directive => 1,
        );
    };
    $ciod;
}

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Collection of utilities for perl dist repos',
};
sub _for_each_repo {
    require File::Slurper;

    my ($opts, $parent_args, $callback) = @_;

    $opts //= {};

    local $CWD = $CWD;
    my $envres = envresmulti();
  REPO:
    for my $repo (@{ $parent_args->{repos} }) {
        $log->tracef("Processing repo %s ...", $repo);

        eval { $CWD = $repo };
        if ($@) {
            $log->warnf("Can't cd to repo %s, skipped", $repo);
            $envres->add_result(500, "Can't cd to repo", {item_id=>$repo});
            next REPO;
        }

        my $requires_parsed_dist_ini = $opts->{requires_parsed_dist_ini} //
            (grep {defined($parent_args->{$_})} qw/depends/);
        my $requires_dist_ini = $opts->{requires_dist_ini};
        $requires_dist_ini ||= $requires_parsed_dist_ini;

        my $dist_ini;
        my $parsed_dist_ini;

        if ($requires_dist_ini) {
            unless (-f "dist.ini") {
                $log->warnf("No dist.ini in repo %s, skipped", $repo);
                $envres->add_result(412, "No dist.ini in repo", {item_id=>$repo});
                next REPO;
            }
            $dist_ini = File::Slurper::read_text("dist.ini");
        }

        if ($requires_parsed_dist_ini) {
            eval { $parsed_dist_ini = _ciod->read_string($dist_ini) };
            if ($@) {
                $log->warnf("Can't parse dist.ini in repo %s, skipped", $repo);
                $envres->add_result(412, "Can't parse dist.ini: $@");
                next REPO;
            }
        }

        my $res = $callback->(
            parent_args => $parent_args,
            repo => $repo,
            (dist_ini => $dist_ini) x !!defined($dist_ini),
            (parsed_dist_ini => $parsed_dist_ini) x !!defined($parsed_dist_ini),
        );
        $log->tracef("Result for repo '%s': %s", $repo, $res);
        if ($res->[0] != 200 && $res->[0] != 304) {
            $log->warnf("Processing repo %s failed: %s", $repo, $res);
        }
        $envres->add_result(@$res, {item_id=>$repo});
    }
    $envres->as_struct;
}

sub _has_prereq {
    my ($iod, $mod) = @_;
    for my $section ($iod->list_sections) {
        # like in lint-prereqs
        $section =~ m!\A(
                          osprereqs \s*/\s* .+ |
                          osprereqs(::\w+)+ |
                          prereqs (?: \s*/\s* (?<prereqs_phase_rel>\w+))? |
                          extras \s*/\s* lint[_-]prereqs \s*/\s* (assume-(?:provided|used))
                      )\z!ix or next;
        for my $param ($iod->list_keys($section)) {
            return 1 if $param eq $mod;
        }
    }
    0;
}

$SPEC{add_prereq} = {
    v => 1.1,
    summary => 'Add a prereq',
    args => {
        %common_args,
        %mod_args,
        %opt_mod_ver_args,
        phase => {
            summary => 'Select prereq phase',
            schema => ['str*', in=>[qw/build configure develop runtime test/]],
            default => 'runtime',
        },
        rel => {
            summary => 'Select prereq relationship',
            schema => ['str*', in=>[qw/requires suggests recommends/]],
            default => 'requires',
        },
        # TODO: replace option
    },
    features => {dry_run=>1},
};
sub add_prereq {
    my %fargs = @_;

    _for_each_repo(
        {requires_parsed_dist_ini=>1},
        \%fargs,
        sub {
            my %cbargs = @_;
            my $pargs = $cbargs{parent_args};
            my $iod   = $cbargs{parsed_dist_ini};
            my $mod   = $pargs->{module};
            my $ver   = $pargs->{module_version} // 0;
            my $phase = $pargs->{phase};
            my $rel   = $pargs->{rel};
            if (_has_prereq($iod, $mod)) {
                return [304, "Already has prereq to '$mod'"];
            }

            my $section;
            for my $s ($iod->list_sections) {
                next unless $s =~ m!\Aprereqs(?:\s*/\s*(\w+))?\z!;
                if ($phase eq 'runtime' && $rel eq 'requires') {
                    next unless !$1 || lc($1) eq 'runtimerequires';
                }
                $section = $s;
                last;
            }
            unless ($section) {
                if ($phase eq 'runtime' && $rel eq 'requires') {
                    $section = 'Prereqs';
                } else {
                    $section = 'Prereqs / '.ucfirst($phase).ucfirst($rel);
                }
            }
            my $linum = $iod->insert_key(
                {create_section=>1, ignore=>1}, $section, $mod, $ver);
            my $modified = defined $linum;
            if ($modified) {
                $log->infof("%sModified dist.ini for repo '%s' (added prereq '%s')",
                            $pargs->{-dry_run} ? "[DRY-RUN] " : "",
                            $cbargs{repo},
                            $mod,
                        );
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
        },
    );
}

$SPEC{remove_prereq} = {
    v => 1.1,
    summary => 'Remove a prereq',
    args => {
        %common_args,
        %mod_args,
    },
    features => {dry_run=>1},
};
sub remove_prereq {
    my %fargs = @_;

    _for_each_repo(
        {requires_parsed_dist_ini=>1},
        \%fargs,
        sub {
            my %cbargs = @_;
            my $pargs = $cbargs{parent_args};
            my $iod = $cbargs{parsed_dist_ini};
            my $mod = $pargs->{module};
            my @sections = grep {
                $_ =~ m!\APrereqs(?:\s*/\s*\w+)?\z!
            } $iod->list_sections;
            my $modified;
            for my $section (@sections) {
                my $num_deleted = $iod->delete_key({all=>1}, $section, $mod);
                $modified++ if $num_deleted;
            }
            if ($modified) {
                $log->infof("%sModified dist.ini for repo '%s' (removed prereq '%s')",
                            $pargs->{-dry_run} ? "[DRY-RUN] " : "",
                            $cbargs{repo},
                            $mod,
                        );
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
        },
    );
}

sub _set_prereq_version {
    require Config::IOD;
    require File::Slurper;

    my $which = shift;
    my %fargs = @_;

    _for_each_repo(
        {requires_parsed_dist_ini => 1},
        \%fargs,
        sub {
            my %cbargs = @_;
            my $pargs = $cbargs{parent_args};
            my $iod = $cbargs{parsed_dist_ini};
            my $mod = $pargs->{module};
            my $found;
            my $modified;
            my ($v, $target_v);
          SECTION:
            for my $section ($iod->list_sections) {
                next unless $section =~ m!\APrereqs(?:\s*/\s*\w+)?\z!;
                for my $param ($iod->list_keys($section)) {
                    next unless $param eq $mod;
                    $v = $iod->get_value($section, $param);
                    return [412, "Prereq '$mod' is specified multiple times"]
                        if ref($v) eq 'ARRAY';
                    $found++;
                    if ($which eq 'set_to') {
                        $target_v = $pargs->{module_version};
                        if (version_eq($v, $target_v)) {
                            return [304, "Version of '$mod' already the same ($v)"];
                        }
                        $iod->set_value({all=>1}, $section, $param, $target_v);
                        $modified++;
                    } elsif ($which eq 'inc_to') {
                        $target_v = $pargs->{module_version};
                        unless (version_gt($target_v, $v)) {
                            return [304, "Version of '$mod' ($v) already >= $target_v"];
                        }
                        $iod->set_value({all=>1}, $section, $param, $target_v);
                        $modified++;
                    } elsif ($which eq 'dec_to') {
                        $target_v = $pargs->{module_version};
                        unless (version_lt($target_v, $v)) {
                            return [304, "Version of '$mod' ($v) already <= $target_v"];
                        }
                        $iod->set_value({all=>1}, $section, $param, $target_v);
                        $modified++;
                    } elsif ($which eq 'inc_by') {
                        eval { $target_v = add_version($v, $pargs->{by}) };
                        return [500, "Can't add version ($v + $pargs->{by}): $@"] if $@;
                        if (version_eq($target_v, $v)) {
                            return [304, "Version of '$mod' ($v) already = $target_v"];
                        }
                        $iod->set_value({all=>1}, $section, $param, $target_v);
                        $modified++;
                    } elsif ($which eq 'dec_by') {
                        eval { $target_v = subtract_version($v, $pargs->{by}) };
                        return [500, "Can't subtract version ($v + $pargs->{by}): $@"] if $@;
                        if (version_eq($target_v, $v)) {
                            return [304, "Version of '$mod' ($v) already = $target_v"];
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
                    $log->infof("%sModified dist.ini for repo '%s' (set prereq '%s' version from %s to %s)",
                                $pargs->{-dry_run} ? "[DRY-RUN] " : "",
                                $cbargs{repo},
                                $mod, $v, $target_v,
                            );
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

=cut
