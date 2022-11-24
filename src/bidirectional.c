/* See LICENSE file for copyright and license details. */
#include <stdbool.h>
#include <stddef.h>

#include "../gen/bidirectional.h"
#include "../grapheme.h"
#include "util.h"

#define MAX_DEPTH 125

enum state_type {
	STATE_PROP,            /* in 0..23, bidi_property */
	STATE_PRESERVED_PROP,  /* in 0..23, preserved bidi_prop for L1-rule */
	STATE_BRACKET_OFF,     /* in 0..255, offset in bidi_bracket */
	STATE_LEVEL,           /* in 0..MAX_DEPTH+1=126, embedding level */
	STATE_PARAGRAPH_LEVEL, /* in 0..1, paragraph embedding level */
	STATE_VISITED,         /* in 0..1, visited within isolating run */
};

static struct {
	uint_least32_t filter_mask;
	size_t mask_shift;
	int_least16_t value_offset;
} state_lut[] = {
	[STATE_PROP] = {
		.filter_mask  = 0x000001F, /* 00000000 00000000 00000000 00011111 */
		.mask_shift   = 0,
		.value_offset = 0,
	},
	[STATE_PRESERVED_PROP] = {
		.filter_mask  = 0x00003E0, /* 00000000 00000000 00000011 11100000 */
		.mask_shift   = 5,
		.value_offset = 0,
	},
	[STATE_BRACKET_OFF] = {
		.filter_mask  = 0x003FC00, /* 00000000 00000011 11111100 00000000 */
		.mask_shift   = 10,
		.value_offset = 0,
	},
	[STATE_LEVEL] = {
		.filter_mask  = 0x1FC0000, /* 00000001 11111100 00000000 00000000 */
		.mask_shift   = 18,
		.value_offset = -1,
	},
	[STATE_PARAGRAPH_LEVEL] = {
		.filter_mask  = 0x2000000, /* 00000010 00000000 00000000 00000000 */
		.mask_shift   = 25,
		.value_offset = 0,
	},
	[STATE_VISITED] = {
		.filter_mask  = 0x4000000, /* 00000100 00000000 00000000 00000000 */
		.mask_shift   = 26,
		.value_offset = 0,
	},
};

static inline int_least16_t
get_state(enum state_type t, uint_least32_t input)
{
	return (int_least16_t)((input & state_lut[t].filter_mask) >>
	                       state_lut[t].mask_shift) +
	       state_lut[t].value_offset;
}

static inline void
set_state(enum state_type t, int_least16_t value, uint_least32_t *output)
{
	*output &= ~state_lut[t].filter_mask;
	*output |= ((uint_least32_t)(value - state_lut[t].value_offset)
	            << state_lut[t].mask_shift) &
	           state_lut[t].filter_mask;
}

struct isolate_runner {
	uint_least32_t *buf;
	size_t buflen;

	struct {
		size_t off;
	} prev, cur, next;

	enum bidi_property sos, eos;

	uint_least8_t paragraph_level;
	int_least8_t isolating_run_level;
	enum bidi_property last_strong_type;
};

static inline enum bidi_property
ir_get_previous_prop(const struct isolate_runner *ir)
{
	return (ir->prev.off == SIZE_MAX) ?
	               ir->sos :
	               (uint_least8_t)get_state(STATE_PROP,
	                                        ir->buf[ir->prev.off]);
}

static inline enum bidi_property
ir_get_current_prop(const struct isolate_runner *ir)
{
	return (uint_least8_t)get_state(STATE_PROP, ir->buf[ir->cur.off]);
}

static inline enum bidi_property
ir_get_next_prop(const struct isolate_runner *ir)
{
	return (ir->next.off == SIZE_MAX) ?
	               ir->eos :
	               (uint_least8_t)get_state(STATE_PROP,
	                                        ir->buf[ir->next.off]);
}

static inline int_least8_t
ir_get_current_level(const struct isolate_runner *ir)
{
	return (int_least8_t)get_state(STATE_LEVEL, ir->buf[ir->cur.off]);
}

static void
ir_set_current_prop(struct isolate_runner *ir, enum bidi_property prop)
{
	set_state(STATE_PROP, (int_least16_t)prop, &(ir->buf[ir->cur.off]));
}

