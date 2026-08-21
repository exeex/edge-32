#ifndef EDGE32_INTRINSIC_HPP
#define EDGE32_INTRINSIC_HPP

#include <stdint.h>

#ifndef EDGE_ADDR_T_DEFINED
typedef uint64_t addr_t;
#define EDGE_ADDR_T_DEFINED 1
#endif

#define EDGE_DCACHE_LINE_SIZE 64u
#define EDGE_CSR_BREAK_ID 0x7e0u
#define EDGE_CSR_SIM_PUTCHAR_ID 0x7e1u
#define EDGE_TENSOR_WTYPE_BF16 1
#define EDGE_TENSOR_WTYPE_INT8 2
#define EDGE_TENSOR_LOAD_OPT_REUSE (1u << 1)
#define EDGE_TENSOR_LOAD_OPT_KNOWN_MASK EDGE_TENSOR_LOAD_OPT_REUSE
#define EDGE_TENSOR_START_OPT_USE_SCALE (1u << 0)
#define EDGE_TENSOR_START_OPT_PSUM_ONCE (1u << 1)
#define EDGE_TENSOR_START_OPT_NO_PSUM (1u << 2)
#define EDGE_TENSOR_START_OPT_SCALE_STREAM (1u << 3)
#define EDGE_TENSOR_START_OPT_RSUM (1u << 4)
#define EDGE_TENSOR_START_OPT_COPY (1u << 5)
#define EDGE_TENSOR_START_OPT_PSUM_MASK \
    (EDGE_TENSOR_START_OPT_PSUM_ONCE | EDGE_TENSOR_START_OPT_NO_PSUM)
#define EDGE_TENSOR_START_OPT_KNOWN_MASK \
    (EDGE_TENSOR_START_OPT_USE_SCALE | EDGE_TENSOR_START_OPT_PSUM_MASK | \
     EDGE_TENSOR_START_OPT_SCALE_STREAM | EDGE_TENSOR_START_OPT_RSUM | \
     EDGE_TENSOR_START_OPT_COPY)

#define EDGE_RV_CORE_ID_EDGE_RV 1u
#define EDGE_RV_CORE_ID_EDGE_RV_LITE 2u
#define EDGE_WEIGHT_SPEC_BF16 (1u << 0)
#define EDGE_WEIGHT_SPEC_INT8 (1u << 1)
#define EDGE_SCALE_SPEC_BF16 (1u << 0)
#define EDGE_TENSOR_SPEC_V1 (1u << 0)

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
static inline uintptr_t edge_get_cycle(void)
{
    uintptr_t cycle;
    __asm__ volatile("csrr %0, cycle" : "=r"(cycle) : : "memory");
    return cycle;
}

static inline void edge_sim_putchar(char ch)
{
    uintptr_t value = static_cast<uintptr_t>(static_cast<unsigned char>(ch));
    __asm__ volatile("csrw 0x7e1, %0" : : "r"(value) : "memory");
}

[[noreturn]] static inline void edge_exit(uintptr_t value)
{
    __asm__ volatile("csrw 0x7e0, %0" : : "r"(value) : "memory");
    for (;;) __asm__ volatile("wfi" ::: "memory");
}

static inline uintptr_t edge_dcache_line_floor(uintptr_t addr)
{
    return addr & ~(uintptr_t)(EDGE_DCACHE_LINE_SIZE - 1u);
}

static inline uintptr_t edge_dcache_line_ceil(uintptr_t addr)
{
    return (addr + EDGE_DCACHE_LINE_SIZE - 1u) &
           ~(uintptr_t)(EDGE_DCACHE_LINE_SIZE - 1u);
}

static inline void edge_dcache_clean_va(addr_t addr)
{
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;
    __asm__ volatile(".insn r 0x0b, 1, 0, x0, %0, x5"
                     : : "r"(edge_addr) : "memory");
}

static inline void edge_dcache_invalidate_va(addr_t addr)
{
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;
    __asm__ volatile(".insn r 0x0b, 1, 0, x0, %0, x6"
                     : : "r"(edge_addr) : "memory");
}

static inline void edge_dcache_clean_invalidate_va(addr_t addr)
{
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;
    __asm__ volatile(".insn r 0x0b, 1, 0, x0, %0, x7"
                     : : "r"(edge_addr) : "memory");
}

