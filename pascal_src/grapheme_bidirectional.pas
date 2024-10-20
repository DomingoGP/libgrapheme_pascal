  {* See LICENSE file for copyright and license details. *}

unit grapheme_bidirectional;

{$ifdef FPC}{$mode delphi}{$endif}
interface

uses
  Classes, SysUtils, grapheme_types;

type
  Pgrapheme_bidirectional_direction = ^grapheme_bidirectional_direction;
  grapheme_bidirectional_direction = (
    GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL,
    GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR,
    GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL
    );


function grapheme_bidirectional_reorder_line(const line: Puint_least32_t; const linedata: Puint_least32_t;
    linelen: size_t; output: Puint_least32_t; outputsize: size_t): size_t;cdecl;
function grapheme_bidirectional_preprocess_paragraph(const src: Puint_least32_t; srclen: size_t;
  Aoverride: grapheme_bidirectional_direction; dest: Puint_least32_t; destlen: size_t; resolved: Pgrapheme_bidirectional_direction): size_t;cdecl;
function grapheme_bidirectional_get_line_embedding_levels(const linedata: Puint_least32_t; linelen: size_t;
  lev: Pint_least8_t; levlen: size_t): size_t;cdecl;

implementation

uses
  Math, grapheme_util, grapheme_character;

  {$I grapheme_gen_bidirectional.inc}

const
  MAX_DEPTH = 125;

type

  state_type = (
    STATE_PROP,            {* in 0..23, bidi_property *}
    STATE_PRESERVED_PROP,  {* in 0..23, preserved bidi_prop for L1-rule *}
    STATE_BRACKET_OFF,     {* in 0..255, offset in bidi_bracket *}
    STATE_LEVEL,           {* in 0..MAX_DEPTH+1:=126, embedding level *}
    STATE_PARAGRAPH_LEVEL, {* in 0..1, paragraph embedding level *}
    STATE_VISITED          {* in 0..1, visited within isolating run *});

  Tstate_lut = record
    filter_mask: uint_least32_t;
    mask_shift: size_t;
    value_offset: int_least16_t;
  end;

const
  state_lut: array[0..5] of Tstate_lut = (
    {[STATE_PROP]} (
    filter_mask: $000001F; {* 00000000 00000000 00000000 00011111 *}
    mask_shift: 0;
    value_offset: 0
    ),
    {[STATE_PRESERVED_PROP]} (
    filter_mask: $00003E0; {* 00000000 00000000 00000011 11100000 *}
    mask_shift: 5;
    value_offset: 0
    ),
    {[STATE_BRACKET_OFF]} (
    filter_mask: $003FC00; {* 00000000 00000011 11111100 00000000 *}
    mask_shift: 10;
    value_offset: 0
    ),
    {[STATE_LEVEL]} (
    filter_mask: $1FC0000; {* 00000001 11111100 00000000 00000000 *}
    mask_shift: 18;
    value_offset: -1
    ),
    {[STATE_PARAGRAPH_LEVEL]} (
    filter_mask: $2000000; {* 00000010 00000000 00000000 00000000 *}
    mask_shift: 25;
    value_offset: 0
    ),
    {[STATE_VISITED]} (
    filter_mask: $4000000; {* 00000100 00000000 00000000 00000000 *}
    mask_shift: 26;
    value_offset: 0
    ));

function get_state(t: state_type; input: uint_least32_t): int_least16_t; //inline;
var
  r:uint_least32_t;
begin
  r := input and state_lut[Ord(t)].filter_mask;
  r := r shr state_lut[Ord(t)].mask_shift;
  result := int_least16_t(r) + state_lut[Ord(t)].value_offset;
end;

procedure set_state(t: state_type; Value: int_least16_t; output: Puint_least32_t); //inline;
var
  r,r1:uint_least32_t;
begin
  r := output^ and (not (state_lut[Ord(t)].filter_mask));
  r1 := uint_least32_t(Value - state_lut[Ord(t)].value_offset) shl state_lut[Ord(t)].mask_shift;
  r1 := r1 and state_lut[Ord(t)].filter_mask;
  output^ := r or r1;
end;

type
  Toff = record
    off: size_t;
  end;

  Pisolate_runner = ^isolate_runner;

  isolate_runner = record
    buf: Puint_least32_t;
    buflen: size_t;
    start: size_t;
    prev, cur, Next: Toff;
    sos, eos: bidi_property;
    paragraph_level: uint_least8_t;
    isolating_run_level: int_least8_t;
  end;

function ir_get_previous_prop(const ir: Pisolate_runner): bidi_property; inline;
begin
  if ir^.prev.off = SIZE_MAX then
    exit(ir^.sos)
  else
    exit(bidi_property(uint_least8_t(get_state(STATE_PROP, ir^.buf[ir^.prev.off]))));
end;

function ir_get_current_prop(const ir: Pisolate_runner): bidi_property; inline;
begin
  exit(bidi_property(uint_least8_t(get_state(STATE_PROP, ir^.buf[ir^.cur.off]))));
end;

function ir_get_next_prop(const ir: Pisolate_runner): bidi_property; inline;
begin
  if ir^.Next.off = SIZE_MAX then
    exit(ir^.eos)
  else
    exit(bidi_property(uint_least8_t(get_state(STATE_PROP, ir^.buf[ir^.Next.off]))));
end;

function ir_get_current_preserved_prop(const ir: Pisolate_runner): bidi_property; inline;
begin
  exit(bidi_property(uint_least8_t(get_state(STATE_PRESERVED_PROP, ir^.buf[ir^.cur.off]))));
end;

function ir_get_current_level(const ir: Pisolate_runner): int_least8_t; inline;
begin
  exit(int_least8_t(get_state(STATE_LEVEL, ir^.buf[ir^.cur.off])));
end;

function ir_get_current_bracket_prop(const ir: Pisolate_runner): Pbracket; inline;
begin
  exit(Pbracket(@bidi_bracket[int_least8_t(get_state(STATE_BRACKET_OFF, ir^.buf[ir^.cur.off]) )])  );
end;

procedure ir_set_current_prop(const ir: Pisolate_runner; prop: bidi_property);
begin
  set_state(STATE_PROP, int_least16_t(prop), @(ir^.buf[ir^.cur.off]));
end;

procedure ir_init(buf: Puint_least32_t; buflen: size_t; off: size_t; paragraph_level: uint_least8_t; within: boolean; ir: Pisolate_runner);
var
  i: size_t;
  sos_level: int_least8_t;
begin

  {* initialize invariants *}
  ir^.buf := buf;
  ir^.buflen := buflen;
  ir^.paragraph_level := paragraph_level;
  ir^.start := off;

  {* advance off until we are at a non-removed character *}
  while off < buflen do
  begin
    if get_state(STATE_LEVEL, buf[off]) <> -1 then
    begin
      break;
    end;
    Inc(off);
  end;
  if off = buflen then
  begin
    {* we encountered no more non-removed character, terminate *}
    ir^.Next.off := SIZE_MAX;
    exit;
  end;

  {* set the isolating run level to that of the current offset *}
  ir^.isolating_run_level := int_least8_t(get_state(STATE_LEVEL, buf[off]));

  {* initialize sos and eos to dummy values *}
  ir^.eos := NUM_BIDI_PROPS;
  ir^.sos := NUM_BIDI_PROPS;

  {*
   * we write the information of the "current" state into next,
   * so that the shift-in at the first advancement moves it in
   * cur, as desired.
   *}
  ir^.Next.off := off;

  {*
   * determine the previous state but store its offset in cur.off,
   * given it's shifted in on the first advancement
   *}
  ir^.cur.off := SIZE_MAX;
  i := off;
  sos_level := -1;
  while i >= 1 do
  begin
    if get_state(STATE_LEVEL, buf[i - 1]) <> -1 then
    begin
      {*
       * we found a character that has not been
       * removed in X9
       *}
      sos_level := int_least8_t(get_state(STATE_LEVEL, buf[i - 1]));
      if within then
      begin
        {* we just take it *}
        ir^.cur.off := i;
      end;
      break;
    end;
    Dec(i);
  end;
  if sos_level = -1 then
  begin
    {*
     * there were no preceding non-removed characters, set
     * sos-level to paragraph embedding level
     *}
    sos_level := int_least8_t(paragraph_level);
  end;

  if (not within) or (ir^.cur.off = SIZE_MAX) then
  begin
    {*
     * we are at the beginning of the sequence; initialize
     * it faithfully according to the algorithm by looking
     * at the sos-level
     *}
    if (Max(sos_level, ir^.isolating_run_level) mod 2) = 0 then
    begin
      {* the higher level is even, set sos to L *}
      ir^.sos := BIDI_PROP_L;
    end
    else
    begin
      {* the higher level is odd, set sos to R *}
      ir^.sos := BIDI_PROP_R;
    end;
  end;
