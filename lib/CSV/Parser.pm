#!/usr/bin/env perl6
 
class CSV::Parser {
  has $.binary              = 0;
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
  has $!lbuff               = '';

  method reset () {
    my $p = $.file_handle.path;
    $.file_handle.close;
    $.file_handle = open $p, :r;
  }

  method get_line () returns Hash {
    return Nil if $.file_handle.eof;
    $!lbuff = $!lbuff == '' ?? ( $.binary == 1 ?? Buf.new() !! '' ) !! $!lbuff;
    my $buffer = $!lbuff;

    $!bpos = 0;
    $!bopn = 0;
    while my $line = ( $.binary == 1 ?? $.file_handle.read($.chunk_size) !! $.file_handle.get ) {
      $buffer = $buffer ~ $line;
      $buffer ~= "\n" if ( $.binary == 0 );
      $buffer ~= $.line_separator if ( $.binary == 1 );
      last if $.detect_end_line( $buffer ) == 1;
    }
    if ($.binary == 1) {
      $buffer = $buffer.subbuf(0, $buffer.bytes - $.line_separator.bytes);
      $!lbuff = $buffer.subbuf($!bpos - 1);
      $buffer = $buffer.subbuf(0, $!bpos);
    } else {
      $buffer = $buffer.substr(0, $buffer.chars - 1);
      $!lbuff = $buffer.substr($!bpos - 1);
      $buffer = $buffer.substr(0, $!bpos);
    }
    if ( $!contains_header_row ) { 
      %!headers = %($.parse( $buffer ));
      $!contains_header_row = 0;
      return $.get_line();
    }
    return %($.parse( $buffer ));
  };

  method parse ( $line ) {
    my %values    = ();
    my %header    = %!headers;
    my $fcnt      = 0;
    my $localbuff = $.binary == 1 ?? Buf.new() !! '';
    my $buffpos   = 0;
    my $buffer    = $line;
    my $bopn      = 0;
    my $key;
    #my $reg       = /^{$.field_operator}|{$.field_operator}$/; #this shit isn't implemented yet

    while ($.binary == 0 && $buffpos < $buffer.chars) || ($.binary == 1 && $buffpos < $buffer.bytes) {
      if ( ( ( $.binary == 0 && $buffer.substr($buffpos, $.field_operator.chars) eq  $.field_operator ) || 
             ( $.binary == 1 && $buffer.subbuf($buffpos, $.field_operator.bytes) eqv $.field_operator ) ) &&
           ( ( $.binary == 0 && $localbuff ne   $.escape_operator ) || 
             ( $.binary == 1 && $localbuff !eqv $.escape_operator ) ) ) {
        $bopn = $bopn == 1 ?? 0 !! 1;
      }
      if ( ( ( $.binary == 0 && $buffer.substr($buffpos, $.field_separator.chars) eq  $.field_separator ) ||
             ( $.binary == 1 && $buffer.subbuf($buffpos, $.field_separator.bytes) eqv $.field_separator ) ) &&
           ( ( $.binary == 0 && $localbuff ne   $.escape_operator ) || 
             ( $.binary == 1 && $localbuff !eqv $.escape_operator ) ) &&
           $bopn == 0 ) {
        $key = %header{$fcnt}:exists ?? %header{ $fcnt } !! $fcnt;
        if ($.binary == 1) {
          %values{ $key } = $buffer.subbuf(0, $buffpos);
          %values{ $key } = %values{ $key }.subbuf($.field_operator.bytes, %values{ $key }.bytes - ( $.field_operator.bytes * 2 )) if %values{ $key }.subbuf(0, $.field_operator.bytes) eqv $.field_operator;
          $buffer = $buffer.subbuf($buffpos+$.field_separator.bytes);
        } else {
          %values{ $key } = $buffer.substr(0, $buffpos);
          %values{ $key } = %values{ $key }.substr($.field_operator.chars, %values{ $key }.chars - ( $.field_operator.chars * 2 )) if %values{ $key }.substr(0, $.field_operator.chars) eq  $.field_operator;
          $buffer = $buffer.substr($buffpos+$.field_separator.chars);
        }
        $buffpos = 0;
        $fcnt++;
        next;
      }
      
      $localbuff = ($localbuff.chars >= $.escape_operator.chars ?? $localbuff.substr(1) !! $localbuff) ~ $buffer.substr($buffpos, 1) if $.binary == 0;
      $localbuff = ($localbuff.bytes >= $.escape_operator.bytes ?? $localbuff.subbuf(1) !! $localbuff) ~ $buffer.subbuf($buffpos, 1) if $.binary == 1; 
      $buffpos++;
    }
    $key = %header{$fcnt}:exists ?? %header{ $fcnt } !! $fcnt;
    %values{ $key } = $buffer;
    %values{ $key } = %values{ $key }.substr($.field_operator.chars, %values{ $key }.chars - ( $.field_operator.chars * 2 )) if $.binary == 0 && %values{ $key }.substr(0, $.field_operator.chars) eq  $.field_operator;
    %values{ $key } = %values{ $key }.subbuf($.field_operator.bytes, %values{ $key }.bytes - ( $.field_operator.bytes * 2 )) if $.binary == 1 && %values{ $key }.subbuf(0, $.field_operator.bytes) eqv $.field_operator;

    while %header{++$fcnt}:exists {
      %values{ %header{ $fcnt } } = Nil;
    }

    return %values;
  };

  method detect_end_line ( $buffer ) {
    my $localbuff = $.binary == 1 ?? Buf.new !! '';
    while $!bpos < ( $.binary == 1 ?? $buffer.bytes !! $buffer.chars ) {
      if ( ( ( $.binary == 0 && $buffer.substr($!bpos, $.field_operator.chars) eq  $.field_operator ) || 
             ( $.binary == 1 && $buffer.subbuf($!bpos, $.field_operator.bytes) eqv $.field_operator ) ) &&
           ( ( $.binary == 0 && $localbuff ne   $.escape_operator ) || 
             ( $.binary == 1 && $localbuff !eqv $.escape_operator ) ) ) {
        $!bopn = $!bopn == 1 ?? 0 !! 1;
      }

      #detect line separator
      if ( ( ( $.binary == 0 && $buffer.substr($!bpos, $.line_separator.chars) eq  $.line_separator ) ||
             ( $.binary == 1 && $buffer.subbuf($!bpos, $.line_separator.bytes) eqv $.line_separator ) ) && 
           ( ( $.binary == 0 && $localbuff ne   $.escape_operator ) ||
             ( $.binary == 1 && $localbuff !eqv $.escape_operator ) ) && 
           $!bopn == 0 ) {
        $!bpos++;
        return 1;
      }
      $localbuff = ($localbuff.chars >= $.escape_operator.chars ?? $localbuff.substr(1) !! $localbuff) ~ $buffer.substr($!bpos, 1) if $.binary == 0;
      $localbuff = ($localbuff.bytes >= $.escape_operator.bytes ?? $localbuff.subbuf(1) !! $localbuff) ~ $buffer.subbuf($!bpos, 1) if $.binary == 1;
      $!bpos++;
    }
    return 0;
  };
};
