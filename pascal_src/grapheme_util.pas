
{*
 * Herodotus, the ancient greek historian and geographer,
 * was criticized for including legends and other fantastic
 * accounts into his works, among others by his contemporary
 * Thucydides.
 *
 * The Herodotus readers and writers are tailored towards the needs
 * of the library interface, doing all the dirty work behind the
 * scenes. While the reader is relatively faithful in his accounts,
 * the Herodotus writer will never fail and always claim to write the
 * data. Internally, it only writes as much as it can, and will simply
 * keep account of the rest. This way, we can properly signal truncation.
 *
 * In this sense, explaining the naming, the writer is always a bit
 * inaccurate in his accounts.
 *
 *}

unit grapheme_util;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils, grapheme_types;

type
herodotus_status = (
	HERODOTUS_STATUS_SUCCESS,
	HERODOTUS_STATUS_END_OF_BUFFER,
	HERODOTUS_STATUS_SOFT_LIMIT_REACHED
);

herodotus_type = (
	HERODOTUS_TYPE_CODEPOINT,
	HERODOTUS_TYPE_UTF8
);

PHERODOTUS_READER=^HERODOTUS_READER;
HERODOTUS_READER = record
	_type: herodotus_type;
	src: Pointer;
        srclen:size_t;
	off:size_t;
	terminated_by_null:boolean;
	soft_limit : array [0..9] of size_t;
end;

PHERODOTUS_WRITER=^HERODOTUS_WRITER;
HERODOTUS_WRITER = record
	_type: herodotus_type;
	dest:Pointer;
	destlen:size_t;
	off:size_t;
	first_unwritable_offset:size_t;
end;

proper_private = record
   prev_prop: array [0..1] of uint_least8_t;
   next_prop: array [0..1] of uint_least8_t;
end;

TF1=function (p1:uint_least32_t):uint_least8_t;
TF2=function (p1:uint_least8_t):boolean;
TP1=procedure (p1:uint_least8_t;p2:Pointer);

PProper=^proper;
proper =record
	{*
	 * prev_prop[1] prev_prop[0] | next_prop[0] next_prop[1]
	 *}
        raw,skip: proper_private;

	mid_reader, raw_reader, skip_reader:HERODOTUS_READER;
	state:Pointer;
	no_prop:uint_least8_t;

	//uint_least8_t ( *get_break_prop)(uint_least32_t);
	//bool ( *is_skippable_prop)(uint_least8_t);
	//void ( *skip_shift_callback)(uint_least8_t, void *);
        get_break_prop:TF1;
        is_skippable_prop:TF2;
        skip_shift_callback:TP1;
end;

procedure herodotus_reader_init(r: PHERODOTUS_READER; AType: herodotus_type; const src: Pointer; srclen: size_t);
procedure herodotus_reader_copy(const src: PHERODOTUS_READER; dest: PHERODOTUS_READER);
procedure herodotus_reader_push_advance_limit(r: PHERODOTUS_READER; Count: size_t);
procedure herodotus_reader_pop_limit(r: PHERODOTUS_READER);
function herodotus_reader_next_word_break(const r: PHERODOTUS_READER): size_t;
function herodotus_reader_next_codepoint_break(const r: PHERODOTUS_READER): size_t;
function herodotus_reader_number_read(const r: PHERODOTUS_READER): size_t;
function herodotus_read_codepoint(r: PHERODOTUS_READER; advance: boolean; cp: Puint_least32_t): herodotus_status;
procedure herodotus_writer_init(w: PHERODOTUS_WRITER; AType: herodotus_type; dest: Pointer; destlen: size_t);
procedure herodotus_writer_nul_terminate(w: PHERODOTUS_WRITER);
function herodotus_writer_number_written(const w: PHERODOTUS_WRITER): size_t;
procedure herodotus_write_codepoint(w: PHERODOTUS_WRITER; cp: uint_least32_t);
procedure proper_init(const r: PHERODOTUS_READER; state: Pointer; no_prop: uint_least8_t; get_break_prop: TF1;
  is_skippable_prop: TF2; skip_shift_callback: TP1; p: PProper);
