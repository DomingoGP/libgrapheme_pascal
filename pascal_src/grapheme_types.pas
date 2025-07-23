{ISC-License

Object Pascal port of the libgraphene library plus some additions:
changes in pascal* folders.
Copyright 2024-2025 Domingo Galmés <dgalmesp@gmail.com>

Original license of the C version read below.

Copyright 2019-2022 Laslo Hunhold <dev@frign.de>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Home page:

Port to pascal
https://github.com/DomingoGP/libgrapheme_pascal

Original C library
https://git.suckless.org/libgrapheme/
}

unit grapheme_types;

{$ifdef FPC}{$mode delphi}{$endif}

interface

uses
  Classes, SysUtils;

const
  GRAPHEME_INVALID_CODEPOINT = $FFFD;
  SIZE_MAX = 4294967295;                          // taken from libc freepascal.
  GRAPHEME_SIZE_MAX = SIZE_MAX;
  GRAPHEME_LAST_CODEPOINT = $10FFFF;

type

  Pgrapheme_bidirectional_direction = ^grapheme_bidirectional_direction;
  grapheme_bidirectional_direction = (
    GRAPHEME_BIDIRECTIONAL_DIRECTION_NEUTRAL,
    GRAPHEME_BIDIRECTIONAL_DIRECTION_LTR,
    GRAPHEME_BIDIRECTIONAL_DIRECTION_RTL
    );

  Psize_t = ^size_t;
  Puint_least32_t = PUInt32;
  uint_least32_t = uint32;
  Pint_least32_t = PInt32;
  int_least32_t = int32;
  Puint_least16_t = PUInt16;
  uint_least16_t = uint16;
  Pint_least16_t = PInt16;
  int_least16_t = int16;
  uint_least8_t = uint8;
  Pint_least8_t = PInt8;
  int_least8_t = int8;


implementation

end.
