unit grapheme_utf8;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils, grapheme_types;

function grapheme_decode_utf8(const AStr: pansichar; ALen: size_t; ACp: PUint_least32_t): size_t;
function grapheme_encode_utf8(ACp: Uint_least32_t; AStr: pansichar; ALen: size_t): size_t;

function graphemeCountCodePoints(const AStr:RawByteString;ACharPosStart:SizeInt=1;ALengthInBytes:integer=-1):SizeInt;overload;
function graphemeCountCodePoints(const AStr:PAnsiChar;ALengthInBytes:integer):SizeInt;overload;
function graphemeCopyCodePoints(const AStr:RawByteString;ACountCodePoints:integer;ACharPosStart:SizeInt=1):RawByteString;overload;
function graphemeCopyCodePoints(const AStr:PAnsiChar;ALenght:SizeInt; ACountCodePoints:integer):RawByteString;overload;
function graphemePosCodePoints(const Substr: RawByteString; const Source: RawByteString; Offset: SizeInt = 1 ): SizeInt;
function graphemeCodePointToChars(const AStr: RawByteString; CodePointIndex: SizeInt = 1 ): SizeInt;

implementation

type
  {* lookup-table for the types of sequence first bytes *}
  RLut=record
       lower:uint_least8_t;   {* lower bound of sequence first byte *}
       upper:uint_least8_t;  {* upper bound of sequence first byte *}
       mincp:uint_least32_t; {* smallest non-overlong encoded codepoint *}
       maxcp:uint_least32_t; {* largest encodable codepoint *}
			     {*
	                      * implicit: table-offset represents the number of following
	                      * bytes of the form 10xxxxxx (6 bits capacity each)
	                      *}
  end;

const
  lut: array[0..3] of RLut = (
    (
    {* 0xxxxxxx *}
    lower: $00; {* 00000000 *}
    upper: $7F; {* 01111111 *}
    mincp: 0;
    maxcp: $7F  //((uint_least32_t)1 << 7) - 1, /* 7 bits capacity */
    ),
    (
    {* 110xxxxx *}
    lower: $C0; {* 11000000 *}
    upper: $DF; {* 11011111 *}
    mincp: $80; //(uint_least32_t)1 << 7,
    maxcp: $7FF //((uint_least32_t)1 << 11) - 1, /* 5+6=11 bits capacity */
    ),
    (
    {* 1110xxxx *}
    lower: $E0;  {* 11100000 *}
    upper: $EF;  {* 11101111 *}
    mincp: $800; //(uint_least32_t)1 << 11,
    maxcp: $FFFF //((uint_least32_t)1 << 16) - 1, /* 4+6+6=16 bits capacity */
    ),
    (
    {* 11110xxx *}
    lower: $F0;    {* 11110000 *}
    upper: $F7;    {* 11110111 *}
    mincp: $10000; //(uint_least32_t)1 << 16,
    maxcp: $1FFFFF //((uint_least32_t)1 << 21) - 1, /* 3+6+6+6=21 bits capacity */
    )
  );

function BETWEEN(c, l, u:Uint32):boolean;overload;
begin
  result := (c >= l) and (c <= u);
end;

function BETWEEN(c, l, u:Uint8):boolean;overload;
begin
  result := (c >= l) and (c <= u);
end;


function grapheme_decode_utf8(const AStr: pansichar; ALen: size_t; ACp: PUint_least32_t): size_t;
var
  off, i: size_t;
  tmp: Uint_least32_t;
