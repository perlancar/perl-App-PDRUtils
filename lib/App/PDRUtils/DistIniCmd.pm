package App::PDRUtils::DistIniCmd;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %common_args = (
    #dist_ini => {
    #    schema => 'str*',
    #    req => 1,
    #},
    parsed_dist_ini => {
        schema => ['obj*'],
        req => 1,
    },
);

1;
# ABSTRACT: Common stuffs for App::PDRUtils::DistIniCmd::*
