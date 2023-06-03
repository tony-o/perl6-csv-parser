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
  has            $!lbuff;
  has Callable   $.field_normalizer    = -> \k, \v, :$header = False { v };

  has        %!headers;

  method headers () { %!headers }

  method reset () {
    my $p = $!file_handle.path;
    $!file_handle.close;
    $!file_handle = open $p, :r;
  }

  method get_line () {
    return Nil if $!file_handle.eof;
    $!lbuff = ?$!binary ?? Buf.new() !! '';
    $!bpos  = $!bopn = 0;
    my $buffer   = $!lbuff;
    my $lso_size = size_of($!line_separator);

    while ( ?$!binary ?? $!file_handle.read($!chunk_size) !! $!file_handle.get ) -> $line {
      $buffer ~= $line ~ $!line_separator;
      last if self.detect_end_line( $buffer ) == 1;
    }

    if (size_of($buffer) - $lso_size) -> $size {
      $buffer  = subpart($buffer, 0, $size);
      $!lbuff  = subpart($buffer, $!bpos - $lso_size);
      $buffer  = subpart($buffer, 0, $!bpos);
    }
    !$!contains_header_row ?? %(self.parse( $buffer, )) !! do {
      %!headers = %(self.parse( $buffer, :header(True) ));
      $!contains_header_row = False;
      self.get_line();
    };
  };

  method parse ( $line, :$header = False ) returns Hash {
    my %values      = ();
    my %header      = %!headers;
    my $localbuff   = ?$!binary ?? Buf.new() !! '';
    my $buffer      = $line;
    my int $fcnt    = 0;
    my int $buffpos = 0;
    my int $bopn    = 0;
    my $key;
    #my $reg       = /^{$.field_operator}|{$.field_operator}$/; #this shit isn't implemented yet
    my $fop_size = size_of($!field_operator);
    my $fsp_size = size_of($!field_separator);
    my $eop_size = size_of($!escape_operator);
    my $lso_size = size_of($!line_separator);

    while $buffpos < size_of($buffer) {
      if subpart($buffer, $buffpos, $fop_size) eqv $!field_operator && $localbuff !eqv $!escape_operator {
        $bopn = $bopn == 1 ?? 0 !! 1;
      }

      if $bopn == 0 && subpart($buffer, $buffpos, $fsp_size) eqv $!field_separator && $localbuff !eqv $!escape_operator {
        $key = %header{(~$fcnt)}:exists ?? %header{~$fcnt} !! $fcnt;
        my $buf := subpart($buffer, 0, $buffpos);
        %values{ $key } = subpart($buf, 0, $fop_size) eqv $!field_operator
          ?? subpart($buf, $fop_size, size_of($buf) - ( $fop_size * 2 ))
          !! $.field_normalizer.($key, $buf, :$header);
        $buffer = subpart($buffer, ($buffpos+$fsp_size));
        $buffpos = 0;
        $fcnt++;
        next;
      }
      $localbuff = (size_of($localbuff) >= $eop_size ?? subpart($localbuff, $eop_size) !! $localbuff) ~ subpart($buffer, $buffpos, $eop_size);
      $buffpos++;
    }

    $key = %header{~$fcnt}:exists ?? %header{~$fcnt} !! $fcnt;
    %values{ $key } = $buffer unless subpart($buffer, 0, $fop_size) eqv $!field_operator;
    %values{ $key } = subpart($buffer, $fop_size, size_of($buffer) - ( $fop_size * 2 ))\
      if subpart($buffer, 0, $fop_size) eqv $!field_operator;

    while %header{~(++$fcnt)}:exists {
      %values{%header{~$fcnt}} = Nil;
    }

    warn 'empty header key found' if $header &&  %header.values.grep(* eq '');
    return %values;
  };

  method detect_end_line ( $buffer ) returns Bool {
    my $localbuff = ?$!binary ?? Buf.new() !! '';
    my $fop_size = size_of($!field_operator);
    my $eop_size = size_of($!escape_operator);
    my $lso_size = size_of($!line_separator);

    while $!bpos < size_of($buffer) {
      if subpart($buffer, $!bpos, $fop_size) eqv $!field_operator && $localbuff !eqv $!escape_operator {
        $!bopn = $!bopn == 1 ?? 0 !! 1;
      }

      #detect line separator
      if subpart($buffer, $!bpos, $lso_size) eqv $!line_separator && $localbuff !eqv $!escape_operator && $!bopn == 0 {
        $!bpos++;
        return True;
      }
      $localbuff = (size_of($localbuff) >= $eop_size ?? subpart($localbuff, $eop_size) !! $localbuff) ~ subpart($buffer, $!bpos, $eop_size);
      $!bpos++;
    }
    return False;
  };

  proto sub size_of(|) {*}
  multi sub size_of(Blob $data) { $data.bytes }
  multi sub size_of(Str $data)  { $data.chars }
  multi sub size_of(Any $)      { 0 }

  proto sub subpart(|) {*}
  multi sub subpart(Blob $data, |c) { $data.subbuf(|c) }
  multi sub subpart(Str $data,  |c) { $data.substr(|c) }
};

