#include <string.h>
#include "../deps/yespower-1.0.1/yespower.h"

static yespower_params_t params = {
  .version = YESPOWER_0_5,
  .N = 2048,
  .r = 8,
  .pers = (const uint8_t *)"Client Key",
  .perslen = strlen("Client Key")
};

static yespower_params_t params_n2r8 = {
  .version = YESPOWER_1_0,
  .N = 2048,
  .r = 8,
  .pers = (const uint8_t *)NULL,
  .perslen = 0
};

static yespower_params_t params_n4r16 = {
  .version = YESPOWER_1_0,
  .N = 4096,
  .r = 16,
  .pers = (const uint8_t *)NULL,
  .perslen = 0
};

static yespower_params_t params_n4r32 = {
  .version = YESPOWER_1_0,
  .N = 4096,
  .r = 32,
  .pers = (const uint8_t *)NULL,
  .perslen = 0
};

int yespower_hash(const char *input, int input_size, char *output)
{
  return yespower_tls((uint8_t *)input, input_size, &params, output);
}

int yespower_n2r8(const char *input, int input_size, char *output)
{
  return yespower_tls((uint8_t *)input, input_size, &params_n2r8, output);
}

int yespower_n4r16(const char *input, int input_size, char *output)
{
  return yespower_tls((uint8_t *)input, input_size, &params_n4r16, output);
}

int yespower_n4r32(const char *input, int input_size, char *output)
{
  return yespower_tls((uint8_t *)input, input_size, &params_n4r32, output);
}
