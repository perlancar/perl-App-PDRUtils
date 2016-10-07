package App::PDRUtils::DistIniCmd::list_prereqs;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use App::PDRUtils::Cmd;
use App::PDRUtils::DistIniCmd;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'List prereqs from `[Prereqs/*]` sections',
    description => <<'_',

This command list prerequisites found in `[Prereqs/*]` sections in your
`dist.ini`.

_
    args => {
        %App::PDRUtils::DistIniCmd::common_args,
        phase => {
            schema => ['str*', in=>[qw/configure build test runtime develop/]],
            tags => ['category:filtering'],
        },
        rel => {
            schema => ['str*', in=>[qw/requires recommends suggests conflicts/]],
            tags => ['category:filtering'],
        },
        detail => {
            schema => 'bool',
            cmdline_aliases => {l=>{}},
        },
    },
};
sub handle_cmd {
    my %fargs = @_;

    my $iod = $fargs{parsed_dist_ini};
    my $hoh = $iod->dump;

    my @res;
    for my $sect (sort keys %$hoh) {
        next unless $sect =~ m!\A
                               Prereqs
                               (?:\s*/\s*
                                   (Configure|Build|Test|Runtime|Develop)
                                   (Requires|Recommends|Suggests|Conflicts))?
                               \z!x;
        my $phase = $1 // "Runtime";
        my $rel   = $2 // "Requires";

        if (defined $fargs{phase}) {
            next unless lc($fargs{phase}) eq lc($phase);
        }
        if (defined $fargs{rel}) {
            next unless lc($fargs{rel}) eq lc($rel);
        }

        my $prereqs = $hoh->{$sect};
        for my $mod (sort keys %$prereqs) {
            my $version = $prereqs->{$mod};
            push @res, {
                module  => $mod,
                version => $version,
                phase   => lc $phase,
                rel     => lc $rel,
            };
        }
    }

    if ($fargs{detail}) {
        return [304, "Not modified", $iod, {
            'func.result' => \@res,
            'table.fields' => [qw/module version phase rel/],
        }];
    } else {
        @res = map { $_->{module} } @res;
        return [304, "Not modified", $iod, {
            'func.result' => \@res,
        }];
    }
}

1;
# ABSTRACT:
