/* See LICENSE file for copyright and license details. */
#include <errno.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../grapheme.h"
#include "util.h"

struct bidirectional_test {
	uint_least32_t *cp;
	size_t cplen;
	enum grapheme_bidirectional_direction mode[3];
	size_t modelen;
	enum grapheme_bidirectional_direction resolved;
	int_least8_t *level;
	int_least16_t *reorder;
	size_t reorderlen;
};

static const struct {
	const char *class;
	const uint_least32_t cp;
} classcpmap[] = {
	{ .class = "L", .cp = UINT32_C(0x0041) },
	{ .class = "AL", .cp = UINT32_C(0x0608) },
	{ .class = "AN", .cp = UINT32_C(0x0600) },
	{ .class = "B", .cp = UINT32_C(0x000A) },
	{ .class = "BN", .cp = UINT32_C(0x0000) },
	{ .class = "CS", .cp = UINT32_C(0x002C) },
	{ .class = "EN", .cp = UINT32_C(0x0030) },
	{ .class = "ES", .cp = UINT32_C(0x002B) },
	{ .class = "ET", .cp = UINT32_C(0x0023) },
	{ .class = "FSI", .cp = UINT32_C(0x2068) },
	{ .class = "LRE", .cp = UINT32_C(0x202A) },
	{ .class = "LRI", .cp = UINT32_C(0x2066) },
	{ .class = "LRO", .cp = UINT32_C(0x202D) },
	{ .class = "NSM", .cp = UINT32_C(0x0300) },
	{ .class = "ON", .cp = UINT32_C(0x0021) },
	{ .class = "PDF", .cp = UINT32_C(0x202C) },
	{ .class = "PDI", .cp = UINT32_C(0x2069) },
	{ .class = "R", .cp = UINT32_C(0x05BE) },
	{ .class = "RLE", .cp = UINT32_C(0x202B) },
	{ .class = "RLI", .cp = UINT32_C(0x2067) },
	{ .class = "RLO", .cp = UINT32_C(0x202E) },
	{ .class = "S", .cp = UINT32_C(0x0009) },
	{ .class = "WS", .cp = UINT32_C(0x000C) },
};

static int
classtocp(const char *str, size_t len, uint_least32_t *cp)
{
	size_t i;

	for (i = 0; i < LEN(classcpmap); i++) {
		if (!strncmp(str, classcpmap[i].class, len)) {
			*cp = classcpmap[i].cp;
			return 0;
		}
	}
	fprintf(stderr, "classtocp: unknown class string '%.*s'.\n", (int)len,
	        str);

	return 1;
}

static int
parse_class_list(const char *str, uint_least32_t **cp, size_t *cplen)
{
	size_t count, i;
	const char *tmp1 = NULL, *tmp2 = NULL;

	if (strlen(str) == 0) {
		*cp = NULL;
		*cplen = 0;
		return 0;
	}

	/* count the number of spaces in the string and infer list length */
	for (count = 1, tmp1 = str; (tmp2 = strchr(tmp1, ' ')) != NULL;
	     count++, tmp1 = tmp2 + 1) {
		;
	}

	/* allocate resources */
	if (!(*cp = calloc((*cplen = count), sizeof(**cp)))) {
		fprintf(stderr, "calloc: %s\n", strerror(errno));
		exit(1);
	}

	/* go through the string again, parsing the classes */
	for (i = 0, tmp1 = tmp2 = str; tmp2 != NULL; i++) {
		tmp2 = strchr(tmp1, ' ');
		if (classtocp(tmp1, tmp2 ? (size_t)(tmp2 - tmp1) : strlen(tmp1),
		              &((*cp)[i]))) {
			return 1;
		}
		if (tmp2 != NULL) {
			tmp1 = tmp2 + 1;
		}
	}

	return 0;
}

static int
strtolevel(const char *str, size_t len, int_least8_t *level)
{
	size_t i;

	if (len == 1 && str[0] == 'x') {
		/*
		 * 'x' indicates those characters that are ignored.
		 * We indicate this with a level of -1
		 */
		*level = -1;
		return 0;
	}

	if (len > 3) {
		/*
		 * given we can only express (positive) numbers from
		 * 0..127, more than 3 digits means an excess
		 */
		goto toolarge;
	}

	/* check if the string is completely numerical */
	for (i = 0; i < len; i++) {
		if (str[i] < '0' && str[i] > '9') {
			fprintf(stderr,
			        "strtolevel: '%.*s' is not an integer.\n",
			        (int)len, str);
			return 1;
		}
	}

	if (len == 3) {
		if (str[0] != '1' || str[1] > '2' ||
		    (str[1] == '2' && str[2] > '7')) {
			goto toolarge;
		}
		*level = (str[0] - '0') * 100 + (str[1] - '0') * 10 +
		         (str[2] - '0');
	} else if (len == 2) {
		*level = (str[0] - '0') * 10 + (str[1] - '0');
	} else if (len == 1) {
		*level = (str[0] - '0');
	} else { /* len == 0 */
		*level = 0;
	}

	return 0;
toolarge:
	fprintf(stderr, "strtolevel: '%.*s' is too large.\n", (int)len, str);
	return 1;
}

static int
strtoreorder(const char *str, size_t len, int_least16_t *reorder)
{
	size_t i;

	if (len == 1 && str[0] == 'x') {
		/*
		 * 'x' indicates those characters that are ignored.
		 * We indicate this with a reorder of -1
		 */
		*reorder = -1;
		return 0;
	}

	if (len > 3) {
		/*
		 * given we want to only express (positive) numbers from
		 * 0..999 (at most!), more than 3 digits means an excess
		 */
		goto toolarge;
	}

	/* check if the string is completely numerical */
	for (i = 0; i < len; i++) {
		if (str[i] < '0' && str[i] > '9') {
			fprintf(stderr,
			        "strtoreorder: '%.*s' is not an integer.\n",
			        (int)len, str);
			return 1;
		}
	}

	if (len == 3) {
		*reorder = (str[0] - '0') * 100 + (str[1] - '0') * 10 +
		           (str[2] - '0');
	} else if (len == 2) {
		*reorder = (str[0] - '0') * 10 + (str[1] - '0');
	} else if (len == 1) {
		*reorder = (str[0] - '0');
	} else { /* len == 0 */
		*reorder = 0;
	}

	return 0;
toolarge:
	fprintf(stderr, "strtoreorder: '%.*s' is too large.\n", (int)len, str);
	return 1;
}

static int
parse_level_list(const char *str, int_least8_t **level, size_t *levellen)
{
	size_t count, i;
	const char *tmp1 = NULL, *tmp2 = NULL;

	if (strlen(str) == 0) {
		*level = NULL;
		*levellen = 0;
		return 0;
	}

	/* count the number of spaces in the string and infer list length */
	for (count = 1, tmp1 = str; (tmp2 = strchr(tmp1, ' ')) != NULL;
	     count++, tmp1 = tmp2 + 1) {
		;
	}

	/* allocate resources */
	if (!(*level = calloc((*levellen = count), sizeof(**level)))) {
		fprintf(stderr, "calloc: %s\n", strerror(errno));
		exit(1);
	}

	/* go through the string again, parsing the levels */
	for (i = 0, tmp1 = tmp2 = str; tmp2 != NULL; i++) {
		tmp2 = strchr(tmp1, ' ');
		if (strtolevel(tmp1,
		               tmp2 ? (size_t)(tmp2 - tmp1) : strlen(tmp1),
		               &((*level)[i]))) {
			return 1;
		}
		if (tmp2 != NULL) {
			tmp1 = tmp2 + 1;
		}
	}

	return 0;
}

static int
parse_reorder_list(const char *str, int_least16_t **reorder, size_t *reorderlen)
{
	size_t count, i;
	const char *tmp1 = NULL, *tmp2 = NULL;

	if (strlen(str) == 0) {
		*reorder = NULL;
		*reorderlen = 0;
		return 0;
	}

	/* count the number of spaces in the string and infer list length */
	for (count = 1, tmp1 = str; (tmp2 = strchr(tmp1, ' ')) != NULL;
	     count++, tmp1 = tmp2 + 1) {
		;
	}

	/* allocate resources */
	if (!(*reorder = calloc((*reorderlen = count), sizeof(**reorder)))) {
		fprintf(stderr, "calloc: %s\n", strerror(errno));
		exit(1);
	}

	/* go through the string again, parsing the reorders */
	for (i = 0, tmp1 = tmp2 = str; tmp2 != NULL; i++) {
		tmp2 = strchr(tmp1, ' ');
		if (strtoreorder(tmp1,
		                 tmp2 ? (size_t)(tmp2 - tmp1) : strlen(tmp1),
		                 &((*reorder)[i]))) {
			return 1;
		}
		if (tmp2 != NULL) {
			tmp1 = tmp2 + 1;
		}
	}

	return 0;
}

static void
bidirectional_test_list_print(const struct bidirectional_test *test,
                              size_t testlen, const char *identifier,
                              const char *progname)
{
	size_t i, j;

	printf("{/* Automatically generated by %s */}\n\n", progname);
    printf("type\n\n");

	printf("bidirectional_test_type=record\n"
	       "\tcp:array of uint_least32_t;\n"
	       "\tcplen:size_t;\n"
	       "\tmode:array of grapheme_bidirectional_direction;\n"
	       "\tmodelen:size_t;\n"
	       "\tresolved:grapheme_bidirectional_direction;\n"
	       "\tlevel:array of int_least8_t;\n"
	       "\treorder:array of int_least16_t;\n"
	       "\treorderlen:size_t;\n"
		   "\tend;\n");
		   
    printf("\n");		   
	printf("const\n");	
    printf("%s:array[0..%d] of bidirectional_test_type = (",identifier,testlen-1);	
	
	for (i = 0; i < testlen; i++) {
		printf("\n\t(\n");

		printf("\t\tcp         : [");
		for (j = 0; j < test[i].cplen; j++) {
			printf(" $%06X", test[i].cp[j]);
			if (j + 1 < test[i].cplen) {
				putchar(',');
			}
		}
		printf(" ];\n");
		printf("\t\tcplen      : %zu;\n", test[i].cplen);

		printf("\t\tmode       : [");
		for (j = 0; j < test[i].modelen; j++) {
			if (test[i].mode[j] ==
			    GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL) {
				printf(" GRAPHEME_BIDIRECTIONAL_DIRECTION_"
				       "NEUTRAL");
			} else if (test[i].mode[j] ==
			           GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR) {
				printf(" GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR");
			} else if (test[i].mode[j] ==
			           GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL) {
				printf(" GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL");
			}
			if (j + 1 < test[i].modelen) {
				putchar(',');
			}
		}
		printf(" ];\n");
		printf("\t\tmodelen    : %zu;\n", test[i].modelen);

		printf("\t\tresolved   : ");
		if (test[i].resolved ==
		    GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL) {
			printf("GRAPHEME_BIDIRECTIONAL_DIRECTION_"
			       "NEUTRAL");
		} else if (test[i].resolved ==
		           GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR) {
			printf("GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR");
		} else if (test[i].resolved ==
		           GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL) {
			printf("GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL");
		}
		printf(";\n");

		printf("\t\tlevel      : [");
		for (j = 0; j < test[i].cplen; j++) {
			printf(" %" PRIdLEAST8, test[i].level[j]);
			if (j + 1 < test[i].cplen) {
				putchar(',');
			}
		}
		printf(" ];\n");

		printf("\t\treorder    : ");
		if (test[i].reorderlen > 0) {
			printf("[");
			for (j = 0; j < test[i].reorderlen; j++) {
				printf(" %" PRIdLEAST16, test[i].reorder[j]);
				if (j + 1 < test[i].reorderlen) {
					putchar(',');
				}
			}
			printf(" ];\n");
		} else {
			printf("nil;\n");
		}
		printf("\t\treorderlen : %zu\n", test[i].reorderlen);

		printf("\t)");
		if (i < (testlen-1)){
		  printf(",");
		}
		printf("\n");
	}
	printf(");\n");
}

static struct bidirectional_test *test;
static size_t testlen;

static int_least8_t *current_level;
static size_t current_level_len;
static int_least16_t *current_reorder;
static size_t current_reorder_len;

