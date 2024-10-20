unit grapheme_character;

{$ifdef FPC}{$mode delphi}{$endif}
interface

uses
  Classes, SysUtils, grapheme_types;


function grapheme_is_character_break(cp0: uint_least32_t; cp1: uint_least32_t; s: Puint_least16_t): boolean;
function grapheme_next_character_break(const Astr: Puint_least32_t; len: size_t): size_t; cdecl;
function grapheme_next_character_break_utf8(const Astr: pansichar; len: size_t): size_t;cdecl;


function graphemeCountGraphemes(const Astr: rawbytestring; ACharPosStart: SizeInt = 1; ALengthInBytes: integer = -1): SizeInt; overload;
function graphemeCountGraphemes(const Astr: pansichar; ALengthInBytes: integer): SizeInt; overload;
function graphemeCopyGraphemes(const Astr: rawbytestring; ACountGraphemes: integer; ACharPosStart: SizeInt = 1): rawbytestring; overload;
function graphemeCopyGraphemes(const Astr: pansichar; ALenght: SizeInt; ACountGraphemes: integer): rawbytestring; overload;
function graphemePosGraphemes(const Substr: rawbytestring; const Source: rawbytestring; Offset: SizeInt = 1): SizeInt;
function graphemeGraphemeToChars(const Astr: rawbytestring; GraphemeIndex: SizeInt = 1): SizeInt;


implementation

uses
  grapheme_util;

  {$I grapheme_gen_character.inc}

type

  PCharacter_break_state = ^character_break_state;
  character_break_state = record
    prop: uint_least8_t;
    prop_set: boolean;
    gb11_flag: boolean;
    gb12_13_flag: boolean;
  end;

const
  dont_break: array [0..NUM_CHAR_BREAK_PROPS - 1] of uint_least16_t =
    (
    //CHAR_BREAK_PROP_OTHER
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or           {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or              {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)),        {* GB9a *}
    //CHAR_BREAK_PROP_CONTROL
    0,
    //CHAR_BREAK_PROP_CR,
    uint16(1) shl uint16(CHAR_BREAK_PROP_LF), {* GB3  *}
    //CHAR_BREAK_PROP_EXTEND,
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC,
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)),  {* GB9a *}
    //  [CHAR_BREAK_PROP_HANGUL_L] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_L)) or   {* GB6  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_V)) or   {* GB6  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_LV)) or  {* GB6  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_LVT)) or {* GB6  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //  [CHAR_BREAK_PROP_HANGUL_V] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_V)) or   {* GB7  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_T)) or   {* GB7  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //  [CHAR_BREAK_PROP_HANGUL_T] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_T)) or   {* GB8  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //  [CHAR_BREAK_PROP_HANGUL_LV] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_V)) or   {* GB7  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_T)) or   {* GB7  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //  [CHAR_BREAK_PROP_HANGUL_LVT] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_HANGUL_T)) or   {* GB8  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //       [CHAR_BREAK_PROP_LF] =
    0,
    //  [CHAR_BREAK_PROP_PREPEND] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or      {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or         {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)) or {* GB9a *}
    (  uint16($FFFF)
      and not (
               (uint16(1) shl uint16(CHAR_BREAK_PROP_CR)) or
               (uint16(1) shl uint16(CHAR_BREAK_PROP_LF)) or
               (uint16(1) shl uint16(CHAR_BREAK_PROP_CONTROL))
               )


    ), {* GB9b *}
    //  [CHAR_BREAK_PROP_REGIONAL_INDICATOR] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //  [CHAR_BREAK_PROP_SPACINGMARK] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)), {* GB9a *}
    //  [CHAR_BREAK_PROP_ZWJ] =
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or     {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or        {* GB9  *}
    (uint16(1) shl uint16(CHAR_BREAK_PROP_SPACINGMARK)) {* GB9a *}
    //      [   NUM_CHAR_BREAK_PROPS]
    //                0
    );

