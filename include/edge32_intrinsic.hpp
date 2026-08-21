#ifndef EDGE32_INTRINSIC_HPP
#define EDGE32_INTRINSIC_HPP

#include <stdint.h>

// Edge-32 fixed instruction layout:
//   [31:25] funct7/subop
//   [24:20] imm8[7:3]
//   [19:15] rs1
//   [14:12] imm8[2:0]
//   [11:7]  reserved rd=0
//   [6:0]   ASIC opcode 0x3f
namespace edge32 {

constexpr uint32_t kAsicOpcode = 0x3fu;
constexpr unsigned kIntrinsicRs1 = 10;  // a0

constexpr uint32_t asic_word(unsigned funct7, unsigned rs1, unsigned imm8)
{
    return ((funct7 & 0x7fu) << 25) |
           (((imm8 >> 3) & 0x1fu) << 20) |
           ((rs1 & 0x1fu) << 15) |
           ((imm8 & 0x7u) << 12) |
           kAsicOpcode;
}

enum class command : uint8_t {
    dma_start = 0x01, dma_sync = 0x02, dma_setn = 0x03,
    dma_setx = 0x04, dma_sety = 0x05, dma_setsrc = 0x06,
    dma_settar = 0x07, dma_setentry = 0x08, asic_power = 0x09,

    tensor_setcsr = 0x10, tensor_wld = 0x11, tensor_setin = 0x12,
    tensor_setout = 0x13, tensor_setpsum = 0x14, tensor_start = 0x15,
    tensor_sync = 0x16, tensor_setn = 0x17, tensor_wld_t = 0x18,
    tensor_start_tile = 0x19, tensor_sld_stream = 0x1a,
    tensor_wld_circular = 0x1b, tensor_wld_t_circular = 0x1c,
    tensor_sld = 0x1d, tensor_wsld_circular = 0x1e,
    tensor_sld_circular = 0x1f,

    actu_setcsr = 0x20, actu_setin = 0x21, actu_setout = 0x22,
    actu_setn = 0x23, actu_setscalar = 0x24, actu_start = 0x25,
    actu_sync = 0x26,