begin
  if ACp = nil then
  begin
    {*
     * instead of checking every time if ACp is NULL within
     * the decoder, simply point it at a dummy variable here.
     *}
    ACp := @tmp;
  end;

  if (AStr = nil) or (ALen = 0) then
  begin
    {* a sequence must be at least 1 byte long *}
    ACp^ := GRAPHEME_INVALID_CODEPOINT;
    exit(0);
  end;

  {* identify sequence type with the first byte *}

  off := 0;
  while off < length(lut) do
  begin
    if BETWEEN(Ord(AStr[0]), lut[off].lower, lut[off].upper) then
    begin
      {*
       * first byte is within the bounds; fill
       * p with the the first bits contained in
       * the first byte (by subtracting the high bits)
       *}
      ACp^ := Ord(AStr[0]) - lut[off].lower;
      break;
    end;
    Inc(off);
  end;
  if off = length(lut) then
  begin
    {*
     * first byte does not match a sequence type;
     * set ACp as invalid and return 1 byte processed
     *
     * this also includes the cases where bits higher than
     * the 8th are set on systems with CHAR_BIT > 8
     *}
    ACp^ := GRAPHEME_INVALID_CODEPOINT;
    exit(1);
  end;
  if (1 + off) > ALen then
  begin
    {*
     * input is not long enough, set ACp as invalid
     *}
    ACp^ := GRAPHEME_INVALID_CODEPOINT;

    {*
     * count the following continuation bytes, but nothing
     * else in case we have a "rogue" case where e.g. such a
     * sequence starter occurs right before a NUL-byte.
     *}

    i := 0;
    while (1 + i) < ALen do
    begin
      if not BETWEEN(Ord(AStr[1 + i]), $80, $BF) then
      begin
        break;
      end;
      Inc(i);
    end;

    {*
     * if the continuation bytes do not continue until
     * the end, return the incomplete sequence length.
     * Otherwise return the number of bytes we actually
     * expected, which is larger than n.
     *}
    if (1 + i) < ALen then
      exit(1 + i)
    else
      exit(1 + off);
  end;

  {*
   * process 'off' following bytes, each of the form 10xxxxxx
   * (i.e. between 0x80 (10000000) and 0xBF (10111111))
   *}
  i := 1;
  while i <= off do
  begin
    if not BETWEEN(Ord(AStr[i]), $80, $BF) then
    begin
      {*
       * byte does not match format; return
       * number of bytes processed excluding the
       * unexpected character as recommended since
       * Unicode 6 (chapter 3)
       *
       * this also includes the cases where bits
       * higher than the 8th are set on systems
       * with CHAR_BIT > 8
       *}
      ACp^ := GRAPHEME_INVALID_CODEPOINT;
      exit(1 + (i - 1));
    end;
    {*
     * shift codepoint by 6 bits and add the 6 stored bits
     * in s[i] to it using the bitmask 0x3F (00111111)
     *}
    //*ACp = (*ACp << 6) | (((const unsigned char *)AStr)[i] & 0x3F);
    ACp^ := ((ACp^) shl 6) or UInt32((Ord(AStr[i]) and $3F));
    Inc(i);
  end;

  if (ACp^ < lut[off].mincp) or BETWEEN(ACp^, $D800, $DFFF) or (ACp^ > GRAPHEME_LAST_CODEPOINT) then
  begin
    {*
     * codepoint is overlong encoded in the sequence, is a
     * high or low UTF-16 surrogate half (0xD800..0xDFFF) or
     * not representable in UTF-16 (>0x10FFFF) (RFC-3629
     * specifies the latter two conditions)
     *}
    ACp^ := GRAPHEME_INVALID_CODEPOINT;
  end;
  exit(1 + off);
end;


function grapheme_encode_utf8(ACp: Uint_least32_t; AStr: pansichar; ALen: size_t): size_t;
var
  off, i: size_t;
begin
  if BETWEEN(ACp, $D800, $DFFF) or (ACp > GRAPHEME_LAST_CODEPOINT) then
  begin
    {*
     * codepoint is a high or low UTF-16 surrogate half
     * (0xD800..0xDFFF) or not representable in UTF-16
     * (>0x10FFFF), which RFC-3629 deems invalid for UTF-8.
     *}
    ACp := GRAPHEME_INVALID_CODEPOINT;
  end;

  {* determine necessary sequence type *}
  off := 0;
  while off < length(lut) do
  begin
    if (ACp <= lut[off].maxcp) then
    begin
      break;
    end;
    Inc(off);
  end;
  if ((1 + off) > ALen) or (AStr = nil) or (ALen = 0) then
  begin
    {*
     * specified buffer is too small to store sequence or
     * the caller just wanted to know how many bytes the
     * codepoint needs by passing a NULL-buffer.
     *}
    exit(1 + off);
  end;

  {* build sequence by filling ACp-bits into each byte *}

  {*
   * lut[off].lower is the bit-format for the first byte and
   * the bits to fill into it are determined by shifting the
   * ACp 6 times the number of following bytes, as each
   * following byte stores 6 bits, yielding the wanted bits.
   *
   * We do not overwrite the mask because we guaranteed earlier
   * that there are no bits higher than the mask allows.
   *}
  //((unsigned char *)AStr)[0] = lut[off].lower | (uint_least8_t)(ACp >> (6 * off));
  AStr[0] := char(lut[off].lower or uint_least8_t((ACp shr (6 * off))));

  for i := 1 to off do
  begin
    {*
     * the bit-format for following bytes is 10000000 (0x80)
     * and it each stores 6 bits in the 6 low bits that we
     * extract from the properly-shifted value using the
     * mask 00111111 (0x3F)
     *}
    //((unsigned char *)AStr)[i] = 0x80 | ((ACp >> (6 * (off - i))) & 0x3F);
    AStr[i] := char($80 or ((ACp shr (6 * (off - i))) and $3F));
  end;

  exit(1 + off);