static void
ir_init(uint_least32_t *buf, size_t buflen, size_t off,
        uint_least8_t paragraph_level, bool within, struct isolate_runner *ir)
{
	size_t i;
	int_least8_t sos_level;

	/* initialize invariants */
	ir->buf = buf;
	ir->buflen = buflen;
	ir->paragraph_level = paragraph_level;

	/* advance off until we are at a non-removed character */
	for (; off < buflen; off++) {
		if (get_state(STATE_LEVEL, buf[off]) != -1) {
			break;
		}
	}
	if (off == buflen) {
		/* we encountered no more non-removed character, terminate */
		ir->next.off = SIZE_MAX;
		return;
	}

	/* set the isolating run level to that of the current offset */
	ir->isolating_run_level =
		(int_least8_t)get_state(STATE_LEVEL, buf[off]);

	/* initialize sos and eos to dummy values */
	ir->sos = ir->eos = NUM_BIDI_PROPS;

	/*
	 * we write the information of the "current" state into next,
	 * so that the shift-in at the first advancement moves it in
	 * cur, as desired.
	 */
	ir->next.off = off;

	/*
	 * determine the previous state but store its offset in cur.off,
	 * given it's shifted in on the first advancement
	 */
	ir->cur.off = SIZE_MAX;
	for (i = off, sos_level = -1; i >= 1; i--) {
		if (get_state(STATE_LEVEL, buf[i - 1]) != -1) {
			/*
			 * we found a character that has not been
			 * removed in X9
			 */
			sos_level = (int_least8_t)get_state(STATE_LEVEL,
			                                    buf[i - 1]);

			if (within) {
				/* we just take it */
				ir->cur.off = i;
			}

			break;
		}
	}
	if (sos_level == -1) {
		/*
		 * there were no preceding non-removed characters, set
		 * sos-level to paragraph embedding level
		 */
		sos_level = (int_least8_t)paragraph_level;
	}

	if (!within || ir->cur.off == SIZE_MAX) {
		/*
		 * we are at the beginning of the sequence; initialize
		 * it faithfully according to the algorithm by looking
		 * at the sos-level
		 */
		if (MAX(sos_level, ir->isolating_run_level) % 2 == 0) {
			/* the higher level is even, set sos to L */
			ir->sos = BIDI_PROP_L;
		} else {
			/* the higher level is odd, set sos to R */
			ir->sos = BIDI_PROP_R;
		}
	}
}

static int
ir_advance(struct isolate_runner *ir)
{
	enum bidi_property prop;
	int_least8_t level, isolate_level, last_isolate_level;
	size_t i;

	if (ir->next.off == SIZE_MAX) {
		/* the sequence is over */
		return 1;
	}

	/* shift in */
	ir->prev.off = ir->cur.off;
	ir->cur.off = ir->next.off;

	/* mark as visited */
	set_state(STATE_VISITED, 1, &(ir->buf[ir->cur.off]));

	/*
	 * update last strong type, which is guaranteed to work properly
	 * on the first advancement as the prev.off is SIZE_T and the
	 * implied sos type can only be either R or L, which are both
	 * strong types
	 */
	if (ir_get_previous_prop(ir) == BIDI_PROP_R ||
	    ir_get_previous_prop(ir) == BIDI_PROP_L ||
	    ir_get_previous_prop(ir) == BIDI_PROP_AL) {
		ir->last_strong_type = ir_get_previous_prop(ir);
	}

	/* initialize next state by going to the next character in the sequence
	 */
	ir->next.off = SIZE_MAX;

	last_isolate_level = -1;
	for (i = ir->cur.off, isolate_level = 0; i < ir->buflen; i++) {
		level = (int_least8_t)get_state(STATE_LEVEL, ir->buf[i]);
		prop = (uint_least8_t)get_state(STATE_PROP, ir->buf[i]);

		if (level == -1) {
			/* this is one of the ignored characters, skip */
			continue;
		} else if (level == ir->isolating_run_level) {
			last_isolate_level = level;
		}

		/* follow BD8/BD9 and P2 to traverse the current sequence */
		if (prop == BIDI_PROP_LRI || prop == BIDI_PROP_RLI ||
		    prop == BIDI_PROP_FSI) {
			/*
			 * we encountered an isolate initiator, increment
			 * counter, but go into processing when we
			 * were not isolated before
			 */
			if (isolate_level < MAX_DEPTH) {
				isolate_level++;
			}
			if (isolate_level != 1) {
				continue;
			}
		} else if (prop == BIDI_PROP_PDI && isolate_level > 0) {
			isolate_level--;

			/*
			 * if the current PDI dropped the isolate-level
			 * to zero, it is itself part of the isolating
			 * run sequence; otherwise we simply continue.
			 */
			if (isolate_level > 0) {
				continue;
			}
		} else if (isolate_level > 0) {
			/* we are in an isolating sequence */
			continue;
		}

		/*
		 * now we either still are in our sequence or we hit
		 * the eos-case as we left the sequence and hit the
		 * first non-isolating-sequence character.
		 */
		if (i == ir->cur.off) {
			/* we were in the first initializing round */
			continue;
		} else if (level == ir->isolating_run_level) {
			/* isolate_level-skips have been handled before, we're
			 * good */
			/* still in the sequence */
			ir->next.off = i;
		} else {
			/* out of sequence or isolated, compare levels via eos
			 */
			ir->next.off = SIZE_MAX;
			if (MAX(last_isolate_level, level) % 2 == 0) {
				ir->eos = BIDI_PROP_L;
			} else {
				ir->eos = BIDI_PROP_R;
			}
		}
		break;
	}
	if (i == ir->buflen) {
		/*
		 * the sequence ended before we could grab an offset.
		 * we need to determine the eos-prop by comparing the
		 * level of the last element in the isolating run sequence
		 * with the paragraph level.
		 */
		ir->next.off = SIZE_MAX;
		if (MAX(last_isolate_level, ir->paragraph_level) % 2 == 0) {
			/* the higher level is even, set eos to L */
			ir->eos = BIDI_PROP_L;
		} else {
			/* the higher level is odd, set eos to R */
			ir->eos = BIDI_PROP_R;
		}
	}

	return 0;
}

