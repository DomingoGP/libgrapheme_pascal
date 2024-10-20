  {* See LICENSE file for copyright and license details. *}

unit grapheme_line;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils, grapheme_types;


function grapheme_next_line_break(const str: Puint_least32_t; len: size_t): size_t;cdecl;
function grapheme_next_line_break_utf8(const str: pansichar; len: size_t): size_t;cdecl;

implementation

uses
  grapheme_util;

{$I grapheme_gen_line.inc}

function get_line_break_prop(cp: uint_least32_t): line_break_property;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
  begin
    exit(line_break_property(line_break_minor[line_break_major[cp shr 8] + (cp and $ff)]));
  end
  else
  begin
    exit(LINE_BREAK_PROP_AL);
  end;
end;

function next_line_break(r: PHERODOTUS_READER): size_t;
var
  tmp: HERODOTUS_READER;
  cp0_prop, cp1_prop, last_non_cm_or_zwj_prop, last_non_sp_prop, last_non_sp_cm_or_zwj_prop: line_break_property;
  cp: uint_least32_t;
  lb25_level: uint_least8_t;
  lb21a_flag, ri_even: boolean;
label
  continue_loop;
begin
  lb25_level := 0;
  lb21a_flag := False;
  ri_even := True;
  {*
   * Apply line breaking algorithm (UAX #14), see
   * https://unicode.org/reports/tr14/#Algorithm and tailoring
   * https://unicode.org/reports/tr14/#Examples (example 7),
   * given the automatic test-cases implement this example for
   * better number handling.
   *
   *}

  {*
   * Initialize the different properties such that we have
   * a good state after the state-update in the loop
   *}
  last_non_cm_or_zwj_prop := LINE_BREAK_PROP_AL; {* according to LB10 *}
  last_non_sp_cm_or_zwj_prop := NUM_LINE_BREAK_PROPS;
  last_non_sp_prop := last_non_sp_cm_or_zwj_prop;

  herodotus_read_codepoint(r, True, @cp);
  cp0_prop := get_line_break_prop(cp);
  while herodotus_read_codepoint(r, False, @cp) = HERODOTUS_STATUS_SUCCESS do
  begin
    {* get property of the right codepoint *}
    cp1_prop := get_line_break_prop(cp);

    {* update retention-states *}

    {*
     * store the last observed non-CM-or-ZWJ-property for
     * LB9 and following.
     *}
    if (cp0_prop <> LINE_BREAK_PROP_CM) and (cp0_prop <> LINE_BREAK_PROP_ZWJ) then
    begin
      {*
       * check if the property we are overwriting now is an
       * HL. If so, we set the LB21a-flag which depends on
       * this knowledge.
       *}
      lb21a_flag := (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_HL);

      {* check regional indicator state *}
      if (cp0_prop = LINE_BREAK_PROP_RI) then
      begin
        {*
         * The property we just shifted in is
         * a regional indicator, increasing the
         * number of consecutive RIs on the left
         * side of the breakpoint by one, changing
         * the oddness.
         *
         *}
        ri_even := not ri_even;
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
        ri_even := True;
      end;

      {*
       * Here comes a bit of magic. The tailored rule
       * LB25 (using example 7) has a very complicated
       * left-hand-side-rule of the form
       *
       *  NU (NU or SY or IS)* (CL or CP)?
       *
       * but instead of backtracking, we keep the state
       * as some kind of "power level" in the variable
       *
       *  lb25_level
       *
       * that goes from 0 to 3
       *
       *  0: we are not in the sequence
       *  1: we have one NU to the left of the middle
       *     spot
       *  2: we have one NU and one or more (NU or SY or IS)
       *     to the left of the middle spot
       *  3: we have one NU, zero or more (NU or SY or IS)
       *     and one (CL or CP) to the left of the middle
       *     spot
       *}
      if ((lb25_level = 0) or (lb25_level = 1)) and (cp0_prop = LINE_BREAK_PROP_NU) then
      begin
        {* sequence has begun *}
        lb25_level := 1;
      end
      else if ((lb25_level = 1) or (lb25_level = 2)) and ((cp0_prop = LINE_BREAK_PROP_NU) or
        (cp0_prop = LINE_BREAK_PROP_SY) or (cp0_prop = LINE_BREAK_PROP_IS)) then
      begin
        {* (NU or SY or IS) sequence begins or goto continue_loop;d
         *}
        lb25_level := 2;
      end
      else if ((lb25_level = 1) or (lb25_level = 2)) and ((cp0_prop = LINE_BREAK_PROP_CL) or
        (cp0_prop = LINE_BREAK_PROP_CP_WITHOUT_EAW_HWF) or (cp0_prop = LINE_BREAK_PROP_CP_WITH_EAW_HWF)) then
      begin
        {* CL or CP at the end of the sequence *}
        lb25_level := 3;
      end
      else
      begin
        {* sequence broke *}
        lb25_level := 0;
      end;

      last_non_cm_or_zwj_prop := cp0_prop;
    end;

    {*
     * store the last observed non-SP-property for LB8, LB14,
     * LB15, LB16 and LB17. LB8 gets its own unskipped property,
     * whereas the others build on top of the CM-ZWJ-skipped
     * properties as they come after LB9
     *}
    if cp0_prop <> LINE_BREAK_PROP_SP then
    begin
      last_non_sp_prop := cp0_prop;
    end;
    if last_non_cm_or_zwj_prop <> LINE_BREAK_PROP_SP then
    begin
      last_non_sp_cm_or_zwj_prop := last_non_cm_or_zwj_prop;
    end;

    {* apply the algorithm *}

    {* LB4 *}
    if (cp0_prop = LINE_BREAK_PROP_BK) then
    begin
      break;
    end;

    {* LB5 *}
    if (cp0_prop = LINE_BREAK_PROP_CR) and (cp1_prop = LINE_BREAK_PROP_LF) then
    begin
      goto continue_loop;
    end;
    if (cp0_prop = LINE_BREAK_PROP_CR) or (cp0_prop = LINE_BREAK_PROP_LF) or (cp0_prop = LINE_BREAK_PROP_NL) then
    begin
      break;
    end;

    {* LB6 *}
    if (cp1_prop = LINE_BREAK_PROP_BK) or (cp1_prop = LINE_BREAK_PROP_CR) or (cp1_prop = LINE_BREAK_PROP_LF) or (cp1_prop = LINE_BREAK_PROP_NL) then
    begin
      goto continue_loop;
    end;

    {* LB7 *}
    if (cp1_prop = LINE_BREAK_PROP_SP) or (cp1_prop = LINE_BREAK_PROP_ZW) then
    begin
      goto continue_loop;
    end;

    {* LB8 *}
    if last_non_sp_prop = LINE_BREAK_PROP_ZW then
    begin
      break;
    end;

    {* LB8a *}
    if cp0_prop = LINE_BREAK_PROP_ZWJ then
    begin
      goto continue_loop;
    end;

    {* LB9 *}
    if ((cp0_prop <> LINE_BREAK_PROP_BK) and (cp0_prop <> LINE_BREAK_PROP_CR) and (cp0_prop <> LINE_BREAK_PROP_LF) and
      (cp0_prop <> LINE_BREAK_PROP_NL) and (cp0_prop <> LINE_BREAK_PROP_SP) and (cp0_prop <> LINE_BREAK_PROP_ZW)) and
      ((cp1_prop = LINE_BREAK_PROP_CM) or (cp1_prop = LINE_BREAK_PROP_ZWJ)) then
    begin
      {*
       * given we skip them, we don't break in such
       * a sequence
       *}
      goto continue_loop;
      ;
    end;

    {* LB10 is baked into the following rules *}

    {* LB11 *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_WJ) or (cp1_prop = LINE_BREAK_PROP_WJ) then
    begin
      goto continue_loop;
    end;

    {* LB12 *}
    if last_non_cm_or_zwj_prop = LINE_BREAK_PROP_GL then
    begin
      goto continue_loop;
    end;

    {* LB12a *}
    if ((last_non_cm_or_zwj_prop <> LINE_BREAK_PROP_SP) and (last_non_cm_or_zwj_prop <> LINE_BREAK_PROP_BA) and
      (last_non_cm_or_zwj_prop <> LINE_BREAK_PROP_HY)) and (cp1_prop = LINE_BREAK_PROP_GL) then
    begin
      goto continue_loop;
    end;

    {* LB13 (affected by tailoring for LB25, see example 7) *}
    if (cp1_prop = LINE_BREAK_PROP_EX) or ((last_non_cm_or_zwj_prop <> LINE_BREAK_PROP_NU) and
      ((cp1_prop = LINE_BREAK_PROP_CL) or (cp1_prop = LINE_BREAK_PROP_CP_WITHOUT_EAW_HWF) or (cp1_prop =
      LINE_BREAK_PROP_CP_WITH_EAW_HWF) or (cp1_prop = LINE_BREAK_PROP_IS) or (cp1_prop = LINE_BREAK_PROP_SY))) then
    begin
      goto continue_loop;
    end;

    {* LB14 *}
    if (last_non_sp_cm_or_zwj_prop = LINE_BREAK_PROP_OP_WITHOUT_EAW_HWF) or (last_non_sp_cm_or_zwj_prop = LINE_BREAK_PROP_OP_WITH_EAW_HWF) then
    begin
      goto continue_loop;
    end;

    {* LB15 *}
    if (last_non_sp_cm_or_zwj_prop = LINE_BREAK_PROP_QU) and ((cp1_prop = LINE_BREAK_PROP_OP_WITHOUT_EAW_HWF) or
      (cp1_prop = LINE_BREAK_PROP_OP_WITH_EAW_HWF)) then
    begin
      goto continue_loop;
    end;

    {* LB16 *}
    if ((last_non_sp_cm_or_zwj_prop = LINE_BREAK_PROP_CL) or (last_non_sp_cm_or_zwj_prop = LINE_BREAK_PROP_CP_WITHOUT_EAW_HWF) or
      (last_non_sp_cm_or_zwj_prop = LINE_BREAK_PROP_CP_WITH_EAW_HWF)) and (cp1_prop = LINE_BREAK_PROP_NS) then
    begin
      goto continue_loop;
    end;

    {* LB17 *}
    if (last_non_sp_cm_or_zwj_prop = LINE_BREAK_PROP_B2) and (cp1_prop = LINE_BREAK_PROP_B2) then
    begin
      goto continue_loop;
    end;

    {* LB18 *}
    if last_non_cm_or_zwj_prop = LINE_BREAK_PROP_SP then
    begin
      break;
    end;

    {* LB19 *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_QU) or (cp1_prop = LINE_BREAK_PROP_QU) then
    begin
      goto continue_loop;
    end;

    {* LB20 *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_CB) or (cp1_prop = LINE_BREAK_PROP_CB) then
    begin
      break;
    end;

    {* LB21 *}
    if (cp1_prop = LINE_BREAK_PROP_BA) or (cp1_prop = LINE_BREAK_PROP_HY) or (cp1_prop = LINE_BREAK_PROP_NS) or
      (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_BB) then
    begin
      goto continue_loop;
    end;

    {* LB21a *}
    if lb21a_flag and ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_HY) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_BA)) then
    begin
      goto continue_loop;
    end;

    {* LB21b *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_SY) and (cp1_prop = LINE_BREAK_PROP_HL) then
    begin
      goto continue_loop;
    end;

    {* LB22 *}
    if cp1_prop = LINE_BREAK_PROP_IN then
    begin
      goto continue_loop;
    end;

    {* LB23 *}
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_AL) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_HL)) and (cp1_prop = LINE_BREAK_PROP_NU) then
    begin
      goto continue_loop;
    end;
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_NU) and ((cp1_prop = LINE_BREAK_PROP_AL) or (cp1_prop = LINE_BREAK_PROP_HL)) then
    begin
      goto continue_loop;
    end;

    {* LB23a *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_PR) and ((cp1_prop = LINE_BREAK_PROP_ID) or (cp1_prop = LINE_BREAK_PROP_EB) or
      (cp1_prop = LINE_BREAK_PROP_EM)) then
    begin
      goto continue_loop;
    end;
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_ID) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_EB) or
      (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_EM)) and (cp1_prop = LINE_BREAK_PROP_PO) then
    begin
      goto continue_loop;
    end;

    {* LB24 *}
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_PR) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_PO)) and
      ((cp1_prop = LINE_BREAK_PROP_AL) or (cp1_prop = LINE_BREAK_PROP_HL)) then
    begin
      goto continue_loop;
    end;
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_AL) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_HL)) and
      ((cp1_prop = LINE_BREAK_PROP_PR) or (cp1_prop = LINE_BREAK_PROP_PO)) then
    begin
      goto continue_loop;
    end;

    {* LB25 (tailored with example 7) *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_PR) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_PO) then
    begin
      if cp1_prop = LINE_BREAK_PROP_NU then
      begin
        goto continue_loop;
      end;

      {* this stupid rule is the reason why we cannot
       * simply have a stateful break-detection between
       * two adjacent codepoints as we have it with
       * characters.
       *}
      herodotus_reader_copy(r, @tmp);
      herodotus_read_codepoint(@tmp, True, @cp);
      if (herodotus_read_codepoint(@tmp, True, @cp) = HERODOTUS_STATUS_SUCCESS) and ((cp1_prop = LINE_BREAK_PROP_OP_WITHOUT_EAW_HWF) or
        (cp1_prop = LINE_BREAK_PROP_OP_WITH_EAW_HWF) or (cp1_prop = LINE_BREAK_PROP_HY)) then
      begin
        if get_line_break_prop(cp) = LINE_BREAK_PROP_NU then
        begin
          goto continue_loop;
          ;
        end;
      end;
    end;
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_OP_WITHOUT_EAW_HWF) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_OP_WITH_EAW_HWF) or
      (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_HY)) and (cp1_prop = LINE_BREAK_PROP_NU) then
    begin
      goto continue_loop;
    end;
    if (lb25_level = 1) and ((cp1_prop = LINE_BREAK_PROP_NU) or (cp1_prop = LINE_BREAK_PROP_SY) or
      (cp1_prop = LINE_BREAK_PROP_IS)) then
    begin
      goto continue_loop;
    end;
    if ((lb25_level = 1) or (lb25_level = 2)) and ((cp1_prop = LINE_BREAK_PROP_NU) or (cp1_prop = LINE_BREAK_PROP_SY) or
      (cp1_prop = LINE_BREAK_PROP_IS) or (cp1_prop = LINE_BREAK_PROP_CL) or (cp1_prop = LINE_BREAK_PROP_CP_WITHOUT_EAW_HWF) or
      (cp1_prop = LINE_BREAK_PROP_CP_WITH_EAW_HWF)) then
    begin
      goto continue_loop;
    end;
    if ((lb25_level = 1) or (lb25_level = 2) or (lb25_level = 3)) and ((cp1_prop = LINE_BREAK_PROP_PO) or
      (cp1_prop = LINE_BREAK_PROP_PR)) then
    begin
      goto continue_loop;
    end;

    {* LB26 *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_JL) and ((cp1_prop = LINE_BREAK_PROP_JL) or (cp1_prop = LINE_BREAK_PROP_JV) or
      (cp1_prop = LINE_BREAK_PROP_H2) or (cp1_prop = LINE_BREAK_PROP_H3)) then
    begin
      goto continue_loop;
    end;
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_JV) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_H2)) and
      ((cp1_prop = LINE_BREAK_PROP_JV) or (cp1_prop = LINE_BREAK_PROP_JT)) then
    begin
      goto continue_loop;
    end;
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_JT) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_H3)) and (cp1_prop = LINE_BREAK_PROP_JT) then
    begin
      goto continue_loop;
    end;

    {* LB27 *}
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_JL) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_JV) or
      (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_JT) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_H2) or
      (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_H3)) and (cp1_prop = LINE_BREAK_PROP_PO) then
    begin
      goto continue_loop;
    end;
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_PR) and ((cp1_prop = LINE_BREAK_PROP_JL) or (cp1_prop = LINE_BREAK_PROP_JV) or
      (cp1_prop = LINE_BREAK_PROP_JT) or (cp1_prop = LINE_BREAK_PROP_H2) or (cp1_prop = LINE_BREAK_PROP_H3)) then
    begin
      goto continue_loop;
    end;

    {* LB28 *}
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_AL) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_HL)) and
      ((cp1_prop = LINE_BREAK_PROP_AL) or (cp1_prop = LINE_BREAK_PROP_HL)) then
    begin
      goto continue_loop;
    end;

    {* LB29 *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_IS) and ((cp1_prop = LINE_BREAK_PROP_AL) or (cp1_prop = LINE_BREAK_PROP_HL)) then
    begin
      goto continue_loop;
    end;

    {* LB30 *}
    if ((last_non_cm_or_zwj_prop = LINE_BREAK_PROP_AL) or (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_HL) or
      (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_NU)) and (cp1_prop = LINE_BREAK_PROP_OP_WITHOUT_EAW_HWF) then
    begin
      goto continue_loop;
    end;
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_CP_WITHOUT_EAW_HWF) and ((cp1_prop = LINE_BREAK_PROP_AL) or
      (cp1_prop = LINE_BREAK_PROP_HL) or (cp1_prop = LINE_BREAK_PROP_NU)) then
    begin
      goto continue_loop;
    end;

    {* LB30a *}
    if (not ri_even) and (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_RI) and (cp1_prop = LINE_BREAK_PROP_RI) then
    begin
      goto continue_loop;
    end;

    {* LB30b *}
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_EB) and (cp1_prop = LINE_BREAK_PROP_EM) then
    begin
      goto continue_loop;
    end;
    if (last_non_cm_or_zwj_prop = LINE_BREAK_PROP_BOTH_CN_EXTPICT) and (cp1_prop = LINE_BREAK_PROP_EM) then
    begin
      goto continue_loop;
    end;

    {* LB31 *}
    break;
continue_loop:;
    herodotus_read_codepoint(r, True, @cp);
    cp0_prop := cp1_prop;
  end;

  exit(herodotus_reader_number_read(r));
end;

function grapheme_next_line_break(const str: Puint_least32_t; len: size_t): size_t;cdecl;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, str, len);

  exit(next_line_break(@r));
end;

function grapheme_next_line_break_utf8(const str: pansichar; len: size_t): size_t;cdecl;
var
  r: HERODOTUS_READER;
begin

  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, str, len);

  exit(next_line_break(@r));
end;

end.