(*
  static const uint_least16_t flag_update_gb11[2 * NUM_CHAR_BREAK_PROPS] = {
  	[CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC] =
  		UINT16_C(1) << CHAR_BREAK_PROP_ZWJ |
  		UINT16_C(1) << CHAR_BREAK_PROP_EXTEND,
  	[CHAR_BREAK_PROP_ZWJ + NUM_CHAR_BREAK_PROPS] =
  		UINT16_C(1) << CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC,
  	[CHAR_BREAK_PROP_EXTEND + NUM_CHAR_BREAK_PROPS] =
  		UINT16_C(1) << CHAR_BREAK_PROP_EXTEND |
  		UINT16_C(1) << CHAR_BREAK_PROP_ZWJ,
  	[CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC + NUM_CHAR_BREAK_PROPS] =
  		UINT16_C(1) << CHAR_BREAK_PROP_ZWJ |
  		UINT16_C(1) << CHAR_BREAK_PROP_EXTEND,
  };
  static const uint_least16_t dont_break_gb11[2 * NUM_CHAR_BREAK_PROPS] = {
  	[CHAR_BREAK_PROP_ZWJ + NUM_CHAR_BREAK_PROPS] =
  		UINT16_C(1) << CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC,
  };
  static const uint_least16_t flag_update_gb12_13[2 * NUM_CHAR_BREAK_PROPS] = {
  	[CHAR_BREAK_PROP_REGIONAL_INDICATOR] =
  		UINT16_C(1) << CHAR_BREAK_PROP_REGIONAL_INDICATOR,
  };
  static const uint_least16_t dont_break_gb12_13[2 * NUM_CHAR_BREAK_PROPS] = {
  	[CHAR_BREAK_PROP_REGIONAL_INDICATOR + NUM_CHAR_BREAK_PROPS] =
  		UINT16_C(1) << CHAR_BREAK_PROP_REGIONAL_INDICATOR,
  };
*)
//NOTE: We can't initialize the same way as C so we do in initialization section

var
  flag_update_gb11: array [0..(2 * uint16(NUM_CHAR_BREAK_PROPS) - 1)] of uint_least16_t;
  dont_break_gb11: array [0..(2 * uint16(NUM_CHAR_BREAK_PROPS) - 1)] of uint_least16_t;
  flag_update_gb12_13: array [0..(2 * uint16(NUM_CHAR_BREAK_PROPS) - 1)] of uint_least16_t;
  dont_break_gb12_13: array [0..(2 * uint16(NUM_CHAR_BREAK_PROPS) - 1)] of uint_least16_t;


function get_break_prop(cp: uint_least32_t): char_break_property; inline;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
    exit(char_break_property(char_break_minor[char_break_major[cp shr 8] + (cp and $FF)]))
  else
    exit(CHAR_BREAK_PROP_OTHER);
end;

procedure state_serialize(const _in: Pcharacter_break_state; _out: Puint_least16_t); inline;
begin
  _out^ := uint_least16_t(_in^.prop and uint8($FF)) or {* first 8 bits *}
    uint_least16_t((uint_least16_t(_in^.prop_set)) shl 8) or {* 9th bit *}
    uint_least16_t((uint_least16_t(_in^.gb11_flag)) shl 9) or {* 10th bit *}
    uint_least16_t((uint_least16_t(_in^.gb12_13_flag)) shl 10); {* 11th bit *}
end;

procedure state_deserialize(_in: uint_least16_t; _out: PCharacter_break_state); inline;
begin
  _out^.prop := _in and uint8($FF);
  _out^.prop_set := (_in and (1 shl 8)) <> 0;
  _out^.gb11_flag := (_in and (1 shl 9)) <> 0;
  _out^.gb12_13_flag := (_in and (1 shl 10)) <> 0;
end;

function grapheme_is_character_break(cp0: uint_least32_t; cp1: uint_least32_t; s: Puint_least16_t): boolean;
var
  state: character_break_state;
  cp0_prop, cp1_prop: char_break_property;
  notbreak: boolean;
