{* See LICENSE file for copyright and license details. *}
//#include <stdboolean.h>
//#include <stddef.h>
//
//#include "../gen/sentence.h"
//#include "../grapheme.h"
//#include "util.h"


unit grapheme_sentence;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils, grapheme_types;


function grapheme_next_sentence_break(const str:Puint_least32_t;len:size_t):size_t;cdecl;
function grapheme_next_sentence_break_utf8(const str:PAnsiChar;len:size_t):size_t;cdecl;


implementation

uses
  grapheme_util;


{$I grapheme_gen_sentence.inc}

type

Psentence_break_state=^sentence_break_state;
sentence_break_state =record
	 aterm_close_sp_level:uint_least8_t;
	saterm_close_sp_parasep_level:uint_least8_t;
end;

function get_sentence_break_prop(cp:uint_least32_t):uint_least8_t;inline;
begin
	if cp <= GRAPHEME_LAST_CODEPOINT then
        begin
		exit( uint_least8_t(
			sentence_break_minor[sentence_break_major[cp  shr  8] +
		                             (cp and $ff)]));
	end
        else
        begin
		exit(ord(SENTENCE_BREAK_PROP_OTHER));
	end;
end;

function is_skippable_sentence_prop(prop:uint_least8_t):boolean;
begin
	exit( (prop = Ord(SENTENCE_BREAK_PROP_EXTEND))  or
	       (prop = Ord(SENTENCE_BREAK_PROP_FORMAT)) );
end;

procedure sentence_skip_shift_callback(prop:uint_least8_t;s:Pointer);
var
   state:Psentence_break_state;
begin
   state:= PSentence_break_state(s);
	{*
	 * Here comes a bit of magic. The rules
	 * SB8, SB8a, SB9 and SB10 have very complicated
	 * left-hand-side-rules of the form
	 *
	 *  ATerm Close* Sp*
	 *  SATerm Close*
	 *  SATerm Close* Sp*
	 *  SATerm Close* Sp* ParaSep?
	 *
	 * but instead of backtracking, we keep the
	 * state as some kind of "power level" in
	 * two state-variables
	 *
	 *  aterm_close_sp_level
	 *  saterm_close_sp_parasep_level
	 *
	 * that go from 0 to 3/4:
	 *
	 *  0: we are not in the sequence
	 *  1: we have one ATerm/SATerm to the left of
	 *     the middle spot
	 *  2: we have one ATerm/SATerm and one or more
	 *     Close to the left of the middle spot
	 *  3: we have one ATerm/SATerm, zero or more
	 *     Close and one or more Sp to the left of
	 *     the middle spot.
	 *  4: we have one SATerm, zero or more Close,
	 *     zero or more Sp and one ParaSep to the
	 *     left of the middle spot.
	 *
	 *}
	if ((state^.aterm_close_sp_level = 0)  or
	     (state^.aterm_close_sp_level = 1))  and
	    (prop = Ord(SENTENCE_BREAK_PROP_ATERM)) then
        begin
		{* sequence has begun *}
		state^.aterm_close_sp_level := 1;
	end
        else if ((state^.aterm_close_sp_level = 1)  or
	            (state^.aterm_close_sp_level = 2))  and
	           (prop = Ord(SENTENCE_BREAK_PROP_CLOSE)) then
        begin
		{* close-sequence begins or continued *}
		state^.aterm_close_sp_level := 2;
	end
        else if ((state^.aterm_close_sp_level = 1)  or
	            (state^.aterm_close_sp_level = 2)  or
	            (state^.aterm_close_sp_level = 3))  and
	           (prop = Ord(SENTENCE_BREAK_PROP_SP)) then
        begin
		{* sp-sequence begins or continued *}
		state^.aterm_close_sp_level := 3;
	end
        else
        begin
		{* sequence broke *}
		state^.aterm_close_sp_level := 0;
	end;

	if ((state^.saterm_close_sp_parasep_level = 0)  or
	     (state^.saterm_close_sp_parasep_level = 1))  and
	    ((prop = Ord(SENTENCE_BREAK_PROP_STERM))  or
	     (prop = Ord(SENTENCE_BREAK_PROP_ATERM))) then
        begin
		{* sequence has begun *}
		state^.saterm_close_sp_parasep_level := 1;
	end
        else if ((state^.saterm_close_sp_parasep_level = 1)  or
	            (state^.saterm_close_sp_parasep_level = 2))  and
	           (prop = Ord(SENTENCE_BREAK_PROP_CLOSE)) then
        begin
		{* close-sequence begins or continued *}
		state^.saterm_close_sp_parasep_level := 2;
	end
        else if ((state^.saterm_close_sp_parasep_level = 1)  or
	            (state^.saterm_close_sp_parasep_level = 2)  or
	            (state^.saterm_close_sp_parasep_level = 3))  and
	           (prop = Ord(SENTENCE_BREAK_PROP_SP)) then
        begin
		{* sp-sequence begins or continued *}
		state^.saterm_close_sp_parasep_level := 3;
	end
        else if ((state^.saterm_close_sp_parasep_level = 1)  or
	            (state^.saterm_close_sp_parasep_level = 2)  or
	            (state^.saterm_close_sp_parasep_level = 3))  and
	           ((prop = Ord(SENTENCE_BREAK_PROP_SEP))  or
	            (prop = Ord(SENTENCE_BREAK_PROP_CR))  or
	            (prop = Ord(SENTENCE_BREAK_PROP_LF))) then
        begin
		{* ParaSep at the end of the sequence *}
		state^.saterm_close_sp_parasep_level := 4;
	end
        else
        begin
		{* sequence broke *}
		state^.saterm_close_sp_parasep_level := 0;
	end;
end;

function next_sentence_break(r:PHERODOTUS_READER):size_t;
var
	tmp:HERODOTUS_READER;
	prop:sentence_break_property;
	p:proper;
	state:sentence_break_state;
	cp:uint_least32_t;
begin
       state.aterm_close_sp_level:=0;
       state.saterm_close_sp_parasep_level:=0;

	{*
	 * Apply sentence breaking algorithm (UAX #29), see
	 * https://unicode.org/reports/tr29/#Sentence_Boundary_Rules
	 *}
	proper_init(r, @state, Ord(NUM_SENTENCE_BREAK_PROPS),
	            get_sentence_break_prop, is_skippable_sentence_prop,
	            sentence_skip_shift_callback, @p);

	while proper_advance(@p)=0 do  //while not proper_advance(@p)
        begin
		{* SB3 *}
		if (p.raw.prev_prop[0] = Ord(SENTENCE_BREAK_PROP_CR))  and
		    (p.raw.next_prop[0] = Ord(SENTENCE_BREAK_PROP_LF)) then
                begin
			continue;
		end;

		{* SB4 *}
		if (p.raw.prev_prop[0] = Ord(SENTENCE_BREAK_PROP_SEP))  or
		    (p.raw.prev_prop[0] = Ord(SENTENCE_BREAK_PROP_CR))  or
		   (p.raw.prev_prop[0] = Ord(SENTENCE_BREAK_PROP_LF)) then
                begin
			break;
		end;

		{* SB5 *}
		if (p.raw.next_prop[0] = Ord(SENTENCE_BREAK_PROP_EXTEND))  or
		    (p.raw.next_prop[0] = Ord(SENTENCE_BREAK_PROP_FORMAT)) then
                begin
			continue;
		end;

		{* SB6 *}
		if (p.skip.prev_prop[0] = Ord(SENTENCE_BREAK_PROP_ATERM))  and
		    (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_NUMERIC)) then
                begin
			continue;
		end;

		{* SB7 *}
		if ((p.skip.prev_prop[1] = Ord(SENTENCE_BREAK_PROP_UPPER))  or
		     (p.skip.prev_prop[1] = Ord(SENTENCE_BREAK_PROP_LOWER)))  and
		    (p.skip.prev_prop[0] = Ord(SENTENCE_BREAK_PROP_ATERM))  and
		    (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_UPPER)) then
                begin
			continue;
		end;

		{* SB8 *}
		if (state.aterm_close_sp_level = 1)  or
		    (state.aterm_close_sp_level = 2) or
		    (state.aterm_close_sp_level = 3) then
                begin
			{*
			 * This is the most complicated rule, requiring
			 * the right-hand-side to satisfy the regular expression
			 *
			 *  ( ¬(OLetter  or  Upper  or  Lower  or  ParaSep  or  SATerm) )*
			 * Lower
			 *
			 * which we simply check "manually" given LUT-lookups
			 * are very cheap by starting at the mid_reader.
			 *
			 *}
			herodotus_reader_copy(@(p.mid_reader), @tmp);

			prop := NUM_SENTENCE_BREAK_PROPS;
			while (herodotus_read_codepoint(@tmp, true, @cp) =
			       HERODOTUS_STATUS_SUCCESS) do
                        begin
				prop := sentence_break_property(get_sentence_break_prop(cp));

				{*
				 * the skippable properties are ignored
				 * automatically here given they do not
				 * match the following condition
				 *}
				if (prop = SENTENCE_BREAK_PROP_OLETTER)  or
				    (prop = SENTENCE_BREAK_PROP_UPPER)  or
				    (prop = SENTENCE_BREAK_PROP_LOWER)  or
				    (prop = SENTENCE_BREAK_PROP_SEP)  or
				    (prop = SENTENCE_BREAK_PROP_CR)  or
				    (prop = SENTENCE_BREAK_PROP_LF)  or
				    (prop = SENTENCE_BREAK_PROP_STERM)  or
				    (prop = SENTENCE_BREAK_PROP_ATERM) then
                                begin
					break;
				end;
			end;

			if prop = SENTENCE_BREAK_PROP_LOWER then
                        begin
				continue;
			end;
		end;

		{* SB8a *}
		if ((state.saterm_close_sp_parasep_level = 1)  or
		     (state.saterm_close_sp_parasep_level = 2)  or
		     (state.saterm_close_sp_parasep_level = 3))  and
		    ((p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_SCONTINUE))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_STERM))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_ATERM))) then
                begin
			continue;
		end;

		{* SB9 *}
		if ((state.saterm_close_sp_parasep_level = 1)  or
		     (state.saterm_close_sp_parasep_level = 2))  and
		    ((p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_CLOSE))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_SP))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_SEP))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_CR))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_LF))) then
                begin
			continue;
		end;

		{* SB10 *}
		if ((state.saterm_close_sp_parasep_level = 1)  or
		     (state.saterm_close_sp_parasep_level = 2)  or
		     (state.saterm_close_sp_parasep_level = 3))  and
		    ((p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_SP))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_SEP))  or
		     (p.skip.next_prop[0] = Ord(SENTENCE_BREAK_PROP_LF))) then
                begin
			continue;
		end;

		{* SB11 *}
		if (state.saterm_close_sp_parasep_level = 1)  or
		    (state.saterm_close_sp_parasep_level = 2)  or
		    (state.saterm_close_sp_parasep_level = 3)  or
		    (state.saterm_close_sp_parasep_level = 4) then
                begin
			break;
		end;

		{* SB998 *}
		continue;
	end;

	exit(herodotus_reader_number_read(@(p.mid_reader)));
end;

function grapheme_next_sentence_break(const str:Puint_least32_t;len:size_t):size_t;cdecl;
var
 r:HERODOTUS_READER;
begin
	herodotus_reader_init(@r, HERODOTUS_TYPE_CODEPOINT, str, len);

	exit(next_sentence_break(@r));
end;

function grapheme_next_sentence_break_utf8(const str:PAnsiChar;len:size_t):size_t;cdecl;
var
  r:HERODOTUS_READER;
begin
	herodotus_reader_init(@r, HERODOTUS_TYPE_UTF8, str, len);

	exit(next_sentence_break(@&r));
end;

end.