end;

function ir_advance(ir: Pisolate_runner): integer;
var
  prop: bidi_property;
  level, isolate_level, last_isolate_level: int_least8_t;
  i: size_t;
label
  continue_loop;
begin
  if ir^.Next.off = SIZE_MAX then
  begin
    {* the sequence is over *}
    exit(1);
  end;

  {* shift in *}
  ir^.prev.off := ir^.cur.off;
  ir^.cur.off := ir^.Next.off;

  {* mark as visited *}
  set_state(STATE_VISITED, 1, @(ir^.buf[ir^.cur.off]));

  {* initialize next state by going to the next character in the sequence
   *}
  ir^.Next.off := SIZE_MAX;

  last_isolate_level := -1;
  i := ir^.cur.off;
  isolate_level := 0;
  while i < ir^.buflen do
  begin
    level := int_least8_t(get_state(STATE_LEVEL, ir^.buf[i]));
    prop := bidi_property(uint_least8_t(get_state(STATE_PROP, ir^.buf[i])));

    if level = -1 then
    begin
      {* this is one of the ignored characters, skip *}
      goto continue_loop;
    end
    else if level = ir^.isolating_run_level then
    begin
      last_isolate_level := level;
    end;

    {* follow BD8/BD9 and P2 to traverse the current sequence *}
    if (prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_FSI) then
    begin
      {*
       * we encountered an isolate initiator, increment
       * counter, but go into processing when we
       * were not isolated before
       *}
      if isolate_level < MAX_DEPTH then
      begin
        Inc(isolate_level);
      end;
      if isolate_level <> 1 then
      begin
        goto continue_loop;
      end;
    end
    else if (prop = BIDI_PROP_PDI) and (isolate_level > 0) then
    begin
      Dec(isolate_level);

      {*
       * if the current PDI dropped the isolate-level
       * to zero, it is itself part of the isolating
       * run sequence; otherwise we simply continue.
       *}
      if isolate_level > 0 then
      begin
        goto continue_loop;
      end;
    end
    else if isolate_level > 0 then
    begin
      {* we are in an isolating sequence *}
      goto continue_loop;
    end;

    {*
     * now we either still are in our sequence or we hit
     * the eos-case as we left the sequence and hit the
     * first non-isolating-sequence character.
     *}
    if i = ir^.cur.off then
    begin
      {* we were in the first initializing round *}
      goto continue_loop;
    end
    else if level = ir^.isolating_run_level then
    begin
      {* isolate_level-skips have been handled before, we're
       * good *}
      {* still in the sequence *}
      ir^.Next.off := i;
    end
    else
    begin
      {* out of sequence or isolated, compare levels via eos
       *}
      ir^.Next.off := SIZE_MAX;
      if (Max(last_isolate_level, level) mod 2) = 0 then
      begin
        ir^.eos := BIDI_PROP_L;
      end
      else
      begin
        ir^.eos := BIDI_PROP_R;
      end;
    end;
    break;
continue_loop: ;
    Inc(i);
  end;

  if i = ir^.buflen then
  begin
    {*
     * the sequence ended before we could grab an offset.
     * we need to determine the eos-prop by comparing the
     * level of the last element in the isolating run sequence
     * with the paragraph level.
     *}
    ir^.Next.off := SIZE_MAX;
    if (Max(last_isolate_level, ir^.paragraph_level) mod 2) = 0 then
    begin
      {* the higher level is even, set eos to L *}
      ir^.eos := BIDI_PROP_L;
    end
    else
    begin
      {* the higher level is odd, set eos to R *}
      ir^.eos := BIDI_PROP_R;
    end;
  end;

  exit(0);
end;

function ir_get_last_strong_prop(const ir: Pisolate_runner): bidi_property;
var
  tmp: isolate_runner;
  last_strong_prop, prop: bidi_property;
begin
  last_strong_prop := ir^.sos;

  ir_init(ir^.buf, ir^.buflen, ir^.start, ir^.paragraph_level, False, @tmp);
  while (not (ir_advance(@tmp) <> 0)) and (tmp.cur.off < ir^.cur.off) do
  begin
    prop := ir_get_current_prop(@tmp);

    if (prop = BIDI_PROP_R) or (prop = BIDI_PROP_L) or (prop = BIDI_PROP_AL) then
    begin
      last_strong_prop := prop;
    end;
  end;

  exit(last_strong_prop);
end;

function ir_get_last_strong_or_number_prop(const ir: Pisolate_runner): bidi_property;
var
  tmp: isolate_runner;
  last_strong_or_number_prop, prop: bidi_property;
begin
  last_strong_or_number_prop := ir^.sos;
  ir_init(ir^.buf, ir^.buflen, ir^.start, ir^.paragraph_level, False, @tmp);
  while (not (ir_advance(@tmp) <> 0)) and (tmp.cur.off < ir^.cur.off) do
  begin
    prop := ir_get_current_prop(@tmp);

    if (prop = BIDI_PROP_R) or (prop = BIDI_PROP_L) or (prop = BIDI_PROP_AL) or (prop = BIDI_PROP_EN) or (prop = BIDI_PROP_AN) then
    begin
      last_strong_or_number_prop := prop;
    end;
  end;

  exit(last_strong_or_number_prop);
end;

procedure preprocess_bracket_pair(const start: Pisolate_runner; const _end: Pisolate_runner);
var
  prop, bracket_prop, last_strong_or_number_prop: bidi_property;
  ir: isolate_runner;
  strong_type_off: size_t;
