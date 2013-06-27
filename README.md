#README CSV::Parser
 
##Synopsis
This module is pretty badass.  It reads CSV files line by line and can handle individual lines so you can handle your own file reads or you can let me do the damn work for you.  It handles binary files with relative ease so you can parse your binary 'Comma Separated Value' files like a pro.

##Options I Can Take

Pass in the following values if you feel like it:
```
  file_handle          : pass me in some file you opened with 'open'
  binary              
    default: 0
    expects: 0 or 1  
      0: not a binary file
      1: file was opened as binary and all operator/separator options
         are *REQUIRED* to be passed as Buf objects (instead of Str)
  contains_header_row
    default: 0
    expects: 0 or 1
      0: first line won't be interepreted as column names and parsed lines
         will be returned as a hash containing keys 0..X
      1: first line will be interpreted as column names
  field_separator      
    default: ','
    expects: variable length Str or Buf
      Str: use a Str when binary == 0
      Buf: use a Buf when binary == 1 or deal with errors.
  line_separator
    default: "\n"
    expects: see field_separator - this will be included in a parsed value 
             if found in an open field_operator
  field_operator
    default: '"'
    expects: see field_separator - this is the character [sequence] used
             to escape a field (can handle line_separator encapsulation)
  escape_operator
    default: '\\'
    expects: see field_separator - used to escape field_operators or bare
             values in a field
  chunk_size
    default: 1024
    expects: some number - can be increased to improve performance if you 
             are parsing some huge lined binary file.  1024 should be 
             sufficient 
```

##Methods my Bad Ass Provides

###get\_line ()
will read a line or chunk from a file and return the parsed line.  if this is the first call to this function and the ```contains_header_row``` is set then this will parse the first 2 lines and use the first row's values as the column values

###parse ( ```line``` )
will parse a Str or Buf in accordance with the options set.  set the damn ```binary``` flag if you are going to pass a Buf


