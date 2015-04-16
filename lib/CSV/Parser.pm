#!/usr/bin/env perl6
 
class CSV::Parser {
  has Bool       $.binary              = False;
  has IO::Handle $.file_handle         = Nil;
  has Bool       $.contains_header_row = False;
  has Buf        $.field_separator    .= new(','.encode('utf8'));
  has Buf        $.line_separator     .= new("\n".encode('utf8'));
  has Buf        $.field_operator     .= new('"'.encode('utf8'));
  has Buf        $.escape_operator    .= new('\\'.encode('utf8'));
  has Int        $.chunk_size          = 1024;
  has Int        $!fpos                = 0;
  has Int        $!bpos                = 0;
  has Int        $!bopn                = 0;
  has Any        %!headers             = Nil;
  has Buf        $!lbuff              .= new;

  method reset () {
    my $p = $.file_handle.path;
    $.file_handle.close;
    $.file_handle = open $p, :r;
  }

  method get_line () {
    return Nil if $.file_handle.eof;
    $!lbuff .= new;
    my Buf $buffer = $!lbuff;

    $!bpos = 0;
    $!bopn = 0;
    while my Buf $line = $.file_handle.read($.chunk_size) {
      $buffer ~= $line;
      $buffer ~= $.line_separator;
      last if $.detect_end_line( $buffer ) == 1;
    }
    $buffer = $buffer.subbuf(0, $buffer.bytes - $.line_separator.bytes);
    $!lbuff = $buffer.subbuf($!bpos - 1);
    $buffer = $buffer.subbuf(0, $!bpos);
    if ( $!contains_header_row ) { 
      %!headers = %($.parse( $buffer ));
      $!contains_header_row = False;
      return $.get_line();
    }
    return %($.parse( $buffer ));
  };

  method parse ( Buf $line ) returns Hash {
    my Any %values     = ();
    my Any %header     = %!headers;
    my Int $fcnt       = 0;
    my Buf $localbuff .= new;
    my Int $buffpos    = 0;
    my Buf $buffer     = $line;
    my Int $bopn       = 0;
    my Any $key;

    while $buffpos < $buffer.bytes {
      if $buffer.subbuf($buffpos, $.field_operator.bytes) eqv $.field_operator
         && $localbuff !eqv $.escape_operator {
        $bopn = $bopn == 1 ?? 0 !! 1;
      }
      if $buffer.subbuf($buffpos, $.field_separator.bytes) eqv $.field_separator
         && $localbuff !eqv $.escape_operator 
         && $bopn == 0 {
        $key = %header{(~$fcnt)}:exists ?? %header{~$fcnt}.decode !! $fcnt;
        %values{ $key } = $buffer.subbuf(0, $buffpos);
        %values{ $key } = %values{ $key }.subbuf($.field_operator.bytes, %values{ $key }.bytes - ( $.field_operator.bytes * 2 )) if %values{ $key }.subbuf(0, $.field_operator.bytes) eqv $.field_operator;
        $buffer = $buffer.subbuf($buffpos+$.field_separator.bytes);
        $buffpos = 0;
        $fcnt++;
        next;
      }
      
      $localbuff = ($localbuff.bytes >= $.escape_operator.bytes ?? $localbuff.subbuf(1) !! $localbuff) ~ $buffer.subbuf($buffpos, 1); 
      $buffpos++;
    }
    $key = %header{~$fcnt}:exists ?? %header{~$fcnt}.decode !! $fcnt;
    %values{ $key } = $buffer;
    %values{ $key } = %values{ $key }.subbuf($.field_operator.bytes, %values{ $key }.bytes - ( $.field_operator.bytes * 2 )) if %values{ $key }.subbuf(0, $.field_operator.bytes) eqv $.field_operator;

    while %header{~(++$fcnt)}:exists {
      %values{%header{~$fcnt}.decode} = Nil;
    }
    return %values;
  };

  method detect_end_line ( Buf $buffer ) returns Int {
    my Buf $localbuff .= new;
    while $!bpos < $buffer.bytes {
      if $buffer.subbuf($!bpos, $.field_operator.bytes) eqv $.field_operator 
         && $localbuff !eqv $.escape_operator {
        $!bopn = $!bopn == 1 ?? 0 !! 1;
      }

      #detect line separator
      if $buffer.subbuf($!bpos, $.line_separator.bytes) eqv $.line_separator 
         && $localbuff !eqv $.escape_operator 
         &&  $!bopn == 0 {
        $!bpos++;
        return 1;
      }
      $localbuff = ($localbuff.bytes >= $.escape_operator.bytes ?? $localbuff.subbuf(1) !! $localbuff) ~ $buffer.subbuf($!bpos, 1);
      $!bpos++;
    }
    return 0;
  };
};