begin
  {*
   * check if the bracket contains a strong type (L or R or EN or AN)
   *}
  ir := start^;
  strong_type_off := SIZE_MAX;
  bracket_prop := NUM_BIDI_PROPS;
  while (not (ir_advance(@ir) <> 0)) and (ir.cur.off < _end^.cur.off) do
  begin
    prop := ir_get_current_prop(@ir);

    if prop = BIDI_PROP_L then
    begin
      strong_type_off := ir.cur.off;
      if (ir.isolating_run_level mod 2) = 0 then
      begin
        {*
         * set the type for both brackets to L (so they
         * match the strong type they contain)
         *}
        bracket_prop := BIDI_PROP_L;
      end;
    end
    else if (prop = BIDI_PROP_R) or (prop = BIDI_PROP_EN) or (prop = BIDI_PROP_AN) then
    begin
      strong_type_off := ir.cur.off;
      if (ir.isolating_run_level mod 2) <> 0 then
      begin
        {*
         * set the type for both brackets to R (so they
         * match the strong type they contain)
         *}
        bracket_prop := BIDI_PROP_R;
      end;
    end;
  end;
  if strong_type_off = SIZE_MAX then
  begin
    {*
     * there are no strong types within the brackets and we just
     * leave the brackets as is
     *}
    exit;
  end;

  if bracket_prop = NUM_BIDI_PROPS then
  begin
    {*
     * We encountered a strong type, but it was opposite
     * to the embedding direction.
     * Check the previous strong type before the opening
     * bracket
     *}
    last_strong_or_number_prop :=
      ir_get_last_strong_or_number_prop(start);
    if (last_strong_or_number_prop = BIDI_PROP_L) and ((ir.isolating_run_level mod 2) <> 0) then
    begin
      {*
       * the previous strong type is also opposite
       * to the embedding direction, so the context
       * was established and we set the brackets
       * accordingly.
       *}
      bracket_prop := BIDI_PROP_L;
    end
    else if ((last_strong_or_number_prop = BIDI_PROP_R) or (last_strong_or_number_prop = BIDI_PROP_EN) or
      (last_strong_or_number_prop = BIDI_PROP_AN)) and ((ir.isolating_run_level mod 2) = 0) then
    begin
      {*
       * the previous strong type is also opposite
       * to the embedding direction, so the context
       * was established and we set the brackets
       * accordingly.
       *}
      bracket_prop := BIDI_PROP_R;
    end
    else
    begin
      {* set brackets to the embedding direction *}
      if (ir.isolating_run_level mod 2) = 0 then
      begin
        bracket_prop := BIDI_PROP_L;
      end
      else
      begin
        bracket_prop := BIDI_PROP_R;
      end;
    end;
  end;

  ir_set_current_prop(start, bracket_prop);
  ir_set_current_prop(_end, bracket_prop);

  {*
   * any sequence of NSMs after opening or closing brackets get
   * the same property as the one we set on the brackets
   *}
  ir := start^;
  while (not (ir_advance(@ir) <> 0)) and (ir_get_current_preserved_prop(@ir) = BIDI_PROP_NSM) do
  begin
    ir_set_current_prop(@ir, bracket_prop);
  end;
  ir := _end^;
  while (not (ir_advance(@ir) <> 0)) and (ir_get_current_preserved_prop(@ir) = BIDI_PROP_NSM) do
  begin
    ir_set_current_prop(@ir, bracket_prop);
  end;
end;

procedure preprocess_bracket_pairs(buf: Puint_least32_t; buflen: size_t; off: size_t; paragraph_level: uint_least8_t);

  {*
   * The N0-rule deals with bracket pairs that shall be determined
   * with the rule BD16. This is specified as an algorithm with a
   * stack of 63 bracket openings that are used to resolve into a
   * separate list of pairs, which is then to be sorted by opening
   * position. Thus, even though the bracketing-depth is limited
   * by 63, the algorithm, as is, requires dynamic memory
   * management.
   *
   * A naive approach (used by Fribidi) would be to screw the
   * stack-approach and simply directly determine the
   * corresponding closing bracket offset for a given opening
   * bracket, leading to O(n²) time complexity in the worst case
   * with a lot of brackets. While many brackets are not common,
   * it is still possible to find a middle ground where you obtain
   * strongly linear time complexity in most common cases:
   *
   * Instead of a stack, we use a FIFO data structure which is
   * filled with bracket openings in the order of appearance (thus
   * yielding an implicit sorting not ) at the top. If the
   * corresponding closing bracket is encountered, it is added to
   * the respective entry, making it ready to "move out" at the
   * bottom (i.e. passed to the bracket processing). Due to the
   * nature of the specified pair detection algorithm, which only
   * cares about the bracket type and nothing else (bidi class,
   * level, etc.), we can mix processing and bracket detection.
   *
   * Obviously, if you, for instance, have one big bracket pair at
   * the bottom that has not been closed yet, it will block the
   * bracket processing and the FIFO might hit its capacity limit.
   * At this point, the blockage is manually resolved using the
   * naive quadratic approach.
   *
   * To remain within the specified standard behaviour, which
   * mandates that processing of brackets should stop when the
   * bracketing-depth is at 63, we simply check in an "overflow"
   * scenario if all 63 elements in the LIFO are unfinished, which
   * corresponds with such a bracketing depth.
   *}
type
  localt = record
    complete: boolean;
    bracket_class: size_t;
    start: isolate_runner;
    _end: isolate_runner;
  end;
var
  prop: bidi_property;
  fifo: array[0..62] of localt;
  bracket_prop, tmp_bracket_prop: Pbracket;
  ir, tmp_ir: isolate_runner;
  fifo_len, i, blevel, j, k: size_t;
begin
  fifo_len := 0;

  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while (not (ir_advance(@ir) <> 0)) do
  begin
    prop := ir_get_current_prop(@ir);
    bracket_prop := ir_get_current_bracket_prop(@ir);
    if (prop = BIDI_PROP_ON) and (bracket_prop^._type = BIDI_BRACKET_OPEN) then
    begin
      if (fifo_len = length(fifo)) then
      begin
        {*
         * The FIFO is full, check first if it's
         * completely blocked (i.e. no finished
         * bracket pairs, triggering the standard
         * that mandates to abort in such a case
         *}
{$PUSH}
{$WARN 5036 off : Local variable "$1" does not seem to be initialized}

        i:=0;
        while i<fifo_len do
        begin
          if fifo[i].complete then
          begin
            break;
          end;
          Inc(i);
        end;
        if i = fifo_len then
        begin
          {* abort processing *}
          exit;
        end;
{$POP}
        {*
         * by construction, the bottom entry
         * in the FIFO is guaranteed to be
         * unfinished (given we "consume" all
         * finished bottom entries after each
         * iteration).
         *
         * iterate, starting after the opening
         * bracket, and find the corresponding
         * closing bracket.
         *
         * if we find none, just drop the FIFO
         * entry silently
         *}
        tmp_ir := fifo[0].start;
        blevel := 0;
        while not (ir_advance(@tmp_ir) <> 0) do
        begin
          tmp_bracket_prop := ir_get_current_bracket_prop(@tmp_ir);

          if (tmp_bracket_prop^._type = BIDI_BRACKET_OPEN) and (tmp_bracket_prop^._class = bracket_prop^._class) then
          begin
            {* we encountered another
             * opening bracket of the
             * same class *}
            Inc(blevel);

          end
          else if (tmp_bracket_prop^._type = BIDI_BRACKET_CLOSE) and
            (tmp_bracket_prop^._class = bracket_prop^._class) then
          begin
            {* we encountered a closing
             * bracket of the same class
             *}
            if blevel = 0 then
            begin
              {* this is the
               * corresponding
               * closing bracket
               *}
              fifo[0].complete := True;
              fifo[0]._end := ir;
            end
            else
            begin
              Dec(blevel);
            end;
          end;
        end;
        if fifo[0].complete then
        begin
          {* we found the matching bracket *}
          preprocess_bracket_pair(@(fifo[i].start), @(fifo[i]._end));
        end;

        {* shift FIFO one to the left *}
        i:= 1;
        // for i := 1 to fifo_len - 1 do
        while i<fifo_len do
        begin
          fifo[i - 1] := fifo[i];
          Inc(i);
        end;
        Dec(fifo_len);
      end;

      {* add element to the FIFO *}
      Inc(fifo_len);
      fifo[fifo_len - 1].complete := False;
      fifo[fifo_len - 1].bracket_class := bracket_prop^._class;
      fifo[fifo_len - 1].start := ir;
    end
    else if (prop = BIDI_PROP_ON) and (bracket_prop^._type = BIDI_BRACKET_CLOSE) then
    begin
      {*
       * go backwards in the FIFO, skip finished entries
       * and simply ignore (do nothing) the closing
       * bracket if we do not match anything
       *}
      //for i := fifo_len downto 1 do
      i:=fifo_len;
      while i>0 do
      begin
        if (bracket_prop^._class = fifo[i - 1].bracket_class) and (not fifo[i - 1].complete) then
        begin
          {* we have found a pair *}
          fifo[i - 1].complete := True;
          fifo[i - 1]._end := ir;

          {* remove all uncompleted FIFO elements
           * above i - 1 *}
          j := i;
          while j < fifo_len do
          begin
            if fifo[j].complete then
            begin
              Inc(j);
              continue;
            end;

            {* shift FIFO one to the left *}
            k := j + 1;
            while k<fifo_len do
            begin
              fifo[k - 1] := fifo[k];
              Inc(k);
            end;
            Dec(fifo_len);
          end;
          break;
        end;
        Dec(i);
      end;
    end;

    {* process all ready bracket pairs from the FIFO bottom *}
    while (fifo_len > 0) and fifo[0].complete do
    begin
      preprocess_bracket_pair(@(fifo[0].start), @(fifo[0]._end));

      {* shift FIFO one to the left *}
      j := 0;
      while (j + 1) < fifo_len do
      begin
        fifo[j] := fifo[j + 1];
        Inc(j);
      end;
      Dec(fifo_len);
    end;
  end;

  {*
   * afterwards, we still might have unfinished bracket pairs
   * that will remain as such, but the subsequent finished pairs
   * also need to be taken into account, so we go through the
   * FIFO once more and process all finished pairs
   *}
  i:=0;
  while i<fifo_len do
  begin
    if fifo[i].complete then
    begin
      preprocess_bracket_pair(@(fifo[i].start), @(fifo[i]._end));
    end;
    inc(i);
  end;
end;

function preprocess_isolating_run_sequence(buf: Puint_least32_t; buflen: size_t; off: size_t;
  paragraph_level: uint_least8_t): size_t;
var
  sequence_prop, prop: bidi_property;
  ir, tmp: isolate_runner;
  runsince, sequence_end: size_t;
begin
  {* W1 *}
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while not (ir_advance(@ir) <> 0) do
  begin
    if (ir_get_current_prop(@ir) = BIDI_PROP_NSM) then
    begin
      prop := ir_get_previous_prop(@ir);

      if (prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_FSI) or (prop = BIDI_PROP_PDI) then
      begin
        ir_set_current_prop(@ir, BIDI_PROP_ON);
      end
      else
      begin
        ir_set_current_prop(@ir, prop);
      end;
    end;
  end;

  {* W2 *}
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while (not (ir_advance(@ir) <> 0)) do
  begin
    if (ir_get_current_prop(@ir) = BIDI_PROP_EN) and (ir_get_last_strong_prop(@ir) = BIDI_PROP_AL) then
    begin
      ir_set_current_prop(@ir, BIDI_PROP_AN);
    end;
  end;

  {* W3 *}
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while (not (ir_advance(@ir) <> 0)) do
  begin
    if ir_get_current_prop(@ir) = BIDI_PROP_AL then
    begin
      ir_set_current_prop(@ir, BIDI_PROP_R);
    end;
  end;

  {* W4 *}
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while (not (ir_advance(@ir) <> 0)) do
  begin
    if (ir_get_previous_prop(@ir) = BIDI_PROP_EN) and
     ((ir_get_current_prop(@ir) = BIDI_PROP_ES) or (ir_get_current_prop(@ir) = BIDI_PROP_CS)
     ) and
      (ir_get_next_prop(@ir) = BIDI_PROP_EN) then
    begin
      ir_set_current_prop(@ir, BIDI_PROP_EN);
    end;

    if (ir_get_previous_prop(@ir) = BIDI_PROP_AN) and (ir_get_current_prop(@ir) = BIDI_PROP_CS) and (ir_get_next_prop(@ir) = BIDI_PROP_AN) then
    begin
      ir_set_current_prop(@ir, BIDI_PROP_AN);
    end;
  end;

  {* W5 *}
  runsince := SIZE_MAX;
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while (not (ir_advance(@ir) <> 0)) do
  begin
    if ir_get_current_prop(@ir) = BIDI_PROP_ET then
    begin
      if runsince = SIZE_MAX then
      begin
        {* a new run has begun *}
        runsince := ir.cur.off;
      end;
    end
    else if ir_get_current_prop(@ir) = BIDI_PROP_EN then
    begin
      {* set the preceding sequence *}
      if runsince <> SIZE_MAX then
      begin
        ir_init(buf, buflen, runsince, paragraph_level,
          (runsince > off), @tmp);
        while (not (ir_advance(@tmp) <> 0)) and (tmp.cur.off < ir.cur.off) do
        begin
          ir_set_current_prop(@tmp, BIDI_PROP_EN);
        end;
        runsince := SIZE_MAX;
      end
      else
      begin
        ir_init(buf, buflen, ir.cur.off,
          paragraph_level, (ir.cur.off > off), @tmp);
        ir_advance(@tmp);
      end;
      {* follow the succeeding sequence *}
      while (not (ir_advance(@tmp) <> 0)) do
      begin
        if ir_get_current_prop(@tmp) <> BIDI_PROP_ET then
        begin
          break;
        end;
        ir_set_current_prop(@tmp, BIDI_PROP_EN);
      end;
    end
    else
    begin
      {* sequence ended *}
      runsince := SIZE_MAX;
    end;
  end;

  {* W6 *}
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while not (ir_advance(@ir) <> 0) do
  begin
    prop := ir_get_current_prop(@ir);

    if (prop = BIDI_PROP_ES) or (prop = BIDI_PROP_ET) or (prop = BIDI_PROP_CS) then
    begin
      ir_set_current_prop(@ir, BIDI_PROP_ON);
    end;
  end;

  {* W7 *}
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while not (ir_advance(@ir) <> 0) do
  begin
    if (ir_get_current_prop(@ir) = BIDI_PROP_EN) and (ir_get_last_strong_prop(@ir) = BIDI_PROP_L) then
    begin
      ir_set_current_prop(@ir, BIDI_PROP_L);
    end;
  end;

  {* N0 *}
  preprocess_bracket_pairs(buf, buflen, off, paragraph_level);

  {* N1 *}
  sequence_end := SIZE_MAX;
  sequence_prop := NUM_BIDI_PROPS;
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while not (ir_advance(@ir) <> 0) do
  begin
    if (sequence_end = SIZE_MAX) then
    begin
      prop := ir_get_current_prop(@ir);

      if (prop = BIDI_PROP_B) or (prop = BIDI_PROP_S) or (prop = BIDI_PROP_WS) or (prop = BIDI_PROP_ON) or
        (prop = BIDI_PROP_FSI) or (prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_PDI) then
      begin
        {* the current character is an NI (neutral
         * or isolate) *}

        {* scan ahead to the end of the NI-sequence
         *}
        ir_init(buf, buflen, ir.cur.off,
          paragraph_level, (ir.cur.off > off), @tmp);
        while not (ir_advance(@tmp) <> 0) do
        begin
          prop := ir_get_next_prop(@tmp);

          if (prop <> BIDI_PROP_B) and (prop <> BIDI_PROP_S) and (prop <> BIDI_PROP_WS) and (prop <> BIDI_PROP_ON) and
            (prop <> BIDI_PROP_FSI) and (prop <> BIDI_PROP_LRI) and (prop <> BIDI_PROP_RLI) and (prop <> BIDI_PROP_PDI) then
          begin
            break;
          end;
        end;

        {*
         * check what follows and see if the text
         * has the same direction on both sides
         *}
        if (ir_get_previous_prop(@ir) = BIDI_PROP_L) and (ir_get_next_prop(@tmp) = BIDI_PROP_L) then
        begin
          sequence_end := tmp.cur.off;
          sequence_prop := BIDI_PROP_L;
        end
        else if ((ir_get_previous_prop(@ir) = BIDI_PROP_R) or
          (ir_get_previous_prop(@ir) = BIDI_PROP_EN) or (ir_get_previous_prop(@ir) =
          BIDI_PROP_AN)) and ((ir_get_next_prop(@tmp) = BIDI_PROP_R) or
          (ir_get_next_prop(@tmp) = BIDI_PROP_EN) or (ir_get_next_prop(@tmp) =
          BIDI_PROP_AN)) then
        begin
          sequence_end := tmp.cur.off;
          sequence_prop := BIDI_PROP_R;
        end;
      end;
    end;

    if sequence_end <> SIZE_MAX then
    begin
      if ir.cur.off <= sequence_end then
      begin
        ir_set_current_prop(@ir, sequence_prop);
      end
      else
      begin
        {* end of sequence, reset *}
        sequence_end := SIZE_MAX;
        sequence_prop := NUM_BIDI_PROPS;
      end;
    end;
  end;

  {* N2 *}
  ir_init(buf, buflen, off, paragraph_level, False, @ir);
  while not (ir_advance(@ir) <> 0) do
  begin
    prop := ir_get_current_prop(@ir);

    if (prop = BIDI_PROP_B) or (prop = BIDI_PROP_S) or (prop = BIDI_PROP_WS) or (prop = BIDI_PROP_ON) or
      (prop = BIDI_PROP_FSI) or (prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_PDI) then
    begin
      {* N2 *}
      if (ir_get_current_level(@ir) mod 2) = 0 then
      begin
        {* even embedding level *}
        ir_set_current_prop(@ir, BIDI_PROP_L);
      end
      else
      begin
        {* odd embedding level *}
        ir_set_current_prop(@ir, BIDI_PROP_R);
      end;
    end;
  end;

  exit(0);
end;

function get_isolated_paragraph_level(const state: Puint_least32_t; statelen: size_t): uint_least8_t;
var
  prop: bidi_property;
  isolate_level: int_least8_t;
  stateoff: size_t;
label
  continue_loop;
begin
  {* determine paragraph level (rules P1-P3) and terminate on PDI *}
  stateoff := 0;
  isolate_level := 0;
  while stateoff < statelen do
  begin
    prop := bidi_property(uint_least8_t(get_state(STATE_PROP, state[stateoff])));

    if (prop = BIDI_PROP_PDI) and (isolate_level = 0) then
    begin
      {*
       * we are in a FSI-subsection of a paragraph and
       * matched with the terminating PDI
       *}
      break;
    end;

    {* BD8/BD9 *}
    if ((prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_FSI)) and (isolate_level < MAX_DEPTH) then
    begin
      {* we hit an isolate initiator, increment counter *}
      Inc(isolate_level);
    end
    else if (prop = BIDI_PROP_PDI) and (isolate_level > 0) then
    begin
      Dec(isolate_level);
    end;

    {* P2 *}
    if isolate_level > 0 then
    begin
      goto  continue_loop;
    end;

    {* P3 *}
    if prop = BIDI_PROP_L then
    begin
      exit(0);
    end
    else if (prop = BIDI_PROP_AL) or (prop = BIDI_PROP_R) then
    begin
      exit(1);
    end;
continue_loop: ;
    Inc(stateoff);
  end;

  exit(0);
end;

function get_bidi_property(cp: uint_least32_t): uint_least8_t; inline;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
  begin
    exit((bidi_minor[bidi_major[cp shr 8] + (cp and $ff)]) and $1F {* 00011111 *});
  end
  else
  begin
    exit(uint_least8_t(BIDI_PROP_L));
  end;
end;

function get_paragraph_level(_override: grapheme_bidirectional_direction; const r: PHERODOTUS_READER): uint_least8_t;
var
  tmp: HERODOTUS_READER;
  prop: bidi_property;
  isolate_level: int_least8_t;
  cp: uint_least32_t;
begin
  {* check overrides first according to rule HL1 *}
  if _override = GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR then
  begin
    exit(0);
  end
  else if _override = GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL then
  begin
    exit(1);
  end;

  {* copy reader into temporary reader *}
  herodotus_reader_copy(r, @tmp);

  {* determine paragraph level (rules P1-P3) *}
  isolate_level := 0;
  while herodotus_read_codepoint(@tmp, True, @cp) = HERODOTUS_STATUS_SUCCESS do
  begin
    prop := bidi_property(get_bidi_property(cp));

    {* BD8/BD9 *}
    if ((prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_FSI)) and (isolate_level < MAX_DEPTH) then
    begin
      {* we hit an isolate initiator, increment counter *}
      Inc(isolate_level);
    end
    else if (prop = BIDI_PROP_PDI) and (isolate_level > 0) then
    begin
      Dec(isolate_level);
    end;

    {* P2 *}
    if isolate_level > 0 then
    begin
      continue;
    end;

    {* P3 *}
    if prop = BIDI_PROP_L then
    begin
      exit(0);
    end
    else if (prop = BIDI_PROP_AL) or (prop = BIDI_PROP_R) then
    begin
      exit(1);
    end;
  end;

  exit(0);
end;

procedure preprocess_paragraph(paragraph_level: uint_least8_t; buf: Puint_least32_t; buflen: size_t);
type
  Plocalt = ^localt;

  localt = record
    level: int_least8_t;
    _override: grapheme_bidirectional_direction;
    directional_isolate: boolean;
  end;
var
  prop: bidi_property;
  level: int_least8_t;
  directional_status: array[0..MAX_DEPTH + 2 - 1] of localt;
  dirstat, prevdirstat: Plocalt;

  overflow_isolate_count, overflow_embedding_count, valid_isolate_count, bufoff, i, runsince: size_t;
label
  again;
begin
  dirstat := @directional_status[0];
  {* X1 *}
  dirstat^.level := int_least8_t(paragraph_level);
  dirstat^._override := GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
  dirstat^.directional_isolate := False;
  overflow_isolate_count := 0;
  overflow_embedding_count := 0;
  valid_isolate_count := 0;

  bufoff :=0;
  while bufoff < buflen do
  begin
    prop := bidi_property(uint_least8_t(get_state(STATE_PROP, buf[bufoff])));

    {* set paragraph level we need for line-level-processing *}
    set_state(STATE_PARAGRAPH_LEVEL, paragraph_level, @(buf[bufoff]));
again: ;
    if prop = BIDI_PROP_RLE then
    begin
      {* X2 *}
      if ((dirstat^.level + byte((dirstat^.level mod 2) <> 0) + 1) <= MAX_DEPTH) and (overflow_isolate_count = 0) and
        (overflow_embedding_count = 0) then
      begin
        {* valid RLE *}
        prevdirstat := dirstat;
        Inc(dirstat);
        dirstat^.level :=
          prevdirstat^.level + byte((prevdirstat^.level mod 2) <> 0) + 1;
        dirstat^._override :=
          GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
        dirstat^.directional_isolate := False;
      end
      else
      begin
        {* overflow RLE *}
        overflow_embedding_count := overflow_embedding_count + byte(overflow_isolate_count = 0);
      end;
    end
    else if prop = BIDI_PROP_LRE then
    begin
      {* X3 *}
      if ((dirstat^.level + byte((dirstat^.level mod 2) = 0) + 1) <= MAX_DEPTH) and (overflow_isolate_count = 0) and
        (overflow_embedding_count = 0) then
      begin
        {* valid LRE *}
        prevdirstat := dirstat;
        Inc(dirstat);
        dirstat^.level :=
          prevdirstat^.level + byte((prevdirstat^.level mod 2) = 0) + 1;
        dirstat^._override :=
          GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
        dirstat^.directional_isolate := False;
      end
      else
      begin
        {* overflow LRE *}
        overflow_embedding_count := overflow_embedding_count + byte(overflow_isolate_count = 0);
      end;
    end
    else if prop = BIDI_PROP_RLO then
    begin
      {* X4 *}
      if ((dirstat^.level + byte((dirstat^.level mod 2) <> 0) + 1) <= MAX_DEPTH) and (overflow_isolate_count = 0) and
        (overflow_embedding_count = 0) then
      begin
        {* valid RLO *}
        prevdirstat := dirstat;
        Inc(dirstat);
        dirstat^.level :=
          prevdirstat^.level + byte((prevdirstat^.level mod 2) <> 0) + 1;
        dirstat^._override :=
          GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL;
        dirstat^.directional_isolate := False;
      end
      else
      begin
        {* overflow RLO *}
        overflow_embedding_count := overflow_embedding_count + byte(overflow_isolate_count = 0);
      end;
    end
    else if prop = BIDI_PROP_LRO then
    begin
      {* X5 *}
      if ((dirstat^.level + byte(((dirstat^.level mod 2)) = 0) + 1) <= MAX_DEPTH) and (overflow_isolate_count = 0) and
        (overflow_embedding_count = 0) then
      begin
        {* valid LRE *}
        prevdirstat := dirstat;
        Inc(dirstat);
        dirstat^.level :=
          prevdirstat^.level + byte((prevdirstat^.level mod 2) = 0) + 1;
        dirstat^._override :=
          GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR;
        dirstat^.directional_isolate := False;
      end
      else
      begin
        {* overflow LRO *}
        overflow_embedding_count := overflow_embedding_count + byte((overflow_isolate_count = 0));
      end;
    end
    else if prop = BIDI_PROP_RLI then
    begin
      {* X5a *}
      set_state(STATE_LEVEL, dirstat^.level, @(buf[bufoff]));
      if dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_L), @(buf[bufoff]));
      end
      else if (dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL) then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_R), @(buf[bufoff]));
      end;

      if ((dirstat^.level + byte(((dirstat^.level mod 2) <> 0)) + 1) <= MAX_DEPTH) and (overflow_isolate_count = 0) and
        (overflow_embedding_count = 0) then
      begin
        {* valid RLI *}
        Inc(valid_isolate_count);
        prevdirstat := dirstat;
        Inc(dirstat);
        dirstat^.level :=
          prevdirstat^.level + byte(((prevdirstat^.level mod 2) <> 0)) + 1;
        dirstat^._override := GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
        dirstat^.directional_isolate := True;
      end
      else
      begin
        {* overflow RLI *}
        Inc(overflow_isolate_count);
      end;
    end
    else if prop = BIDI_PROP_LRI then
    begin
      {* X5b *}
      set_state(STATE_LEVEL, dirstat^.level, @(buf[bufoff]));
      if (dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR) then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_L), @(buf[bufoff]));
      end
      else if dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_R), @(buf[bufoff]));
      end;

      if ((dirstat^.level + byte((dirstat^.level mod 2) = 0) + 1) <= MAX_DEPTH) and (overflow_isolate_count = 0) and
        (overflow_embedding_count = 0) then
      begin
        {* valid LRI *}
        Inc(valid_isolate_count);

        prevdirstat := dirstat;
        Inc(dirstat);
        dirstat^.level :=
          prevdirstat^.level + byte((prevdirstat^.level mod 2) = 0) + 1;
        dirstat^._override :=
          GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
        dirstat^.directional_isolate := True;
      end
      else
      begin
        {* overflow LRI *}
        Inc(overflow_isolate_count);
      end;
    end
    else if prop = BIDI_PROP_FSI then
    begin
      {* X5c *}
      if get_isolated_paragraph_level(buf + (bufoff + 1), buflen - (bufoff + 1)) = 1 then
      begin
        prop := BIDI_PROP_RLI;
        goto again;
      end
      else
      begin {* ... = 0 *}
        prop := BIDI_PROP_LRI;
        goto again;
      end;
    end
    else if (prop <> BIDI_PROP_B) and (prop <> BIDI_PROP_BN) and (prop <> BIDI_PROP_PDF) and (prop <> BIDI_PROP_PDI) then
    begin
      {* X6 *}
      set_state(STATE_LEVEL, dirstat^.level, @(buf[bufoff]));
      if dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_L), @(buf[bufoff]));
      end
      else if dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_R), @(buf[bufoff]));
      end;
    end
    else if prop = BIDI_PROP_PDI then
    begin
      {* X6a *}
      if overflow_isolate_count > 0 then
      begin
        {* PDI matches an overflow isolate initiator
         *}
        Dec(overflow_isolate_count);
      end
      else if valid_isolate_count > 0 then
      begin
        {* PDI matches a normal isolate initiator *}
        overflow_embedding_count := 0;
        while (dirstat^.directional_isolate = False) and (dirstat > @directional_status[0]) do
        begin
          {*
           * we are safe here as given the
           * valid isolate count is positive
           * there must be a stack-entry
           * with positive directional
           * isolate status, but we take
           * no chances and include an
           * explicit check
           *
           * POSSIBLE OPTIMIZATION: Whenever
           * we push on the stack, check if it
           * has the directional isolate
           * status true and store a pointer
           * to it so we can jump to it very
           * quickly.
           *}
          Dec(dirstat);
        end;

        {*
         * as above, the following check is not
         * necessary, given we are guaranteed to
         * have at least one stack entry left,
         * but it's better to be safe
         *}
        if dirstat > @directional_status[0] then
        begin
          Dec(dirstat);
        end;
        Dec(valid_isolate_count);
      end;

      set_state(STATE_LEVEL, dirstat^.level, @(buf[bufoff]));
      if dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_L), @(buf[bufoff]));
      end
      else if dirstat^._override = GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL then
      begin
        set_state(STATE_PROP, int_least16_t(BIDI_PROP_R), @(buf[bufoff]));
      end;
    end
    else if prop = BIDI_PROP_PDF then
    begin
      {* X7 *}
      if overflow_isolate_count > 0 then
      begin
        {* do nothing *}
      end
      else if overflow_embedding_count > 0 then
      begin
        Dec(overflow_embedding_count);
      end
      else if (dirstat^.directional_isolate = False) and (dirstat > @directional_status[0]) then
      begin
        Dec(dirstat);
      end;
    end
    else if prop = BIDI_PROP_B then
    begin
      {* X8 *}
      set_state(STATE_LEVEL, paragraph_level, @(buf[bufoff]));
    end;

    {* X9 *}
    if (prop = BIDI_PROP_RLE) or (prop = BIDI_PROP_LRE) or (prop = BIDI_PROP_RLO) or (prop = BIDI_PROP_LRO) or
      (prop = BIDI_PROP_PDF) or (prop = BIDI_PROP_BN) then
    begin
      set_state(STATE_LEVEL, -1, @(buf[bufoff]));
    end;
    Inc(bufoff);
  end;

  {* X10 (W1-W7, N0-N2) *}
  bufoff := 0;
  while bufoff < buflen do
  begin
    if (get_state(STATE_VISITED, buf[bufoff]) = 0) and (get_state(STATE_LEVEL, buf[bufoff]) <> -1) then
    begin
      bufoff := bufoff + preprocess_isolating_run_sequence(buf, buflen, bufoff, paragraph_level);
    end;
    Inc(bufoff);
  end;

  {*
   * I1-I2 (given our sequential approach to processing the
   * isolating run sequences, we apply this rule separately)
   *}
  bufoff:=0;
  while bufoff < buflen do
  begin
    level := int_least8_t(get_state(STATE_LEVEL, buf[bufoff]));
    prop := bidi_property(uint_least8_t(get_state(STATE_PROP, buf[bufoff])));

    if (level mod 2) = 0 then
    begin
      {* even level *}
      if (prop = BIDI_PROP_R) then
      begin
        set_state(STATE_LEVEL, level + 1, @(buf[bufoff]));
      end
      else if (prop = BIDI_PROP_AN) or (prop = BIDI_PROP_EN) then
      begin
        set_state(STATE_LEVEL, level + 2, @(buf[bufoff]));
      end;
    end
    else
    begin
      {* odd level *}
      if (prop = BIDI_PROP_L) or (prop = BIDI_PROP_EN) or (prop = BIDI_PROP_AN) then
      begin
        set_state(STATE_LEVEL, level + 1, @(buf[bufoff]));
      end;
    end;
    inc(bufoff);
  end;

  {* L1 (rules 1-3) *}
  runsince := SIZE_MAX;
  bufoff:=0;
  while bufoff < buflen do
  begin
    level := int_least8_t(get_state(STATE_LEVEL, buf[bufoff]));
    prop := bidi_property(uint_least8_t(get_state(STATE_PRESERVED_PROP, buf[bufoff])));

    if level = -1 then
    begin
      {* ignored character *}
      inc(bufoff);
      continue;
    end;

    {* rules 1 and 2 *}
    if (prop = BIDI_PROP_S) or (prop = BIDI_PROP_B) then
    begin
      set_state(STATE_LEVEL, paragraph_level, @(buf[bufoff]));
    end;

    {* rule 3 *}
    if (prop = BIDI_PROP_WS) or (prop = BIDI_PROP_FSI) or (prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_PDI) then
    begin
      if runsince = SIZE_MAX then
      begin
        {* a new run has begun *}
        runsince := bufoff;
      end;
    end
    else if ((prop = BIDI_PROP_S) or (prop = BIDI_PROP_B)) and (runsince <> SIZE_MAX) then
    begin
      {*
       * we hit a segment or paragraph separator in a
       * sequence, reset sequence-levels
       *}
      i:= runsince;
      while i < bufoff do
      begin
        if get_state(STATE_LEVEL, buf[i]) <> -1 then
        begin
          set_state(STATE_LEVEL, paragraph_level, @(buf[i]));
        end;
        inc(i);
      end;
      runsince := SIZE_MAX;
    end
    else
    begin
      {* sequence ended *}
      runsince := SIZE_MAX;
    end;
    inc(bufoff);
  end;

  if runsince <> SIZE_MAX then
  begin
    {*
     * this is the end of the paragraph and we
     * are in a run
     *}
    i:= runsince;
    while i < buflen do
    begin
      if get_state(STATE_LEVEL, buf[i]) <> -1 then
      begin
        set_state(STATE_LEVEL, paragraph_level, @(buf[i]));
      end;
      inc(i);
    end;
    runsince := SIZE_MAX;
  end;
