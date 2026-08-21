#include "intrinsic.hpp"

static_assert(edge32::asic_word(0x11, 10, 0xa5) == 0x2345503fu);

int main()
{
    edge32::asic_on();
    edge32::tensor_setin(0x1000);
    edge32::tensor_start();
    edge32::tensor_sync();
    edge_dma_start(UINT64_C(0x1234567880002000),
                   UINT64_C(0xabcdef0180003000), 64);
    edge_dma_sync();
    return 0;
}
