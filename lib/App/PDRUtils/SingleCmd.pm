package App::PDRUtils::SingleCmd;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use App::PDRUtils::DistIniCmd;
use Function::Fallback::CoreOrPP qw(clone);

our %common_args = (
);

sub create_cmd_from_dist_ini_cmd {
    require Config::IOD;
    require File::Slurper;

    no strict 'refs';

    my %cargs = @_;

    my $name = $cargs{dist_ini_cmd};

    my $source_pkg = "App::PDRUtils::DistIniCmd::$name";
    my $target_pkg = caller();#"App::PDRUtils::SingleCmd::$name";

    eval "use $source_pkg"; die if $@;

    my $source_specs = \%{"$source_pkg\::SPEC"};
    my $spec = clone($source_specs->{handle_cmd});

    for (keys %App::PDRUtils::DistIniCmd::common_args) {
        delete $spec->{args}{$_};
    }
    for (keys %common_args) {
        $spec->{args}{$_} = $common_args{$_};
    }
    $spec->{features}{dry_run} = 1;

    ${"$target_pkg\::SPEC"}{handle_cmd} = $spec;
    *{"$target_pkg\::handle_cmd"} = sub {
        my %fargs = @_;
        return [412, "No dist.ini in current directory"] unless -f "dist.ini";

        my $ciod = Config::IOD->new(
            ignore_unknown_directive => 1,
        );
        my $iod;
        eval { $iod = $ciod->read_file("dist.ini") };
        return [500, "Can't parse dist.ini: $@"] if $@;
        my $handle_cmd = \&{"$source_pkg\::handle_cmd"};
        my $res = $handle_cmd->(
            %fargs,
            parsed_dist_ini => $iod,
        );
        if ($res->[0] == 200) {
            $log->infof("%s%s",
                        $fargs{-dry_run} ? "[DRY-RUN] " : "",
                        $res->[1]);
            if ($fargs{-dry_run}) {
                $res->[0] = 304;
            } else {
                File::Slurper::write_text("dist.ini", $res->[2]->as_string);
            }
            undef $res->[2];
        } else {
            $log->tracef("%d - %s", $res->[0], $res->[1]);
        }

        # move final result so users can see it
        if (exists $res->[3]{'func.result'}) {
            $res->[2] = delete $res->[3]{'func.result'};
        }

        $res;
    };
}

1;
# ABSTRACT: Common stuffs for App::PDRUtils::SingleCmd::*

=head1 DESCRIPTION

A module in L<App::PDRUtils::SingleCmd> namespace represents a subcommand for
the L<pdrutil> utility.


=head1 FUNCTIONS

=head2 create_cmd_from_dist_ini_cmd(%args)

Turn a DistIniCmd into a SingleCmd.

=cut