end;

function get_bidi_bracket_off(cp: uint_least32_t): uint_least8_t; inline;
begin
  if cp <= GRAPHEME_LAST_CODEPOINT then
    exit( uint_least8_t(SarLongInt(bidi_minor[bidi_major[cp shr 8] + (cp and $ff)],5)) )
  else
    exit(0);
end;

function preprocess(r: PHERODOTUS_READER; Aoverride: grapheme_bidirectional_direction; buf: Puint_least32_t; buflen: size_t;
  resolved: Pgrapheme_bidirectional_direction): size_t;
var
  tmp: HERODOTUS_READER;
  bufoff, bufsize, paragraph_len: size_t;
  cp: uint_least32_t;
  paragraph_level: uint_least8_t;
begin
  {* determine length and level of the paragraph *}
  herodotus_reader_copy(r, @tmp);
  while herodotus_read_codepoint(@tmp, True, @cp) = HERODOTUS_STATUS_SUCCESS do
  begin
    {* break on paragraph separator *}
    if get_bidi_property(cp) = Ord(BIDI_PROP_B) then
    begin
      break;
    end;
  end;
  paragraph_len := herodotus_reader_number_read(@tmp);
  paragraph_level := get_paragraph_level(Aoverride, r);

  if resolved <> nil then
  begin
    {* store resolved paragraph level in output variable *}
    {* TODO use enum-type *}
    if paragraph_level = 0 then
    begin
      resolved^ := GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR;
    end
    else
      resolved^ := GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL;
  end;

  if buf = nil then
  begin
    {* see below for exit value reasoning *}
    exit(paragraph_len);
  end;

  {*
   * the first step is to determine the bidirectional properties
   * and store them in the buffer
   *}
  bufoff := 0;
  while (bufoff < paragraph_len) and (herodotus_read_codepoint(r, True, @cp) = HERODOTUS_STATUS_SUCCESS) do
  begin
    if bufoff < buflen then
    begin
      {*
       * actually only do something when we have
       * space in the level-buffer. We continue
       * the iteration to be able to give a good
       * exit value
       *}
      set_state(STATE_PROP, uint_least8_t(get_bidi_property(cp)), @(buf[bufoff]));
      set_state(STATE_BRACKET_OFF, get_bidi_bracket_off(cp), @(buf[bufoff]));
      set_state(STATE_LEVEL, 0, @(buf[bufoff]));
      set_state(STATE_PARAGRAPH_LEVEL, 0, @(buf[bufoff]));
      set_state(STATE_VISITED, 0, @(buf[bufoff]));
      set_state(STATE_PRESERVED_PROP, uint_least8_t(get_bidi_property(cp)), @(buf[bufoff]));
    end;
    Inc(bufoff);
  end;
  bufsize := herodotus_reader_number_read(r);
  bufoff:=0;
  while bufoff < bufsize do
  begin
    if (get_state(STATE_PROP, buf[bufoff]) <> Ord(BIDI_PROP_B)) and (bufoff <> (bufsize - 1)) then
    begin
      inc(bufoff);
      continue;
    end;

    {*
     * we either encountered a paragraph terminator or this
     * is the last character in the string.
     * Call the paragraph handler on the paragraph, including
     * the terminating character or last character of the
     * string respectively
     *}
    preprocess_paragraph(paragraph_level, buf, bufoff + 1);
    break;
  end;

  {*
   * we exit the number of total bytes read, as the function
   * should indicate if the given level-buffer is too small
   *}
  exit(herodotus_reader_number_read(r));
