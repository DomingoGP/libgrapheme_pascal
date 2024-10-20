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
