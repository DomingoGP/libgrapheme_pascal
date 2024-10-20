program Test_case;

{$mode delphi}

uses
  SysUtils,
  Math,
  grapheme_types,grapheme_case,
  Test_util;

const
  SIZE_MAX = 4294967295;  // taken from libc freepascal.

type

  tinput1 = record
    src: pansichar;
    srclen: size_t;
  end;

  tinput2 = record
    src: pansichar;
    srclen: size_t;
    destlen: size_t;
  end;

  toutput1 = record
    ret: boolean;
    caselen: size_t;
  end;

  toutput2 = record
    dest:pansichar;
    ret: size_t;
  end;

  Punit_test_is_case_utf8=^unit_test_is_case_utf8;
  unit_test_is_case_utf8 = record
	description:string;
	input:tinput1;
	output:toutput1;
  end;

  Punit_test_to_case_utf8=^unit_test_to_case_utf8;
  unit_test_to_case_utf8 = record
	description:string;
	input:tinput2;
	output:toutput2;
  end;



const
  is_lowercase_utf8: array[0..10] of unit_test_is_case_utf8 = (
  (
  	description : 'empty input';
  	input : ( src: '';srclen: 0 );
  	output : ( ret:true; caselen: 0 );
  ),
  (
  	description : 'one character, violation';
  	input : ( src:'A';srclen: 1 );
  	output : ( ret:false; caselen: 0 )
  ),
  (
  	description : 'one character, confirmation';
  	input : ( src:#$C3#$9F;srclen: 2 );
  	output : ( ret:true; caselen: 2 )
  ),
  (
  	description : 'one character, violation, NUL-terminated';
  	input : ( src:'A';srclen: SIZE_MAX );
  	output : ( ret:false; caselen: 0 )
  ),
  (
  	description : 'one character, confirmation, NUL-terminated';
  	input : ( src:#$C3#$9F;srclen: SIZE_MAX );
  	output : ( ret:true; caselen: 2 )
  ),
  (
  	description : 'one word, violation';
  	input : ( src:'Hello';srclen: 5 );
  	output : ( ret:false; caselen: 0 )
  ),
  (
  	description : 'one word, partial confirmation';
  	input : (src: 'gru'#$C3#$9F'fOrmel';srclen:
                     11 );
  	output : ( ret:false; caselen: 6 )
  ),
  (
  	description : 'one word, full confirmation';
  	input : ( src:'gru'#$C3#$9F'formel';srclen:
                     11 );
  	output : ( ret:true; caselen: 11 )
  ),
  (
  	description : 'one word, violation, NUL-terminated';
  	input : ( src:'Hello';srclen: SIZE_MAX );
  	output : ( ret:false; caselen: 0 )
  ),
  (
  	description : 'one word, partial confirmation, NUL-terminated';
  	input : ( src:'gru'#$C3#$9F'fOrmel';srclen:
                     SIZE_MAX );
  	output : ( ret:false; caselen: 6 )
  ),
  (
  	description : 'one word, full confirmation, NUL-terminated';
  	input : ( src:'gru'#$C3#$9F'formel';srclen:
                     SIZE_MAX );
  	output : ( ret:true; caselen: 11 )
  )
);


  is_uppercase_utf8: array[0..10] of unit_test_is_case_utf8 = (

  	(
  		description : 'empty input';
  		input : ( src:'';srclen: 0 );
  		output : ( ret: true; caselen: 0 )
  	),
  	(
  		description : 'one character, violation';
  		input : ( src:#$C3#$9F;srclen: 2 );
  		output : ( ret: false; caselen: 0 )
  	),
  	(
  		description : 'one character, confirmation';
  		input : ( src:'A';srclen: 1 );
  		output : ( ret: true; caselen: 1 )
  	),
  	(
  		description : 'one character, violation, NUL-terminated';
  		input : ( src:#$C3#$9F;srclen: SIZE_MAX );
  		output : ( ret: false; caselen: 0 )
        ),
  	(
  		description : 'one character, confirmation, NUL-terminated';
  		input : ( src:'A';srclen: SIZE_MAX );
  		output : ( ret: true; caselen: 1 )
  	),
  	(
  		description : 'one word, violation';
  		input : ( src:'hello';srclen: 5 );
  		output : ( ret: false; caselen: 0 )
  	),
  	(
  		description : 'one word, partial confirmation';
  		input : ( src:'GRU'#$C3#$9F'formel';srclen: 11 );
  		output : ( ret: false; caselen: 3 )
  	),
  	(
  		description : 'one word, full confirmation';
  		input : ( src:'HELLO';srclen: 5 );
  		output : ( ret: true; caselen: 5 )
  	),
  	(
  		description : 'one word, violation, NUL-terminated';
  		input : ( src:'hello';srclen: SIZE_MAX );
  		output : ( ret: false; caselen: 0 )
  	),
  	(
  		description : 'one word, partial confirmation, NUL-terminated';
  		input : ( src:'GRU'#$C3#$9F'formel';srclen: SIZE_MAX );
  		output : ( ret: false; caselen: 3 )
  	),
  	(
  		description : 'one word, full confirmation, NUL-terminated';
  		input : ( src:'HELLO';srclen: SIZE_MAX );
  		output : ( ret: true; caselen: 5 )
  	)
  );

 is_titlecase_utf8:array [0..14] of unit_test_is_case_utf8 = (
  	(
  		description : 'empty input';
  		input : ( src:'';srclen: 0 );
  		output : ( ret: true; caselen: 0 )
  	),
  	(
  		description : 'one character, violation';
  		input : ( src:#$C3#$9F;srclen: 2 );
  		output : ( ret: false; caselen: 0 )
  	),
  	(
  		description : 'one character, confirmation';
  		input : ( src:'A';srclen: 1 );
  		output : ( ret: true; caselen: 1 )
  	),
  	(
  		description : 'one character, violation, NUL-terminated';
  		input : ( src:#$C3#$9F;srclen: SIZE_MAX );
  		output : ( ret: false; caselen: 0 )
  	),
  	(
  		description : 'one character, confirmation, NUL-terminated';
  		input : ( src:'A';srclen: SIZE_MAX );
  		output : ( ret: true; caselen: 1 )
  	),
  	(
  		description : 'one word, violation';
  		input : ( src:'hello';srclen: 5 );
  		output : ( ret: false; caselen: 0 )
  	),
  	(
  		description : 'one word, partial confirmation';
  		input : ( src:'Gru'#$C3#$9F'fOrmel';srclen: 11 );
  		output : ( ret: false; caselen: 6 )
  	),
  	(
  		description : 'one word, full confirmation';
  		input : ( src:'Gru'#$C3#$9F'formel';srclen: 11 );
  		output : ( ret: true; caselen: 11 )
  	),
  	(
  		description : 'one word, violation, NUL-terminated';
  		input : ( src:'hello';srclen: SIZE_MAX );
  		output : ( ret: false; caselen: 0 )
  	),
  	(
  		description : 'one word, partial confirmation, NUL-terminated';
  		input : ( src:'Gru'#$C3#$9F'fOrmel';srclen: SIZE_MAX );
  		output : ( ret: false; caselen: 6 )
  	),
  	(
  		description : 'one word, full confirmation, NUL-terminated';
  		input : ( src:'Gru'#$C3#$9F'formel';srclen: SIZE_MAX );
  		output : ( ret: true; caselen: 11 )
  	),
  	(
  		description : 'multiple words, partial confirmation';
  		input : ( src:'Hello Gru'#$C3#$9F'fOrmel!';srclen: 18 );
  		output : ( ret: false; caselen: 12 )
  	),
  	(
  		description : 'multiple words, full confirmation';
  		input : ( src:'Hello Gru'#$C3#$9F'formel!';srclen: 18 );
  		output : ( ret: true; caselen: 18 )
  	),
  	(
  		description :
  			'multiple words, partial confirmation, NUL-terminated';
  		input : ( src:'Hello Gru'#$C3#$9F'fOrmel!';srclen: SIZE_MAX );
  		output : ( ret: false; caselen: 12 )
  	),
  	(
  		description :
  			'multiple words, full confirmation, NUL-terminated';
  		input : ( src:'Hello Gru'#$C3#$9F'formel!';srclen: SIZE_MAX );
  		output : ( ret: true; caselen: 18 )
  	)
  );

 to_lowercase_utf8:array[0..13] of unit_test_to_case_utf8 = (
  	(
  		description : 'empty input';
  		input : ( src:'';srclen: 0;destlen:10 );
  		output : ( dest:'';ret: 0 )
  	),
  	(
  		description : 'empty output';
  		input : ( src:'hello';srclen: 5;destlen: 0 );
  		output : ( dest:'';ret: 5 )
  	),
  	(
  		description : 'one character, conversion';
  		input : ( src:'A';srclen: 1;destlen: 10 );
  		output : ( dest:'a';ret: 1 )
  	),
  	(
  		description : 'one character, no conversion';
  		input : ( src:#$C3#$9F;srclen: 2;destlen: 10 );
  		output : ( dest:#$C3#$9F;ret: 2 )
  	),
  	(
  		description : 'one character, conversion, truncation';
  		input : ( src:'A';srclen: 1;destlen: 0 );
  		output : ( dest:'';ret: 1 )
  	),
  	(
  		description : 'one character, conversion, NUL-terminated';
  		input : ( src:'A';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'a';ret: 1 )
  	),
  	(
  		description : 'one character, no conversion, NUL-terminated';
  		input : ( src:#$C3#$9F;srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:#$C3#$9F;ret: 2 )
  	),
  	(
  		description :
  			'one character, conversion, NUL-terminated, truncation';
  		input : ( src:'A';srclen: SIZE_MAX;destlen: 0 );
  		output : ( dest:'';ret: 1 )
  	),
  	(
  		description : 'one word, conversion';
  		input : ( src:'wOrD';srclen: 4;destlen: 10 );
  		output : ( dest:'word';ret: 4 )
  	),
  	(
  		description : 'one word, no conversion';
  		input : ( src:'word';srclen: 4;destlen: 10 );
  		output : ( dest:'word';ret: 4 )
  	),
  	(
  		description : 'one word, conversion, truncation';
  		input : ( src:'wOrD';srclen: 4;destlen: 3 );
  		output : ( dest:'wo';ret: 4 )
  	),
  	(
  		description : 'one word, conversion, NUL-terminated';
  		input : ( src:'wOrD';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'word';ret: 4 )
  	),
  	(
  		description : 'one word, no conversion, NUL-terminated';
  		input : ( src:'word';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'word';ret: 4 )
  	),
  	(
  		description :
  			'one word, conversion, NUL-terminated, truncation';
  		input : ( src:'wOrD';srclen: SIZE_MAX;destlen: 3 );
  		output : ( dest:'wo';ret: 4 )
  	)
  );

 to_uppercase_utf8:array [0..13] of unit_test_to_case_utf8 = (
  	(
  		description : 'empty input';
  		input : ( src:'';srclen: 0;destlen: 10 );
  		output : ( dest:'';ret: 0 )
  	),
  	(
  		description : 'empty output';
  		input : ( src:'hello';srclen: 5;destlen: 0 );
  		output : ( dest:'';ret: 5 )
  	),
  	(
  		description : 'one character, conversion';
  		input : ( src:#$C3#$9F;srclen: 2;destlen: 10 );
  		output : ( dest:'SS';ret: 2 )
  	),
  	(
  		description : 'one character, no conversion';
  		input : ( src:'A';srclen: 1;destlen: 10 );
  		output : ( dest:'A';ret: 1 )
  	),
  	(
  		description : 'one character, conversion, truncation';
  		input : ( src:#$C3#$9F;srclen: 2;destlen: 0 );
  		output : ( dest:'';ret: 2 )
  	),
  	(
  		description : 'one character, conversion, NUL-terminated';
  		input : ( src:#$C3#$9F;srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'SS';ret: 2 )
  	),
  	(
  		description : 'one character, no conversion, NUL-terminated';
  		input : ( src:'A';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'A';ret: 1 )
  	),
  	(
  		description :
  			'one character, conversion, NUL-terminated, truncation';
  		input : ( src:#$C3#$9F;srclen: SIZE_MAX;destlen: 0 );
  		output : ( dest:'';ret: 2 )
  	),
  	(
  		description : 'one word, conversion';
  		input : ( src:'gRu'#$C3#$9F'fOrMel';srclen: 11;destlen: 15 );
  		output : ( dest:'GRUSSFORMEL';ret: 11 )
  	),
  	(
  		description : 'one word, no conversion';
  		input : ( src:'WORD';srclen: 4;destlen: 10 );
  		output : ( dest:'WORD';ret: 4 )
  	),
  	(
  		description : 'one word, conversion, truncation';
  		input : ( src:'gRu'#$C3#$9F'formel';srclen: 11;destlen: 5 );
  		output : ( dest:'GRUS';ret: 11 )
  	),
  	(
  		description : 'one word, conversion, NUL-terminated';
  		input : ( src:'gRu'#$C3#$9F'formel';srclen: SIZE_MAX;destlen: 15 );
  		output : ( dest:'GRUSSFORMEL';ret: 11 )
  	),
  	(
  		description : 'one word, no conversion, NUL-terminated';
  		input : ( src:'WORD';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'WORD';ret: 4 )
  	),
  	(
  		description :
  			'one word, conversion, NUL-terminated, truncation';
  		input : ( src:'gRu'#$C3#$9F'formel';srclen: SIZE_MAX;destlen: 5 );
  		output : ( dest:'GRUS';ret: 11 )
  	)
  );

 to_titlecase_utf8:array[0..19] of unit_test_to_case_utf8 = (
  	(
  		description : 'empty input';
  		input : ( src:'';srclen: 0;destlen: 10 );
  		output : ( dest:'';ret: 0 )
  	),
  	(
  		description : 'empty output';
  		input : ( src:'hello';srclen: 5;destlen: 0 );
  		output : ( dest:'';ret: 5 )
  	),
  	(
  		description : 'one character, conversion';
  		input : ( src:'a';srclen: 1;destlen: 10 );
  		output : ( dest:'A';ret: 1 )
  	),
  	(
  		description : 'one character, no conversion';
  		input : ( src:'A';srclen: 1;destlen: 10 );
  		output : ( dest:'A';ret: 1 )
  	),
  	(
  		description : 'one character, conversion, truncation';
  		input : ( src:'a';srclen: 1;destlen: 0 );
  		output : ( dest:'';ret: 1 )
  	),
  	(
  		description : 'one character, conversion, NUL-terminated';
  		input : ( src:'a';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'A';ret: 1 )
  	),
  	(
  		description : 'one character, no conversion, NUL-terminated';
  		input : ( src:'A';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'A';ret: 1 )
  	),
  	(
  		description :  'one character, conversion, NUL-terminated, truncation';
  		input : ( src:'a';srclen: SIZE_MAX;destlen: 0 );
  		output : ( dest:'';ret: 1 )
  	),
  	(
  		description : 'one word, conversion';
  		input : ( src:'heLlo';srclen: 5;destlen: 10 );
  		output : ( dest:'Hello';ret: 5 )
  	),
  	(
  		description : 'one word, no conversion';
  		input : ( src:'Hello';srclen: 5;destlen: 10 );
  		output : ( dest:'Hello';ret: 5 )
  	),
  	(
  		description : 'one word, conversion, truncation';
  		input : ( src:'heLlo';srclen: 5;destlen: 2 );
  		output : ( dest:'H';ret: 5 )
  	),
  	(
  		description : 'one word, conversion, NUL-terminated';
  		input : ( src:'heLlo';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'Hello';ret: 5 )
  	),
  	(
  		description : 'one word, no conversion, NUL-terminated';
  		input : ( src:'Hello';srclen: SIZE_MAX;destlen: 10 );
  		output : ( dest:'Hello';ret: 5 )
  	),
  	(
  		description :
  			'one word, conversion, NUL-terminated, truncation';
  		input : ( src:'heLlo';srclen: SIZE_MAX;destlen: 3 );
  		output : ( dest:'He';ret: 5 )
  	),
  	(
  		description : 'two words, conversion';
  		input : ( src:'heLlo wORLd!';srclen: 12;destlen: 20 );
  		output : ( dest:'Hello World!';ret: 12 )
  	),
  	(
  		description : 'two words, no conversion';
  		input : ( src:'Hello World!';srclen: 12;destlen: 20 );
  		output : ( dest:'Hello World!';ret: 12 )
  	),
  	(
  		description : 'two words, conversion, truncation';
  		input : ( src:'heLlo wORLd!';srclen: 12;destlen: 8 );
  		output : ( dest:'Hello W';ret: 12 )
  	),
  	(
  		description : 'two words, conversion, NUL-terminated';
  		input : ( src:'heLlo wORLd!';srclen: SIZE_MAX;destlen: 20 );
  		output : ( dest:'Hello World!';ret: 12 )
  	),
  	(
  		description : 'two words, no conversion, NUL-terminated';
  		input : ( src:'Hello World!';srclen: SIZE_MAX;destlen: 20 );
  		output : ( dest:'Hello World!';ret: 12 )
  	),
  	(
  		description :
  			'two words, conversion, NUL-terminated, truncation';
  		input : ( src:'heLlo wORLd!';srclen: SIZE_MAX;destlen: 4 );
  		output : ( dest:'Hel';ret: 12 )
  	)
  );


var
  filengthame: string;

function b2s(Value:boolean):string;
begin
  if Value then
    result:='true'
  else
    result:='false';

end;

function unit_test_callback_is_case_utf8(const t: Pointer; off: size_t; const Name: string; const argv0: string): integer;
var
	test :Punit_test_is_case_utf8;
	ret:boolean;
	caselen:size_t;
label
  err;
begin
      test :=Punit_test_is_case_utf8(t);
      Inc(test,off);
      ret := false;
      caselen := $7f;

        if t = @is_lowercase_utf8[0] then
        begin
	  ret := grapheme_is_lowercase_utf8(test^.input.src, test^.input.srclen, @caselen);
	end
        else if t = @is_uppercase_utf8[0] then
        begin
	  ret := grapheme_is_uppercase_utf8(test^.input.src, test^.input.srclen, @caselen);
	end else if t = @is_titlecase_utf8[0] then
        begin
          ret := grapheme_is_titlecase_utf8(test^.input.src, test^.input.srclen, @caselen);
	end else
        begin
		goto err;
	end;
	{/* check results */}
	if (ret <> test^.output.ret) or (caselen <> test^.output.caselen)  then
        begin
		goto err;
	end;
	exit(0);
err:;
	writeln(Format('%s: %s: Failed unit test %u "%s" (returned (%s, %u) instead of (%s, %u)).',
	        [argv0, name, off, test^.description,b2s(ret),
	        caselen, b2s(test^.output.ret),
	        test^.output.caselen]));
	exit( 1);
end;

var
	buf:array[0..511] of ansichar;


function unit_test_callback_to_case_utf8(const t: Pointer; off: size_t; const Name: string; const argv0: string): integer;
var
	test :Punit_test_to_case_utf8;
	ret,i:size_t;
//	buf:array[0..511] of ansichar;
label
  err;
begin
        test := Punit_test_to_case_utf8(t);
        Inc(test, off);
        ret:=0;
	{/* fill the array with canary values */}
        fillchar(buf,length(buf),$7f);

	if t = @to_lowercase_utf8[0] then
        begin
		ret := grapheme_to_lowercase_utf8(test^.input.src,
		                                 test^.input.srclen, buf,
		                                 test^.input.destlen);
	end
        else if t = @to_uppercase_utf8[0] then
        begin
		ret := grapheme_to_uppercase_utf8(test^.input.src,
		                                 test^.input.srclen, buf,
		                                 test^.input.destlen);
	end
        else if t = @to_titlecase_utf8[0] then
        begin
		ret := grapheme_to_titlecase_utf8(test^.input.src,
		                                 test^.input.srclen, buf,
		                                 test^.input.destlen);
	end
        else
        begin
		goto err;
	end;

	{/* check results */}
	if (ret <> test^.output.ret) or (not CompareMem(@buf[0], test^.output.dest,
	           min(test^.input.destlen, test^.output.ret) ) ) then
        begin
		goto err;
	end;

	{/* check that none of the canary values have been overwritten */}
	for i := test^.input.destlen to  length(buf)-1 do
        begin
		if Ord(buf[i]) <> $7f then
                begin
			goto err;
		end;
	end;

	exit(0);
err:;
	writeln(Format(
	        '%s: %s: Failed unit test %u "%s" (returned ("%.*s", %u) instead of ("%.*s", %u)).',
	        [argv0, name, off, test^.description, integer(ret), buf, ret,
	        integer(test^.output.ret), test^.output.dest, test^.output.ret]));
	exit( 1);
end;


begin
  filengthame := ExtractFilename(ParamStr(0));

  ExitCode :=
          run_unit_tests(unit_test_callback_is_case_utf8,
                        @is_lowercase_utf8[0], length(is_lowercase_utf8),
                        'grapheme_is_lowercase_utf8', filengthame) +
         run_unit_tests(unit_test_callback_is_case_utf8,
                        @is_uppercase_utf8[0], length(is_uppercase_utf8),
                        'grapheme_is_uppercase_utf8', filengthame) +
         run_unit_tests(unit_test_callback_is_case_utf8,
                        @is_titlecase_utf8[0], length(is_titlecase_utf8),
                        'grapheme_is_titlecase_utf8', filengthame) +
         run_unit_tests(unit_test_callback_to_case_utf8,
                        @to_lowercase_utf8[0], length(to_lowercase_utf8),
                        'grapheme_to_lowercase_utf8', filengthame) +
         run_unit_tests(unit_test_callback_to_case_utf8,
                        @to_uppercase_utf8[0], length(to_uppercase_utf8),
                        'grapheme_to_uppercase_utf8', filengthame) +
         run_unit_tests(unit_test_callback_to_case_utf8,
                        @to_titlecase_utf8[0], length(to_titlecase_utf8),
                        'grapheme_to_titlecase_utf8', filengthame);

  writeln('Press Enter');
  readln;

end.