function proper_advance(p: PProper): integer;

implementation

uses
  Math, grapheme_utf8, grapheme_word;

procedure herodotus_reader_init(r: PHERODOTUS_READER; AType: herodotus_type; const src: Pointer; srclen: size_t);
var
  i: size_t;
begin
  r^._type := AType;
  r^.src := src;
  r^.srclen := srclen;
  r^.off := 0;
  r^.terminated_by_null := False;

  i:=0;
  while i<length(r^.soft_limit) do
  begin
    r^.soft_limit[i] := SIZE_MAX;
    Inc(i);
  end;
end;

procedure herodotus_reader_copy(const src: PHERODOTUS_READER; dest: PHERODOTUS_READER);
var
  i: size_t;
begin
  {*
   * we copy such that we have a "fresh" start and build on the
   * fact that src->soft_limit[i] for any i and src->srclen are
   * always larger or equal to src->off
   *}
  dest^._type := src^._type;
  if src^._type = HERODOTUS_TYPE_CODEPOINT then
  begin
    if src^.src = nil then
      dest^.src := nil
    else
      dest^.src := Puint_least32_t(src^.src) + src^.off;
  end
  else {* src->type == HERODOTUS_TYPE_UTF8 *}
  begin
    if src^.src = nil then
      dest^.src := nil
    else
      dest^.src := pansichar(src^.src) + src^.off;
  end;
  if src^.srclen = SIZE_MAX then
  begin
    dest^.srclen := SIZE_MAX;
  end
  else
  begin
    if src^.off < src^.srclen then
      dest^.srclen := src^.srclen - src^.off
    else
      dest^.srclen := 0;
  end;
  dest^.off := 0;
  dest^.terminated_by_null := src^.terminated_by_null;

  i:=0;
  while i<length(src^.soft_limit) do
  begin
    if src^.soft_limit[i] = SIZE_MAX then
    begin
      dest^.soft_limit[i] := SIZE_MAX;
    end
    else
    begin
      {/*
       * if we have a degenerate case where the offset is
       * higher than the soft-limit, we simply clamp the
       * soft-limit to zero given we can't decide here
       * to release the limit and, instead, we just
       * prevent any more reads
       *}
      if src^.off < src^.soft_limit[i] then
        dest^.soft_limit[i] := src^.soft_limit[i] - src^.off
      else
        dest^.soft_limit[i] := 0;
    end;
    inc(i);
  end;
end;

procedure herodotus_reader_push_advance_limit(r: PHERODOTUS_READER; Count: size_t);
var
  i: size_t;
begin
  i := length(r^.soft_limit) - 1;
  while i >= 1 do
  begin
    r^.soft_limit[i] := r^.soft_limit[i - 1];
    Dec(i);
  end;
  r^.soft_limit[0] := r^.off + Count;
end;

procedure herodotus_reader_pop_limit(r: PHERODOTUS_READER);
var
  i: size_t;
begin
  i := 0;
  while i < (length(r^.soft_limit) - 1) do
  begin
    r^.soft_limit[i] := r^.soft_limit[i + 1];
    Inc(i);
  end;
  r^.soft_limit[length(r^.soft_limit) - 1] := SIZE_MAX;
end;

function herodotus_reader_next_word_break(const r: PHERODOTUS_READER): size_t;
begin
  if r^._type = HERODOTUS_TYPE_CODEPOINT then
  begin
    exit(grapheme_next_word_break(Puint_least32_t(r^.src) + r^.off, min(r^.srclen, r^.soft_limit[0]) - r^.off));
  end
  else
  begin
    {* r->type == HERODOTUS_TYPE_UTF8 *}
    exit(grapheme_next_word_break_utf8(pansichar(r^.src) + r^.off, min(r^.srclen, r^.soft_limit[0]) - r^.off));
  end;
end;

function herodotus_reader_next_codepoint_break(const r: PHERODOTUS_READER): size_t;
begin
  if r^._type = HERODOTUS_TYPE_CODEPOINT then
  begin
    if r^.off < min(r^.srclen, r^.soft_limit[0]) then
      exit(1)
    else
      exit(0);
  end
  else  {* r->type == HERODOTUS_TYPE_UTF8 *}
  begin
    exit(grapheme_decode_utf8(pansichar(r^.src) + r^.off, min(r^.srclen, r^.soft_limit[0]) - r^.off, nil));
  end;
end;


function herodotus_reader_number_read(const r: PHERODOTUS_READER): size_t;
begin
  exit(r^.off);
end;

function herodotus_read_codepoint(r: PHERODOTUS_READER; advance: boolean; cp: Puint_least32_t): herodotus_status;
var
  ret: size_t;
begin
  if r^.terminated_by_null or (r^.off >= r^.srclen) or (r^.src = nil) then
  begin
    cp^ := GRAPHEME_INVALID_CODEPOINT;
    exit(HERODOTUS_STATUS_END_OF_BUFFER);
  end;

  if r^.off >= r^.soft_limit[0] then
  begin
    cp^ := GRAPHEME_INVALID_CODEPOINT;
    exit(HERODOTUS_STATUS_SOFT_LIMIT_REACHED);
  end;

  if r^._type = HERODOTUS_TYPE_CODEPOINT then
  begin
    cp^ := (Puint_least32_t(r^.src))[r^.off];
    ret := 1;
  end
  else  {* r->type == HERODOTUS_TYPE_UTF8 *}
  begin
    ret := grapheme_decode_utf8(pansichar(r^.src) + r^.off, min(r^.srclen, r^.soft_limit[0]) - r^.off, cp);
  end;

  if (r^.srclen = SIZE_MAX) and (cp^ = 0) then
  begin
    {*
     * We encountered a null-codepoint. Don't increment
     * offset and return as if the buffer had ended here all
     * along
     *}
    r^.terminated_by_null := True;
    exit(HERODOTUS_STATUS_END_OF_BUFFER);
  end;

  if (r^.off + ret) > min(r^.srclen, r^.soft_limit[0]) then
  begin
    {*
     * we want more than we have; instead of returning
     * garbage we terminate here.
     *}
    exit(HERODOTUS_STATUS_END_OF_BUFFER);
  end;

  {*
   * Increase offset which we now know won't surpass the limits,
   * unless we got told otherwise
   *}
  if advance then
  begin
    r^.off := r^.off + ret;
  end;

  exit(HERODOTUS_STATUS_SUCCESS);
end;

procedure herodotus_writer_init(w: PHERODOTUS_WRITER; AType: herodotus_type; dest: Pointer; destlen: size_t);
begin
  w^._type := AType;
  w^.dest := dest;
  w^.destlen := destlen;
  w^.off := 0;
  w^.first_unwritable_offset := SIZE_MAX;
end;


procedure herodotus_writer_nul_terminate(w: PHERODOTUS_WRITER);
begin
  if w^.dest = nil then
    exit;

  if w^.off < w^.destlen then
  begin
    {* We still have space in the buffer. Simply use it *}
    if w^._type = HERODOTUS_TYPE_CODEPOINT then
      Puint_least32_t(w^.dest)[w^.off] := 0
    else  {* w->type = HERODOTUS_TYPE_UTF8 *}
      pansichar(w^.dest)[w^.off] := #0;

  end
  else
  if w^.first_unwritable_offset < w^.destlen then
  begin
    {*
     * There is no more space in the buffer. However,
     * we have noted down the first offset we couldn't
     * use to write into the buffer and it's smaller than
     * destlen. Thus we bailed writing into the
     * destination when a multibyte-codepoint couldn't be
     * written. So the last "real" byte might be at
     * destlen-4, destlen-3, destlen-2 or destlen-1
     * (the last case meaning truncation).
     *}
    if w^._type = HERODOTUS_TYPE_CODEPOINT then
      Puint_least32_t(w^.dest)[w^.first_unwritable_offset] := 0
    else  {* w->type == HERODOTUS_TYPE_UTF8 *}
      pansichar(w^.dest)[w^.first_unwritable_offset] := #0;

  end
  else
  if w^.destlen > 0 then
  begin
    {*
     * In this case, there is no more space in the buffer and
     * the last unwritable offset is larger than
     * or equal to the destination buffer length. This means
     * that we are forced to simply write into the last
     * byte.
     *}
    if w^._type = HERODOTUS_TYPE_CODEPOINT then
      Puint_least32_t(w^.dest)[w^.destlen - 1] := 0
    else  {* w->type == HERODOTUS_TYPE_UTF8 *}
      pansichar(w^.dest)[w^.destlen - 1] := #0;

  end;

  {* w->off is not incremented in any case *}
end;

function herodotus_writer_number_written(const w: PHERODOTUS_WRITER): size_t;
begin
  exit(w^.off);
end;


procedure herodotus_write_codepoint(w: PHERODOTUS_WRITER; cp: uint_least32_t);
var
  ret: size_t;
begin
  {*
   * This function will always faithfully say how many codepoints
   * were written, even if the buffer ends. This is used to enable
   * truncation detection.
   *}
  if w^._type = HERODOTUS_TYPE_CODEPOINT then
  begin
    if (w^.dest <> nil) and (w^.off < w^.destlen) then
      Puint_least32_t(w^.dest)[w^.off] := cp;

    w^.off := w^.off + 1;
  end
  else  {* w->type == HERODOTUS_TYPE_UTF8 *}
  begin
    {*
     * First determine how many bytes we need to encode the
     * codepoint
     *}
    ret := grapheme_encode_utf8(cp, nil, 0);

    if (w^.dest <> nil) and ((w^.off + ret) < w^.destlen) then
      {* we still have enough room in the buffer *}
      grapheme_encode_utf8(cp, pansichar(w^.dest) + w^.off,
        w^.destlen - w^.off)
    else
    if w^.first_unwritable_offset = SIZE_MAX then
    begin
      {/*
       * the first unwritable offset has not been
       * noted down, so this is the first time we can't
       * write (completely) to an offset
       */}
      w^.first_unwritable_offset := w^.off;
    end;

    w^.off := w^.off + ret;
  end;