begin
  notbreak := False;

  if s  <> nil then
  begin
    state_deserialize(s^, @state);

    if state.prop_set then
      cp0_prop := char_break_property(state.prop)
    else
      cp0_prop := get_break_prop(cp0);
    cp1_prop := get_break_prop(cp1);

    {* preserve prop of right codepoint for next iteration *}
    state.prop := uint_least8_t(cp1_prop);
    state.prop_set := True;

    {* update flags *}
    state.gb11_flag :=
      ((flag_update_gb11[uint16(cp0_prop) + uint16(NUM_CHAR_BREAK_PROPS) * byte(state.gb11_flag)])
      and (uint16(1) shl uint16(cp1_prop))) <> 0;
    state.gb12_13_flag :=
      ((flag_update_gb12_13[uint16(cp0_prop) + uint16(NUM_CHAR_BREAK_PROPS) * byte(state.gb12_13_flag)]) and
      (uint16(1) shl uint16(cp1_prop))) <> 0;

    {*
     * Apply grapheme cluster breaking algorithm (UAX #29), see
     * http://unicode.org/reports/tr29/#Grapheme_Cluster_Boundary_Rules
     *}
    notbreak := ((dont_break[uint16(cp0_prop)] and (1 shl uint16(cp1_prop)))
      or (dont_break_gb11[uint16(cp0_prop) + byte(state.gb11_flag) * uint16(NUM_CHAR_BREAK_PROPS)]
      and (1 shl uint16(cp1_prop)))
      or  (dont_break_gb12_13[uint16(cp0_prop) + byte(state.gb12_13_flag) *
      uint16(NUM_CHAR_BREAK_PROPS)] and (1 shl uint16(cp1_prop)))) <> 0;

    {* update or reset flags (when we have a break) *}
    if not notbreak then
    begin
      state.gb11_flag := False;
      state.gb12_13_flag := False;
    end;

    state_serialize(@state, s);
  end
  else
  begin
    cp0_prop := get_break_prop(cp0);
    cp1_prop := get_break_prop(cp1);

    {*
     * Apply grapheme cluster breaking algorithm (UAX #29), see
     * http://unicode.org/reports/tr29/#Grapheme_Cluster_Boundary_Rules
     *
     * Given we have no state, this behaves as if the state-booleans
     * were all set to false
     *}
    notbreak := ((dont_break[uint16(cp0_prop)] and (1 shl uint16(cp1_prop))) or
    (dont_break_gb11[uint16(cp0_prop)] and (1 shl uint16(cp1_prop))) or
    (dont_break_gb12_13[uint16(cp0_prop)] and (1 shl uint16(cp1_prop)))) <> 0;
  end;

  exit(not notbreak);
end;

function next_character_break(r: PHERODOTUS_READER): size_t;
var
  state: uint_least16_t;
  cp0, cp1: uint_least32_t;
begin
  state := 0;
  cp0 := 0;
  cp1 := 0;
  herodotus_read_codepoint(r, True, @cp0);
  while herodotus_read_codepoint(r, False, @cp1) = HERODOTUS_STATUS_SUCCESS do
  begin
    if grapheme_is_character_break(cp0, cp1, @state) then
      break;
    herodotus_read_codepoint(r, True, @cp0);
  end;
  exit(herodotus_reader_number_read(r));
end;

function grapheme_next_character_break(const Astr: Puint_least32_t; len: size_t): size_t; cdecl;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, Astr, len);
  exit(next_character_break(@r));
end;

function grapheme_next_character_break_utf8(const Astr: pansichar; len: size_t): size_t;cdecl;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, Astr, len);
  exit(next_character_break(@r));
end;

function graphemeCountGraphemes(const Astr: rawbytestring; ACharPosStart: SizeInt = 1; ALengthInBytes: integer = -1): SizeInt; overload;
var
  CharPtr: pansichar;
  ret: size_t;
  len: SizeInt;
begin
  Result := 0;
  if ACharPosStart < 1 then
    exit;
  if ALengthInBytes < 0 then
    len := length(Astr)
  else
    len := ALengthInBytes;
  if ACharPosStart > len then
    exit;
  len := len - ACharPosStart + 1;
  CharPtr := @Astr[ACharPosStart];
  while len > 0 do
  begin
    ret := grapheme_next_character_break_utf8(CharPtr, len);
    if ret <= 0 then
      break;
    len := len - ret;
    CharPtr := CharPtr + ret;
    Inc(Result);
  end;
end;

function graphemeCountGraphemes(const Astr: pansichar; ALengthInBytes: integer): SizeInt; overload;
var
  CharPtr: pansichar;
  ret: size_t;
  len: SizeInt;
begin
  Result := 0;
  len := ALengthInBytes;
  CharPtr := Astr;
  while len > 0 do
  begin
    ret := grapheme_next_character_break_utf8(CharPtr, len);
    if ret <= 0 then
      exit;
    len := len - ret;
    CharPtr := CharPtr + ret;
    Inc(Result);
  end;
end;

function graphemeCopyGraphemes(const Astr: rawbytestring; ACountGraphemes: integer; ACharPosStart: SizeInt = 1): rawbytestring; overload;
var
  len: SizeInt;
  bytes, ret: size_t;
  CharPtr: pansichar;
