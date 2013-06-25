#!/usr/bin/env perl6

use Test;
plan 1;

use Text::CSV;

my $outcome = 1;
my $fh      = open 't/data/multiline.csv', :r;
my $parser  = Text::CSV.new( file_handle => $fh , contains_header_row => 1 );
my $keys    = 0;
my %line    = $parser.get_line();

for (%line.kv) -> $k,$v {
  $keys++;
  $outcome = 0 if $k ne $v; 
}

$outcome = 0 if $keys != 5; 

$fh.close;
ok $outcome == 1;