end;


procedure proper_init(const r: PHERODOTUS_READER; state: Pointer; no_prop: uint_least8_t; get_break_prop: TF1;
  is_skippable_prop: TF2; skip_shift_callback: TP1; p: PProper);
var
  prop: uint_least8_t;
  cp: uint_least32_t;
  i: size_t;
begin
  {* set internal variables *}
  p^.state := state;
  p^.no_prop := no_prop;
  p^.get_break_prop := get_break_prop;
  p^.is_skippable_prop := is_skippable_prop;
  p^.skip_shift_callback := skip_shift_callback;

  {*
   * Initialize mid-reader, which is basically just there
   * to reflect the current position of the viewing-line
   *}
  herodotus_reader_copy(r, @(p^.mid_reader));

  {*
   * In the initialization, we simply (try to) fill in next_prop.
   * If we cannot read in more (due to the buffer ending), we
   * fill in the prop as invalid
   *}

  {*
   * initialize the previous properties to have no property
   * (given we are at the start of the buffer)
   *}
  p^.raw.prev_prop[1] := p^.no_prop;
  p^.raw.prev_prop[0] := p^.no_prop;
  p^.skip.prev_prop[1] := p^.no_prop;
  p^.skip.prev_prop[0] := p^.no_prop;

  {*
   * initialize the next properties
   *}

  {* initialize the raw reader *}
  herodotus_reader_copy(r, @(p^.raw_reader));

  {* fill in the two next raw properties (after no-initialization) *}
  p^.raw.next_prop[0] := p^.no_prop;
  p^.raw.next_prop[1] := p^.no_prop;
  i := 0;
  while (i < 2) and (herodotus_read_codepoint(@(p^.raw_reader), True, @cp) = HERODOTUS_STATUS_SUCCESS) do
  begin
    p^.raw.next_prop[i] := p^.get_break_prop(cp);
    Inc(i);
  end;

  {* initialize the skip reader *}
  herodotus_reader_copy(r, @(p^.skip_reader));

  {* fill in the two next skip properties (after no-initialization) *}
  p^.skip.next_prop[0] := p^.no_prop;
  p^.skip.next_prop[1] := p^.no_prop;
  i := 0;
  while (i < 2) and (herodotus_read_codepoint(@(p^.skip_reader), True, @cp) = HERODOTUS_STATUS_SUCCESS) do
  begin
    prop := p^.get_break_prop(cp);
    if not p^.is_skippable_prop(prop) then
    begin
      p^.skip.next_prop[i] := prop;
      Inc(i);
    end;
  end;
