program Test_sentence;

{$mode delphi}

uses
  SysUtils,
  grapheme_types, grapheme_sentence,
  Test_util;

const
  SIZE_MAX = 4294967295;  // taken from libc freepascal.


  {$I sentence-test.inc}


const
  next_sentence_break: array[0..4] of unit_test_next_break = (
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
  		src    : [ $0 ];
  		srclen : 0
  	);
  	output : ( ret:0 )
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
  	description : 'one sentence';
  	input : (
  	   src    : [ $1F1E9, $1F1EA, $2E, $20, $2A ];
  	   srclen : 5
  	);
  	output : ( ret:4 )
  ),
  (
  	description : 'one sentence, null-terminated';
  	input : (
  		src    : [ $1F1E9, $1F1EA, $2E, $20, $2A, $0 ];
  		srclen : SIZE_MAX
  	);
  	output : ( ret:4 )
  )
);

  next_sentence_break_utf8: array[0..6] of unit_test_next_break_utf8 = (
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
          src:'';
          srclen:0 );
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
  	description : 'one sentence';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0#$9F#$87#$AA' is the flag of Germany.  It';
          srclen: 36 );
  	output : (ret: 34 )
  ),
  (
  	description : 'one sentence, fragment';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0;
          srclen:  5
        );
  	output : ( ret:4 )
  ),
  (
  	description : 'one sentence, NUL-terminated';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0#$9F#$87#$AA' is the flag of Germany.  It';
          srclen: SIZE_MAX );
  	output : ( ret: 34 )
  ),
  (
  	description : 'one sentence, fragment, NUL-terminated';
  	input : (
          src: #$F0#$9F#$87#$A9#$F0#$9F;
          srclen: SIZE_MAX );
        output : (ret: 6 )
  )
);

var
  fileName: string;

function unit_test_callback_next_sentence_break(const t: Pointer; off: size_t; const Name: string; const argv0: string): integer;
begin
  exit(unit_test_callback_next_break(t, off, grapheme_next_sentence_break, Name, argv0));
end;

function unit_test_callback_next_sentence_break_utf8(const t: Pointer; off: size_t; const Name: string; const argv0: string): integer;
begin
  exit(unit_test_callback_next_break_utf8(t, off, grapheme_next_sentence_break_utf8, Name, argv0));
end;

begin
  fileName := ExtractFileName(ParamStr(0));

  ExitCode :=
    run_break_tests(grapheme_next_sentence_break, @sentence_break_test[0], length(sentence_break_test), fileName) +
    run_unit_tests(unit_test_callback_next_sentence_break, @next_sentence_break[0], length(next_sentence_break),
        'grapheme_next_sentence_break', fileName) +
    run_unit_tests(unit_test_callback_next_sentence_break_utf8,
        @next_sentence_break_utf8[0], length(next_sentence_break_utf8), 'grapheme_next_sentence_break_utf8', fileName);

  writeln('Press Enter');
  readln;

end.