static size_t
preprocess_isolating_run_sequence(uint_least32_t *buf, size_t buflen,
                                  size_t off, uint_least8_t paragraph_level)
{
	enum bidi_property sequence_prop, prop;
	struct isolate_runner ir, tmp;
	size_t runsince, sequence_end;

	/* W1 */
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		if (ir_get_current_prop(&ir) == BIDI_PROP_NSM) {
			prop = ir_get_previous_prop(&ir);

			if (prop == BIDI_PROP_LRI || prop == BIDI_PROP_RLI ||
			    prop == BIDI_PROP_FSI || prop == BIDI_PROP_PDI) {
				ir_set_current_prop(&ir, BIDI_PROP_ON);
			} else {
				ir_set_current_prop(&ir, prop);
			}
		}
	}

	/* W2 */
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		if (ir_get_current_prop(&ir) == BIDI_PROP_EN &&
		    ir.last_strong_type == BIDI_PROP_AL) {
			ir_set_current_prop(&ir, BIDI_PROP_AN);
		}
	}

	/* W3 */
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		if (ir_get_current_prop(&ir) == BIDI_PROP_AL) {
			ir_set_current_prop(&ir, BIDI_PROP_R);
		}
	}

	/* W4 */
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		if (ir_get_previous_prop(&ir) == BIDI_PROP_EN &&
		    (ir_get_current_prop(&ir) == BIDI_PROP_ES ||
		     ir_get_current_prop(&ir) == BIDI_PROP_CS) &&
		    ir_get_next_prop(&ir) == BIDI_PROP_EN) {
			ir_set_current_prop(&ir, BIDI_PROP_EN);
		}

		if (ir_get_previous_prop(&ir) == BIDI_PROP_AN &&
		    ir_get_current_prop(&ir) == BIDI_PROP_CS &&
		    ir_get_next_prop(&ir) == BIDI_PROP_AN) {
			ir_set_current_prop(&ir, BIDI_PROP_AN);
		}
	}

	/* W5 */
	runsince = SIZE_MAX;
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		if (ir_get_current_prop(&ir) == BIDI_PROP_ET) {
			if (runsince == SIZE_MAX) {
				/* a new run has begun */
				runsince = ir.cur.off;
			}
		} else if (ir_get_current_prop(&ir) == BIDI_PROP_EN) {
			/* set the preceding sequence */
			if (runsince != SIZE_MAX) {
				ir_init(buf, buflen, runsince, paragraph_level,
				        (runsince > off), &tmp);
				while (!ir_advance(&tmp) &&
				       tmp.cur.off < ir.cur.off) {
					ir_set_current_prop(&tmp, BIDI_PROP_EN);
				}
				runsince = SIZE_MAX;
			} else {
				ir_init(buf, buflen, ir.cur.off,
				        paragraph_level, (ir.cur.off > off),
				        &tmp);
				ir_advance(&tmp);
			}
			/* follow the succeeding sequence */
			while (!ir_advance(&tmp)) {
				if (ir_get_current_prop(&tmp) != BIDI_PROP_ET) {
					break;
				}
				ir_set_current_prop(&tmp, BIDI_PROP_EN);
			}
		} else {
			/* sequence ended */
			runsince = SIZE_MAX;
		}
	}

	/* W6 */
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		prop = ir_get_current_prop(&ir);

		if (prop == BIDI_PROP_ES || prop == BIDI_PROP_ET ||
		    prop == BIDI_PROP_CS) {
			ir_set_current_prop(&ir, BIDI_PROP_ON);
		}
	}

	/* W7 */
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		if (ir_get_current_prop(&ir) == BIDI_PROP_EN &&
		    ir.last_strong_type == BIDI_PROP_L) {
			ir_set_current_prop(&ir, BIDI_PROP_L);
		}
	}

	/* N0 */

	/* N1 */
	sequence_end = SIZE_MAX;
	sequence_prop = NUM_BIDI_PROPS;
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		if (sequence_end == SIZE_MAX) {
			prop = ir_get_current_prop(&ir);

			if (prop == BIDI_PROP_B || prop == BIDI_PROP_S ||
			    prop == BIDI_PROP_WS || prop == BIDI_PROP_ON ||
			    prop == BIDI_PROP_FSI || prop == BIDI_PROP_LRI ||
			    prop == BIDI_PROP_RLI || prop == BIDI_PROP_PDI) {
				/* the current character is an NI (neutral or
				 * isolate) */

				/* scan ahead to the end of the NI-sequence */
				ir_init(buf, buflen, ir.cur.off,
				        paragraph_level, (ir.cur.off > off),
				        &tmp);
				while (!ir_advance(&tmp)) {
					prop = ir_get_next_prop(&tmp);

					if (prop != BIDI_PROP_B &&
					    prop != BIDI_PROP_S &&
					    prop != BIDI_PROP_WS &&
					    prop != BIDI_PROP_ON &&
					    prop != BIDI_PROP_FSI &&
					    prop != BIDI_PROP_LRI &&
					    prop != BIDI_PROP_RLI &&
					    prop != BIDI_PROP_PDI) {
						break;
					}
				}

				/*
				 * check what follows and see if the text has
				 * the same direction on both sides
				 */
				if (ir_get_previous_prop(&ir) == BIDI_PROP_L &&
				    ir_get_next_prop(&tmp) == BIDI_PROP_L) {
					sequence_end = tmp.cur.off;
					sequence_prop = BIDI_PROP_L;
				} else if ((ir_get_previous_prop(&ir) ==
				                    BIDI_PROP_R ||
				            ir_get_previous_prop(&ir) ==
				                    BIDI_PROP_EN ||
				            ir_get_previous_prop(&ir) ==
				                    BIDI_PROP_AN) &&
				           (ir_get_next_prop(&tmp) ==
				                    BIDI_PROP_R ||
				            ir_get_next_prop(&tmp) ==
				                    BIDI_PROP_EN ||
				            ir_get_next_prop(&tmp) ==
				                    BIDI_PROP_AN)) {
					sequence_end = tmp.cur.off;
					sequence_prop = BIDI_PROP_R;
				}
			}
		}

		if (sequence_end != SIZE_MAX) {
			if (ir.cur.off <= sequence_end) {
				ir_set_current_prop(&ir, sequence_prop);
			} else {
				/* end of sequence, reset */
				sequence_end = SIZE_MAX;
				sequence_prop = NUM_BIDI_PROPS;
			}
		}
	}

	/* N2 */
	ir_init(buf, buflen, off, paragraph_level, false, &ir);
	while (!ir_advance(&ir)) {
		prop = ir_get_current_prop(&ir);

		if (prop == BIDI_PROP_B || prop == BIDI_PROP_S ||
		    prop == BIDI_PROP_WS || prop == BIDI_PROP_ON ||
		    prop == BIDI_PROP_FSI || prop == BIDI_PROP_LRI ||
		    prop == BIDI_PROP_RLI || prop == BIDI_PROP_PDI) {
			/* N2 */
			if (ir_get_current_level(&ir) % 2 == 0) {
				/* even embedding level */
				ir_set_current_prop(&ir, BIDI_PROP_L);
			} else {
				/* odd embedding level */
				ir_set_current_prop(&ir, BIDI_PROP_R);
			}
		}
	}

	return 0;
}

