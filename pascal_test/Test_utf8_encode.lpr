program Test_utf8_encode;

{$mode delphi}

uses
  SysUtils,
  grapheme_types, grapheme_utf8;

type

  test = record
    cp:uint_least32_t; //* input codepoint */
    exp_arr:array of AnsiChar;     //* expected UTF-8 byte sequence */
    exp_len:size_t;    //* expected length of UTF-8 sequence */
  end;

const
  enc_test: array[0..5] of test = (
  (
  	//* invalid codepoint (UTF-16 surrogate half) */
  	cp : $D800;
  	exp_arr : [ #$EF, #$BF, #$BD ];
  	exp_len : 3
  ),
  (
  	//* invalid codepoint (UTF-16-unrepresentable) */
  	cp : $110000;
  	exp_arr : [ #$EF, #$BF, #$BD ];
  	exp_len : 3
  ),
  (
  	//* codepoint encoded to a 1-byte sequence */
  	cp : $01;
  	exp_arr : [ #$01 ];
  	exp_len : 1
  ),
  (
  	//* codepoint encoded to a 2-byte sequence */
  	cp : $FF;
  	exp_arr : [ #$C3, #$BF ];
  	exp_len : 2
  ),
  (
  	//* codepoint encoded to a 3-byte sequence */
  	cp : $FFF;
  	exp_arr : [ #$E0, #$BF, #$BF ];
  	exp_len : 3
  ),
  (
  	//* codepoint encoded to a 4-byte sequence */
  	cp : $FFFFF;
  	exp_arr : [ #$F3, #$BF, #$BF, #$BF ];
  	exp_len : 4
  )
  );

var
  i, j, failed, len: size_t;
  fileName: string;
  arr:array[0..3] of ansichar;

begin
  writeln('test');

  fileName := ExtractFileName(ParamStr(0));
  //* UTF-8 decoder test */
  failed := 0;

  for i := 0 to length(enc_test) - 1 do
  begin
    len := grapheme_encode_utf8(enc_test[i].cp, arr, length(arr));

    if (len <> enc_test[i].exp_len) or (not CompareMem(@arr[0], @enc_test[i].exp_arr[0], len)) then
    begin
    	write(Format('%s, Failed test %u: Expected (',[fileName, i]));
    	for j := 0 to enc_test[i].exp_len-1 do
        begin
    		write(Format('#$%x',[ Ord(enc_test[i].exp_arr[j]) ]));
    		if (j + 1) < enc_test[i].exp_len then
                begin
        		write(' ');
    		end;
    	end;
    	write('), but got (');
    	for j := 0 to len-1 do
        begin
    		write(Format('#$%x', [Ord(arr[j])]));
    		if (j + 1) < len then
                begin
    		   writeln(' ');
    		end;
    	end;
    	writeln(').');
    	Inc(failed);
    end;
  end;
  writeln(Format('%s: %u/%u unit tests passed.', [fileName, length(enc_test) + 1 - failed, length(enc_test) + 1]));


  writeln('Press Enter');
  readln;


  if failed > 0 then
    exitCode := 1
  else
    exitCode := 0;
end.

