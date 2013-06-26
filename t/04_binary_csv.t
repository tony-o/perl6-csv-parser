#!/usr/bin/env perl6

use Test;
plan 2;

use CSV::Parser;

my $outcome = 1;
my $parser  = CSV::Parser.new( field_separator => Buf.new(5), 
                             field_operator  => Buf.new(6), 
                             line_separator  => Buf.new(7),
                             escape_operator => Buf.new(8),
                             binary => 1 );

my %line    = $parser.parse(Buf.new(6, 10, 6, 5, 11));

$outcome = 0 if %line{"0"} !eqv Buf.new(10);
$outcome = 0 if %line{"1"} !eqv Buf.new(11);

ok $outcome == 1;

$outcome = 1;
my $fh   = open 't/data/binary.csv', :r:bin;
$parser  = CSV::Parser.new( file_handle => $fh,
                          field_separator => '||'.encode('ASCII'), 
                          field_operator  => '\'\''.encode('ASCII'), 
                          line_separator  => "\n".encode('ASCII'),
                          escape_operator => '\\'.encode('ASCII'),
                          binary => 1 );

%line = $parser.get_line();
my %line2 = $parser.get_line();

for (%line.kv) -> $k,$v {
  $outcome = 0 if %line2{ $k } eqv $v;
}


ok $outcome == 1;