static uint_least8_t
get_paragraph_level(enum grapheme_bidirectional_override override,
                    bool terminate_on_pdi, const uint_least32_t *buf,
                    size_t buflen)
{
	enum bidi_property prop;
	int_least8_t isolate_level;
	size_t bufoff;

	/* check overrides first according to rule HL1 */
	if (override == GRAPHEME_BIDIRECTIONAL_OVERRIDE_LTR) {
		return 0;
	} else if (override == GRAPHEME_BIDIRECTIONAL_OVERRIDE_RTL) {
		return 1;
	}

	/* determine paragraph level (rules P1-P3) */

	for (bufoff = 0, isolate_level = 0; bufoff < buflen; bufoff++) {
		prop = (uint_least8_t)get_state(STATE_PROP, buf[bufoff]);

		if (prop == BIDI_PROP_PDI && isolate_level == 0 &&
		    terminate_on_pdi) {
			/*
			 * we are in a FSI-subsection of a paragraph and
			 * matched with the terminating PDI
			 */
			break;
		}

		/* BD8/BD9 */
		if ((prop == BIDI_PROP_LRI || prop == BIDI_PROP_RLI ||
		     prop == BIDI_PROP_FSI) &&
		    isolate_level < MAX_DEPTH) {
			/* we hit an isolate initiator, increment counter */
			isolate_level++;
		} else if (prop == BIDI_PROP_PDI && isolate_level > 0) {
			isolate_level--;
		}

		/* P2 */
		if (isolate_level > 0) {
			continue;
		}

		/* P3 */
		if (prop == BIDI_PROP_L) {
			return 0;
		} else if (prop == BIDI_PROP_AL || prop == BIDI_PROP_R) {
			return 1;
		}
	}

	return 0;
}