end;

function grapheme_bidirectional_preprocess_paragraph(const src: Puint_least32_t; srclen: size_t;
  Aoverride: grapheme_bidirectional_direction; dest: Puint_least32_t; destlen: size_t; resolved: Pgrapheme_bidirectional_direction): size_t;cdecl;
var
  r: HERODOTUS_READER;
begin
  herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, src, srclen);
  result := preprocess(@r, Aoverride, dest, destlen, resolved);
end;

type
  func_get_Level = function(const p1: Pointer; p2: size_t): int_least8_t;
  proc_set_level = procedure(p1: Pointer; p2: size_t; p3: int_least8_t);

function get_line_embedding_levels(const linedata: Puint_least32_t; linelen: size_t; get_level: func_get_Level;
  set_level: proc_set_level; lev: Pointer; levsize: size_t; skipignored: boolean): size_t;
var
  prop: bidi_property;
  i, levlen, runsince: size_t;
  level, runlevel: int_least8_t;
begin
  {* rule L1.4 *}
  runsince := SIZE_MAX;
  runlevel := -1;
  levlen := 0;
  i:=0;
  while i<linelen do
  begin
    level := int_least8_t(get_state(STATE_LEVEL, linedata[i]));
    prop := bidi_property(uint_least8_t(get_state(STATE_PRESERVED_PROP, linedata[i])));

    {* write level into level array if we still have space *}
    if (level <> -1) or (skipignored = False) then
    begin
      if levlen <= levsize then
      begin
        set_level(lev, levlen, level);
      end;
      Inc(levlen);
    end;

    if level = -1 then
    begin
      {* ignored character *}
      inc(i);
      continue;
    end;

    if (prop = BIDI_PROP_WS) or (prop = BIDI_PROP_FSI) or (prop = BIDI_PROP_LRI) or (prop = BIDI_PROP_RLI) or (prop = BIDI_PROP_PDI) then
    begin
      if runsince = SIZE_MAX then
      begin
        {* a new run has begun *}
        runsince := levlen - 1; {* levlen > 0 *}
        runlevel := int_least8_t(get_state(STATE_PARAGRAPH_LEVEL, linedata[i]));
      end;
    end
    else
    begin
      {* sequence ended *}
      runsince := SIZE_MAX;
      runlevel := -1;
    end;
    inc(i);
  end;

  if runsince <> SIZE_MAX then
  begin
    {*
     * we hit the end of the line but were in a run;
     * reset the line levels to the paragraph level
     *}
    i:=runsince;
    while i < Min(linelen, levlen) do
    begin
      if get_level(lev, i) <> -1 then
      begin
        set_level(lev, i, runlevel);
      end;
      inc(i);
    end;
  end;
  exit(levlen);
end;

function get_level_int8(const lev: Pointer; off: size_t): int_least8_t; inline;
begin
  exit(Pint_least8_t(lev)[off]);
end;

procedure set_level_int8(lev: Pointer; off: size_t; Value: int_least8_t); inline;
begin
  Pint_least8_t(lev)[off] := Value;
end;

function grapheme_bidirectional_get_line_embedding_levels(const linedata: Puint_least32_t; linelen: size_t;
  lev: Pint_least8_t; levlen: size_t): size_t;cdecl;
begin
  exit(get_line_embedding_levels(linedata, linelen, get_level_int8, set_level_int8, lev, levlen, False));
end;

function get_level_uint32(const lev: Pointer; off: size_t): int_least8_t; inline;
begin
  exit(int_least8_t(SarLongInt(Puint_least32_t(lev)[off] and uint32($1FE00000),21)) - 1);
end;

procedure set_level_uint32(lev: Pointer; off: size_t; Value: int_least8_t); inline;
begin
  Puint_least32_t(lev)[off] := Puint_least32_t(lev)[off] xor (Puint_least32_t(lev)[off] and uint32($1FE00000));
  Puint_least32_t(lev)[off] := Puint_least32_t(lev)[off] or ((uint_least32_t(Value + 1)) shl 21);