begin
  Result := '';
  if (ACharPosStart < 1) or (ACharPosStart > length(Astr)) then
    exit;
  bytes := 0;
  len := length(Astr) - ACharPosStart + 1;
  CharPtr := @Astr[ACharPosStart];
  while (ACountGraphemes > 0) and (len > 0) do
  begin
    ret := grapheme_next_character_break_utf8(CharPtr, len);
    if ret <= 0 then
      break;
    len := len - ret;
    CharPtr := CharPtr + ret;
    bytes := bytes + ret;
    Dec(ACountGraphemes);
  end;
  Result := Copy(Astr, ACharPosStart, bytes);
end;

function graphemeCopyGraphemes(const Astr: pansichar; ALenght: SizeInt; ACountGraphemes: integer): rawbytestring; overload;
var
  len: SizeInt;
  ret, bytes: size_t;
  CharPtr: pansichar;
begin
  Result := '';
  bytes := 0;
  len := ALenght;
  CharPtr := Astr;
  while (ACountGraphemes > 0) and (len > 0) do
  begin
    ret := grapheme_next_character_break_utf8(CharPtr, len);
    if ret <= 0 then
      break;
    len := len - ret;
    CharPtr := CharPtr + ret;
    bytes := bytes + ret;
    Dec(ACountGraphemes);
  end;
  Result := Copy(Astr, 1, bytes);
end;

function graphemePosGraphemes(const Substr: rawbytestring; const Source: rawbytestring; Offset: SizeInt = 1): SizeInt;
var
  p: SizeInt;
begin
  p := Pos(Substr, Source, Offset);
  if p > 0 then
    Result := graphemeCountGraphemes(Source, 1, p)
  else
    Result := -1;
end;

function graphemeGraphemeToChars(const Astr: rawbytestring; GraphemeIndex: SizeInt = 1): SizeInt;
var
  ret, len: SizeInt;
  CharPtr: pansichar;
begin
  if (length(Astr) < GraphemeIndex) or (GraphemeIndex < 1) then
    exit(-1);
  Result := 1;
  len := length(Astr);
  CharPtr := @Astr[1];
  while (GraphemeIndex > 1) and (len > 0) do
  begin
    ret := grapheme_next_character_break_utf8(CharPtr, len);
    if ret <= 0 then
    begin
      exit(-1);
    end;
    len := len - ret;
    CharPtr := CharPtr + ret;
    Result := Result + ret;
    Dec(GraphemeIndex);
  end;
  if GraphemeIndex > 1 then
    Result := -1;
end;


initialization
  {$PUSH}
  {$WARN 5058 off : Variable "$1" does not seem to be initialized}
  FillChar(flag_update_gb11,sizeof(flag_update_gb11),0);
  FillChar(dont_break_gb11,sizeof(dont_break_gb11),0);
  FillChar(flag_update_gb12_13,sizeof(flag_update_gb12_13),0);
  FillChar(dont_break_gb12_13,sizeof(dont_break_gb12_13),0);
  {$POP}
  flag_update_gb11[uint16(CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC)] :=
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND));

  flag_update_gb11[uint16(CHAR_BREAK_PROP_ZWJ) + uint16(NUM_CHAR_BREAK_PROPS)] :=
    uint16(1) shl uint16(CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC);

  flag_update_gb11[uint16(CHAR_BREAK_PROP_EXTEND) + uint16(NUM_CHAR_BREAK_PROPS)] :=
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND)) or (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ));

  flag_update_gb11[uint16(CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC) + uint16(NUM_CHAR_BREAK_PROPS)] :=
    (uint16(1) shl uint16(CHAR_BREAK_PROP_ZWJ)) or (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTEND));

  dont_break_gb11[uint16(CHAR_BREAK_PROP_ZWJ) + uint16(NUM_CHAR_BREAK_PROPS)] :=
    (uint16(1) shl uint16(CHAR_BREAK_PROP_EXTENDED_PICTOGRAPHIC));

  flag_update_gb12_13[uint16(CHAR_BREAK_PROP_REGIONAL_INDICATOR)] :=
    (uint16(1) shl uint16(CHAR_BREAK_PROP_REGIONAL_INDICATOR));

  dont_break_gb12_13[uint16(CHAR_BREAK_PROP_REGIONAL_INDICATOR) + uint16(NUM_CHAR_BREAK_PROPS)] :=
    (uint16(1) shl uint16(CHAR_BREAK_PROP_REGIONAL_INDICATOR));

end.