=begin pod

=head1 NAME

C<CSV::Parser> - parses binary CSV file and reads it line by line.

=head1 SYNOPSIS

This module is pretty badass. It reads CSV files line by line and can handle
individual lines so you can handle your own file reads or you can let me do the
damn work for you. It handles binary files with relative ease so you can parse
your binary 'Comma Separated Value' files like a pro.

=begin code :lang<raku>
use CSV::Parser;

my $file_handle = open 'some.csv', :r;
my $parser = CSV::Parser.new(
    :$file_handle,
    :contains_header_row,
);

# Option 1
until $file_handle.eof {
  my %data = %($parser.get_line());
  # do something here with your hashish data
}

$parser.reset;

# Option 2
my %data;
while %data = %($parser.get_line()) {
  # do something with data here
}

$file_handle.close; # don't forget to close
=end code

=head1 INSTALLATION

=begin code :lang<console>
$ zef install CSV::Parser
=end code

=head1 METHODS

=head2 method new

=begin code :lang<raku>
method new(
    IO::Handle :$file_handle,
    Bool       :$binary,
    Bool       :$contains_header_row,
               :$field_separator,
               :$line_separator,
               :$field_operator,
               :$escape_operator,
    int        :$chunk_size,
)
=end code

Constructs a CSV parser and sets its attributes to the provided options.

=head3 C<file_handle>

File handle opened with L<C<read>|https://docs.raku.org/routine/read>.

=head3 C<binary>

=item Default: C<False>
=item Type: C<Bool>

Indicates if file was opened in binary mode. If C<True>, the
file was opened as binary and all operator/separator options are B<REQUIRED> to
be passed as C<Buf> objects (instead of C<Str>).

=head3 C<contains_header_row>

=item Default: C<False>
=item Type: C<Bool>

Indicates if the first line should be intepreted
as column names. If C<False>, the first line won't be interpreted as column
names and each parsed line will be returned as a hash with keys C<0..X-1>, where
C<X> is the number of columns. If C<True>, the first line will be interpreted as
column names, and each subsequent line will be returned as a hash whose keys are
the column names.

=head3 C<field_normalizer>

=item Default: C«-> $k, $v, :$header = False { $v }».
=item Type: C<Callable>

A C<Callable> with signature C<($key, $value, :$header = False)> to normalize
the key-value pair for each CSV row. The C<$key> is the header value if
available, otherwise the column index. The C<$value> is the value of the column.
The C<$header> boolean flag indicates whether we're parsing a header or a row
value. The return value is the column's final value, i.e., a C<Str>.

=head3 C<field_separator>

=item Default: C<,>
=item Type: C<Str> or C<Buf>

Specifies a single-character string used as the the column separator for each row.

=head3 C<line_separator>

=item Default: C<\n>
=item Type: C<Str>

Specifies the separator between CSV rows. See C<field_separator> - this will
be included in a parsed value if found in an open C<field_operator>.

=head3 C<field_operator>

=item Default: C<">
=item Type: C<Str>

Specifies the character [sequence] used to escape a field (can handle
C<line_separator> encapsulation). See C<field_separator>.

=head3 C<escape_operator>

=item Default: C<\\>
=item Type: C<Str>

Specifies the single-character string used to escape strings in a CSV row. See
C<field_separator>.

=head3 C<chunk_size>

=item Default: C<1024>
=item Type: C<Int>

Specifies how many bytes to read from the file handle. It
can be increased to improve performance if you are parsing some huge lined
binary file. 1024 should be sufficient.

=head2 method headers

Returns the parsed headers, if available.

=head2 method get_line

=begin code :lang<raku>
method get_line()
=end code

Reads a line or chunk from a file and return the parsed line. If this is the
first call to this function and C<contains_header_row> is set then this will
parse the first 2 lines and use the first row's values as the column values.

=head2 method parse

=begin code :lang<raku>
method parse($line, :$header = False) returns Hash
=end code

Parses a C<Str> or C<Buf> in accordance with the options set in C<new>. Set the
C<binary> flag in C<new> if you are going to pass a C<Buf>.

=head2 method reset

=begin code :lang<raku>
method reset()
=end code

Closes and re-opens the file handle provided in C<new>.

=head1 AUTHOR

tony-o L<https://github.com/tony-o/>

=head1 COPYRIGHT AND LICENSE

Copyright 2023 tony-o

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.
=end pod
