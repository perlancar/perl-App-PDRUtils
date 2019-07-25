package App::PDRUtils::Cmd;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %mod_args = (
    module => {
        schema => 'str*',
        req => 1,
        pos => 0,
    },
);

my $re_mod_ver = qr/\Av?\d{1,15}(?: (?:(?:\.\d{1,3}){0,2})|(?:\.\d{1,8}) )\z/x;

our %mod_ver_args = (
    module_version => {
        schema => ['str*', match=>$re_mod_ver], # XXX perl::mod_ver?
        req => 1,
        pos => 1,
    },
);

our %opt_mod_ver_args = (
    module_version => {
        schema => ['str*', match=>$re_mod_ver], # XXX perl::mod_ver?
        default => "0",
        pos => 1,
    },
);

our %by_ver_args = (
    by => {
        schema => ['str*', match=>$re_mod_ver], # XXX perl::mod_ver?
        req => 1,
        pos => 1,
    },
);

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

1;
# ABSTRACT: Common stuffs for App::PDRUtils::*Cmd::*