static inline void edge_dcache_clean_range(addr_t addr, uintptr_t len)
{
    uintptr_t cur = edge_dcache_line_floor((uintptr_t)addr);
    const uintptr_t end = edge_dcache_line_ceil((uintptr_t)addr + len);
    while (cur < end) {
        edge_dcache_clean_va((addr_t)cur);
        cur += EDGE_DCACHE_LINE_SIZE;
    }
}

static inline void edge_dcache_invalidate_range(addr_t addr, uintptr_t len)
{
    uintptr_t cur = edge_dcache_line_floor((uintptr_t)addr);
    const uintptr_t end = edge_dcache_line_ceil((uintptr_t)addr + len);
    while (cur < end) {
        edge_dcache_invalidate_va((addr_t)cur);
        cur += EDGE_DCACHE_LINE_SIZE;
    }
}

static inline void edge_dcache_clean_invalidate_range(addr_t addr, uintptr_t len)
{
    uintptr_t cur = edge_dcache_line_floor((uintptr_t)addr);
    const uintptr_t end = edge_dcache_line_ceil((uintptr_t)addr + len);
    while (cur < end) {
        edge_dcache_clean_invalidate_va((addr_t)cur);
        cur += EDGE_DCACHE_LINE_SIZE;
    }
}

static inline void edge_asic_power(unsigned enable)
{
    if (enable) edge32::emit<edge32::command::asic_power, 1>();
    else edge32::emit<edge32::command::asic_power, 0>();
}
static inline void edge_asic_on(void) { edge_asic_power(1); }
static inline void edge_asic_off(void) { edge_asic_power(0); }

static inline void edge_dma_setsrc(addr_t src) { edge32::dma_setsrc(src); }
static inline void edge_dma_settar(addr_t dst) { edge32::dma_settar(dst); }
static inline void edge_dma_start(addr_t src, addr_t dst, uintptr_t len)
{
    edge_dma_setsrc(src);
    edge_dma_settar(dst);
    edge32::dma_start(static_cast<uint32_t>(len));
}
static inline void edge_dma_sync(void) { edge32::dma_sync(); }
static inline void edge_dma_setn(uintptr_t bytes)
{ edge32::dma_setn(static_cast<uint32_t>(bytes)); }
static inline void edge_dma_setentry(uintptr_t bytes)
{ edge32::dma_setentry(static_cast<uint32_t>(bytes)); }
static inline void edge_dma_setx(uintptr_t stride, uintptr_t count)
{
    // Compact DMA XY uses imm8 for the axis count and rs1 for the stride.
    // Current public Tensor shapes are bounded to 255 entries per axis.
    switch (count) {
    case 1: edge32::emit<edge32::command::dma_setx, 1>(stride); break;
    case 8: edge32::emit<edge32::command::dma_setx, 8>(stride); break;
    case 64: edge32::emit<edge32::command::dma_setx, 64>(stride); break;
    case 128: edge32::emit<edge32::command::dma_setx, 128>(stride); break;
    default: edge32::emit<edge32::command::dma_setx>(stride); break;
    }
}
static inline void edge_dma_sety(uintptr_t stride, uintptr_t count)
{
    switch (count) {
    case 1: edge32::emit<edge32::command::dma_sety, 1>(stride); break;
    case 8: edge32::emit<edge32::command::dma_sety, 8>(stride); break;
    case 64: edge32::emit<edge32::command::dma_sety, 64>(stride); break;
    case 128: edge32::emit<edge32::command::dma_sety, 128>(stride); break;
    default: edge32::emit<edge32::command::dma_sety>(stride); break;
    }
}
static inline void edge_dma_start_strided(
    addr_t src, addr_t dst, uintptr_t bytes, uintptr_t stride,
    uintptr_t count)
{
    edge_dma_setn(bytes);
    edge_dma_setx(stride, count);
    edge_dma_sety(0, 1);
    edge_dma_setsrc(src);
    edge_dma_settar(dst);
    edge32::dma_start(static_cast<uint32_t>(bytes), 1);
}
static inline void edge_dma_start_strided_circular(
    addr_t src, addr_t ring, uintptr_t bytes, uintptr_t x_stride,
    uintptr_t x_max, uintptr_t y_stride, uintptr_t y_max,
    uintptr_t entry_bytes, uintptr_t ring_entries)
{
    edge_dma_setn(bytes);
    edge_dma_setentry(entry_bytes);
    edge_dma_setx(x_stride, x_max);
    edge_dma_sety(y_stride, y_max);
    edge_dma_setsrc(src);
    edge_dma_settar(ring);
    edge32::dma_start(static_cast<uint32_t>(ring_entries), 3);
}

template <int dtype, int wtype>
static inline void edge_tensor_setcsr()
{
    static_assert(dtype >= 0 && dtype < 16, "tensor dtype must fit imm4");
    static_assert(wtype >= 0 && wtype < 16, "tensor wtype must fit imm4");
    edge32::emit<edge32::command::tensor_setcsr,
                 static_cast<uint8_t>((dtype << 4) | wtype)>();
}

template <unsigned Options = 0>
static inline void edge_tensor_wld(addr_t weight_addr = 0)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.wld option");
    if constexpr (Options & EDGE_TENSOR_LOAD_OPT_REUSE)
        edge32::emit<edge32::command::tensor_wld,
                     static_cast<uint8_t>(Options)>();
    else
        edge32::emit<edge32::command::tensor_wld>(
            static_cast<uint32_t>(weight_addr));
}

template <unsigned Options = 0>
static inline void edge_tensor_wld_t(addr_t weight_addr = 0)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.wld_t option");
    if constexpr (Options & EDGE_TENSOR_LOAD_OPT_REUSE)
        edge32::emit<edge32::command::tensor_wld_t,
                     static_cast<uint8_t>(Options)>();
    else
        edge32::emit<edge32::command::tensor_wld_t>(
            static_cast<uint32_t>(weight_addr));
}

static inline void edge_tensor_setin(addr_t addr)
{ edge32::tensor_setin(static_cast<uint32_t>(addr)); }
static inline void edge_tensor_setout(addr_t addr)
{ edge32::tensor_setout(static_cast<uint32_t>(addr)); }
static inline void edge_tensor_setpsum(addr_t addr)
{ edge32::tensor_setpsum(static_cast<uint32_t>(addr)); }
static inline void edge_tensor_setn(uintptr_t n)
{ edge32::tensor_setn(static_cast<uint32_t>(n)); }

template <unsigned Options = 0>
static inline void edge_tensor_start()
{
    static_assert((Options & ~EDGE_TENSOR_START_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.start option");
    static_assert((Options & EDGE_TENSOR_START_OPT_PSUM_MASK) !=
                      EDGE_TENSOR_START_OPT_PSUM_MASK,
                  "tensor.start psum modes are mutually exclusive");
    edge32::emit<edge32::command::tensor_start,
                 static_cast<uint8_t>(Options)>();
}

static inline void edge_tensor_sync(void) { edge32::tensor_sync(); }

static inline void edge_tensor_wld_t_circular(void)
{ edge32::emit<edge32::command::tensor_wld_t_circular>(); }

struct edge_hardware_info {
    uint16_t rv_core_id;
    uint16_t product_id;
    uint8_t fpu_ver;
    uint8_t vpu_ver;
    uint8_t tensor_p;
    uint8_t tensor_q;
    uint8_t weight_spec;
    uint8_t scale_spec;
    uint8_t tensor_spec;
};

struct edge_tensor_engine_spec {
    uint32_t rows;
    uint32_t columns;
};

static inline uint64_t edge_get_hardware_id()
{
    uintptr_t low;
    __asm__ volatile("csrr %0, 0xfc0" : "=r"(low));
    return static_cast<uint64_t>(low);
}

static inline edge_hardware_info edge_decode_hardware_id(uint64_t value)
{
    return {
        static_cast<uint16_t>((value >> 55) & 0x1ffu),
        static_cast<uint16_t>((value >> 40) & 0x7fffu),
        static_cast<uint8_t>((value >> 36) & 0x0fu),
        static_cast<uint8_t>((value >> 32) & 0x0fu),
        static_cast<uint8_t>((value >> 28) & 0x0fu),
        static_cast<uint8_t>((value >> 24) & 0x0fu),
        static_cast<uint8_t>((value >> 16) & 0xffu),
        static_cast<uint8_t>((value >> 8) & 0xffu),
        static_cast<uint8_t>(value & 0xffu),
    };
}

static inline edge_tensor_engine_spec edge_get_tensor_engine_spec()
{
    const edge_hardware_info hardware =
        edge_decode_hardware_id(edge_get_hardware_id());
    return {1u << hardware.tensor_p, 1u << hardware.tensor_q};
}

#endif
