package App::PDRUtils::SingleCmd::list_prereqs;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use App::PDRUtils::SingleCmd;

App::PDRUtils::SingleCmd::create_cmd_from_dist_ini_cmd(
    dist_ini_cmd => 'list_prereqs',
);

1;
# ABSTRACT:
