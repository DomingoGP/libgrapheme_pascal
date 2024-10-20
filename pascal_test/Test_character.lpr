program Test_character;

{$mode delphi}

uses
  SysUtils,
  grapheme_types,grapheme_character,
  Test_util;

const
  SIZE_MAX = 4294967295;  // taken from libc freepascal.

  next_character_break: array[0..4] of unit_test_next_break = (
    (
    description: 'NULL input';
    input: (
    src: nil;
    srclen: 0
    );
    output: (ret: 0)
    ),
    (
    description: 'empty input';
    input: (
    src: [$0];
    srclen: 0
    );
    output: (ret: 0)
    ),
    (
      description : 'empty input, null-terminated';
      input : (
        src : [$0];
        srclen : SIZE_MAX
      );
      output: (ret:0 )
    ),
    (
      description : 'one character';
      input : (
        src   : [ $1F1E9, $1F1EA, $2A ];
        srclen : 3
      );
      output : (ret:2)
    ),
    (
      description : 'one character, null-terminated';
      input : (
       src    : [ $1F1E9, $1F1EA, $0 ];
       srclen : SIZE_MAX
      );
      output : (ret:2 );
      )
    );

  next_character_break_utf8: array[0..6] of unit_test_next_break_utf8 = (
    (
      description:'NULL input';
        input : (
        src:nil;
        srclen : 0
      );
      output : (ret:0 )
    ),
    (
    description: 'empty input';
    input: (src: ''; srclen: 0);
    output: (ret: 0)
    ),
    (
      description : 'empty input, NUL-terminated';
      input : (src:'';srclen:SIZE_MAX);
      output : (ret: 0 )
    ),
    (
      description : 'one character';
      input : (src: #$F0#$9F#$87#$A9#$F0#$9F#$87#$AA'*';
               srclen: 9 );
      output : (ret: 8 )
    ),
    (
      description : 'one character, fragment';
      input : (src: #$F0#$9F#$87#$A9#$F0#$0;
        srclen:5 );
      output : (ret:4 )
    ),
    (
      description : 'one character, NUL-terminated';
      input : ( src: #$F0#$9F#$87#$A9#$F0#$9F#$87#$AA#$0;
                 srclen: SIZE_MAX );
      output : (ret:8 )
    ),
    (
      description : 'one character, fragment, NUL-terminated';
      input : ( src: #$F0#$9F#$87#$A9#$F0#$9F#$0;
               srclen: SIZE_MAX );
      output : (ret:4 )
    )
    );

{$I character-test.inc}

var
  fileName: string;


function unit_test_callback_next_character_break(const t: Pointer; off: size_t; const Name: string;
const argv0: string): integer;
begin
  exit(unit_test_callback_next_break(t, off, grapheme_next_character_break, Name, argv0));
end;

function unit_test_callback_next_character_break_utf8(const t: Pointer; off: size_t; const Name: string;
const argv0: string): integer;
begin
  exit(unit_test_callback_next_break_utf8(t, off, grapheme_next_character_break_utf8, Name, argv0));
end;


begin
  fileName := ExtractFileName(ParamStr(0));


  ExitCode :=
    run_break_tests(grapheme_next_character_break,
                             @character_break_test[0], length(character_break_test),
                             fileName) +
    run_unit_tests(unit_test_callback_next_character_break, @next_character_break[0],
    length(next_character_break), 'grapheme_next_character_break', fileName) + run_unit_tests(
    unit_test_callback_next_character_break_utf8, @next_character_break_utf8[0],
    length(next_character_break_utf8), 'grapheme_next_character_break_utf8', fileName);

  writeln('Press Enter');
  readln;

end.