    cmpu_setcsr = 0x27, cmpu_setlhs = 0x28, cmpu_setrhs = 0x29,
    cmpu_setmask = 0x2a, cmpu_setout = 0x2b, cmpu_setn = 0x2c,
    cmpu_start = 0x2d, cmpu_sync = 0x2e, accel_getcsr = 0x2f
};

template<command Command, uint8_t Imm8 = 0>
inline void emit()
{
#if defined(__riscv)
    constexpr uint32_t word = asic_word(static_cast<unsigned>(Command), 0, Imm8);
    __asm__ volatile(".word %c0" : : "i"(word) : "memory");
#endif
}

template<command Command, uint8_t Imm8 = 0>
inline void emit(uint32_t value)
{
#if defined(__riscv)
    register uintptr_t operand __asm__("a0") = value;
    constexpr uint32_t word =
        asic_word(static_cast<unsigned>(Command), kIntrinsicRs1, Imm8);
    __asm__ volatile("# edge32 operand=%0\n.word %c1"
                     : "+r"(operand) : "i"(word) : "memory");
#else
    (void)value;
#endif
}

inline void asic_power(bool enable)
{
    if (enable) emit<command::asic_power, 1>();
    else emit<command::asic_power, 0>();
}
inline void asic_on() { asic_power(true); }
inline void asic_off() { asic_power(false); }

inline void dma_setn(uint32_t bytes) { emit<command::dma_setn>(bytes); }
inline void dma_setentry(uint32_t bytes) { emit<command::dma_setentry>(bytes); }
inline void dma_setsrc(uint64_t address)
{
    emit<command::dma_setsrc, 0>(static_cast<uint32_t>(address));
    const uint32_t high = static_cast<uint32_t>(address >> 32);
    if (high != 0) emit<command::dma_setsrc, 1>(high);
}
inline void dma_settar(uint64_t address)
{
    emit<command::dma_settar, 0>(static_cast<uint32_t>(address));
    const uint32_t high = static_cast<uint32_t>(address >> 32);
    if (high != 0) emit<command::dma_settar, 1>(high);
}
inline void dma_start(uint32_t bytes, uint8_t mode = 0)
{
    // Runtime modes should normally be one of the four constant cases so the
    // instruction remains an immediate-only encoding.
    switch (mode & 3u) {
    case 0: emit<command::dma_start, 0>(bytes); break;
    case 1: emit<command::dma_start, 1>(bytes); break;
    case 2: emit<command::dma_start, 2>(bytes); break;
    default: emit<command::dma_start, 3>(bytes); break;
    }
}
inline void dma_sync() { emit<command::dma_sync>(); }

inline void tensor_setcsr(uint32_t value) { emit<command::tensor_setcsr>(value); }
inline void tensor_wld(uint32_t ptr) { emit<command::tensor_wld>(ptr); }
inline void tensor_setin(uint32_t ptr) { emit<command::tensor_setin>(ptr); }
inline void tensor_setout(uint32_t ptr) { emit<command::tensor_setout>(ptr); }
inline void tensor_setpsum(uint32_t ptr) { emit<command::tensor_setpsum>(ptr); }
inline void tensor_setn(uint32_t value) { emit<command::tensor_setn>(value); }
inline void tensor_start(uint8_t mode = 0)
{
    switch (mode) {
    case 0: emit<command::tensor_start, 0>(); break;
    case 1: emit<command::tensor_start, 1>(); break;
    default: emit<command::tensor_start, 0>(); break;
    }
}
inline void tensor_sync() { emit<command::tensor_sync>(); }

inline void actu_setcsr(uint32_t value) { emit<command::actu_setcsr>(value); }
inline void actu_setin(uint32_t ptr) { emit<command::actu_setin>(ptr); }
inline void actu_setout(uint32_t ptr) { emit<command::actu_setout>(ptr); }
inline void actu_setn(uint32_t value) { emit<command::actu_setn>(value); }
inline void actu_setscalar(uint32_t value) { emit<command::actu_setscalar>(value); }
inline void actu_start() { emit<command::actu_start>(); }
inline void actu_sync() { emit<command::actu_sync>(); }

inline void cmpu_setcsr(uint32_t value) { emit<command::cmpu_setcsr>(value); }
inline void cmpu_setlhs(uint32_t ptr) { emit<command::cmpu_setlhs>(ptr); }
inline void cmpu_setrhs(uint32_t ptr) { emit<command::cmpu_setrhs>(ptr); }
inline void cmpu_setmask(uint32_t ptr) { emit<command::cmpu_setmask>(ptr); }
inline void cmpu_setout(uint32_t ptr) { emit<command::cmpu_setout>(ptr); }
inline void cmpu_setn(uint32_t value) { emit<command::cmpu_setn>(value); }
inline void cmpu_start() { emit<command::cmpu_start>(); }
inline void cmpu_sync() { emit<command::cmpu_sync>(); }

static_assert(asic_word(0x24, 5, 0x30) == 0x4862803fu,
              "ASIC32 encoding must match RTL");
static_assert((asic_word(0x7f, 31, 0xff) & 0x00000f80u) == 0,
              "ASIC32 rd field must remain zero");

}  // namespace edge32

// Drop-in Edge API names for edge-32. Addresses are integer values rather
// than pointers because the scalar ABI is RV32 while DMA addresses are 64-bit.
static inline void edge_dma_setsrc(uint64_t src) { edge32::dma_setsrc(src); }
static inline void edge_dma_settar(uint64_t dst) { edge32::dma_settar(dst); }
static inline void edge_dma_start(uint64_t src, uint64_t dst, uint32_t len)
{
    edge_dma_setsrc(src);
    edge_dma_settar(dst);
    edge32::dma_start(len);
}
static inline void edge_dma_sync(void) { edge32::dma_sync(); }

#endif
