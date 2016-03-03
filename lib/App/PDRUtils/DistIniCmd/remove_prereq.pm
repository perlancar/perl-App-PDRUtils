package App::PDRUtils::DistIniCmd::remove_prereq;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use App::PDRUtils::Cmd;
use App::PDRUtils::DistIniCmd;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'Add a prereq',
    args => {
        %App::PDRUtils::DistIniCmd::common_args,
        %App::PDRUtils::Cmd::mod_args,
    },
};
sub handle_cmd {
    my %args = @_;

    my $iod   = $args{parsed_dist_ini};
    my $mod   = $args{module};

    my @sections = grep {
        $_ =~ m!\APrereqs(?:\s*/\s*\w+)?\z!
    } $iod->list_sections;

    my $modified;
    for my $section (@sections) {
        my $num_deleted = $iod->delete_key({all=>1}, $section, $mod);
        $modified++ if $num_deleted;
    }

    if ($modified) {
        return [200, "Removed prereq '$mod'", $iod];
    } else {
        return [304, "Not modified"];
    }
}

1;
# ABSTRACT:
