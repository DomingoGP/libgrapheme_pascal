  {* See LICENSE file for copyright and license details. *}
unit grapheme_word;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils, grapheme_types;

function grapheme_next_word_break(const str: Puint_least32_t; len: size_t): size_t;cdecl;
function grapheme_next_word_break_utf8(const str: pansichar; len: size_t): size_t;cdecl;

implementation
uses
  grapheme_util;

{$I grapheme_gen_word.inc}

type

  Pword_break_state = ^word_break_state;
  word_break_state = record
    ri_even: boolean;
  end;

function get_word_break_prop(cp: uint_least32_t): uint_least8_t; inline;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
  begin
    exit(uint_least8_t(word_break_minor[word_break_major[cp shr 8] + (cp and $ff)]));
  end
  else
  begin
    exit(Ord(WORD_BREAK_PROP_OTHER));
  end;
end;

function is_skippable_word_prop(prop: uint_least8_t): boolean;
begin
  exit((prop = Ord(WORD_BREAK_PROP_EXTEND)) or (prop = Ord(WORD_BREAK_PROP_FORMAT)) or (prop = Ord(WORD_BREAK_PROP_ZWJ)));
end;

procedure word_skip_shift_callback(prop: uint_least8_t; s: Pointer);
var
  state: Pword_break_state;
begin
  state := Pword_break_state(s);
  if prop = Ord(WORD_BREAK_PROP_REGIONAL_INDICATOR) then
  begin
    {*
     * The property we just shifted in is
     * a regional indicator, increasing the
     * number of consecutive RIs on the left
     * side of the breakpoint by one, changing
     * the oddness.
     *
     *}
    state^.ri_even := not (state^.ri_even);
  end
  else
  begin
    {*
     * We saw no regional indicator, so the
     * number of consecutive RIs on the left
     * side of the breakpoint is zero, which
     * is an even number.
     *
     *}
    state^.ri_even := True;
  end;
end;

function next_word_break(r: PHERODOTUS_READER): size_t;
var
  p: proper;
  state: word_break_state;
begin
  state.ri_even := True;
  {*
   * Apply word breaking algorithm (UAX #29), see
   * https://unicode.org/reports/tr29/#Word_Boundary_Rules
   *}
  proper_init(r, @state, Ord(NUM_WORD_BREAK_PROPS), get_word_break_prop,
    is_skippable_word_prop, word_skip_shift_callback, @p);

  while proper_advance(@p) = 0 do    // from C !proper_advance(@p)
  begin
    {* WB3 *}
    if (p.raw.prev_prop[0] = Ord(WORD_BREAK_PROP_CR)) and (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_LF)) then
    begin
      continue;
    end;

    {* WB3a *}
    if (p.raw.prev_prop[0] = Ord(WORD_BREAK_PROP_NEWLINE)) or (p.raw.prev_prop[0] = Ord(WORD_BREAK_PROP_CR)) or (p.raw.prev_prop[0] = Ord(WORD_BREAK_PROP_LF)) then
    begin
      break;
    end;

    {* WB3b *}
    if (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_NEWLINE)) or (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_CR)) or (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_LF)) then
    begin
      break;
    end;

    {* WB3c *}
    if (p.raw.prev_prop[0] = Ord(WORD_BREAK_PROP_ZWJ)) and ((p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_EXTENDED_PICTOGRAPHIC)) or
      (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT))) then
    begin
      continue;
    end;

    {* WB3d *}
    if (p.raw.prev_prop[0] = Ord(WORD_BREAK_PROP_WSEGSPACE)) and (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_WSEGSPACE)) then
    begin
      continue;
    end;

    {* WB4 *}
    if (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_EXTEND)) or (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_FORMAT)) or
      (p.raw.next_prop[0] = Ord(WORD_BREAK_PROP_ZWJ)) then
    begin
      continue;
    end;

    {* WB5 *}
    if ((p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_ALETTER)) or (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or
      (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER))) and ((p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_ALETTER)) or
      (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER))) then
    begin
      continue;
    end;

    {* WB6 *}
    if ((p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_ALETTER)) or (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or
      (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER))) and ((p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_MIDLETTER)) or
      (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_MIDNUMLET)) or (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_SINGLE_QUOTE))) and
      ((p.skip.next_prop[1] = Ord(WORD_BREAK_PROP_ALETTER)) or (p.skip.next_prop[1] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or
      (p.skip.next_prop[1] = Ord(WORD_BREAK_PROP_HEBREW_LETTER))) then
    begin
      continue;
    end;

    {* WB7 *}
    if  (
         (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_MIDLETTER) ) or
         (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_MIDNUMLET) ) or
         (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_SINGLE_QUOTE) ) ) and
        ((p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_ALETTER) ) or
         (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT) ) or
         (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER) )) and
        ((p.skip.prev_prop[1] = Ord(WORD_BREAK_PROP_ALETTER) ) or
         (p.skip.prev_prop[1] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT) ) or
         (p.skip.prev_prop[1] = Ord(WORD_BREAK_PROP_HEBREW_LETTER) )
        ) then
    begin
      continue;
    end;

    {* WB7a *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER)) and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_SINGLE_QUOTE)) then
    begin
      continue;
    end;

    {* WB7b *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER)) and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_DOUBLE_QUOTE)) and
      (p.skip.next_prop[1] = Ord(WORD_BREAK_PROP_HEBREW_LETTER)) then
    begin
      continue;
    end;

    {* WB7c *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_DOUBLE_QUOTE)) and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER)) and
      (p.skip.prev_prop[1] = Ord(WORD_BREAK_PROP_HEBREW_LETTER)) then
    begin
      continue;
    end;

    {* WB8 *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) then
    begin
      continue;
    end;

    {* WB9 *}
    if ((p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_ALETTER)) or (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or
      (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER))) and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) then
    begin
      continue;
    end;

    {* WB10 *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) and ((p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_ALETTER)) or
      (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER))) then
    begin
      continue;
    end;

    {* WB11 *}
    if ((p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_MIDNUM)) or (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_MIDNUMLET)) or
      (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_SINGLE_QUOTE))) and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) and
      (p.skip.prev_prop[1] = Ord(WORD_BREAK_PROP_NUMERIC)) then
    begin
      continue;
    end;

    {* WB12 *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) and ((p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_MIDNUM)) or
      (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_MIDNUMLET)) or (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_SINGLE_QUOTE))) and
      (p.skip.next_prop[1] = Ord(WORD_BREAK_PROP_NUMERIC)) then
    begin
      continue;
    end;

    {* WB13 *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_KATAKANA)) and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_KATAKANA)) then
    begin
      continue;
    end;

    {* WB13a *}
    if ((p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_ALETTER)) or (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or
      (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER)) or (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) or
      (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_KATAKANA)) or (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_EXTENDNUMLET))) and
      (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_EXTENDNUMLET)) then
    begin
      continue;
    end;

    {* WB13b *}
    if (p.skip.prev_prop[0] = Ord(WORD_BREAK_PROP_EXTENDNUMLET)) and ((p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_ALETTER)) or
      (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_BOTH_ALETTER_EXTPICT)) or (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_HEBREW_LETTER)) or
      (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_NUMERIC)) or (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_KATAKANA))) then
    begin
      continue;
    end;

    {* WB15 and WB16 *}
    if not state.ri_even and (p.skip.next_prop[0] = Ord(WORD_BREAK_PROP_REGIONAL_INDICATOR)) then
    begin
      continue;
    end;

    {* WB999 *}
    break;
  end;

  exit(herodotus_reader_number_read(@(p.mid_reader)));
end;

function grapheme_next_word_break(const str: Puint_least32_t; len: size_t): size_t;cdecl;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, str, len);

  exit(next_word_break(@r));
end;

function grapheme_next_word_break_utf8(const str: pansichar; len: size_t): size_t;cdecl;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, str, len);

  exit(next_word_break(@r));
end;

end.