end;

function get_mirror_offset(cp: uint_least32_t): int_least16_t; inline;
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

function grapheme_bidirectional_reorder_line(const line: Puint_least32_t; const linedata: Puint_least32_t;
  linelen: size_t; output: Puint_least32_t; outputsize: size_t): size_t;cdecl;
var
  i, outputlen, First, last, j, k, l {*, laststart*}: size_t;
  level, min_odd_level, max_level: int_least8_t;
  tmp: uint_least32_t;
begin
  min_odd_level := MAX_DEPTH + 2;
  max_level := 0;
  {* write output characters (and apply possible mirroring) *}
  outputlen := 0;
  i:=0;
  while i < linelen do
  begin
    if get_state(STATE_LEVEL, linedata[i]) <> -1 then
    begin
      if outputlen < outputsize then
      begin
        output[outputlen] :=
          uint_least32_t((int_least32_t(line[i]) + get_mirror_offset(line[i])));
      end;
      Inc(outputlen);
    end;
    inc(i);
  end;
  if outputlen >= outputsize then
  begin
    {* clear output buffer *}
    i:=0;
    while i<outputsize do
    begin
      output[i] := GRAPHEME_INVALID_CODEPOINT;
      inc(i);
    end;

    {* exit required size *}
    exit(outputlen);
  end;

  {*
   * write line embedding levels as metadata and codepoints into the
   * output
   *}
  get_line_embedding_levels(linedata, linelen, get_level_uint32,
    set_level_uint32, output, outputsize, True);

  {* determine level range *}
  i:=0;
  while i<outputlen do
  begin
    level := get_level_uint32(output, i);

    if level = -1 then
    begin
      {* ignored character *}
      Inc(i);
      continue;
    end;

    if ((level mod 2) = 1) and (level < min_odd_level) then
    begin
      min_odd_level := level;
    end;
    if (level > max_level) then
    begin
      max_level := level;
    end;
    Inc(i);
  end;

  level:=max_level;
  while level >= min_odd_level do
  begin
    i := 0;
    while i < outputlen do
    begin
      if get_level_uint32(output, i) >= level then
      begin
        {*
         * the current character has the desired level
         *}
        last := i;
        First := last;
        {* find the end of the level-sequence *}
        Inc(i);
        while i < outputlen do
        begin
          if (get_level_uint32(output, i) >= level) then
          begin
            {* the sequence continues *}
            last := i;
          end
          else
          begin
            break;
          end;
          Inc(i);
        end;
        {* invert the sequence first..last respecting
         * grapheme clusters
         *
         * The standard only speaks of combining marks
         * inversion, but we should in the perfect case
         * respect _all_ grapheme clusters, which we do
         * here not
         *}

        {* mark grapheme cluster breaks *}
        j := First;
        while j <= last do
        begin
          {*
           * we use a special trick here: The
           * first 21 bits of the state are filled
           * with the codepoint, the next 8 bits
           * are used for the level, so we can use
           * the 30th bit to mark the grapheme
           * cluster breaks. This allows us to
           * reinvert the grapheme clusters into
           * the proper direction later.
           *}
          output[j] := output[j] or (uint32(1) shl 29);
          j := j + grapheme_next_character_break(line + j, outputlen - j);

        end;

        {* global inversion *}
        k := First;
        l := last;
        while k < l do
        begin
          {* swap *}
          tmp := output[k];
          output[k] := output[l];
          output[l] := tmp;
          Inc(k);
          Dec(l);
        end;

        {* grapheme cluster reinversion *}
        //#if 0
        //        for (j := first, laststart := first; j <= last;
        //             j++) begin
        //          if (output[j] & (UINT32_C(1)  shl  29)) begin
        //            {* we hit a mark not  given the
        //             * grapheme cluster is inverted,
        //             * this means that the cluster
        //             * ended and we now reinvert it
        //             * again
        //             *}
        //            for (k := laststart, l := j;
        //                 k < l; k++, l--) begin
        //              {* swap *}
        //              tmp := output[k];
        //              output[k] := output[l];
        //              output[l] := tmp;
        //            end;
        //            laststart := j + 1;
        //          end;
        //        end;
        //#endif

        {* unmark grapheme cluster breaks *}
        j:=First;
        while j<= last do
        begin
          output[j] := output[j] xor (output[j] and uint32($20000000));
          inc(j);
        end;
      end;
      Inc(i);
    end;
    dec(level);
  end;

  {* remove embedding level metadata *}
  i:=0;
  while i<outputlen do
  begin
    output[i] := output[i] xor (output[i] and uint32($1FE00000));
    Inc(i);
  end;

  exit(outputlen);
end;

end.
