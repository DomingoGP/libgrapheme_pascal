program Test_utf8_decode;

{$mode delphi}

uses
  SysUtils,
  grapheme_types,grapheme_utf8;

type

  test = record
    arr: array of ansichar;             //* UTF-8 byte sequence */
    len: size_t;            //* length of UTF-8 byte sequence */
    exp_len: size_t;        //* expected length returned */
    exp_cp: uint_least32_t; //* expected codepoint returned */
  end;

const
  dec_test: array[0..26] of test = (

    (
      {* empty sequence
             * [ ] ->
             * INVALID
             *}
      arr : nil;
      len : 0;
      exp_len : 0;
      exp_cp : GRAPHEME_INVALID_CODEPOINT
    ),
    (
    {* invalid lead byte
           * [ 11111101 ] ->
           * INVALID
           *}
    arr: [#$FD, #0, #0, #0];
    len: 1;
    exp_len: 1;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
    {/* valid 1-byte sequence
           * [ 00000001 ] ->
           * 0000001
           */}
    arr: [#$01, #0, #0, #0];
    len: 1;
    exp_len: 1;
    exp_cp: $1
    ),
    (
    {/* valid 2-byte sequence
           * [ 11000011 10111111 ] ->
           * 00011111111
           */}
    arr: [#$C3, #$BF, #0, #0];
    len: 2;
    exp_len: 2;
    exp_cp: $FF
    ),
    (
      {/* invalid 2-byte sequence (second byte missing)
             * [ 11000011 ] ->
             * INVALID
             */}
    arr: [#$C3, #0, #0, #0];
    len: 1;
    exp_len: 2;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 2-byte sequence (second byte malformed)
             * [ 11000011 11111111 ] ->
             * INVALID
             */}
    arr: [#$C3, #$FF, #0, #0];
    len: 2;
    exp_len: 1;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 2-byte sequence (overlong encoded)
             * [ 11000001 10111111 ] ->
             * INVALID
             */}
    arr: [#$C1, #$BF, #0, #0];
    len: 2;
    exp_len: 2;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* valid 3-byte sequence
             * [ 11100000 10111111 10111111 ] ->
             * 0000111111111111
             */}
    arr: [#$E0, #$BF, #$BF, #0];
    len: 3;
    exp_len: 3;
    exp_cp: $FFF
    ),
    (
      {/* invalid 3-byte sequence (second byte missing)
             * [ 11100000 ] ->
             * INVALID
             */}
    arr: [#$E0, #0, #0, #0];
    len: 1;
    exp_len: 3;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 3-byte sequence (second byte malformed)
             * [ 11100000 01111111 10111111 ] ->
             * INVALID
             */}
    arr: [#$E0, #$7F, #$BF, #0];
    len: 3;
    exp_len: 1;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 3-byte sequence (short string, second byte malformed)
             * [ 11100000 01111111 ] ->
             * INVALID
             */}
    arr: [#$E0, #$7F, #0, #0];
    len: 2;
    exp_len: 1;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 3-byte sequence (third byte missing)
             * [ 11100000 10111111 ] ->
             * INVALID
             */}
    arr: [#$E0, #$BF, #0, #0];
    len: 2;
    exp_len: 3;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 3-byte sequence (third byte malformed)
             * [ 11100000 10111111 01111111 ] ->
             * INVALID
             */}
    arr: [#$E0, #$BF, #$7F, #0];
    len: 3;
    exp_len: 2;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 3-byte sequence (overlong encoded)
             * [ 11100000 10011111 10111111 ] ->
             * INVALID
             */}
    arr: [#$E0, #$9F, #$BF, #0];
    len: 3;
    exp_len: 3;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 3-byte sequence (UTF-16 surrogate half)
             * [ 11101101 10100000 10000000 ] ->
             * INVALID
             */}
    arr: [#$ED, #$A0, #$80, #0];
    len: 3;
    exp_len: 3;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* valid 4-byte sequence
             * [ 11110011 10111111 10111111 10111111 ] ->
             * 011111111111111111111
             */}
    arr: [#$F3, #$BF, #$BF, #$BF];
    len: 4;
    exp_len: 4;
    exp_cp: $FFFFF
    ),
    (
      {/* invalid 4-byte sequence (second byte missing)
             * [ 11110011 ] ->
             * INVALID
             */}
    arr: [#$F3, #0, #0, #0];
    len: 1;
    exp_len: 4;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (second byte malformed)
             * [ 11110011 01111111 10111111 10111111 ] ->
             * INVALID
             */}
    arr: [#$F3, #$7F, #$BF, #$BF];
    len: 4;
    exp_len: 1;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (short string 1, second byte
             * malformed) [ 11110011 011111111 ] -> INVALID
             */}
    arr: [#$F3, #$7F, #0, #0];
    len: 2;
    exp_len: 1;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (short string 2, second byte
             * malformed) [ 11110011 011111111 10111111 ] -> INVALID
             */}
    arr: [#$F3, #$7F, #$BF, #0];
    len: 3;
    exp_len: 1;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (third byte missing)
             * [ 11110011 10111111 ] ->
             * INVALID
             */}
    arr: [#$F3, #$BF, #0, #0];
    len: 2;
    exp_len: 4;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (third byte malformed)
             * [ 11110011 10111111 01111111 10111111 ] ->
             * INVALID
             */}
    arr: [#$F3, #$BF, #$7F, #$BF];
    len: 4;
    exp_len: 2;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (short string, third byte malformed)
             * [ 11110011 10111111 01111111 ] ->
             * INVALID
             */}
    arr: [#$F3, #$BF, #$7F, #0];
    len: 3;
    exp_len: 2;
    exp_cp: GRAPHEME_INVALID_CODEPOINT;
    ),
    (
      {/* invalid 4-byte sequence (fourth byte missing)
             * [ 11110011 10111111 10111111 ] ->
             * INVALID
             */}
    arr: [#$F3, #$BF, #$BF, #0];
    len: 3;
    exp_len: 4;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (fourth byte malformed)
             * [ 11110011 10111111 10111111 01111111 ] ->
             * INVALID
             */}
    arr: [#$F3, #$BF, #$BF, #$7F];
    len: 4;
    exp_len: 3;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (overlong encoded)
             * [ 11110000 10000000 10000001 10111111 ] ->
             * INVALID
             */}
    arr: [#$F0, #$80, #$81, #$BF];
    len: 4;
    exp_len: 4;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    ),
    (
      {/* invalid 4-byte sequence (UTF-16-unrepresentable)
             * [ 11110100 10010000 10000000 10000000 ] ->
             * INVALID
             */}
    arr: [#$F4, #$90, #$80, #$80];
    len: 4;
    exp_len: 4;
    exp_cp: GRAPHEME_INVALID_CODEPOINT
    )
    );

var
  i, failed, len: size_t;
  cp: uint_least32_t;
  fileName: string;

begin
  writeln('test');

  fileName := ExtractFileName(ParamStr(0));
  //* UTF-8 decoder test */
  failed := 0;

  for i := 0 to length(dec_test) - 1 do
  begin

    len := grapheme_decode_utf8(PChar(dec_test[i].arr), dec_test[i].len, @cp);

    if (len <> dec_test[i].exp_len) or (cp <> dec_test[i].exp_cp) then
    begin
      writeln(Format('%s: Failed test %u: Expected (%x,%u), but got (%x,%u).', [fileName, i, dec_test[i].exp_len, dec_test[i].exp_cp, len, cp]));
      Inc(failed);
    end;
  end;
  writeln(Format('%s: %u/%u unit tests passed.', [fileName, length(dec_test) + 1 - failed, length(dec_test) + 1]));


  writeln('Press Enter');
  readln;


  if failed > 0 then
    exitCode := 1
  else
    exitCode := 0;
end.
