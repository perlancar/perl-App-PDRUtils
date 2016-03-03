package App::PDRUtils::MultiCmd::ls;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use App::PDRUtils::MultiCmd;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'List repos',
    args => {
        %App::PDRUtils::MultiCmd::common_args,
        detail => {
            schema => 'bool',
            cmdline_aliases => {l=>{}},
        },
        dist => {
            summary => 'Show dist names instead of repo dirs',
            schema => 'bool',
            cmdline_aliases => {d=>{}},
        },
    },
};
sub handle_cmd {
    my %fargs = @_;

    my @res;
    App::PDRUtils::MultiCmd::_for_each_repo(
        {requires_parsed_dist_ini => 1},
        \%fargs,
        sub {
            my %cbargs = @_;

            my $repo = $cbargs{repo};
            my $dist = $cbargs{dist};
            my $pargs = $cbargs{parent_args};

            if ($fargs{detail}) {
                push @res, {
                    dist => $dist,
                    repo => $repo,
                };
            } else {
                push @res, $fargs{dist} ? $dist : $repo;
            }

            [304];
        }, # callback
    ); # for each repo

    my $resmeta = {};
    $resmeta->{'table.fields'} = [qw/dist repo/] if $fargs{detail};

    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT: Common stuffs for App::PDRUtils::MultiCmd::*