static void
preprocess_paragraph(enum grapheme_bidirectional_override override,
                     uint_least32_t *buf, size_t buflen)
{
	enum bidi_property prop;
	int_least8_t level;

	struct {
		int_least8_t level;
		enum grapheme_bidirectional_override override;
		bool directional_isolate;
	} directional_status[MAX_DEPTH + 2], *dirstat = directional_status;

	size_t overflow_isolate_count, overflow_embedding_count,
		valid_isolate_count, bufoff, i, runsince;
	uint_least8_t paragraph_level;

	paragraph_level = get_paragraph_level(override, false, buf, buflen);

	/* X1 */
	dirstat->level = (int_least8_t)paragraph_level;
	dirstat->override = GRAPHEME_BIDIRECTIONAL_OVERRIDE_NEUTRAL;
	dirstat->directional_isolate = false;
	overflow_isolate_count = overflow_embedding_count =
		valid_isolate_count = 0;

	for (bufoff = 0; bufoff < buflen; bufoff++) {
		prop = (uint_least8_t)get_state(STATE_PROP, buf[bufoff]);

		/* set paragraph level we need for line-level-processing */
		set_state(STATE_PARAGRAPH_LEVEL, paragraph_level,
		          &(buf[bufoff]));
again:
		if (prop == BIDI_PROP_RLE) {
			/* X2 */
			if (dirstat->level + (dirstat->level % 2 != 0) + 1 <=
			            MAX_DEPTH &&
			    overflow_isolate_count == 0 &&
			    overflow_embedding_count == 0) {
				/* valid RLE */
				dirstat++;
				dirstat->level =
					(dirstat - 1)->level +
					((dirstat - 1)->level % 2 != 0) + 1;
				dirstat->override =
					GRAPHEME_BIDIRECTIONAL_OVERRIDE_NEUTRAL;
				dirstat->directional_isolate = false;
			} else {
				/* overflow RLE */
				overflow_embedding_count +=
					(overflow_isolate_count == 0);
			}
		} else if (prop == BIDI_PROP_LRE) {
			/* X3 */
			if (dirstat->level + (dirstat->level % 2 == 0) + 1 <=
			            MAX_DEPTH &&
			    overflow_isolate_count == 0 &&
			    overflow_embedding_count == 0) {
				/* valid LRE */
				dirstat++;
				dirstat->level =
					(dirstat - 1)->level +
					((dirstat - 1)->level % 2 == 0) + 1;
				dirstat->override =
					GRAPHEME_BIDIRECTIONAL_OVERRIDE_NEUTRAL;
				dirstat->directional_isolate = false;
			} else {
				/* overflow LRE */
				overflow_embedding_count +=
					(overflow_isolate_count == 0);
			}
		} else if (prop == BIDI_PROP_RLO) {
			/* X4 */
			if (dirstat->level + (dirstat->level % 2 != 0) + 1 <=
			            MAX_DEPTH &&
			    overflow_isolate_count == 0 &&
			    overflow_embedding_count == 0) {
				/* valid RLO */
				dirstat++;
				dirstat->level =
					(dirstat - 1)->level +
					((dirstat - 1)->level % 2 != 0) + 1;
				dirstat->override =
					GRAPHEME_BIDIRECTIONAL_OVERRIDE_RTL;
				dirstat->directional_isolate = false;
			} else {
				/* overflow RLO */
				overflow_embedding_count +=
					(overflow_isolate_count == 0);
			}
		} else if (prop == BIDI_PROP_LRO) {
			/* X5 */
			if (dirstat->level + (dirstat->level % 2 == 0) + 1 <=
			            MAX_DEPTH &&
			    overflow_isolate_count == 0 &&
			    overflow_embedding_count == 0) {
				/* valid LRE */
				dirstat++;
				dirstat->level =
					(dirstat - 1)->level +
					((dirstat - 1)->level % 2 == 0) + 1;
				dirstat->override =
					GRAPHEME_BIDIRECTIONAL_OVERRIDE_LTR;
				dirstat->directional_isolate = false;
			} else {
				/* overflow LRO */
				overflow_embedding_count +=
					(overflow_isolate_count == 0);
			}
		} else if (prop == BIDI_PROP_RLI) {
			/* X5a */
			set_state(STATE_LEVEL, dirstat->level, &(buf[bufoff]));
			if (dirstat->override ==
			    GRAPHEME_BIDIRECTIONAL_OVERRIDE_LTR) {
				set_state(STATE_PROP, BIDI_PROP_L,
				          &(buf[bufoff]));
			} else if (dirstat->override ==
			           GRAPHEME_BIDIRECTIONAL_OVERRIDE_RTL) {
				set_state(STATE_PROP, BIDI_PROP_R,
				          &(buf[bufoff]));
			}

			if (dirstat->level + (dirstat->level % 2 != 0) + 1 <=
			            MAX_DEPTH &&
			    overflow_isolate_count == 0 &&
			    overflow_embedding_count == 0) {
				/* valid RLI */
				valid_isolate_count++;

				dirstat++;
				dirstat->level =
					(dirstat - 1)->level +
					((dirstat - 1)->level % 2 != 0) + 1;
				dirstat->override =
					GRAPHEME_BIDIRECTIONAL_OVERRIDE_NEUTRAL;
				dirstat->directional_isolate = true;
			} else {
				/* overflow RLI */
				overflow_isolate_count++;
			}
		} else if (prop == BIDI_PROP_LRI) {
			/* X5b */
			set_state(STATE_LEVEL, dirstat->level, &(buf[bufoff]));
			if (dirstat->override ==
			    GRAPHEME_BIDIRECTIONAL_OVERRIDE_LTR) {
				set_state(STATE_PROP, BIDI_PROP_L,
				          &(buf[bufoff]));
			} else if (dirstat->override ==
			           GRAPHEME_BIDIRECTIONAL_OVERRIDE_RTL) {
				set_state(STATE_PROP, BIDI_PROP_R,
				          &(buf[bufoff]));
			}

			if (dirstat->level + (dirstat->level % 2 == 0) + 1 <=
			            MAX_DEPTH &&
			    overflow_isolate_count == 0 &&
			    overflow_embedding_count == 0) {
				/* valid LRI */
				valid_isolate_count++;

				dirstat++;
				dirstat->level =
					(dirstat - 1)->level +
					((dirstat - 1)->level % 2 == 0) + 1;
				dirstat->override =
					GRAPHEME_BIDIRECTIONAL_OVERRIDE_NEUTRAL;
				dirstat->directional_isolate = true;
			} else {
				/* overflow LRI */
				overflow_isolate_count++;
			}
		} else if (prop == BIDI_PROP_FSI) {
			/* X5c */
			if (get_paragraph_level(
				    GRAPHEME_BIDIRECTIONAL_OVERRIDE_NEUTRAL,
				    true, buf + (bufoff + 1),
				    buflen - (bufoff + 1)) == 1) {
				prop = BIDI_PROP_RLI;
				goto again;
			} else { /* ... == 0 */
				prop = BIDI_PROP_LRI;
				goto again;
			}
		} else if (prop != BIDI_PROP_B && prop != BIDI_PROP_BN &&
		           prop != BIDI_PROP_PDF && prop != BIDI_PROP_PDI) {
			/* X6 */
			set_state(STATE_LEVEL, dirstat->level, &(buf[bufoff]));
			if (dirstat->override ==
			    GRAPHEME_BIDIRECTIONAL_OVERRIDE_LTR) {
				set_state(STATE_PROP, BIDI_PROP_L,
				          &(buf[bufoff]));
			} else if (dirstat->override ==
			           GRAPHEME_BIDIRECTIONAL_OVERRIDE_RTL) {
				set_state(STATE_PROP, BIDI_PROP_R,
				          &(buf[bufoff]));
			}
		} else if (prop == BIDI_PROP_PDI) {
			/* X6a */
			if (overflow_isolate_count > 0) {
				/* PDI matches an overflow isolate initiator */
				overflow_isolate_count--;
			} else if (valid_isolate_count > 0) {
				/* PDI matches a normal isolate initiator */
				overflow_embedding_count = 0;
				while (dirstat->directional_isolate == false &&
				       dirstat > directional_status) {
					/*
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
					 * has the directional isolate status
					 * true and store a pointer to it
					 * so we can jump to it very quickly.
					 */
					dirstat--;
				}

				/*
				 * as above, the following check is not
				 * necessary, given we are guaranteed to
				 * have at least one stack entry left,
				 * but it's better to be safe
				 */
				if (dirstat > directional_status) {
					dirstat--;
				}
				valid_isolate_count--;
			}

			set_state(STATE_LEVEL, dirstat->level, &(buf[bufoff]));
			if (dirstat->override ==
			    GRAPHEME_BIDIRECTIONAL_OVERRIDE_LTR) {
				set_state(STATE_PROP, BIDI_PROP_L,
				          &(buf[bufoff]));
			} else if (dirstat->override ==
			           GRAPHEME_BIDIRECTIONAL_OVERRIDE_RTL) {
				set_state(STATE_PROP, BIDI_PROP_R,
				          &(buf[bufoff]));
			}
		} else if (prop == BIDI_PROP_PDF) {
			/* X7 */
			if (overflow_isolate_count > 0) {
				/* do nothing */
			} else if (overflow_embedding_count > 0) {
				overflow_embedding_count--;
			} else if (dirstat->directional_isolate == false &&
			           dirstat > directional_status) {
				dirstat--;
			}
		} else if (prop == BIDI_PROP_B) {
			/* X8 */
			set_state(STATE_LEVEL, paragraph_level, &(buf[bufoff]));
		}

		/* X9 */
		if (prop == BIDI_PROP_RLE || prop == BIDI_PROP_LRE ||
		    prop == BIDI_PROP_RLO || prop == BIDI_PROP_LRO ||
		    prop == BIDI_PROP_PDF || prop == BIDI_PROP_BN) {
			set_state(STATE_LEVEL, -1, &(buf[bufoff]));
		}
	}

	/* X10 (W1-W7, N0-N2) */
	for (bufoff = 0; bufoff < buflen; bufoff++) {
		if (get_state(STATE_VISITED, buf[bufoff]) == 0 &&
		    get_state(STATE_LEVEL, buf[bufoff]) != -1) {
			bufoff += preprocess_isolating_run_sequence(
				buf, buflen, bufoff, paragraph_level);
		}
	}

	/*
	 * I1-I2 (given our sequential approach to processing the
	 * isolating run sequences, we apply this rule separately)
	 */
	for (bufoff = 0; bufoff < buflen; bufoff++) {
		level = (int_least8_t)get_state(STATE_LEVEL, buf[bufoff]);
		prop = (uint_least8_t)get_state(STATE_PROP, buf[bufoff]);

		if (level % 2 == 0) {
			/* even level */
			if (prop == BIDI_PROP_R) {
				set_state(STATE_LEVEL, level + 1,
				          &(buf[bufoff]));
			} else if (prop == BIDI_PROP_AN ||
			           prop == BIDI_PROP_EN) {
				set_state(STATE_LEVEL, level + 2,
				          &(buf[bufoff]));
			}
		} else {
			/* odd level */
			if (prop == BIDI_PROP_L || prop == BIDI_PROP_EN ||
			    prop == BIDI_PROP_AN) {
				set_state(STATE_LEVEL, level + 1,
				          &(buf[bufoff]));
			}
		}
	}

	/* L1 (rules 1-3) */
	runsince = SIZE_MAX;
	for (bufoff = 0; bufoff < buflen; bufoff++) {
		level = (int_least8_t)get_state(STATE_LEVEL, buf[bufoff]);
		prop = (uint_least8_t)get_state(STATE_PRESERVED_PROP,
		                                buf[bufoff]);

		if (level == -1) {
			/* ignored character */
			continue;
		}

		/* rules 1 and 2 */
		if (prop == BIDI_PROP_S || prop == BIDI_PROP_B) {
			set_state(STATE_LEVEL, paragraph_level, &(buf[bufoff]));
		}

		/* rule 3 */
		if (prop == BIDI_PROP_WS || prop == BIDI_PROP_FSI ||
		    prop == BIDI_PROP_LRI || prop == BIDI_PROP_RLI ||
		    prop == BIDI_PROP_PDI) {
			if (runsince == SIZE_MAX) {
				/* a new run has begun */
				runsince = bufoff;
			}
		} else if ((prop == BIDI_PROP_S || prop == BIDI_PROP_B) &&
		           runsince != SIZE_MAX) {
			/*
			 * we hit a segment or paragraph separator in a
			 * sequence, reset sequence-levels
			 */
			for (i = runsince; i < bufoff; i++) {
				if (get_state(STATE_LEVEL, buf[i]) != -1) {
					set_state(STATE_LEVEL, paragraph_level,
					          &(buf[i]));
				}
			}
			runsince = SIZE_MAX;
		} else {
			/* sequence ended */
			runsince = SIZE_MAX;
		}
	}
	if (runsince != SIZE_MAX) {
		/*
		 * this is the end of the paragraph and we
		 * are in a run
		 */
		for (i = runsince; i < buflen; i++) {
			if (get_state(STATE_LEVEL, buf[i]) != -1) {
				set_state(STATE_LEVEL, paragraph_level,
				          &(buf[i]));
			}
		}
		runsince = SIZE_MAX;
	}
}

