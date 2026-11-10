#ifndef HEY_UTF8_SUPPORT
#define HEY_UTF8_SUPPORT

static bool hey_valid_utf8_bytes(const char *text, size_t size) {
  if (!size) return true;
  const unsigned char *cursor = (const unsigned char *)text;
  const unsigned char *end = cursor + size;
  while (cursor < end) {
    unsigned lead = *cursor++;
    if (lead < 0x80) continue;
    unsigned count, low = 0x80, high = 0xbf;
    if (lead >= 0xc2 && lead <= 0xdf) count = 1;
    else if (lead >= 0xe0 && lead <= 0xef) {
      count = 2;
      if (lead == 0xe0) low = 0xa0;
      if (lead == 0xed) high = 0x9f;
    } else if (lead >= 0xf0 && lead <= 0xf4) {
      count = 3;
      if (lead == 0xf0) low = 0x90;
      if (lead == 0xf4) high = 0x8f;
    } else return false;
    if ((size_t)(end - cursor) < count) return false;
    for (unsigned i = 0; i < count; i++) {
      unsigned byte = *cursor++;
      if (byte < low || byte > high) return false;
      low = 0x80;
      high = 0xbf;
    }
  }
  return true;
}

static bool hey_valid_utf8(const char *text) {
  return hey_valid_utf8_bytes(text, strlen(text));
}
#endif