static int
test_callback(const char *file, char **field, size_t nfields, char *comment,
              void *payload)
{
	char *tmp;

	(void)file;
	(void)comment;
	(void)payload;

	/* we either get a line beginning with an '@', or an input line */
	if (nfields > 0 && field[0][0] == '@') {
		if (!strncmp(field[0], "@Levels:", sizeof("@Levels:") - 1)) {
			tmp = field[0] + sizeof("@Levels:") - 1;
			for (; *tmp != '\0' && (*tmp == ' ' || *tmp == '\t');
			     tmp++) {
				;
			}
			free(current_level);
			parse_level_list(tmp, &current_level,
			                 &current_level_len);
		} else if (!strncmp(field[0],
		                    "@Reorder:", sizeof("@Reorder:") - 1)) {
			tmp = field[0] + sizeof("@Reorder:") - 1;
			for (; *tmp != '\0' && (*tmp == ' ' || *tmp == '\t');
			     tmp++) {
				;
			}
			free(current_reorder);
			parse_reorder_list(tmp, &current_reorder,
			                   &current_reorder_len);
		} else {
			fprintf(stderr, "Unknown @-input-line.\n");
			exit(1);
		}
	} else {
		if (nfields < 2) {
			/* discard any line that does not have at least 2 fields
			 */
			return 0;
		}

		/* extend test array */
		if (!(test = realloc(test, (++testlen) * sizeof(*test)))) {
			fprintf(stderr, "realloc: %s\n", strerror(errno));
			exit(1);
		}

		/* parse field data */
		parse_class_list(field[0], &(test[testlen - 1].cp),
		                 &(test[testlen - 1].cplen));

		/* copy current level- and reorder-arrays */
		if (!(test[testlen - 1].level =
		              calloc(current_level_len,
		                     sizeof(*(test[testlen - 1].level))))) {
			fprintf(stderr, "calloc: %s\n", strerror(errno));
			exit(1);
		}
		memcpy(test[testlen - 1].level, current_level,
		       current_level_len * sizeof(*(test[testlen - 1].level)));

		if (!(test[testlen - 1].reorder =
		              calloc(current_reorder_len,
		                     sizeof(*(test[testlen - 1].reorder))))) {
			fprintf(stderr, "calloc: %s\n", strerror(errno));
			exit(1);
		}
		if (current_reorder != NULL) {
			memcpy(test[testlen - 1].reorder, current_reorder,
			       current_reorder_len *
			               sizeof(*(test[testlen - 1].reorder)));
		}
		test[testlen - 1].reorderlen = current_reorder_len;

		if (current_level_len != test[testlen - 1].cplen) {
			fprintf(stderr,
			        "mismatch between string and level lengths.\n");
			exit(1);
		}

		/* parse paragraph-level-bitset */
		if (strlen(field[1]) != 1) {
			fprintf(stderr, "malformed paragraph-level-bitset.\n");
			exit(1);
		} else if (field[1][0] == '2') {
			test[testlen - 1].mode[0] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR;
			test[testlen - 1].modelen = 1;
		} else if (field[1][0] == '3') {
			/* auto=0 and LTR=1 */
			test[testlen - 1].mode[0] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
			test[testlen - 1].mode[1] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR;
			test[testlen - 1].modelen = 2;
		} else if (field[1][0] == '4') {
			test[testlen - 1].mode[0] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL;
			test[testlen - 1].modelen = 1;
		} else if (field[1][0] == '5') {
			test[testlen - 1].mode[0] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
			test[testlen - 1].mode[1] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL;
			test[testlen - 1].modelen = 2;
		} else if (field[1][0] == '7') {
			test[testlen - 1].mode[0] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
			test[testlen - 1].mode[1] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR;
			test[testlen - 1].mode[2] =
				GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL;
			test[testlen - 1].modelen = 3;
		} else {
			fprintf(stderr,
			        "unhandled paragraph-level-bitset %s.\n",
			        field[1]);
			exit(1);
		}

		/* the resolved paragraph level is always neutral as the test
		 * file does not specify it */
		test[testlen - 1].resolved =
			GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
	}

	return 0;
}

static int
character_test_callback(const char *file, char **field, size_t nfields,
                        char *comment, void *payload)
{
	size_t tmp;

	(void)file;
	(void)comment;
	(void)payload;

	if (nfields < 5) {
		/* discard any line that does not have at least 5 fields */
		return 0;
	}

	/* extend test array */
	if (!(test = realloc(test, (++testlen) * sizeof(*test)))) {
		fprintf(stderr, "realloc: %s\n", strerror(errno));
		exit(1);
	}

	/* parse field data */
	parse_cp_list(field[0], &(test[testlen - 1].cp),
	              &(test[testlen - 1].cplen));
	parse_level_list(field[3], &(test[testlen - 1].level), &tmp);
	parse_reorder_list(field[4], &(test[testlen - 1].reorder),
	                   &(test[testlen - 1].reorderlen));

	/* parse paragraph-level-mode */
	if (strlen(field[1]) != 1) {
		fprintf(stderr, "malformed paragraph-level-setting.\n");
		exit(1);
	} else if (field[1][0] == '0') {
		test[testlen - 1].mode[0] =
			GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR;
	} else if (field[1][0] == '1') {
		test[testlen - 1].mode[0] =
			GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL;
	} else if (field[1][0] == '2') {
		test[testlen - 1].mode[0] =
			GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL;
	} else {
		fprintf(stderr, "unhandled paragraph-level-setting.\n");
		exit(1);
	}
	test[testlen - 1].modelen = 1;

	/* parse resolved paragraph level */
	if (strlen(field[2]) != 1) {
		fprintf(stderr, "malformed resolved paragraph level.\n");
		exit(1);
	} else if (field[2][0] == '0') {
		test[testlen - 1].resolved =
			GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR;
	} else if (field[2][0] == '1') {
		test[testlen - 1].resolved =
			GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL;
	} else {
		fprintf(stderr, "unhandled resolved paragraph level.\n");
		exit(1);
	}

	if (tmp != test[testlen - 1].cplen) {
		fprintf(stderr, "mismatch between string and level lengths.\n");
		exit(1);
	}

	return 0;
}

int
main(int argc, char *argv[])
{
	(void)argc;

	parse_file_with_callback("data/BidiTest.txt", test_callback, NULL);
	parse_file_with_callback("data/BidiCharacterTest.txt",
	                         character_test_callback, NULL);
	bidirectional_test_list_print(test, testlen, "bidirectional_test",
	                              argv[0]);

	return 0;
}
