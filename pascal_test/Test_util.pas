unit Test_util;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, grapheme_types;

type
  pbreak_test = ^break_test;

  break_test = record
    //cp:puint_least32_t;
    cp: array of uint_least32_t;
    cplen: size_t;
    //len:psize_t;
    len: array of size_t;
    lenlen: size_t;
    descr: string;
  end;

  tinput = record
    //src: puint_least32_t;
    src: array of uint_least32_t;
    srclen: size_t;
  end;

  tinput_utf8 = record
    src: pansichar;
    srclen: size_t;
  end;

  toutput = record
    ret: size_t;
  end;

  punit_test_next_break = ^unit_test_next_break;

  unit_test_next_break = record
    description: string;
    input: tinput;
    output: toutput;
  end;

  punit_test_next_break_utf8 = ^unit_test_next_break_utf8;

  unit_test_next_break_utf8 = record
    description: string;
    input: tinput_utf8;
    output: toutput;
  end;

  func_next_break = function(const p1: puint_least32_t; p2: size_t): size_t; cdecl;
  func_next_break_utf8 = function(const p1: pansichar; p2: size_t): size_t; cdecl;

  func_unit_test_callback = function(const p1: Pointer; p2: size_t; const p3: string; const p4: string): integer;

function run_break_tests(next_break: func_next_break; const test: pbreak_test; testlen: size_t; argv0: string): integer;
function run_unit_tests(unit_test_callback: func_unit_test_callback; const test: Pointer; testlen: size_t; const Name: string;
  const argv0: string): integer;
function unit_test_callback_next_break(const t: punit_test_next_break; off: size_t; next_break: func_next_break;
  const Name: string; const argv0: string): integer;
function unit_test_callback_next_break_utf8(const t: punit_test_next_break_utf8; off: size_t; next_break_utf8: func_next_break_utf8;
  const Name: string; const argv0: string): integer;


implementation


function run_break_tests(next_break: func_next_break; const test: pbreak_test; testlen: size_t; argv0: string): integer;
var
  i, j, off, res, failed: size_t;
begin
  //* character break test */
  failed := 0;
  for i := 0 to testlen - 1 do
  begin
    off := 0;
    j := 0;
    while off < test[i].cplen do
    begin
      res := next_break(puint_least32_t(@test[i].cp[0]) + off, test[i].cplen - off);

      //* check if our resulting offset matches */
      //  if (j == test[i].lenlen || res != test[i].len[j++]) {   note j++ side effects.
      if (j = test[i].lenlen) or (res <> test[i].len[j]) then
      begin
        if j <> test[i].lenlen then
          Inc(j);
        writeln(Format('%s: Failed conformance test %u "%s".', [argv0, i, test[i].descr]));
        writeln(Format('J=%u: EXPECTED len %u, got %u', [j - 1, test[i].len[j - 1], res]));
        Inc(failed);
        break;
      end
      else
      begin
        if j <> test[i].lenlen then
          Inc(j);
      end;
      off := off + res;
    end;
  end;
  writeln(Format('%s: %u/%u conformance tests passed.', [argv0, testlen - failed, testlen]));
  exit(byte(failed > 0));
end;

function run_unit_tests(unit_test_callback: func_unit_test_callback; const test: Pointer; testlen: size_t; const Name: string; const argv0: string): integer;
var
  i, failed: size_t;
begin
  failed := 0;
  for i := 0 to testlen - 1 do
  begin
    if unit_test_callback(test, i, Name, argv0) <> 0 then
      Inc(failed);
  end;
  writeln(Format('%s: %s: %u/%u unit tests passed.', [argv0, Name, testlen - failed, testlen]));
  exit(byte(failed > 0));
end;

function unit_test_callback_next_break(const t: punit_test_next_break; off: size_t; next_break: func_next_break;
  const Name: string; const argv0: string): integer;
var
  test: punit_test_next_break;
  ret: size_t;
label
  err;
begin
  test := t + off;
  ret := next_break(puint_least32_t(test^.input.src), test^.input.srclen);
  if (ret <> test^.output.ret) then
    goto err;
  exit(0);
err: ;
  writeln(Format('%s: %s: Failed unit test %u "%s" (returned %u instead of %u).', [argv0, Name, off, test^.description, ret, test^.output.ret]));
  exit(1);
end;

function unit_test_callback_next_break_utf8(const t: punit_test_next_break_utf8; off: size_t; next_break_utf8: func_next_break_utf8;
  const Name: string; const argv0: string): integer;
var
  test: punit_test_next_break_utf8;
  ret: size_t;
label
  err;
begin
  test := t + off;
  ret := next_break_utf8(test^.input.src, test^.input.srclen);
  if ret <> test^.output.ret then
    goto err;
  exit(0);
err: ;
  writeln(Format('%s: %s: Failed unit test %u "%s" (returned %u instead of %u).', [argv0, Name, off, test^.description, ret, test^.output.ret]));
  exit(1);
end;

end.
