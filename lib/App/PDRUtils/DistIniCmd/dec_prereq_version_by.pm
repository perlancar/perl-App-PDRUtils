package App::PDRUtils::DistIniCmd::dec_prereq_version_by;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use App::PDRUtils::Cmd;
use App::PDRUtils::DistIniCmd;
use App::PDRUtils::DistIniCmd::_modify_prereq_version;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'Decrease prereq version by a certain decrement',
    args => {
        %App::PDRUtils::DistIniCmd::common_args,
        %App::PDRUtils::Cmd::mod_args,
        %App::PDRUtils::Cmd::by_ver_args,
    },
};
sub handle_cmd {
    App::PDRUtils::DistIniCmd::_modify_prereq_version::_modify_prereq_version(
        'dec_by', @_);
}

1;
# ABSTRACT:
