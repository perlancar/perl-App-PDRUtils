package App::PDRUtils::SingleCmd;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use App::PDRUtils::DistIniCmd;
use App::PDRUtils::SingleCmd;
use Function::Fallback::CoreOrPP qw(clone);

our %common_args = (
);

sub create_cmd_from_dist_ini_cmd {
    no strict 'refs';

    my %args = @_;

    my $name = $args{dist_ini_cmd};

    my $source_pkg = "App::PDRUtils::DistIniCmd::$name";
    my $target_pkg = "App::PDRUtils::SingleCmd::$name";

    eval "use $source_pkg"; die if $@;

    my $source_specs = \%{"$source_pkg\::SPEC"};
    my $spec = clone($source_specs->{handle_cmd});

    for (keys %App::PDRUtils::DistIniCmd::common_args) {
        delete $spec->{args}{$_};
    }
    for (keys %App::PDRUtils::SingleCmd::common_args) {
        $spec->{args}{$_} = $App::PDRUtils::SingleCmd::common_args{$_};
    }

    ${"$target_pkg\::SPEC"}{handle_cmd} = $spec;
}

1;
# ABSTRACT: Common stuffs for App::PDRUtils::SingleCmd::*
