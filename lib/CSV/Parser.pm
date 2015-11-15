#!/usr/bin/env perl6
 
class CSV::Parser {
  has Bool       $.binary              = False;
  has IO::Handle $.file_handle         = Nil;
  has Bool       $.contains_header_row = False;
  has            $.field_separator     = ',';
  has            $.line_separator      = "\n";
  has            $.field_operator      = '"';
  has            $.escape_operator     = '\\';
  has int        $.chunk_size          = 1024;
  has int        $!fpos                = 0;
  has int        $!bpos                = 0;
  has int        $!bopn                = 0;
  has            $!lbuff               = '';

  has        %!headers;

  method reset () {
    my $p = $!file_handle.path;
    $!file_handle.close;
    $!file_handle = open $p, :r;
  }

  method get_line () {
    return Nil if $!file_handle.eof;
    $!lbuff = (?$!binary ?? Buf.new() !! '') if $!lbuff."{self!sizer}"();
    my $buffer = $!lbuff;
    $!bpos = $!bopn = 0;

    while ( ?$!binary ?? $!file_handle.read($!chunk_size) !! $!file_handle.get ) -> $line {
      $buffer ~= $line ~ $!line_separator;
      last if self.detect_end_line( $buffer ) == 1;
    }

    if ($buffer."{self!sizer}"() - $!line_separator."{self!sizer}"()) -> $size {
      $buffer  = $buffer."{self!subber}"(0, $size);
      $!lbuff  = $buffer."{self!subber}"($!bpos - 1);
      $buffer  = $buffer."{self!subber}"(0, $!bpos);
    }

    !$!contains_header_row ?? %(self.parse( $buffer )) !! do {
      %!headers = %(self.parse( $buffer ));
      $!contains_header_row = False;
      self.get_line();
    }
  };

  method !sizer  { ?$!binary ?? "bytes"  !! "chars"  }
  method !subber { ?$!binary ?? "subbuf" !! "substr" }
  method !cmper($a,$b)  { ?$!binary ?? ($a eqv $b) !! ($a eq $b) } # make me an infix

  method parse ( $line ) returns Hash {
    my %values      = ();
    my %header      = %!headers;
    my $localbuff   = ?$!binary ?? Buf.new() !! '';
    my $buffer      = $line;
    my int $fcnt    = 0;
    my int $buffpos = 0;
    my int $bopn    = 0;
    my $key;
    #my $reg       = /^{$.field_operator}|{$.field_operator}$/; #this shit isn't implemented yet

    while $buffpos < $buffer."{self!sizer}"() {
      if self!cmper($buffer."{self!subber}"($buffpos, $!field_operator."{self!sizer}"()), $!field_operator )
            && !self!cmper($localbuff, $!escape_operator) {
        $bopn = $bopn == 1 ?? 0 !! 1;
      }

      if self!cmper($buffer."{self!subber}"($buffpos, $!field_separator."{self!sizer}"()), $!field_separator )
            && !self!cmper($localbuff, $!escape_operator) && $bopn == 0 {
        $key = %header{(~$fcnt)}:exists ?? %header{~$fcnt} !! $fcnt;
        %values{ $key } = $buffer."{self!subber}"(0, $buffpos);
        %values{ $key } = %values{ $key }."{self!subber}"($!field_operator."{self!sizer}"(), %values{ $key }."{self!sizer}"() - ( $!field_operator."{self!sizer}"() * 2 ))\
          if self!cmper( %values{ $key }."{self!subber}"(0, $!field_operator."{self!sizer}"()), $!field_operator);
        $buffer = $buffer."{self!subber}"($buffpos+$!field_separator."{self!sizer}"());
        $buffpos = 0;
        $fcnt++;
        next;
      }
      
      $localbuff = ($localbuff."{self!sizer}"() >= $!escape_operator."{self!sizer}"() ?? $localbuff."{self!subber}"(1) !! $localbuff) ~ $buffer."{self!subber}"($buffpos, 1);
      $buffpos++;
    }
    $key = %header{~$fcnt}:exists ?? %header{~$fcnt} !! $fcnt;
    %values{ $key } = $buffer;
    %values{ $key } = %values{ $key }."{self!subber}"($!field_operator."{self!sizer}"(), %values{ $key }."{self!sizer}"() - ( $!field_operator."{self!sizer}"() * 2 )) if self!cmper( %values{ $key }."{self!subber}"(0, $!field_operator."{self!sizer}"()), $!field_operator);

    while %header{~(++$fcnt)}:exists {
      %values{%header{~$fcnt}} = Nil;
    }

    return %values;
  };

  method detect_end_line ( $buffer ) returns Bool {
    my $localbuff = ?$!binary ?? Buf.new() !! '';
    while $!bpos < $buffer."{self!sizer}"() {
      if self!cmper($buffer."{self!subber}"($!bpos, $!field_operator."{self!sizer}"()), $!field_operator )
            && !self!cmper($localbuff, $!escape_operator) {
        $!bopn = $!bopn == 1 ?? 0 !! 1;
      }

      #detect line separator
      if self!cmper($buffer."{self!subber}"($!bpos, $!line_separator."{self!sizer}"()), $!line_separator )
            && !self!cmper($localbuff, $!escape_operator) && $!bopn == 0 {
        $!bpos++;
        return True;
      }
      $localbuff = ($localbuff."{self!sizer}"() >= $!escape_operator."{self!sizer}"() ?? $localbuff."{self!subber}"(1) !! $localbuff) ~ $buffer."{self!subber}"($!bpos, 1);
      $!bpos++;
    }
    return False;
  };
};
