package App::PDRUtils::DistIniCmd::sort_prereqs;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use App::PDRUtils::Cmd;
use App::PDRUtils::DistIniCmd;
use Config::IOD::Constants ':ALL';
use POSIX qw(floor);

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'Sort lines in `[Prereqs/*]` sections',
    description => <<'_',

This command can sort `[Prereqs/*]` sections in your `dist.ini` according to
this rule (TODO: allow customized rule): `perl` comes first, then pragmas sorted
ascibetically and case-insensitively (e.g. `strict`, `utf8`, `warnings`), then
other modules sorted ascibetically and case-insensitively.

Can detect one-spacing or two-spacing. Detects directives and comments.

_
    args => {
        %App::PDRUtils::DistIniCmd::common_args,
        spacing => {
            summary => 'Set spacing explicitly',
            schema => ['int*', min=>1, max=>10],
        },
    },
};
sub handle_cmd {
    my %fargs = @_;

    my $iod = $fargs{parsed_dist_ini};
    my $old_content = $iod->as_string;

    my @sections;
    $iod->each_section(
        sub {
            my ($self, %cbargs) = @_;
            return unless $cbargs{section} =~ m!\Aprereqs(?:\s*/\s*(\w+))?\z!ix;
            push @sections, {
                linum_start => $cbargs{linum_start},
                linum_end   => $cbargs{linum_end},
            };
        }
    );

    for my $s (reverse @sections) {
        my @lines;
        my $num_lines = 0;
        my $num_blank_lines = 0;
        my $num_key_lines = 0;

        # remove blank lines and calculate spacing
        for my $linum ($s->{linum_start} .. $s->{linum_end}-1) {
            my $l = $iod->{_parsed}[$linum];
            $num_lines++;
            if ($l->[COL_TYPE] eq 'B') {
                $num_blank_lines++;
                next;
            }
            my $mod;
            if ($l->[COL_TYPE] eq 'K') {
                $num_key_lines++;
                $mod = $l->[COL_K_KEY];
            }
            if ($l->[COL_TYPE] eq 'C') {
                # check if this is a commented param
                if ($l->[COL_C_COMMENT] =~ /\s*([^=]+?)\s*=/) {
                    $mod = $1;
                }
            }
            push @lines, {
                mod => $mod,
                linum => $linum,
                parsed => $l,
            };
        }
        my $spacing = $fargs{spacing} //
            (floor(($num_blank_lines) / ($num_key_lines+1))+1);

        # there's no prereq lines, no need to sort this section
        next unless $num_key_lines;

        # associate comments/directives to the key line directly below it
        my $cur_mod;
        for my $lrec (reverse @lines) {
            if (defined $lrec->{mod}) {
                $cur_mod = $lrec->{mod};
                next;
            }
            if ($lrec->{parsed}[COL_TYPE] =~ /[CD]/) {
                $lrec->{mod} = $cur_mod // "Zzzzzzzzzzzzzzzz";
            }
        }

        # sort it!
        @lines = sort {
            my $mod_a = $a->{mod};
            my $mod_b = $b->{mod};

            my $mod_a_is_perl = $mod_a eq 'perl' ? 1:0;
            my $mod_b_is_perl = $mod_b eq 'perl' ? 1:0;

            my $mod_a_is_pragma = $mod_a =~ /\A[a-z]/ ? 1:0;
            my $mod_b_is_pragma = $mod_b =~ /\A[a-z]/ ? 1:0;

            ($mod_b_is_perl <=> $mod_a_is_perl) ||
                ($mod_b_is_pragma <=> $mod_a_is_pragma) ||
                lc($mod_a) cmp lc($mod_b) ||
                $a->{linum} <=> $b->{linum};
        } @lines;

        # insert spaces if necessary
        {
            last unless $spacing > 1;
            undef $cur_mod;
            for my $i (reverse (0..$#lines)) {
                my $lrec = $lines[$i];
                if (!defined($cur_mod) || $cur_mod ne $lrec->{mod}) {
                    for (1..$spacing-1) {
                        splice @lines, $i+1, 0, {parsed=>['B', "\n"]};
                    }
                }
                $cur_mod = $lrec->{mod};
            }
        }
        push @lines, {parsed=>['B', "\n"]};
        splice @{ $iod->{_parsed} },
            $s->{linum_start},
            ($s->{linum_end} - $s->{linum_start}),
            map {$_->{parsed}} @lines;
    }

    $iod->_discard_cache;

    my $new_content = $iod->as_string;
    #say $new_content;
    my $modified = $old_content ne $new_content;

    if ($modified) {
        return [200, "Sorted prereqs", $iod];
    } else {
        return [304, "Not modified"];
    }
}

1;
# ABSTRACT:
