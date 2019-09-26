#include <string.h>
#include "../deps/yespower-1.0.1/yespower.h"

static yespower_params_t params = {
  .version = YESPOWER_0_5,
  .N = 2048,
  .r = 8,
  .pers = (const uint8_t *)"Client Key",
  .perslen = strlen("Client Key")
};

int yespower_hash(const char *input, int input_size, char *output)
{
  return yespower_tls((uint8_t *)input, input_size, &params, output);
}
