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

=head1 DESCRIPTION

A module under the L<App::PDRUtils::DistIniCmd> namespace represents a command
that modifies F<dist.ini>. It is passed a parsed F<dist.ini> in the form of
L<Config::IOD::Document> object and is expected to modify the object and return
status 200 (along with the object), or return 304 if nothing is modified. Result
(if there is an output) can be returned in the result metadata in
C<func.result> key).

A DistIniCmd can easily be turned into a SingleCmd or MultiCmd.
