{ Since fpc 32 bits can't cope with the
  file bidirectinal-test.inc, now we parse the file
  reading each rule.

}


program Test_bidirectional;

{$mode delphi}

uses
  SysUtils,
  Math,
  bufstream,
  grapheme_types, grapheme_bidirectional,
  Test_util;

type

  bidirectional_test_type = record
    cp: array of uint_least32_t;
    cplen: size_t;
    mode: array of grapheme_bidirectional_direction;
    modelen: size_t;
    resolved: grapheme_bidirectional_direction;
    level: array of int_least8_t;
    reorder: array of int_least16_t;
    reorderlen: size_t;
  end;

var

  bidirectional_test: array[0..0] of bidirectional_test_type;


const
  SIZE_MAX = 4294967295;  // taken from libc freepascal.

  {.$I bidirectional-test.inc}
  {$I ../pascal_src/grapheme_gen_bidirectional.inc}

var
  resolved: grapheme_bidirectional_direction;
  Data: array[0..511] of uint_least32_t;
  output: array[0..511] of uint_least32_t;
  lev: array[0..511] of int_least8_t;
  target: uint_least32_t;{/* TODO iterate and get max, allocate *}
  i, num_tests, failed, datalen, levlen, outputlen, ret, j, m, ret2: size_t;
  fileName: string;


function get_mirror_offset(cp: uint_least32_t): int_least16_t;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
  begin
    exit(mirror_minor[mirror_major[cp shr 8] + (cp and $FF)]);
  end
  else
  begin
    exit(0);
  end;
end;

type
  TTokenType = (ttUnexpected, ttWord, ttOpenBracket, ttOpenSquareBracket, ttNil, ttDot, ttComma,
    ttColon, ttSemicolon, ttEqual, ttCloseBracket, ttCloseSquareBracket, ttEof,
    ttHexNumber, ttNumber);

const
  EOFMARK = -1;
  READNEXT = 0;
var
  LineCount: integer = 1;
  LastChar: integer = READNEXT;
  g_stream: TBufferedFileStream;
  g_tokensource: ansistring;

function GetNextChar: ansichar;
begin
  if g_stream.Read(Result, 1) < 1 then
  begin
    LastChar := EOFMARK;
    Result := #0;
  end
  else if Result = #$0D then
    Inc(LineCount);
end;

procedure SetLastChar(c: ansichar);
begin
  if c = #0 then
    LastChar := EOFMARK
  else
    LastChar := Ord(c);
end;

function IsIdentifierDigit(c: ansichar): boolean;
begin
  Result := ((c >= 'A') and (c <= 'Z')) or ((c >= 'a') and (c <= 'z')) or ((c >= '0') and (c <= '9')) or (c = '_');
end;

function IsHexaDecimalDigit(c: ansichar): boolean;
begin
  Result := ((c >= 'A') and (c <= 'F')) or ((c >= 'a') and (c <= 'f')) or ((c >= '0') and (c <= '9'));
end;

function IsDecimalDigit(c: ansichar): boolean;
begin
  Result := (c >= '0') and (c <= '9');
end;

function GetNextSolidToken(var aSource: ansistring): TTokenType;
var
  c: ansichar;
begin
  aSource := '';
  if LastChar = EOFMARK then
    exit(ttEof);
  if LastChar = READNEXT then
    c := GetNextChar
  else
    c := char(LastChar);
  while c <> #0 do   // skip comments, tabs, LF, CR  and spaces.
  begin
    if c = '/' then  // start //comment.
    begin
      while (c <> #0) and (c <> #$0D) do
        c := GetNextChar;
      if c <> #0 then
      begin
        if c = #$0D then
        begin
          c := GetNextChar;
          if c = #$0a then
            c := GetNextChar;
        end;
      end;
    end
    else if c = '{' then
    begin
      while (c <> #0) and (c <> '}') do
      begin
        c := GetNextChar;
      end;
      c := GetNextChar;
    end;
    if not (c in [' ', #9, #$0D, #$0A]) then
      break;
    c := GetNextChar;
  end;
  LastChar := READNEXT;
  case c of
    '(':
    begin
      aSource := '(';
      exit(ttOpenBracket);
    end;
    ')':
    begin
      aSource := ')';
      exit(ttCloseBracket);
    end;
    '[':
    begin
      aSource := '[';
      exit(ttOpenSquareBracket);
    end;
    ']':
    begin
      aSource := ']';
      exit(ttCloseSquareBracket);
    end;
    '.':
    begin
      aSource := '.';
      exit(ttDot);
    end;
    ':':
    begin
      aSource := ':';
      exit(ttColon);
    end;
    ',':
    begin
      aSource := ',';
      exit(ttComma);
    end;
    ';':
    begin
      aSource := ';';
      exit(ttSemicolon);
    end;
    '=':
    begin
      aSource := '=';
      exit(ttEqual);
    end;
    else
      if c = '$' then
      begin
        repeat
          aSource := aSource + c;
          c := GetNextChar;
        until not IsHexaDecimalDigit(c);
        SetLastChar(c);
        exit(ttHexNumber);
      end
      else if (c = '-') or IsDecimalDigit(c) then // number
      begin
        repeat
          aSource := aSource + c;
          c := GetNextChar;
        until not IsDecimalDigit(c); // -,0..9
        SetLastChar(c);
        exit(ttNumber);
      end;
      repeat
        aSource := aSource + c;
        c := GetNextChar;
      until not IsIdentifierDigit(c);  // _0..9a..zA..Z
      SetLastChar(c);
      if aSource = 'nil' then
        exit(ttNil);
      exit(ttWord);
  end;
end;

function StrToDir(AStr: string): grapheme_bidirectional_direction;
begin
  if AStr = 'GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL' then
    Result := GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL
  else if AStr = 'GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR' then
    Result := GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR
  else if AStr = 'GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL' then
    Result := GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL
  else
    Result := GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
end;

function GetDirectionArray(var AData: array of grapheme_bidirectional_direction): integer;
var
  tokentype: TTokenType;
  sourcetoken: ansistring;
  dir: grapheme_bidirectional_direction;
begin
  Result := 0;
  repeat
    tokentype := GetNextSolidToken(sourcetoken);
    dir := StrToDir(sourcetoken);
    AData[Result] := dir;
    Inc(Result);
    tokentype := GetNextSolidToken(sourcetoken);
  until tokentype <> ttComma;
end;

function GetHexIntegerArray(var AData: array of uint_least32_t): integer;
var
  tokentype: TTokenType;
  sourcetoken: ansistring;
begin
  Result := 0;
  repeat
    tokentype := GetNextSolidToken(sourcetoken);
    AData[Result] := StrToIntDef(sourcetoken, 0);
    Inc(Result);
    tokentype := GetNextSolidToken(sourcetoken);
  until tokentype <> ttComma;
end;

function GetIntegerArray(var AData: array of int_least16_t): integer; overload;
var
  tokentype: TTokenType;
  sourcetoken: ansistring;
begin
  Result := 0;
  repeat
    tokentype := GetNextSolidToken(sourcetoken);
    AData[Result] := StrToIntDef(sourcetoken, 0);
    Inc(Result);
    tokentype := GetNextSolidToken(sourcetoken);
  until tokentype <> ttComma;
end;

function GetIntegerArray(var AData: array of int_least8_t): integer; overload;
var
  tokentype: TTokenType;
  sourcetoken: ansistring;
begin
  Result := 0;
  repeat
    tokentype := GetNextSolidToken(sourcetoken);
    AData[Result] := StrToIntDef(sourcetoken, 0);
    Inc(Result);
    tokentype := GetNextSolidToken(sourcetoken);
  until tokentype <> ttComma;
end;

{ sample rule format.
bidirectional_test:array[0..582552] of bidirectional_test_type = (
  (
    cp         : [ $00202A ];
    cplen      : 1;
    mode       : [ GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL, GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR, GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL ];
    modelen    : 3;
    resolved   : GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
    level      : [ -1 ];
    reorder    : nil;          //<<<<<<<<<<<<<<<<<<<<<< or [1,2,3]
    reorderlen : 0
  ),

}

function GetNextRule: boolean;
var
  tokensource: ansistring;
  tokentype: TTokenType;
  len, l2: integer;
const
  DEFAULT_ARRAY_SIZE = 512;
begin
  Result := False;
  if GetNextSolidToken(tokensource) = ttOpenBracket then
  begin
    //cp :
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    if tokentype <> ttOpenSquareBracket then
      exit(False);

    SetLength(bidirectional_test[0].cp, DEFAULT_ARRAY_SIZE);
    len := GetHexIntegerArray(bidirectional_test[0].cp);
    {;}tokentype := GetNextSolidToken(tokensource);
    //cplen :
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    l2 := StrToIntDef(tokensource, 0);
    SetLength(bidirectional_test[0].cp, l2);
    bidirectional_test[0].cplen := l2;
    {;}tokentype := GetNextSolidToken(tokensource);
    //mode
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    if tokentype <> ttOpenSquareBracket then
      exit(False);
    SetLength(bidirectional_test[0].mode, DEFAULT_ARRAY_SIZE);
    len := GetDirectionArray(bidirectional_test[0].mode);
    {;}tokentype := GetNextSolidToken(tokensource);
    //modelen :
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    l2 := StrToIntDef(tokensource, 0);
    SetLength(bidirectional_test[0].mode, l2);
    bidirectional_test[0].modelen := l2;
    {;}tokentype := GetNextSolidToken(tokensource);
    //resolved
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    bidirectional_test[0].resolved := StrToDir(tokensource);
    {;}tokentype := GetNextSolidToken(tokensource);
    //level
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    if tokentype <> ttOpenSquareBracket then
      exit(False);
    SetLength(bidirectional_test[0].level, DEFAULT_ARRAY_SIZE);
    len := GetIntegerArray(bidirectional_test[0].level);
    SetLength(bidirectional_test[0].level, len);
    {;}tokentype := GetNextSolidToken(tokensource);
    //reorder
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    if tokentype = ttNil then
    begin
      bidirectional_test[0].reorder := nil;
    end
    else
    begin
      if tokentype <> ttOpenSquareBracket then
        exit(False);
      SetLength(bidirectional_test[0].reorder, DEFAULT_ARRAY_SIZE);
      len := GetIntegerArray(bidirectional_test[0].reorder);
      SetLength(bidirectional_test[0].reorder, len);
    end;
    {;}tokentype := GetNextSolidToken(tokensource);
    //reorderlen
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    tokentype := GetNextSolidToken(tokensource);
    l2 := StrToIntDef(tokensource, 0);
    bidirectional_test[0].reorderlen := l2;
    {)}tokentype := GetNextSolidToken(tokensource);
    if tokentype <> ttCloseBracket then
      exit(False);
    Result := True;
  end;
end;

label
err,ExitErr;

begin
  writeln('Testing, please wait...');

  g_stream := TBufferedFileStream.Create('bidirectional-test.inc', fmOpenRead);
  try

    fileName := ExtractFilename(ParamStr(0));

    datalen := length(Data);
    levlen := length(lev);
    outputlen := length(output);
    num_tests := 0;
    failed := 0;
    // skip start of file.
    while GetNextSolidToken(g_tokensource) <> ttOpenBracket do
    begin
      //  empty
    end;

    while GetNextRule do
    begin
      num_tests := num_tests + bidirectional_test[0].modelen;

      //       num_tests:=0;
      //for i := 0 to length(bidirectional_test)-1 do
      //       begin
      //  num_tests := num_tests + bidirectional_test[i].modelen;
      //end;

      i:=0;
      while i<length(bidirectional_test) do
      begin
        m:=0;
        while m<bidirectional_test[i].modelen do
        begin
          ret := grapheme_bidirectional_preprocess_paragraph(PDWord(bidirectional_test[i].cp), bidirectional_test[i].cplen,
             bidirectional_test[i].mode[m], Data, datalen, @resolved);
          ret2 := 0;

          if (ret <> bidirectional_test[i].cplen) or (ret > datalen) then
          begin
            goto err;
          end;

      {/* resolved paragraph level (if specified in the test)
       */}
          if (bidirectional_test[i].resolved <> GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL) and (resolved <> bidirectional_test[i].resolved) then
          begin
            goto err;
          end;

          {/* line levels */}
          ret := grapheme_bidirectional_get_line_embedding_levels(Data, ret, lev, levlen);

          if ret > levlen then
          begin
            goto err;
          end;

          j:=0;
          while j<ret do
          begin
            if lev[j] <> bidirectional_test[i].level[j] then
            begin
              goto err;
            end;
            Inc(j);
          end;

          {/* reordering */}
          ret2 := grapheme_bidirectional_reorder_line(PDWord(bidirectional_test[i].cp), Data, ret, output, outputlen);

          if ret2 <> bidirectional_test[i].reorderlen then
          begin
            goto err;
          end;

          j := 0;
          while j < ret2 do
          begin
            target := bidirectional_test[i].cp[bidirectional_test[i].reorder[j]];
            if (output[j] <> uint_least32_t(int_least32_t(target) + get_mirror_offset(target))) then
            begin
              goto err;
            end;
            Inc(j);
          end;

          Inc(m);
          continue;
       err: ;
          Write(Format('%s: Failed conformance test %u (mode %d) [', [argv[0], i, bidirectional_test[i].mode[m]]));
          j:=0;
          while j<bidirectional_test[i].cplen do
          begin
            Write(Format(' 0x%.4x', [bidirectional_test[i].cp[j]]));
            Inc(j);
          end;
          writeln(' ],');
          Write('    levels: got      (');
          j:=0;
          while j<ret do
          begin
            Write(Format(' %d', [int_least8_t(lev[j])]));
            Inc(j);
          end;
          writeln(' ),');
          Write('    levels: expected (');
          j:=0;
          while j<ret do
          begin
            Write(Format(' %d', [bidirectional_test[i].level[j]]));
            Inc(j);
          end;
          writeln(' ).');

          Write('    reordering: got      (');
          j:=0;
          while j<ret2 do
          begin
            Write(Format(' 0x%.4x', [output[j]]));
            Inc(j);
          end;
          writeln(' ),');
          Write('    reordering: expected (');
          j:=0;
          while j < bidirectional_test[i].reorderlen do
          begin
            Write(Format(' 0x%.4x', [bidirectional_test[i].cp[bidirectional_test[i].reorder[j]]]));
            Inc(j);
          end;
          writeln(' ).');
//writeln(Format('AT LINE %D',[LineCount]));
//goto ExitErr;
          Inc(failed);
          Inc(m);
        end;
        Inc(i);
      end;
      if GetNextSolidToken(g_tokensource) <> ttComma then
        break;
    end;
ExitErr:;
    writeln(Format('%s: %u/%u conformance tests passed.', [fileName, num_tests - failed, num_tests]));
    ExitCode := 0;
  finally
    g_stream.Free;
  end;
  writeln('Press Enter');
  readln;
end.
