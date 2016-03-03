package App::PDRUtils::DistIniCmd::add_prereq;

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
    summary => 'Add a prereq',
    args => {
        %App::PDRUtils::DistIniCmd::common_args,
        %App::PDRUtils::Cmd::mod_args,
        %App::PDRUtils::Cmd::opt_mod_ver_args,
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
};
sub handle_cmd {
    my %args = @_;

    my $iod   = $args{parsed_dist_ini};
    my $mod   = $args{module};
    my $ver   = $args{module_version} // 0;
    my $phase = $args{phase} // 'runtime';
    my $rel   = $args{rel} // 'requires';

    if (App::PDRUtils::Cmd::_has_prereq($iod, $mod)) {
        return [304, "Already has prereq to '$mod'"];
    }

    my $section;
    for my $s ($iod->list_sections) {
        next unless $s =~ m!\Aprereqs(?:\s*/\s*(\w+))?\z!ix;
        if ($phase eq 'runtime' && $rel eq 'requires') {
            next unless !$1 || lc($1) eq 'runtimerequires';
        } else {
            next unless  $1 && lc($1) eq $phase.$rel;
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
        return [200, "Added prereq '$mod=$ver' to section [$section]", $iod];
    } else {
        return [304, "Not modified"];
    }
}

1;
# ABSTRACT:
