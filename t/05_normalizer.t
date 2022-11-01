#!/usr/bin/env perl6

use Test;
plan 1;

use CSV::Parser;

my $outcome = 1;
my $dc = 0;
my $fh      = open 't/data/multiline.csv', :r;
my $parser  = CSV::Parser.new(file_handle         => $fh,
                              contains_header_row => True,
                              field_normalizer => -> $k, $v, :$header = False {
                                $header ?? $v !! $dc++;
                              });
my %line    = %($parser.get_line());
my %found;

for (%line.kv) -> $k,$v {
  if $v ~~ Int {
    %found{$v} = True;
  }
}

$outcome = 0 if %found.keys.elems != $dc; 

$fh.close;
ok $outcome == 1;