static inline uint_least8_t
get_bidi_property(uint_least32_t cp)
{
	if (likely(cp <= 0x10FFFF)) {
		return (bidi_minor[bidi_major[cp >> 8] + (cp & 0xff)]) &
		       0x1F /* 00011111 */;
	} else {
		return BIDI_PROP_L;
	}
}

static inline uint_least8_t
get_bidi_bracket_off(uint_least32_t cp)
{
	if (likely(cp <= 0x10FFFF)) {
		return (bidi_minor[bidi_major[cp >> 8] + (cp & 0xff)]) >> 5;
	} else {
		return 0;
	}
}

static size_t
preprocess(HERODOTUS_READER *r, enum grapheme_bidirectional_override override,
           uint_least32_t *buf, size_t buflen)
{
	size_t bufoff, bufsize, lastparoff;
	uint_least32_t cp;

	if (buf == NULL) {
		for (; herodotus_read_codepoint(r, true, &cp) ==
		       HERODOTUS_STATUS_SUCCESS;) {
			;
		}

		/* see below for return value reasoning */
		return herodotus_reader_number_read(r);
	}

	/*
	 * the first step is to determine the bidirectional properties
	 * and store them in the buffer
	 */
	for (bufoff = 0;
	     herodotus_read_codepoint(r, true, &cp) == HERODOTUS_STATUS_SUCCESS;
	     bufoff++) {
		if (bufoff < buflen) {
			/*
			 * actually only do something when we have
			 * space in the level-buffer. We continue
			 * the iteration to be able to give a good
			 * return value
			 */
			set_state(STATE_PROP,
			          (uint_least8_t)get_bidi_property(cp),
			          &(buf[bufoff]));
			set_state(STATE_BRACKET_OFF, get_bidi_bracket_off(cp),
			          &(buf[bufoff]));
			set_state(STATE_LEVEL, 0, &(buf[bufoff]));
			set_state(STATE_PARAGRAPH_LEVEL, 0, &(buf[bufoff]));
			set_state(STATE_VISITED, 0, &(buf[bufoff]));
			set_state(STATE_PRESERVED_PROP,
			          (uint_least8_t)get_bidi_property(cp),
			          &(buf[bufoff]));
		}
	}
	bufsize = herodotus_reader_number_read(r);

	for (bufoff = 0, lastparoff = 0; bufoff < bufsize; bufoff++) {
		if (get_state(STATE_PROP, buf[bufoff]) != BIDI_PROP_B &&
		    bufoff != bufsize - 1) {
			continue;
		}

		/*
		 * we either encountered a paragraph terminator or this
		 * is the last character in the string.
		 * Call the paragraph handler on the paragraph, including
		 * the terminating character or last character of the
		 * string respectively
		 */
		preprocess_paragraph(override, buf + lastparoff,
		                     bufoff + 1 - lastparoff);
		lastparoff = bufoff + 1;
	}

	/*
	 * we return the number of total bytes read, as the function
	 * should indicate if the given level-buffer is too small
	 */
	return herodotus_reader_number_read(r);
}