end;


function graphemeCountCodePoints(const AStr:RawByteString;ACharPosStart:SizeInt=1;ALengthInBytes:integer=-1):SizeInt;overload;
var
  CharPtr:PAnsiChar;
  ret:size_t;
  CP:uint_least32_t;
  len:SizeInt;
begin
  result:=0;
  if ACharPosStart < 1 then
    exit;
  if AlengthInBytes<0 then
    len:=length(AStr)
  else
    len:=AlengthInBytes;
  if ACharPosStart > len then
    exit;
  len := len - ACharPosStart + 1;
  CharPtr := @AStr[ACharPosStart];
  while len > 0 do
  begin
    ret := grapheme_decode_utf8(CharPtr, len, @CP);
    if CP = GRAPHEME_INVALID_CODEPOINT then
      exit;
    len := len - ret;
    CharPtr := CharPtr + ret;
    inc(result);
  end;
end;

function graphemeCountCodePoints(const AStr:PAnsiChar;ALengthInBytes:integer):SizeInt;overload;
var
  CharPtr:PAnsiChar;
  ret:size_t;
  CP:uint_least32_t;
  len:SizeInt;
begin
  result:=0;
  len:=AlengthInBytes;
  CharPtr := Astr;
  while len > 0 do
  begin
    ret := grapheme_decode_utf8(CharPtr, len, @CP);
    if CP = GRAPHEME_INVALID_CODEPOINT then
      exit;
    len := len - ret;
    CharPtr := CharPtr + ret;
    inc(result);
  end;
end;

function graphemeCopyCodePoints(const AStr:RawByteString;ACountCodePoints:integer;ACharPosStart:SizeInt=1):RawByteString;overload;
var
  len: SizeInt;
  bytes, ret : size_t;
  CP:uint_least32_t;
  CharPtr:PAnsiChar;
begin
  result := '';
  if (ACharPosStart<1) or (ACharPosStart>length(Astr)) then
    exit;
  bytes := 0;
  len := length(AStr) - ACharPosStart + 1;
  CharPtr := @AStr[ACharPosStart];
  while (ACountCodePoints > 0) and (len > 0) do
  begin
    ret := grapheme_decode_utf8(CharPtr, len, @CP);
    if CP = GRAPHEME_INVALID_CODEPOINT then
      break;
    len := len - ret;
    CharPtr := CharPtr + ret;
    bytes := bytes + ret;
    Dec(ACountCodePoints);
  end;
  result := Copy(Astr,ACharPosStart,bytes);
end;

function graphemeCopyCodePoints(const AStr:PAnsiChar;ALenght:SizeInt; ACountCodePoints:integer):RawByteString;overload;
var
  len: SizeInt;
  ret,bytes : size_t;
  CP:uint_least32_t;
  CharPtr:PAnsiChar;
begin
  result := '';
  bytes := 0;
  len := Alenght;
  CharPtr := AStr;
  while (ACountCodePoints > 0) and (len > 0) do
  begin
    ret := grapheme_decode_utf8(CharPtr, len, @CP);
    if CP = GRAPHEME_INVALID_CODEPOINT then
      break;
    len := len - ret;
    CharPtr := CharPtr + ret;
    bytes := bytes + ret;
    Dec(ACountCodePoints);
  end;
  result := Copy(Astr,1,bytes);
end;

function graphemePosCodePoints(const Substr: RawByteString; const Source: RawByteString; Offset: SizeInt = 1 ): SizeInt;
var
  p: SizeInt;
begin
  p := Pos(Substr, Source,Offset);
  if p>0 then
    result := graphemeCountCodePoints(Source,1, p)
  else
    result := -1;
end;

function graphemeCodePointToChars(const AStr: RawByteString; CodePointIndex: SizeInt = 1 ): SizeInt;
var
  ret,len: SizeInt;
  CP:uint_least32_t;
  CharPtr:PAnsiChar;
begin
  if (length(AStr) < CodePointIndex) or (CodePointIndex < 1) then
    exit(-1);
  result := 1;
  len := length(AStr);
  CharPtr := @AStr[1];
  while (CodePointIndex > 1) and (len>0) do
  begin
    ret := grapheme_decode_utf8(CharPtr, len, @CP);
    if CP = GRAPHEME_INVALID_CODEPOINT then
    begin
      exit(-1);
    end;
    len := len - ret;
    CharPtr := CharPtr + ret;
    result := result + ret;
    Dec(CodePointIndex);
  end;
  if CodePointIndex > 1 then
    result := -1;
end;


end.


