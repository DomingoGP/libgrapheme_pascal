unit grapheme_case;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils, grapheme_types;


function grapheme_is_uppercase(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;
function grapheme_is_lowercase(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;
function grapheme_is_titlecase(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;

function grapheme_is_uppercase_utf8(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;
function grapheme_is_lowercase_utf8(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;
function grapheme_is_titlecase_utf8(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;

function grapheme_to_uppercase(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;
function grapheme_to_lowercase(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;
function grapheme_to_titlecase(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;

function grapheme_to_uppercase_utf8(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;
function grapheme_to_lowercase_utf8(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;
function grapheme_to_titlecase_utf8(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;

function graphemeUpperCase(const src: rawbytestring): rawbytestring;
function graphemeLowerCase(const src: rawbytestring): rawbytestring;
function graphemeTitleCase(const src: rawbytestring): rawbytestring;


implementation

uses
  grapheme_util, grapheme_word;


{$I grapheme_gen_case.inc}

function get_case_property(cp: uint_least32_t): case_property; inline;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
    exit(case_property(case_minor[case_major[cp shr 8] + (cp and $FF)]))
  else
    exit(CASE_PROP_OTHER);
end;


function get_case_offset(cp: uint_least32_t; const major: Puint_least16_t; const minor: Pint_least32_t): int_least32_t; inline;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
  begin
    {*
     * this value might be larger than or equal to 0x110000
     * for the special-case-mapping. This needs to be handled
     * separately
     *}
    exit(minor[major[cp shr 8] + (cp and $FF)]);
  end
  else
    exit(0);
end;

function to_case(r: PHERODOTUS_READER; w: PHERODOTUS_WRITER; final_sigma_level: uint_least8_t; const major: Puint_least16_t;
  const minor: Pint_least32_t; const sc: Pspecial_case): size_t; {inline;}
var
  tmp: HERODOTUS_READER;
  prop: case_property;
  s: herodotus_status;
  off, i: size_t;
  cp, tmp_cp: uint_least32_t;
  map: int_least32_t;
  scPtr: Pspecial_case;
begin
  while herodotus_read_codepoint(r, True, @cp) = HERODOTUS_STATUS_SUCCESS do
  begin
    if sc = @lower_special then
    begin
      {*
       * For the special Final_Sigma-rule (see
       * SpecialCasing.txt), which is the only non-localized
       * case-dependent rule, we apply a different mapping
       * when a sigma is at the end of a word.
       *
       * Before: cased case-ignorable*
       * After: not(case-ignorable* cased)
       *
       * We check the after-condition on demand, but the
       * before- condition is best checked using the
       * "level"-heuristic also used in the sentence and line
       * breaking-implementations.
       *}
      if (cp = uint32($03A3)) and  {* GREEK CAPITAL LETTER
                                       SIGMA *}
        ((final_sigma_level = 1) or (final_sigma_level = 2)) then
      begin
        {*
         * check succeeding characters by first skipping
         * all case-ignorable characters and then
         * checking if the succeeding character is
         * cased, invalidating the after-condition
         *}
        herodotus_reader_copy(r, @tmp);
        prop := NUM_CASE_PROPS;
        s := herodotus_read_codepoint(@tmp, True, @tmp_cp);
        while s = HERODOTUS_STATUS_SUCCESS do
        begin
          prop := get_case_property(tmp_cp);

          if (prop <> CASE_PROP_CASE_IGNORABLE) and (prop <> CASE_PROP_BOTH_CASED_CASE_IGNORABLE) then
          begin
            break;
          end;
          s := herodotus_read_codepoint(@tmp, True, @tmp_cp);
        end;

        {*
         * Now prop is something other than
         * case-ignorable or the source-string ended. If
         * it is something other than cased, we know
         * that the after-condition holds
         *}
        if (s <> HERODOTUS_STATUS_SUCCESS) or ((prop <> CASE_PROP_CASED) and (prop <> CASE_PROP_BOTH_CASED_CASE_IGNORABLE)) then
        begin
          {*
           * write GREEK SMALL LETTER FINAL SIGMA
           * to destination
           *}
          herodotus_write_codepoint(
            w, uint32($03C2));

          {* reset Final_Sigma-state and continue
           *}
          final_sigma_level := 0;
          continue;
        end;
      end;

      {* update state *}
      prop := get_case_property(cp);
      if ((final_sigma_level = 0) or (final_sigma_level = 1)) and ((prop = CASE_PROP_CASED) or (prop = CASE_PROP_BOTH_CASED_CASE_IGNORABLE)) then
      begin
        {* sequence has begun *}
        final_sigma_level := 1;
      end
      else if ((final_sigma_level = 1) or (final_sigma_level = 2)) and ((prop = CASE_PROP_CASE_IGNORABLE) or
        (prop = CASE_PROP_BOTH_CASED_CASE_IGNORABLE)) then
      begin
        {* case-ignorable sequence begins or continued
         *}
        final_sigma_level := 2;
      end
      else
      begin
        {* sequence broke *}
        final_sigma_level := 0;
      end;
    end;

    {* get and handle case mapping *}
    map := get_case_offset(cp, major, minor);
    if map >= int32($110000) then
    begin
      {* we have a special case and the offset in the sc-array
       * is the difference to 0x110000*}
      off := uint_least32_t(map) - uint32($110000);

      scPtr := sc;                //PASCAL CONVERSION. sc[off].cplen.
      Inc(scPtr, off);
      for i := 0 to scPtr^.cplen - 1 do
      begin
        herodotus_write_codepoint(w, scPtr^.cp[i]);
      end;
    end
    else
    begin
      {* we have a simple mapping *}
      herodotus_write_codepoint(
        w, uint_least32_t(int_least32_t(cp) + map));
    end;
  end;

  herodotus_writer_nul_terminate(w);

  exit(herodotus_writer_number_written(w));
end;


function herodotus_next_word_break(const r: PHERODOTUS_READER): size_t;
var
  tmp: HERODOTUS_READER;
begin
  herodotus_reader_copy(r, @tmp);

  if r^._type = HERODOTUS_TYPE_CODEPOINT then
    exit(grapheme_next_word_break(tmp.src, tmp.srclen))
  else  {* r->type == HERODOTUS_TYPE_UTF8 *}
    exit(grapheme_next_word_break_utf8(tmp.src, tmp.srclen));
end;

function to_titlecase(r: PHERODOTUS_READER; w: PHERODOTUS_WRITER): size_t; {inline;}
var
  prop: case_property;
  s: herodotus_status;
  cp: uint_least32_t;
  nwb: size_t;
begin
  nwb := herodotus_next_word_break(r);

  while nwb > 0 do
  begin
    herodotus_reader_push_advance_limit(r, nwb);
    s := herodotus_read_codepoint(r, False, @cp);
    while s = HERODOTUS_STATUS_SUCCESS do
    begin
      {* check if we have a cased character *}
      prop := get_case_property(cp);
      if (prop = CASE_PROP_CASED) or (prop = CASE_PROP_BOTH_CASED_CASE_IGNORABLE) then
      begin
        break;
      end
      else
      begin
        {* write the data to the output verbatim, it if
         * permits *}
        herodotus_write_codepoint(w, cp);

        {* increment reader *}
        herodotus_read_codepoint(r, True, @cp);
      end;

      s := herodotus_read_codepoint(r, False, @cp);
    end;
    if s = HERODOTUS_STATUS_END_OF_BUFFER then
    begin
      {* we are done *}
      herodotus_reader_pop_limit(r);
      break;
    end
    else if s = HERODOTUS_STATUS_SOFT_LIMIT_REACHED then
    begin
      {*
       * we did not encounter any cased character
       * up to the word break
       *}
      herodotus_reader_pop_limit(r);
      nwb := herodotus_next_word_break(r);
      continue;
    end
    else
    begin
      {*
       * we encountered a cased character before the word
       * break, convert it to titlecase
       *}
      herodotus_reader_push_advance_limit(r, herodotus_reader_next_codepoint_break(r));
      to_case(r, w, 0, title_major, title_minor, title_special);
      herodotus_reader_pop_limit(r);
    end;

    {* cast the rest of the codepoints in the word to lowercase *}
    to_case(r, w, 1, lower_major, lower_minor, lower_special);

    {* remove the limit on the word before the next iteration *}
    herodotus_reader_pop_limit(r);
    nwb := herodotus_next_word_break(r);
  end;

  herodotus_writer_nul_terminate(w);

  exit(herodotus_writer_number_written(w));
end;

function grapheme_to_uppercase(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;
var
  r: HERODOTUS_READER;
  w: HERODOTUS_WRITER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, src, srclen);
  herodotus_writer_init(@w, HERODOTUS_TYPE_CODEPOINT, dest, destlen);

  exit(to_case(@r, @w, 0, upper_major, upper_minor, upper_special));
end;


function grapheme_to_lowercase(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;
var
  r: HERODOTUS_READER;
  w: HERODOTUS_WRITER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, src, srclen);
  herodotus_writer_init(@w, HERODOTUS_TYPE_CODEPOINT, dest, destlen);

  exit(to_case(@r, @w, 0, lower_major, lower_minor, lower_special));
end;

function grapheme_to_titlecase(const src: Puint_least32_t; srclen: size_t; dest: Puint_least32_t; destlen: size_t): size_t;
var
  r: HERODOTUS_READER;
  w: HERODOTUS_WRITER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, src, srclen);
  herodotus_writer_init(@w, HERODOTUS_TYPE_CODEPOINT, dest, destlen);

  exit(to_titlecase(@r, @w));
end;




function grapheme_to_uppercase_utf8(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;
var
  r: HERODOTUS_READER;
  w: HERODOTUS_WRITER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, src, srclen);
  herodotus_writer_init(@w, HERODOTUS_TYPE_UTF8, dest, destlen);

  exit(to_case(@r, @w, 0, upper_major, upper_minor, upper_special));
end;

function grapheme_to_lowercase_utf8(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;
var
  r: HERODOTUS_READER;
  w: HERODOTUS_WRITER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, src, srclen);
  herodotus_writer_init(@w, HERODOTUS_TYPE_UTF8, dest, destlen);

  exit(to_case(@r, @w, 0, lower_major, lower_minor, lower_special));
end;

function grapheme_to_titlecase_utf8(const src: pansichar; srclen: size_t; dest: pansichar; destlen: size_t): size_t;
var
  r: HERODOTUS_READER;
  w: HERODOTUS_WRITER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, src, srclen);
  herodotus_writer_init(@w, HERODOTUS_TYPE_UTF8, dest, destlen);

  exit(to_titlecase(@r, @w));
end;


function is_case(r: PHERODOTUS_READER; const major: Puint_least16_t; const minor: Pint_least32_t; const sc: Pspecial_case;
  output: Psize_t): boolean; {inline;}
var
  off, i: size_t;
  ret: boolean;
  cp: uint_least32_t;
  map: int_least32_t;
  scPtr: Pspecial_case;
label
  done;
begin
  ret := True;
  while herodotus_read_codepoint(r, False, @cp) = HERODOTUS_STATUS_SUCCESS do
  begin
    {* get and handle case mapping *}
    map := get_case_offset(cp, major, minor);
    if map >= int32($110000) then
    begin
      {* we have a special case and the offset in the sc-array
       * is the difference to 0x110000*}
      off := uint_least32_t(map) - uint32($110000);
      scPtr := sc;                //PASCAL CONVERSION. sc[off].cplen.
      Inc(scPtr, off);
      i := 0;
      while i < scPtr^.cplen do
      begin
        if herodotus_read_codepoint(r, False, @cp) = HERODOTUS_STATUS_SUCCESS then
        begin
          if cp <> scPtr^.cp[i] then
          begin
            ret := False;
            goto done;
          end
          else
          begin
            {* move forward *}
            herodotus_read_codepoint(r, True, @cp);
          end;
        end
        else
        begin
          {*
           * input ended and we didn't see
           * any difference so far, so this
           * string is in fact okay
           *}
          ret := True;
          goto done;
        end;
        Inc(i);
      end;
    end
    else
    begin
      {* we have a simple mapping *}
      if cp <> uint_least32_t(int_least32_t(cp) + map) then
      begin
        {* we have a difference *}
        ret := False;
        goto done;
      end
      else
      begin
        {* move forward *}
        herodotus_read_codepoint(r, True, @cp);
      end;
    end;
  end;
  done:
    if output <> nil then
      output^ := herodotus_reader_number_read(r);

  exit(ret);
end;


function is_titlecase(r: PHERODOTUS_READER; output: Psize_t): boolean; {inline;}
var
  prop: case_property;
  s: herodotus_status;
  ret: boolean;
  cp: uint_least32_t;
  nwb: size_t;
label
  done;
begin
  ret := True;
  nwb := herodotus_next_word_break(r);
  while nwb > 0 do
  begin
    herodotus_reader_push_advance_limit(r, nwb);

    s := herodotus_read_codepoint(r, False, @cp);
    while s = HERODOTUS_STATUS_SUCCESS do
    begin
      {* check if we have a cased character *}
      prop := get_case_property(cp);
      if (prop = CASE_PROP_CASED) or (prop = CASE_PROP_BOTH_CASED_CASE_IGNORABLE) then
      begin
        break;
      end
      else
      begin
        {* increment reader *}
        herodotus_read_codepoint(r, True, @cp);
      end;
      s := herodotus_read_codepoint(r, False, @cp);
    end;


    if s = HERODOTUS_STATUS_END_OF_BUFFER then
    begin
      {* we are done *}
      break;
    end
    else if s = HERODOTUS_STATUS_SOFT_LIMIT_REACHED then
    begin
      {*
       * we did not encounter any cased character
       * up to the word break
       *}
      herodotus_reader_pop_limit(r);
      nwb := herodotus_next_word_break(r);
      continue;
    end
    else
    begin
      {*
       * we encountered a cased character before the word
       * break, check if it's titlecase
       *}
      herodotus_reader_push_advance_limit(
        r, herodotus_reader_next_codepoint_break(r));
      if not is_case(r, title_major, title_minor, title_special, nil) then
      begin
        ret := False;
        goto done;
      end;
      herodotus_reader_pop_limit(r);
    end;

    {* check if the rest of the codepoints in the word are lowercase
     *}
    if not is_case(r, lower_major, lower_minor, lower_special, nil) then
    begin
      ret := False;
      goto done;
    end;

    {* remove the limit on the word before the next iteration *}
    herodotus_reader_pop_limit(r);
    nwb := herodotus_next_word_break(r);
  end;
  done:
    if output <> nil then
    begin
      output^ := herodotus_reader_number_read(r);
    end;
  exit(ret);
end;


function grapheme_is_uppercase(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, src, srclen);

  exit(is_case(@r, upper_major, upper_minor, upper_special, caselen));
end;

function grapheme_is_lowercase(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, src, srclen);

  exit(is_case(@r, lower_major, lower_minor, lower_special, caselen));
end;

function grapheme_is_titlecase(const src: Puint_least32_t; srclen: size_t; caselen: Psize_t): boolean;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, src, srclen);

  exit(is_titlecase(@r, caselen));
end;

function grapheme_is_uppercase_utf8(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, src, srclen);

  exit(is_case(@r, upper_major, upper_minor, upper_special, caselen));
end;

function grapheme_is_lowercase_utf8(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, src, srclen);

  exit(is_case(@r, lower_major, lower_minor, lower_special, caselen));
end;

function grapheme_is_titlecase_utf8(const src: pansichar; srclen: size_t; caselen: Psize_t): boolean;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, src, srclen);

  exit(is_titlecase(@r, caselen));
end;


function graphemeUpperCase(const src: rawbytestring): rawbytestring;
var
  len, len2: integer;
begin
  len := length(src);
  Result := '';
  if len <= 0 then
    exit;
  //calc result len
  len2 := grapheme_to_uppercase_utf8(@src[1], len, nil, 0);
  SetLength(Result, len2);
  grapheme_to_uppercase_utf8(@src[1], len, @Result[1], len2+1);
end;

function graphemeLowerCase(const src: rawbytestring): rawbytestring;
var
  len, len2: integer;
begin
  len := length(src);
  Result := '';
  if len <= 0 then
    exit;
  //calc result len
  len2 := grapheme_to_lowercase_utf8(@src[1], len, nil, 0);
  SetLength(Result, len2);
  grapheme_to_lowercase_utf8(@src[1], len, @Result[1], len2+1);
end;

function graphemeTitleCase(const src: rawbytestring): rawbytestring;
var
  len, len2: integer;
begin
  len := length(src);
  Result := '';
  if len <= 0 then
    exit;
  //calc result len
  len2 := grapheme_to_titlecase_utf8(@src[1], len, nil, 0);
  SetLength(Result, len2);
  grapheme_to_titlecase_utf8(@src[1], len, @Result[1], len2+1);
end;

end.
