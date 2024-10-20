program Test_line;

{$mode delphi}

uses
  SysUtils,
  grapheme_types,grapheme_line,
  Test_util;

const
  SIZE_MAX = 4294967295;  // taken from libc freepascal.


  {$I line-test.inc}


const
  next_line_break: array[0..4] of unit_test_next_break = (
  (
  	description : 'NULL input';
  	input : (
  		src    : nil;
  		srclen : 0
        );
  	output : (ret: 0 )
  ),
  (
  	description : 'empty input';
  	input : (
  		src    : [ $0 ];
  		srclen : 0
  	);
  	output : (ret: 0 )
  ),
  (
  	description : 'empty input, null-terminated';
  	input : (
  		src    : [ $0 ];
  		srclen : SIZE_MAX
  	);
  	output : (ret: 0 )
  ),
  (
  	description : 'one opportunity';
  	input : (
  		src    : [ $1F1E9, $1F1EA, $20, $2A ];
  		srclen : 4
  	);
  	output : (ret: 3 )
  ),
  (
  	description : 'one opportunity, null-terminated';
  	input : (
  		src    : [ $1F1E9, $1F1EA, $20, $2A, $0 ];
  		srclen : SIZE_MAX
  	);
  	output : (ret: 3 )
  )
);

  next_line_break_utf8: array[0..6] of unit_test_next_break_utf8 = (
  (
  	description : 'NULL input';
  	input : (
  		src    : nil;
  		srclen : 0
  	);
  	output : ( ret:0 )
  ),
  (
  	description : 'empty input';
  	input : (
          src:'';
          srclen: 0 );
  	output : (ret: 0 )
  ),
  (
  	description : 'empty input, NUL-terminated';
  	input : (
          src:'';
          srclen: SIZE_MAX );
  	output : (ret: 0 )
  ),
  (
  	description : 'one opportunity';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0#$9F#$87#$AA' *';
          srclen: 10 );
  	output : ( ret:9 )
  ),
  (
  	description : 'one opportunity, fragment';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0;
          srclen: 5 );
  	output : ( ret:4 )
  ),
  (
  	description : 'one opportunity, NUL-terminated';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0#$9F#$87#$AA' A';
          srclen: SIZE_MAX );
  	output : ( ret:9 )
  ),
  (
  	description : 'one opportunity, fragment, NUL-terminated';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0#$9F;
          srclen: SIZE_MAX );
  	output : ( ret:4 )
  )
);

var
  fileName: string;

function unit_test_callback_next_line_break(const t: Pointer; off: size_t; const Name: string; const argv0: string): integer;
begin
  exit(unit_test_callback_next_break(t, off, grapheme_next_line_break, Name, argv0));
end;

function unit_test_callback_next_line_break_utf8(const t: Pointer; off: size_t; const Name: string; const argv0: string): integer;
begin
  exit(unit_test_callback_next_break_utf8(t, off, grapheme_next_line_break_utf8, Name, argv0));
end;

begin
  fileName := ExtractFileName(ParamStr(0));

  ExitCode :=
    run_break_tests(grapheme_next_line_break, @line_break_test[0], length(line_break_test), fileName) +
    run_unit_tests(unit_test_callback_next_line_break, @next_line_break[0], length(next_line_break),
        'grapheme_next_line_break', fileName) +
    run_unit_tests(unit_test_callback_next_line_break_utf8,
        @next_line_break_utf8[0], length(next_line_break_utf8), 'grapheme_next_line_break_utf8', fileName);

  writeln('Press Enter');
  readln;

end.