size_t
grapheme_bidirectional_preprocess(const uint_least32_t *src, size_t srclen,
                                  enum grapheme_bidirectional_override override,
                                  uint_least32_t *dest, size_t destlen)
{
	HERODOTUS_READER r;

	herodotus_reader_init(&r, HERODOTUS_TYPE_CODEPOINT, src, srclen);

	return preprocess(&r, override, dest, destlen);
}

size_t
grapheme_bidirectional_preprocess_utf8(
	const char *src, size_t srclen,
	enum grapheme_bidirectional_override override, uint_least32_t *dest,
	size_t destlen)
{
	HERODOTUS_READER r;

	herodotus_reader_init(&r, HERODOTUS_TYPE_UTF8, src, srclen);

	return preprocess(&r, override, dest, destlen);
}

void
grapheme_bidirectional_get_line_embedding_levels(const uint_least32_t *linedata,
                                                 size_t linelen,
                                                 int_least8_t *linelevel)
{
	enum bidi_property prop;
	size_t i, runsince;

	/* rule L1.4 */
	runsince = SIZE_MAX;
	for (i = 0; i < linelen; i++) {
		prop = (uint_least8_t)get_state(STATE_PRESERVED_PROP,
		                                linedata[i]);

		/* write level into level array */
		if ((linelevel[i] = (int_least8_t)get_state(
			     STATE_LEVEL, linedata[i])) == -1) {
			/* ignored character */
			continue;
		}

		if (prop == BIDI_PROP_WS || prop == BIDI_PROP_FSI ||
		    prop == BIDI_PROP_LRI || prop == BIDI_PROP_RLI ||
		    prop == BIDI_PROP_PDI) {
			if (runsince == SIZE_MAX) {
				/* a new run has begun */
				runsince = i;
			}
		} else {
			/* sequence ended */
			runsince = SIZE_MAX;
		}
	}
	if (runsince != SIZE_MAX) {
		/*
		 * we hit the end of the line but were in a run;
		 * reset the line levels to the paragraph level
		 */
		for (i = runsince; i < linelen; i++) {
			if (linelevel[i] != -1) {
				linelevel[i] = (int_least8_t)get_state(
					STATE_PARAGRAPH_LEVEL, linedata[i]);
			}
		}
	}
}