end;



function proper_advance(p: PProper): integer;
var
  prop: uint_least8_t;
  cp: uint_least32_t;
begin
  {* read in next "raw" property *}
  if herodotus_read_codepoint(@(p^.raw_reader), True, @cp) = HERODOTUS_STATUS_SUCCESS then
    prop := p^.get_break_prop(cp)
  else
    prop := p^.no_prop;

  {*
   * do a shift-in, unless we find that the property that is to
   * be moved past the "raw-viewing-line" (this property is stored
   * in p->raw.next_prop[0]) is a no_prop, indicating that
   * we are at the end of the buffer.
   *}
  if p^.raw.next_prop[0] = p^.no_prop then
    exit(1);

  {* shift in the properties *}
  p^.raw.prev_prop[1] := p^.raw.prev_prop[0];
  p^.raw.prev_prop[0] := p^.raw.next_prop[0];
  p^.raw.next_prop[0] := p^.raw.next_prop[1];
  p^.raw.next_prop[1] := prop;

  {* advance the middle reader viewing-line *}
  herodotus_read_codepoint(@(p^.mid_reader), True, @cp);

  {* check skippability-property *}
  if not p^.is_skippable_prop(p^.raw.prev_prop[0]) then
  begin
    {/*
     * the property that has moved past the "raw-viewing-line"
     * (this property is now (after the raw-shift) stored in
     * p->raw.prev_prop[0] and guaranteed not to be a no-prop,
     * guaranteeing that we won't shift a no-prop past the
     * "viewing-line" in the skip-properties) is not a skippable
     * property, thus we need to shift the skip property as well.
     *}
    p^.skip.prev_prop[1] := p^.skip.prev_prop[0];
    p^.skip.prev_prop[0] := p^.skip.next_prop[0];
    p^.skip.next_prop[0] := p^.skip.next_prop[1];

    {*
     * call the skip-shift-callback on the property that
     * passed the skip-viewing-line (this property is now
     * stored in p->skip.prev_prop[0]).
     *}
    p^.skip_shift_callback(p^.skip.prev_prop[0], p^.state);

    {* determine the next shift property *}
    p^.skip.next_prop[1] := p^.no_prop;
    while herodotus_read_codepoint(@(p^.skip_reader), True, @cp) = HERODOTUS_STATUS_SUCCESS do
    begin
      prop := p^.get_break_prop(cp);
      if not p^.is_skippable_prop(prop) then
      begin
        p^.skip.next_prop[1] := prop;
        break;
      end;
    end;
  end;
  exit(0);
end;

end.
