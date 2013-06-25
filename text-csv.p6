#!/usr/bin/env perl6
use Grammar::Debugger;
class Text::CSV {
  has $.binary              = 1;
  has $.file_handle         = Nil;
  has $.contains_header_row = 0;
  has $.field_separator     = ',';
  has $.line_separator      = "\n";
  has $.field_operator      = '"';
  has $.escape_operator     = '\\';
  has $.chunk_size          = 1024;
  has $!fpos                = 0;
  has $!bpos                = 0;
  has $!bopn                = 0;
  has %!headers             = Nil;

  method get_line () {
    my $buffer = '';

    $!bpos = 0;
    $!bopn = 0;
    while my $line = $.file_handle.get {
      $buffer ~= $line;
      $buffer ~= "\n";
      last if $.detect_end_line( $buffer ) == 1;
    }
    $.file_handle.seek($!bpos, 0) if not $.file_handle.eof;
    $buffer = $buffer.substr(0, $!bpos).chomp;
    return $.parse( $buffer ); 
  };

  method parse ( $line ) {
    my %values    = ();
    my %header    = %!headers;
    my $fcnt      = 0;
    my $localbuff = '';
    my $buffpos   = 0;
    my $buffer    = $line;
    my $bopn      = 0;
    my $reg       = /^{$.field_operator}|{$.field_operator}$/;

    while $buffpos < $buffer.chars {
      if ( $buffer.substr($buffpos, $.field_operator.chars) eq $.field_operator &&
           $localbuff ne $.escape_operator ) {
        $bopn = $bopn == 1 ?? 0 !! 1;
      }
      if ( $buffer.substr($buffpos, $.field_separator.chars) eq $.field_separator &&
           $localbuff ne $.escape_operator &&
           $bopn == 0 ) {
        %values{ ( %header.exists($fcnt) ?? %header{ $fcnt } !! $fcnt ) } = $buffer.substr(0, $buffpos).subst($reg, '', :g);
        $buffer = $buffer.substr($buffpos+1);
        $buffpos = 0;
        $fcnt++;
        next;
      }
      
      $localbuff = ($localbuff.chars >= $.escape_operator.chars ?? $localbuff.substr(1) !! $localbuff) ~ $buffer.substr($buffpos, 1).subst($reg, '', :g);
      $buffpos++;
    }
    %values{ ( %header.exists($fcnt) ?? %header{ $fcnt } !! $fcnt ) } = $buffer;

    return %values;
  };

  method detect_end_line ( $buffer ) {
    my $localbuff = '';
    while $!bpos < $buffer.chars {
      if ( $buffer.substr($!bpos, $.field_operator.chars) eq $.field_operator && 
           $localbuff ne $.escape_operator ) {
        $!bopn = $!bopn == 1 ?? 0 !! 1;
      }

      #detect line separator
      if ( $buffer.substr($!bpos, $.line_separator.chars) eq $.line_separator &&
           $localbuff ne $.escape_operator && 
           $!bopn == 0 ) {
        $!bpos++;
        return 1;
      }
      $localbuff = ($localbuff.chars >= $.escape_operator.chars ?? $localbuff.substr(1) !! $localbuff) ~ $buffer.substr($!bpos, 1);
      $!bpos++;
    }
    return 0;
  };
};

my $fh = open 'in1.csv', :r;

my $fdom = Text::CSV.new( file_handle => $fh );

say '1: ' ~ $fdom.get_line().perl;
say '2: ' ~ $fdom.get_line().perl;
