/*-----------------------------------------------------------------------------
 * MurmurHash3 was written by Austin Appleby, and is placed in the public
 * domain.
 *
 * This is a c++ implementation of MurmurHash3_128 with support for progressive
 * processing based on PMurHash implementation written by Shane Day.
 */

/* ------------------------------------------------------------------------- */

// Microsoft Visual Studio

#if defined(_MSC_VER) && (_MSC_VER < 1600)

typedef unsigned char uint8_t;
typedef unsigned int uint32_t;
typedef unsigned __int64 uint64_t;

// Other compilers

#else // defined(_MSC_VER)

#include <stdint.h>

#endif // !defined(_MSC_VER)

/* ------------------------------------------------------------------------- */
/* Formal prototypes */

extern "C" {
// PMurHash128x86
void PMurHash128_Process(uint32_t ph[4], uint32_t pcarry[4], const void *key, int len);
void PMurHash128_Result(const uint32_t ph[4], const uint32_t pcarry[4], uint32_t total_length, uint32_t out[4]);
void PMurHash128x86(const void * key, const int len, uint32_t seed, void * out);
}
