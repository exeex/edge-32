#ifndef EDGE32_INTRINSIC_HPP
#define EDGE32_INTRINSIC_HPP

#include <stdint.h>

#ifndef EDGE_ADDR_T_DEFINED
typedef uint64_t addr_t;
#define EDGE_ADDR_T_DEFINED 1
#endif

#ifdef __cplusplus
static inline addr_t edge_addr_from_ptr(const void *ptr)
{
  return static_cast<addr_t>(reinterpret_cast<uintptr_t>(ptr));
}
#endif

#define EDGE_DCACHE_LINE_SIZE 64u
#define EDGE_CSR_BREAK_ID 0x7e0u
#define EDGE_CSR_SIM_PUTCHAR_ID 0x7e1u
#define EDGE_CSR_ICACHE_HEADER_ID 0x7dbu
#define EDGE_CSR_DCACHE_HEADER_ID 0x7dcu

static inline uint32_t edge_icache_header_read() {
  uint32_t value;
#if defined(__riscv)
  __asm__ volatile("csrr %0, 0x7db" : "=r"(value));
#else
  value = 0;
#endif
  return value;
}

static inline void edge_icache_header_write(uint32_t value) {
#if defined(__riscv)
  __asm__ volatile("csrw 0x7db, %0" :: "r"(value) : "memory");
#else
  (void)value;
#endif
}

static inline uint32_t edge_dcache_header_read() {
  uint32_t value;
#if defined(__riscv)
  __asm__ volatile("csrr %0, 0x7dc" : "=r"(value));
#else
  value = 0;
#endif
  return value;
}

static inline void edge_dcache_header_write(uint32_t value) {
#if defined(__riscv)
  __asm__ volatile("csrw 0x7dc, %0" :: "r"(value) : "memory");
#else
  (void)value;
#endif
}
#define EDGE_TENSOR_DTYPE_BF16 1
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
//   [11:7]  rd=0 for commands; GETCSR names its result GPR
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

constexpr uint32_t asic_result_word(unsigned funct7, unsigned rd,
                                     unsigned rs1, unsigned imm8)
{
    return ((funct7 & 0x7fu) << 25) |
           (((imm8 >> 3) & 0x1fu) << 20) |
           ((rs1 & 0x1fu) << 15) |
           ((imm8 & 0x7u) << 12) |
           ((rd & 0x1fu) << 7) |
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

template<command Command>
inline void emit_address(uint64_t address)
{
    // RV32 carries one address half per command.  Always send both halves;
    // sending a zero high half is required to clear a previous >4GB address.
    emit<Command, 0>(static_cast<uint32_t>(address));
    emit<Command, 1>(static_cast<uint32_t>(address >> 32));
}

template<command Command, uint8_t Imm8 = 0>
inline uintptr_t emit_result()
{
#if defined(__riscv)
    // GETCSR returns through the normal accelerator response path.  Keep the
    // ABI fixed on a0 so the C/C++ wrapper can consume the RV32 result.
    register uintptr_t result __asm__("a0");
    constexpr uint32_t word = asic_result_word(
        static_cast<unsigned>(Command), kIntrinsicRs1, 0, Imm8);
    __asm__ volatile(".word %c1" : "=r"(result) : "i"(word) : "memory");
    return result;
#else
    return 0;
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
    emit_address<command::dma_setsrc>(address);
}
inline void dma_settar(uint64_t address)
{
    emit_address<command::dma_settar>(address);
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
inline void tensor_wld(uint64_t address)
{ emit_address<command::tensor_wld>(address); }
inline void tensor_setin(uint64_t address)
{ emit_address<command::tensor_setin>(address); }
inline void tensor_setout(uint64_t address)
{ emit_address<command::tensor_setout>(address); }
inline void tensor_setpsum(uint64_t address)
{ emit_address<command::tensor_setpsum>(address); }
inline void tensor_setn(uint32_t value) { emit<command::tensor_setn>(value); }
inline void tensor_wld_t(uint64_t address)
{ emit_address<command::tensor_wld_t>(address); }
inline void tensor_sld(uint64_t address)
{ emit_address<command::tensor_sld>(address); }
inline void tensor_sld_stream(uint64_t address)
{ emit_address<command::tensor_sld_stream>(address); }
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
static_assert(asic_result_word(0x2f, 10, 0, 4) == 0x5e00453fu,
              "ASIC32 GETCSR encoding must match RTL");

}  // namespace edge32

// Drop-in Edge API names for edge-32. DMA and tensor addresses are integer
// values rather than C++ pointers; RV32 transports each as low/high words.
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
#if defined(__riscv)
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;
    __asm__ volatile(".insn r 0x0b, 1, 0, x0, %0, x5"
                     : : "r"(edge_addr) : "memory");
#else
    (void)addr;
#endif
}

static inline void edge_dcache_invalidate_va(addr_t addr)
{
#if defined(__riscv)
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;
    __asm__ volatile(".insn r 0x0b, 1, 0, x0, %0, x6"
                     : : "r"(edge_addr) : "memory");
#else
    (void)addr;
#endif
}

static inline void edge_dcache_clean_invalidate_va(addr_t addr)
{
#if defined(__riscv)
    register uintptr_t edge_addr __asm__("a0") = (uintptr_t)addr;
    __asm__ volatile(".insn r 0x0b, 1, 0, x0, %0, x7"
                     : : "r"(edge_addr) : "memory");
#else
    (void)addr;
#endif
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

#ifdef __cplusplus
static inline void edge_dcache_clean_range(const void *addr, uintptr_t len)
{ edge_dcache_clean_range(edge_addr_from_ptr(addr), len); }
static inline void edge_dcache_invalidate_range(const void *addr, uintptr_t len)
{ edge_dcache_invalidate_range(edge_addr_from_ptr(addr), len); }
static inline void edge_dcache_clean_invalidate_range(const void *addr,
                                                     uintptr_t len)
{ edge_dcache_clean_invalidate_range(edge_addr_from_ptr(addr), len); }
#endif

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
#ifdef __cplusplus
static inline void edge_dma_start(const void *src, void *dst, uintptr_t len)
{ edge_dma_start(edge_addr_from_ptr(src), edge_addr_from_ptr(dst), len); }
#endif
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
    case 2: edge32::emit<edge32::command::dma_setx, 2>(stride); break;
    case 3: edge32::emit<edge32::command::dma_setx, 3>(stride); break;
    case 4: edge32::emit<edge32::command::dma_setx, 4>(stride); break;
    case 5: edge32::emit<edge32::command::dma_setx, 5>(stride); break;
    case 6: edge32::emit<edge32::command::dma_setx, 6>(stride); break;
    case 7: edge32::emit<edge32::command::dma_setx, 7>(stride); break;
    case 8: edge32::emit<edge32::command::dma_setx, 8>(stride); break;
    case 9: edge32::emit<edge32::command::dma_setx, 9>(stride); break;
    case 10: edge32::emit<edge32::command::dma_setx, 10>(stride); break;
    case 11: edge32::emit<edge32::command::dma_setx, 11>(stride); break;
    case 12: edge32::emit<edge32::command::dma_setx, 12>(stride); break;
    case 13: edge32::emit<edge32::command::dma_setx, 13>(stride); break;
    case 14: edge32::emit<edge32::command::dma_setx, 14>(stride); break;
    case 15: edge32::emit<edge32::command::dma_setx, 15>(stride); break;
    case 16: edge32::emit<edge32::command::dma_setx, 16>(stride); break;
    case 17: edge32::emit<edge32::command::dma_setx, 17>(stride); break;
    case 18: edge32::emit<edge32::command::dma_setx, 18>(stride); break;
    case 19: edge32::emit<edge32::command::dma_setx, 19>(stride); break;
    case 20: edge32::emit<edge32::command::dma_setx, 20>(stride); break;
    case 21: edge32::emit<edge32::command::dma_setx, 21>(stride); break;
    case 22: edge32::emit<edge32::command::dma_setx, 22>(stride); break;
    case 23: edge32::emit<edge32::command::dma_setx, 23>(stride); break;
    case 24: edge32::emit<edge32::command::dma_setx, 24>(stride); break;
    case 25: edge32::emit<edge32::command::dma_setx, 25>(stride); break;
    case 26: edge32::emit<edge32::command::dma_setx, 26>(stride); break;
    case 27: edge32::emit<edge32::command::dma_setx, 27>(stride); break;
    case 28: edge32::emit<edge32::command::dma_setx, 28>(stride); break;
    case 29: edge32::emit<edge32::command::dma_setx, 29>(stride); break;
    case 30: edge32::emit<edge32::command::dma_setx, 30>(stride); break;
    case 31: edge32::emit<edge32::command::dma_setx, 31>(stride); break;
    case 32: edge32::emit<edge32::command::dma_setx, 32>(stride); break;
    case 33: edge32::emit<edge32::command::dma_setx, 33>(stride); break;
    case 34: edge32::emit<edge32::command::dma_setx, 34>(stride); break;
    case 35: edge32::emit<edge32::command::dma_setx, 35>(stride); break;
    case 36: edge32::emit<edge32::command::dma_setx, 36>(stride); break;
    case 37: edge32::emit<edge32::command::dma_setx, 37>(stride); break;
    case 38: edge32::emit<edge32::command::dma_setx, 38>(stride); break;
    case 39: edge32::emit<edge32::command::dma_setx, 39>(stride); break;
    case 40: edge32::emit<edge32::command::dma_setx, 40>(stride); break;
    case 41: edge32::emit<edge32::command::dma_setx, 41>(stride); break;
    case 42: edge32::emit<edge32::command::dma_setx, 42>(stride); break;
    case 43: edge32::emit<edge32::command::dma_setx, 43>(stride); break;
    case 44: edge32::emit<edge32::command::dma_setx, 44>(stride); break;
    case 45: edge32::emit<edge32::command::dma_setx, 45>(stride); break;
    case 46: edge32::emit<edge32::command::dma_setx, 46>(stride); break;
    case 47: edge32::emit<edge32::command::dma_setx, 47>(stride); break;
    case 48: edge32::emit<edge32::command::dma_setx, 48>(stride); break;
    case 49: edge32::emit<edge32::command::dma_setx, 49>(stride); break;
    case 50: edge32::emit<edge32::command::dma_setx, 50>(stride); break;
    case 51: edge32::emit<edge32::command::dma_setx, 51>(stride); break;
    case 52: edge32::emit<edge32::command::dma_setx, 52>(stride); break;
    case 53: edge32::emit<edge32::command::dma_setx, 53>(stride); break;
    case 54: edge32::emit<edge32::command::dma_setx, 54>(stride); break;
    case 55: edge32::emit<edge32::command::dma_setx, 55>(stride); break;
    case 56: edge32::emit<edge32::command::dma_setx, 56>(stride); break;
    case 57: edge32::emit<edge32::command::dma_setx, 57>(stride); break;
    case 58: edge32::emit<edge32::command::dma_setx, 58>(stride); break;
    case 59: edge32::emit<edge32::command::dma_setx, 59>(stride); break;
    case 60: edge32::emit<edge32::command::dma_setx, 60>(stride); break;
    case 61: edge32::emit<edge32::command::dma_setx, 61>(stride); break;
    case 62: edge32::emit<edge32::command::dma_setx, 62>(stride); break;
    case 63: edge32::emit<edge32::command::dma_setx, 63>(stride); break;
    case 64: edge32::emit<edge32::command::dma_setx, 64>(stride); break;
    case 65: edge32::emit<edge32::command::dma_setx, 65>(stride); break;
    case 66: edge32::emit<edge32::command::dma_setx, 66>(stride); break;
    case 67: edge32::emit<edge32::command::dma_setx, 67>(stride); break;
    case 68: edge32::emit<edge32::command::dma_setx, 68>(stride); break;
    case 69: edge32::emit<edge32::command::dma_setx, 69>(stride); break;
    case 70: edge32::emit<edge32::command::dma_setx, 70>(stride); break;
    case 71: edge32::emit<edge32::command::dma_setx, 71>(stride); break;
    case 72: edge32::emit<edge32::command::dma_setx, 72>(stride); break;
    case 73: edge32::emit<edge32::command::dma_setx, 73>(stride); break;
    case 74: edge32::emit<edge32::command::dma_setx, 74>(stride); break;
    case 75: edge32::emit<edge32::command::dma_setx, 75>(stride); break;
    case 76: edge32::emit<edge32::command::dma_setx, 76>(stride); break;
    case 77: edge32::emit<edge32::command::dma_setx, 77>(stride); break;
    case 78: edge32::emit<edge32::command::dma_setx, 78>(stride); break;
    case 79: edge32::emit<edge32::command::dma_setx, 79>(stride); break;
    case 80: edge32::emit<edge32::command::dma_setx, 80>(stride); break;
    case 81: edge32::emit<edge32::command::dma_setx, 81>(stride); break;
    case 82: edge32::emit<edge32::command::dma_setx, 82>(stride); break;
    case 83: edge32::emit<edge32::command::dma_setx, 83>(stride); break;
    case 84: edge32::emit<edge32::command::dma_setx, 84>(stride); break;
    case 85: edge32::emit<edge32::command::dma_setx, 85>(stride); break;
    case 86: edge32::emit<edge32::command::dma_setx, 86>(stride); break;
    case 87: edge32::emit<edge32::command::dma_setx, 87>(stride); break;
    case 88: edge32::emit<edge32::command::dma_setx, 88>(stride); break;
    case 89: edge32::emit<edge32::command::dma_setx, 89>(stride); break;
    case 90: edge32::emit<edge32::command::dma_setx, 90>(stride); break;
    case 91: edge32::emit<edge32::command::dma_setx, 91>(stride); break;
    case 92: edge32::emit<edge32::command::dma_setx, 92>(stride); break;
    case 93: edge32::emit<edge32::command::dma_setx, 93>(stride); break;
    case 94: edge32::emit<edge32::command::dma_setx, 94>(stride); break;
    case 95: edge32::emit<edge32::command::dma_setx, 95>(stride); break;
    case 96: edge32::emit<edge32::command::dma_setx, 96>(stride); break;
    case 97: edge32::emit<edge32::command::dma_setx, 97>(stride); break;
    case 98: edge32::emit<edge32::command::dma_setx, 98>(stride); break;
    case 99: edge32::emit<edge32::command::dma_setx, 99>(stride); break;
    case 100: edge32::emit<edge32::command::dma_setx, 100>(stride); break;
    case 101: edge32::emit<edge32::command::dma_setx, 101>(stride); break;
    case 102: edge32::emit<edge32::command::dma_setx, 102>(stride); break;
    case 103: edge32::emit<edge32::command::dma_setx, 103>(stride); break;
    case 104: edge32::emit<edge32::command::dma_setx, 104>(stride); break;
    case 105: edge32::emit<edge32::command::dma_setx, 105>(stride); break;
    case 106: edge32::emit<edge32::command::dma_setx, 106>(stride); break;
    case 107: edge32::emit<edge32::command::dma_setx, 107>(stride); break;
    case 108: edge32::emit<edge32::command::dma_setx, 108>(stride); break;
    case 109: edge32::emit<edge32::command::dma_setx, 109>(stride); break;
    case 110: edge32::emit<edge32::command::dma_setx, 110>(stride); break;
    case 111: edge32::emit<edge32::command::dma_setx, 111>(stride); break;
    case 112: edge32::emit<edge32::command::dma_setx, 112>(stride); break;
    case 113: edge32::emit<edge32::command::dma_setx, 113>(stride); break;
    case 114: edge32::emit<edge32::command::dma_setx, 114>(stride); break;
    case 115: edge32::emit<edge32::command::dma_setx, 115>(stride); break;
    case 116: edge32::emit<edge32::command::dma_setx, 116>(stride); break;
    case 117: edge32::emit<edge32::command::dma_setx, 117>(stride); break;
    case 118: edge32::emit<edge32::command::dma_setx, 118>(stride); break;
    case 119: edge32::emit<edge32::command::dma_setx, 119>(stride); break;
    case 120: edge32::emit<edge32::command::dma_setx, 120>(stride); break;
    case 121: edge32::emit<edge32::command::dma_setx, 121>(stride); break;
    case 122: edge32::emit<edge32::command::dma_setx, 122>(stride); break;
    case 123: edge32::emit<edge32::command::dma_setx, 123>(stride); break;
    case 124: edge32::emit<edge32::command::dma_setx, 124>(stride); break;
    case 125: edge32::emit<edge32::command::dma_setx, 125>(stride); break;
    case 126: edge32::emit<edge32::command::dma_setx, 126>(stride); break;
    case 127: edge32::emit<edge32::command::dma_setx, 127>(stride); break;
    case 128: edge32::emit<edge32::command::dma_setx, 128>(stride); break;
    case 129: edge32::emit<edge32::command::dma_setx, 129>(stride); break;
    case 130: edge32::emit<edge32::command::dma_setx, 130>(stride); break;
    case 131: edge32::emit<edge32::command::dma_setx, 131>(stride); break;
    case 132: edge32::emit<edge32::command::dma_setx, 132>(stride); break;
    case 133: edge32::emit<edge32::command::dma_setx, 133>(stride); break;
    case 134: edge32::emit<edge32::command::dma_setx, 134>(stride); break;
    case 135: edge32::emit<edge32::command::dma_setx, 135>(stride); break;
    case 136: edge32::emit<edge32::command::dma_setx, 136>(stride); break;
    case 137: edge32::emit<edge32::command::dma_setx, 137>(stride); break;
    case 138: edge32::emit<edge32::command::dma_setx, 138>(stride); break;
    case 139: edge32::emit<edge32::command::dma_setx, 139>(stride); break;
    case 140: edge32::emit<edge32::command::dma_setx, 140>(stride); break;
    case 141: edge32::emit<edge32::command::dma_setx, 141>(stride); break;
    case 142: edge32::emit<edge32::command::dma_setx, 142>(stride); break;
    case 143: edge32::emit<edge32::command::dma_setx, 143>(stride); break;
    case 144: edge32::emit<edge32::command::dma_setx, 144>(stride); break;
    case 145: edge32::emit<edge32::command::dma_setx, 145>(stride); break;
    case 146: edge32::emit<edge32::command::dma_setx, 146>(stride); break;
    case 147: edge32::emit<edge32::command::dma_setx, 147>(stride); break;
    case 148: edge32::emit<edge32::command::dma_setx, 148>(stride); break;
    case 149: edge32::emit<edge32::command::dma_setx, 149>(stride); break;
    case 150: edge32::emit<edge32::command::dma_setx, 150>(stride); break;
    case 151: edge32::emit<edge32::command::dma_setx, 151>(stride); break;
    case 152: edge32::emit<edge32::command::dma_setx, 152>(stride); break;
    case 153: edge32::emit<edge32::command::dma_setx, 153>(stride); break;
    case 154: edge32::emit<edge32::command::dma_setx, 154>(stride); break;
    case 155: edge32::emit<edge32::command::dma_setx, 155>(stride); break;
    case 156: edge32::emit<edge32::command::dma_setx, 156>(stride); break;
    case 157: edge32::emit<edge32::command::dma_setx, 157>(stride); break;
    case 158: edge32::emit<edge32::command::dma_setx, 158>(stride); break;
    case 159: edge32::emit<edge32::command::dma_setx, 159>(stride); break;
    case 160: edge32::emit<edge32::command::dma_setx, 160>(stride); break;
    case 161: edge32::emit<edge32::command::dma_setx, 161>(stride); break;
    case 162: edge32::emit<edge32::command::dma_setx, 162>(stride); break;
    case 163: edge32::emit<edge32::command::dma_setx, 163>(stride); break;
    case 164: edge32::emit<edge32::command::dma_setx, 164>(stride); break;
    case 165: edge32::emit<edge32::command::dma_setx, 165>(stride); break;
    case 166: edge32::emit<edge32::command::dma_setx, 166>(stride); break;
    case 167: edge32::emit<edge32::command::dma_setx, 167>(stride); break;
    case 168: edge32::emit<edge32::command::dma_setx, 168>(stride); break;
    case 169: edge32::emit<edge32::command::dma_setx, 169>(stride); break;
    case 170: edge32::emit<edge32::command::dma_setx, 170>(stride); break;
    case 171: edge32::emit<edge32::command::dma_setx, 171>(stride); break;
    case 172: edge32::emit<edge32::command::dma_setx, 172>(stride); break;
    case 173: edge32::emit<edge32::command::dma_setx, 173>(stride); break;
    case 174: edge32::emit<edge32::command::dma_setx, 174>(stride); break;
    case 175: edge32::emit<edge32::command::dma_setx, 175>(stride); break;
    case 176: edge32::emit<edge32::command::dma_setx, 176>(stride); break;
    case 177: edge32::emit<edge32::command::dma_setx, 177>(stride); break;
    case 178: edge32::emit<edge32::command::dma_setx, 178>(stride); break;
    case 179: edge32::emit<edge32::command::dma_setx, 179>(stride); break;
    case 180: edge32::emit<edge32::command::dma_setx, 180>(stride); break;
    case 181: edge32::emit<edge32::command::dma_setx, 181>(stride); break;
    case 182: edge32::emit<edge32::command::dma_setx, 182>(stride); break;
    case 183: edge32::emit<edge32::command::dma_setx, 183>(stride); break;
    case 184: edge32::emit<edge32::command::dma_setx, 184>(stride); break;
    case 185: edge32::emit<edge32::command::dma_setx, 185>(stride); break;
    case 186: edge32::emit<edge32::command::dma_setx, 186>(stride); break;
    case 187: edge32::emit<edge32::command::dma_setx, 187>(stride); break;
    case 188: edge32::emit<edge32::command::dma_setx, 188>(stride); break;
    case 189: edge32::emit<edge32::command::dma_setx, 189>(stride); break;
    case 190: edge32::emit<edge32::command::dma_setx, 190>(stride); break;
    case 191: edge32::emit<edge32::command::dma_setx, 191>(stride); break;
    case 192: edge32::emit<edge32::command::dma_setx, 192>(stride); break;
    case 193: edge32::emit<edge32::command::dma_setx, 193>(stride); break;
    case 194: edge32::emit<edge32::command::dma_setx, 194>(stride); break;
    case 195: edge32::emit<edge32::command::dma_setx, 195>(stride); break;
    case 196: edge32::emit<edge32::command::dma_setx, 196>(stride); break;
    case 197: edge32::emit<edge32::command::dma_setx, 197>(stride); break;
    case 198: edge32::emit<edge32::command::dma_setx, 198>(stride); break;
    case 199: edge32::emit<edge32::command::dma_setx, 199>(stride); break;
    case 200: edge32::emit<edge32::command::dma_setx, 200>(stride); break;
    case 201: edge32::emit<edge32::command::dma_setx, 201>(stride); break;
    case 202: edge32::emit<edge32::command::dma_setx, 202>(stride); break;
    case 203: edge32::emit<edge32::command::dma_setx, 203>(stride); break;
    case 204: edge32::emit<edge32::command::dma_setx, 204>(stride); break;
    case 205: edge32::emit<edge32::command::dma_setx, 205>(stride); break;
    case 206: edge32::emit<edge32::command::dma_setx, 206>(stride); break;
    case 207: edge32::emit<edge32::command::dma_setx, 207>(stride); break;
    case 208: edge32::emit<edge32::command::dma_setx, 208>(stride); break;
    case 209: edge32::emit<edge32::command::dma_setx, 209>(stride); break;
    case 210: edge32::emit<edge32::command::dma_setx, 210>(stride); break;
    case 211: edge32::emit<edge32::command::dma_setx, 211>(stride); break;
    case 212: edge32::emit<edge32::command::dma_setx, 212>(stride); break;
    case 213: edge32::emit<edge32::command::dma_setx, 213>(stride); break;
    case 214: edge32::emit<edge32::command::dma_setx, 214>(stride); break;
    case 215: edge32::emit<edge32::command::dma_setx, 215>(stride); break;
    case 216: edge32::emit<edge32::command::dma_setx, 216>(stride); break;
    case 217: edge32::emit<edge32::command::dma_setx, 217>(stride); break;
    case 218: edge32::emit<edge32::command::dma_setx, 218>(stride); break;
    case 219: edge32::emit<edge32::command::dma_setx, 219>(stride); break;
    case 220: edge32::emit<edge32::command::dma_setx, 220>(stride); break;
    case 221: edge32::emit<edge32::command::dma_setx, 221>(stride); break;
    case 222: edge32::emit<edge32::command::dma_setx, 222>(stride); break;
    case 223: edge32::emit<edge32::command::dma_setx, 223>(stride); break;
    case 224: edge32::emit<edge32::command::dma_setx, 224>(stride); break;
    case 225: edge32::emit<edge32::command::dma_setx, 225>(stride); break;
    case 226: edge32::emit<edge32::command::dma_setx, 226>(stride); break;
    case 227: edge32::emit<edge32::command::dma_setx, 227>(stride); break;
    case 228: edge32::emit<edge32::command::dma_setx, 228>(stride); break;
    case 229: edge32::emit<edge32::command::dma_setx, 229>(stride); break;
    case 230: edge32::emit<edge32::command::dma_setx, 230>(stride); break;
    case 231: edge32::emit<edge32::command::dma_setx, 231>(stride); break;
    case 232: edge32::emit<edge32::command::dma_setx, 232>(stride); break;
    case 233: edge32::emit<edge32::command::dma_setx, 233>(stride); break;
    case 234: edge32::emit<edge32::command::dma_setx, 234>(stride); break;
    case 235: edge32::emit<edge32::command::dma_setx, 235>(stride); break;
    case 236: edge32::emit<edge32::command::dma_setx, 236>(stride); break;
    case 237: edge32::emit<edge32::command::dma_setx, 237>(stride); break;
    case 238: edge32::emit<edge32::command::dma_setx, 238>(stride); break;
    case 239: edge32::emit<edge32::command::dma_setx, 239>(stride); break;
    case 240: edge32::emit<edge32::command::dma_setx, 240>(stride); break;
    case 241: edge32::emit<edge32::command::dma_setx, 241>(stride); break;
    case 242: edge32::emit<edge32::command::dma_setx, 242>(stride); break;
    case 243: edge32::emit<edge32::command::dma_setx, 243>(stride); break;
    case 244: edge32::emit<edge32::command::dma_setx, 244>(stride); break;
    case 245: edge32::emit<edge32::command::dma_setx, 245>(stride); break;
    case 246: edge32::emit<edge32::command::dma_setx, 246>(stride); break;
    case 247: edge32::emit<edge32::command::dma_setx, 247>(stride); break;
    case 248: edge32::emit<edge32::command::dma_setx, 248>(stride); break;
    case 249: edge32::emit<edge32::command::dma_setx, 249>(stride); break;
    case 250: edge32::emit<edge32::command::dma_setx, 250>(stride); break;
    case 251: edge32::emit<edge32::command::dma_setx, 251>(stride); break;
    case 252: edge32::emit<edge32::command::dma_setx, 252>(stride); break;
    case 253: edge32::emit<edge32::command::dma_setx, 253>(stride); break;
    case 254: edge32::emit<edge32::command::dma_setx, 254>(stride); break;
    case 255: edge32::emit<edge32::command::dma_setx, 255>(stride); break;
    default: edge32::emit<edge32::command::dma_setx>(stride); break;
    }
}
static inline void edge_dma_sety(uintptr_t stride, uintptr_t count)
{
    switch (count) {
    case 1: edge32::emit<edge32::command::dma_sety, 1>(stride); break;
    case 2: edge32::emit<edge32::command::dma_sety, 2>(stride); break;
    case 3: edge32::emit<edge32::command::dma_sety, 3>(stride); break;
    case 4: edge32::emit<edge32::command::dma_sety, 4>(stride); break;
    case 5: edge32::emit<edge32::command::dma_sety, 5>(stride); break;
    case 6: edge32::emit<edge32::command::dma_sety, 6>(stride); break;
    case 7: edge32::emit<edge32::command::dma_sety, 7>(stride); break;
    case 8: edge32::emit<edge32::command::dma_sety, 8>(stride); break;
    case 9: edge32::emit<edge32::command::dma_sety, 9>(stride); break;
    case 10: edge32::emit<edge32::command::dma_sety, 10>(stride); break;
    case 11: edge32::emit<edge32::command::dma_sety, 11>(stride); break;
    case 12: edge32::emit<edge32::command::dma_sety, 12>(stride); break;
    case 13: edge32::emit<edge32::command::dma_sety, 13>(stride); break;
    case 14: edge32::emit<edge32::command::dma_sety, 14>(stride); break;
    case 15: edge32::emit<edge32::command::dma_sety, 15>(stride); break;
    case 16: edge32::emit<edge32::command::dma_sety, 16>(stride); break;
    case 17: edge32::emit<edge32::command::dma_sety, 17>(stride); break;
    case 18: edge32::emit<edge32::command::dma_sety, 18>(stride); break;
    case 19: edge32::emit<edge32::command::dma_sety, 19>(stride); break;
    case 20: edge32::emit<edge32::command::dma_sety, 20>(stride); break;
    case 21: edge32::emit<edge32::command::dma_sety, 21>(stride); break;
    case 22: edge32::emit<edge32::command::dma_sety, 22>(stride); break;
    case 23: edge32::emit<edge32::command::dma_sety, 23>(stride); break;
    case 24: edge32::emit<edge32::command::dma_sety, 24>(stride); break;
    case 25: edge32::emit<edge32::command::dma_sety, 25>(stride); break;
    case 26: edge32::emit<edge32::command::dma_sety, 26>(stride); break;
    case 27: edge32::emit<edge32::command::dma_sety, 27>(stride); break;
    case 28: edge32::emit<edge32::command::dma_sety, 28>(stride); break;
    case 29: edge32::emit<edge32::command::dma_sety, 29>(stride); break;
    case 30: edge32::emit<edge32::command::dma_sety, 30>(stride); break;
    case 31: edge32::emit<edge32::command::dma_sety, 31>(stride); break;
    case 32: edge32::emit<edge32::command::dma_sety, 32>(stride); break;
    case 33: edge32::emit<edge32::command::dma_sety, 33>(stride); break;
    case 34: edge32::emit<edge32::command::dma_sety, 34>(stride); break;
    case 35: edge32::emit<edge32::command::dma_sety, 35>(stride); break;
    case 36: edge32::emit<edge32::command::dma_sety, 36>(stride); break;
    case 37: edge32::emit<edge32::command::dma_sety, 37>(stride); break;
    case 38: edge32::emit<edge32::command::dma_sety, 38>(stride); break;
    case 39: edge32::emit<edge32::command::dma_sety, 39>(stride); break;
    case 40: edge32::emit<edge32::command::dma_sety, 40>(stride); break;
    case 41: edge32::emit<edge32::command::dma_sety, 41>(stride); break;
    case 42: edge32::emit<edge32::command::dma_sety, 42>(stride); break;
    case 43: edge32::emit<edge32::command::dma_sety, 43>(stride); break;
    case 44: edge32::emit<edge32::command::dma_sety, 44>(stride); break;
    case 45: edge32::emit<edge32::command::dma_sety, 45>(stride); break;
    case 46: edge32::emit<edge32::command::dma_sety, 46>(stride); break;
    case 47: edge32::emit<edge32::command::dma_sety, 47>(stride); break;
    case 48: edge32::emit<edge32::command::dma_sety, 48>(stride); break;
    case 49: edge32::emit<edge32::command::dma_sety, 49>(stride); break;
    case 50: edge32::emit<edge32::command::dma_sety, 50>(stride); break;
    case 51: edge32::emit<edge32::command::dma_sety, 51>(stride); break;
    case 52: edge32::emit<edge32::command::dma_sety, 52>(stride); break;
    case 53: edge32::emit<edge32::command::dma_sety, 53>(stride); break;
    case 54: edge32::emit<edge32::command::dma_sety, 54>(stride); break;
    case 55: edge32::emit<edge32::command::dma_sety, 55>(stride); break;
    case 56: edge32::emit<edge32::command::dma_sety, 56>(stride); break;
    case 57: edge32::emit<edge32::command::dma_sety, 57>(stride); break;
    case 58: edge32::emit<edge32::command::dma_sety, 58>(stride); break;
    case 59: edge32::emit<edge32::command::dma_sety, 59>(stride); break;
    case 60: edge32::emit<edge32::command::dma_sety, 60>(stride); break;
    case 61: edge32::emit<edge32::command::dma_sety, 61>(stride); break;
    case 62: edge32::emit<edge32::command::dma_sety, 62>(stride); break;
    case 63: edge32::emit<edge32::command::dma_sety, 63>(stride); break;
    case 64: edge32::emit<edge32::command::dma_sety, 64>(stride); break;
    case 65: edge32::emit<edge32::command::dma_sety, 65>(stride); break;
    case 66: edge32::emit<edge32::command::dma_sety, 66>(stride); break;
    case 67: edge32::emit<edge32::command::dma_sety, 67>(stride); break;
    case 68: edge32::emit<edge32::command::dma_sety, 68>(stride); break;
    case 69: edge32::emit<edge32::command::dma_sety, 69>(stride); break;
    case 70: edge32::emit<edge32::command::dma_sety, 70>(stride); break;
    case 71: edge32::emit<edge32::command::dma_sety, 71>(stride); break;
    case 72: edge32::emit<edge32::command::dma_sety, 72>(stride); break;
    case 73: edge32::emit<edge32::command::dma_sety, 73>(stride); break;
    case 74: edge32::emit<edge32::command::dma_sety, 74>(stride); break;
    case 75: edge32::emit<edge32::command::dma_sety, 75>(stride); break;
    case 76: edge32::emit<edge32::command::dma_sety, 76>(stride); break;
    case 77: edge32::emit<edge32::command::dma_sety, 77>(stride); break;
    case 78: edge32::emit<edge32::command::dma_sety, 78>(stride); break;
    case 79: edge32::emit<edge32::command::dma_sety, 79>(stride); break;
    case 80: edge32::emit<edge32::command::dma_sety, 80>(stride); break;
    case 81: edge32::emit<edge32::command::dma_sety, 81>(stride); break;
    case 82: edge32::emit<edge32::command::dma_sety, 82>(stride); break;
    case 83: edge32::emit<edge32::command::dma_sety, 83>(stride); break;
    case 84: edge32::emit<edge32::command::dma_sety, 84>(stride); break;
    case 85: edge32::emit<edge32::command::dma_sety, 85>(stride); break;
    case 86: edge32::emit<edge32::command::dma_sety, 86>(stride); break;
    case 87: edge32::emit<edge32::command::dma_sety, 87>(stride); break;
    case 88: edge32::emit<edge32::command::dma_sety, 88>(stride); break;
    case 89: edge32::emit<edge32::command::dma_sety, 89>(stride); break;
    case 90: edge32::emit<edge32::command::dma_sety, 90>(stride); break;
    case 91: edge32::emit<edge32::command::dma_sety, 91>(stride); break;
    case 92: edge32::emit<edge32::command::dma_sety, 92>(stride); break;
    case 93: edge32::emit<edge32::command::dma_sety, 93>(stride); break;
    case 94: edge32::emit<edge32::command::dma_sety, 94>(stride); break;
    case 95: edge32::emit<edge32::command::dma_sety, 95>(stride); break;
    case 96: edge32::emit<edge32::command::dma_sety, 96>(stride); break;
    case 97: edge32::emit<edge32::command::dma_sety, 97>(stride); break;
    case 98: edge32::emit<edge32::command::dma_sety, 98>(stride); break;
    case 99: edge32::emit<edge32::command::dma_sety, 99>(stride); break;
    case 100: edge32::emit<edge32::command::dma_sety, 100>(stride); break;
    case 101: edge32::emit<edge32::command::dma_sety, 101>(stride); break;
    case 102: edge32::emit<edge32::command::dma_sety, 102>(stride); break;
    case 103: edge32::emit<edge32::command::dma_sety, 103>(stride); break;
    case 104: edge32::emit<edge32::command::dma_sety, 104>(stride); break;
    case 105: edge32::emit<edge32::command::dma_sety, 105>(stride); break;
    case 106: edge32::emit<edge32::command::dma_sety, 106>(stride); break;
    case 107: edge32::emit<edge32::command::dma_sety, 107>(stride); break;
    case 108: edge32::emit<edge32::command::dma_sety, 108>(stride); break;
    case 109: edge32::emit<edge32::command::dma_sety, 109>(stride); break;
    case 110: edge32::emit<edge32::command::dma_sety, 110>(stride); break;
    case 111: edge32::emit<edge32::command::dma_sety, 111>(stride); break;
    case 112: edge32::emit<edge32::command::dma_sety, 112>(stride); break;
    case 113: edge32::emit<edge32::command::dma_sety, 113>(stride); break;
    case 114: edge32::emit<edge32::command::dma_sety, 114>(stride); break;
    case 115: edge32::emit<edge32::command::dma_sety, 115>(stride); break;
    case 116: edge32::emit<edge32::command::dma_sety, 116>(stride); break;
    case 117: edge32::emit<edge32::command::dma_sety, 117>(stride); break;
    case 118: edge32::emit<edge32::command::dma_sety, 118>(stride); break;
    case 119: edge32::emit<edge32::command::dma_sety, 119>(stride); break;
    case 120: edge32::emit<edge32::command::dma_sety, 120>(stride); break;
    case 121: edge32::emit<edge32::command::dma_sety, 121>(stride); break;
    case 122: edge32::emit<edge32::command::dma_sety, 122>(stride); break;
    case 123: edge32::emit<edge32::command::dma_sety, 123>(stride); break;
    case 124: edge32::emit<edge32::command::dma_sety, 124>(stride); break;
    case 125: edge32::emit<edge32::command::dma_sety, 125>(stride); break;
    case 126: edge32::emit<edge32::command::dma_sety, 126>(stride); break;
    case 127: edge32::emit<edge32::command::dma_sety, 127>(stride); break;
    case 128: edge32::emit<edge32::command::dma_sety, 128>(stride); break;
    case 129: edge32::emit<edge32::command::dma_sety, 129>(stride); break;
    case 130: edge32::emit<edge32::command::dma_sety, 130>(stride); break;
    case 131: edge32::emit<edge32::command::dma_sety, 131>(stride); break;
    case 132: edge32::emit<edge32::command::dma_sety, 132>(stride); break;
    case 133: edge32::emit<edge32::command::dma_sety, 133>(stride); break;
    case 134: edge32::emit<edge32::command::dma_sety, 134>(stride); break;
    case 135: edge32::emit<edge32::command::dma_sety, 135>(stride); break;
    case 136: edge32::emit<edge32::command::dma_sety, 136>(stride); break;
    case 137: edge32::emit<edge32::command::dma_sety, 137>(stride); break;
    case 138: edge32::emit<edge32::command::dma_sety, 138>(stride); break;
    case 139: edge32::emit<edge32::command::dma_sety, 139>(stride); break;
    case 140: edge32::emit<edge32::command::dma_sety, 140>(stride); break;
    case 141: edge32::emit<edge32::command::dma_sety, 141>(stride); break;
    case 142: edge32::emit<edge32::command::dma_sety, 142>(stride); break;
    case 143: edge32::emit<edge32::command::dma_sety, 143>(stride); break;
    case 144: edge32::emit<edge32::command::dma_sety, 144>(stride); break;
    case 145: edge32::emit<edge32::command::dma_sety, 145>(stride); break;
    case 146: edge32::emit<edge32::command::dma_sety, 146>(stride); break;
    case 147: edge32::emit<edge32::command::dma_sety, 147>(stride); break;
    case 148: edge32::emit<edge32::command::dma_sety, 148>(stride); break;
    case 149: edge32::emit<edge32::command::dma_sety, 149>(stride); break;
    case 150: edge32::emit<edge32::command::dma_sety, 150>(stride); break;
    case 151: edge32::emit<edge32::command::dma_sety, 151>(stride); break;
    case 152: edge32::emit<edge32::command::dma_sety, 152>(stride); break;
    case 153: edge32::emit<edge32::command::dma_sety, 153>(stride); break;
    case 154: edge32::emit<edge32::command::dma_sety, 154>(stride); break;
    case 155: edge32::emit<edge32::command::dma_sety, 155>(stride); break;
    case 156: edge32::emit<edge32::command::dma_sety, 156>(stride); break;
    case 157: edge32::emit<edge32::command::dma_sety, 157>(stride); break;
    case 158: edge32::emit<edge32::command::dma_sety, 158>(stride); break;
    case 159: edge32::emit<edge32::command::dma_sety, 159>(stride); break;
    case 160: edge32::emit<edge32::command::dma_sety, 160>(stride); break;
    case 161: edge32::emit<edge32::command::dma_sety, 161>(stride); break;
    case 162: edge32::emit<edge32::command::dma_sety, 162>(stride); break;
    case 163: edge32::emit<edge32::command::dma_sety, 163>(stride); break;
    case 164: edge32::emit<edge32::command::dma_sety, 164>(stride); break;
    case 165: edge32::emit<edge32::command::dma_sety, 165>(stride); break;
    case 166: edge32::emit<edge32::command::dma_sety, 166>(stride); break;
    case 167: edge32::emit<edge32::command::dma_sety, 167>(stride); break;
    case 168: edge32::emit<edge32::command::dma_sety, 168>(stride); break;
    case 169: edge32::emit<edge32::command::dma_sety, 169>(stride); break;
    case 170: edge32::emit<edge32::command::dma_sety, 170>(stride); break;
    case 171: edge32::emit<edge32::command::dma_sety, 171>(stride); break;
    case 172: edge32::emit<edge32::command::dma_sety, 172>(stride); break;
    case 173: edge32::emit<edge32::command::dma_sety, 173>(stride); break;
    case 174: edge32::emit<edge32::command::dma_sety, 174>(stride); break;
    case 175: edge32::emit<edge32::command::dma_sety, 175>(stride); break;
    case 176: edge32::emit<edge32::command::dma_sety, 176>(stride); break;
    case 177: edge32::emit<edge32::command::dma_sety, 177>(stride); break;
    case 178: edge32::emit<edge32::command::dma_sety, 178>(stride); break;
    case 179: edge32::emit<edge32::command::dma_sety, 179>(stride); break;
    case 180: edge32::emit<edge32::command::dma_sety, 180>(stride); break;
    case 181: edge32::emit<edge32::command::dma_sety, 181>(stride); break;
    case 182: edge32::emit<edge32::command::dma_sety, 182>(stride); break;
    case 183: edge32::emit<edge32::command::dma_sety, 183>(stride); break;
    case 184: edge32::emit<edge32::command::dma_sety, 184>(stride); break;
    case 185: edge32::emit<edge32::command::dma_sety, 185>(stride); break;
    case 186: edge32::emit<edge32::command::dma_sety, 186>(stride); break;
    case 187: edge32::emit<edge32::command::dma_sety, 187>(stride); break;
    case 188: edge32::emit<edge32::command::dma_sety, 188>(stride); break;
    case 189: edge32::emit<edge32::command::dma_sety, 189>(stride); break;
    case 190: edge32::emit<edge32::command::dma_sety, 190>(stride); break;
    case 191: edge32::emit<edge32::command::dma_sety, 191>(stride); break;
    case 192: edge32::emit<edge32::command::dma_sety, 192>(stride); break;
    case 193: edge32::emit<edge32::command::dma_sety, 193>(stride); break;
    case 194: edge32::emit<edge32::command::dma_sety, 194>(stride); break;
    case 195: edge32::emit<edge32::command::dma_sety, 195>(stride); break;
    case 196: edge32::emit<edge32::command::dma_sety, 196>(stride); break;
    case 197: edge32::emit<edge32::command::dma_sety, 197>(stride); break;
    case 198: edge32::emit<edge32::command::dma_sety, 198>(stride); break;
    case 199: edge32::emit<edge32::command::dma_sety, 199>(stride); break;
    case 200: edge32::emit<edge32::command::dma_sety, 200>(stride); break;
    case 201: edge32::emit<edge32::command::dma_sety, 201>(stride); break;
    case 202: edge32::emit<edge32::command::dma_sety, 202>(stride); break;
    case 203: edge32::emit<edge32::command::dma_sety, 203>(stride); break;
    case 204: edge32::emit<edge32::command::dma_sety, 204>(stride); break;
    case 205: edge32::emit<edge32::command::dma_sety, 205>(stride); break;
    case 206: edge32::emit<edge32::command::dma_sety, 206>(stride); break;
    case 207: edge32::emit<edge32::command::dma_sety, 207>(stride); break;
    case 208: edge32::emit<edge32::command::dma_sety, 208>(stride); break;
    case 209: edge32::emit<edge32::command::dma_sety, 209>(stride); break;
    case 210: edge32::emit<edge32::command::dma_sety, 210>(stride); break;
    case 211: edge32::emit<edge32::command::dma_sety, 211>(stride); break;
    case 212: edge32::emit<edge32::command::dma_sety, 212>(stride); break;
    case 213: edge32::emit<edge32::command::dma_sety, 213>(stride); break;
    case 214: edge32::emit<edge32::command::dma_sety, 214>(stride); break;
    case 215: edge32::emit<edge32::command::dma_sety, 215>(stride); break;
    case 216: edge32::emit<edge32::command::dma_sety, 216>(stride); break;
    case 217: edge32::emit<edge32::command::dma_sety, 217>(stride); break;
    case 218: edge32::emit<edge32::command::dma_sety, 218>(stride); break;
    case 219: edge32::emit<edge32::command::dma_sety, 219>(stride); break;
    case 220: edge32::emit<edge32::command::dma_sety, 220>(stride); break;
    case 221: edge32::emit<edge32::command::dma_sety, 221>(stride); break;
    case 222: edge32::emit<edge32::command::dma_sety, 222>(stride); break;
    case 223: edge32::emit<edge32::command::dma_sety, 223>(stride); break;
    case 224: edge32::emit<edge32::command::dma_sety, 224>(stride); break;
    case 225: edge32::emit<edge32::command::dma_sety, 225>(stride); break;
    case 226: edge32::emit<edge32::command::dma_sety, 226>(stride); break;
    case 227: edge32::emit<edge32::command::dma_sety, 227>(stride); break;
    case 228: edge32::emit<edge32::command::dma_sety, 228>(stride); break;
    case 229: edge32::emit<edge32::command::dma_sety, 229>(stride); break;
    case 230: edge32::emit<edge32::command::dma_sety, 230>(stride); break;
    case 231: edge32::emit<edge32::command::dma_sety, 231>(stride); break;
    case 232: edge32::emit<edge32::command::dma_sety, 232>(stride); break;
    case 233: edge32::emit<edge32::command::dma_sety, 233>(stride); break;
    case 234: edge32::emit<edge32::command::dma_sety, 234>(stride); break;
    case 235: edge32::emit<edge32::command::dma_sety, 235>(stride); break;
    case 236: edge32::emit<edge32::command::dma_sety, 236>(stride); break;
    case 237: edge32::emit<edge32::command::dma_sety, 237>(stride); break;
    case 238: edge32::emit<edge32::command::dma_sety, 238>(stride); break;
    case 239: edge32::emit<edge32::command::dma_sety, 239>(stride); break;
    case 240: edge32::emit<edge32::command::dma_sety, 240>(stride); break;
    case 241: edge32::emit<edge32::command::dma_sety, 241>(stride); break;
    case 242: edge32::emit<edge32::command::dma_sety, 242>(stride); break;
    case 243: edge32::emit<edge32::command::dma_sety, 243>(stride); break;
    case 244: edge32::emit<edge32::command::dma_sety, 244>(stride); break;
    case 245: edge32::emit<edge32::command::dma_sety, 245>(stride); break;
    case 246: edge32::emit<edge32::command::dma_sety, 246>(stride); break;
    case 247: edge32::emit<edge32::command::dma_sety, 247>(stride); break;
    case 248: edge32::emit<edge32::command::dma_sety, 248>(stride); break;
    case 249: edge32::emit<edge32::command::dma_sety, 249>(stride); break;
    case 250: edge32::emit<edge32::command::dma_sety, 250>(stride); break;
    case 251: edge32::emit<edge32::command::dma_sety, 251>(stride); break;
    case 252: edge32::emit<edge32::command::dma_sety, 252>(stride); break;
    case 253: edge32::emit<edge32::command::dma_sety, 253>(stride); break;
    case 254: edge32::emit<edge32::command::dma_sety, 254>(stride); break;
    case 255: edge32::emit<edge32::command::dma_sety, 255>(stride); break;
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
#ifdef __cplusplus
static inline void edge_dma_start_strided(
    const void *src, void *dst, uintptr_t bytes, uintptr_t stride,
    uintptr_t count)
{
    edge_dma_start_strided(edge_addr_from_ptr(src), edge_addr_from_ptr(dst),
                           bytes, stride, count);
}
#endif
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

#ifdef __cplusplus
static inline void edge_dma_start_strided_circular(
    const void *src, void *ring, uintptr_t bytes, uintptr_t x_stride,
    uintptr_t x_max, uintptr_t y_stride, uintptr_t y_max,
    uintptr_t entry_bytes, uintptr_t ring_entries)
{
    edge_dma_start_strided_circular(
        edge_addr_from_ptr(src), edge_addr_from_ptr(ring), bytes, x_stride,
        x_max, y_stride, y_max, entry_bytes, ring_entries);
}
#endif

static inline void edge_dma_start_strided_circular(
    addr_t src, addr_t ring, uintptr_t bytes, uintptr_t x_stride,
    uintptr_t x_max, uintptr_t y_stride, uintptr_t y_max,
    uintptr_t ring_entries)
{
    edge_dma_start_strided_circular(src, ring, bytes, x_stride, x_max,
                                    y_stride, y_max, bytes, ring_entries);
}

#ifdef __cplusplus
static inline void edge_dma_start_strided_circular(
    const void *src, void *ring, uintptr_t bytes, uintptr_t x_stride,
    uintptr_t x_max, uintptr_t y_stride, uintptr_t y_max,
    uintptr_t ring_entries)
{
    edge_dma_start_strided_circular(
        edge_addr_from_ptr(src), edge_addr_from_ptr(ring), bytes, x_stride,
        x_max, y_stride, y_max, ring_entries);
}
#endif

static inline void edge_dma_start_strided_circular(
    addr_t src, addr_t ring, uintptr_t bytes, uintptr_t x_stride,
    uintptr_t x_max, uintptr_t y_stride, uintptr_t y_max)
{
    edge_dma_start_strided_circular(src, ring, bytes, x_stride, x_max,
                                    y_stride, y_max, x_max);
}

#ifdef __cplusplus
static inline void edge_dma_start_strided_circular(
    const void *src, void *ring, uintptr_t bytes, uintptr_t x_stride,
    uintptr_t x_max, uintptr_t y_stride, uintptr_t y_max)
{
    edge_dma_start_strided_circular(
        edge_addr_from_ptr(src), edge_addr_from_ptr(ring), bytes, x_stride,
        x_max, y_stride, y_max);
}
#endif

static inline void edge_dma_start_strided_circular(
    addr_t src, addr_t ring, uintptr_t bytes, uintptr_t source_stride,
    uintptr_t repeat_count)
{
    edge_dma_start_strided_circular(src, ring, bytes, source_stride,
                                    repeat_count, 0u, 1u, repeat_count);
}

#ifdef __cplusplus
static inline void edge_dma_start_strided_circular(
    const void *src, void *ring, uintptr_t bytes, uintptr_t source_stride,
    uintptr_t repeat_count)
{
    edge_dma_start_strided_circular(
        edge_addr_from_ptr(src), edge_addr_from_ptr(ring), bytes,
        source_stride, repeat_count);
}
#endif

#ifdef __cplusplus
struct bfloat16_t {
    uint16_t bits;

    constexpr bfloat16_t() : bits(0) {}
    explicit constexpr bfloat16_t(uint16_t raw_bits) : bits(raw_bits) {}

    static constexpr bfloat16_t from_bits(uint16_t raw_bits)
    {
        return bfloat16_t(raw_bits);
    }

    static bfloat16_t from_float(float value)
    {
        union {
            float f32;
            uint32_t u32;
        } bits = { value };
        bits.u32 += 0x7fffu + ((bits.u32 >> 16) & 1u);
        return bfloat16_t(static_cast<uint16_t>(bits.u32 >> 16));
    }

    constexpr bfloat16_t(float value) : bits(from_float(value).bits) {}

    float to_float() const
    {
        union {
            uint32_t u32;
            float f32;
        } bits = { static_cast<uint32_t>(this->bits) << 16 };
        return bits.f32;
    }

    operator float() const { return to_float(); }
};

template <typename T>
struct edge_tensor_dtype_encoding {
    static constexpr int value = -1;
};

template <>
struct edge_tensor_dtype_encoding<bfloat16_t> {
    static constexpr int value = EDGE_TENSOR_DTYPE_BF16;
};

template <typename T>
struct edge_tensor_wtype_encoding {
    static constexpr int value = -1;
};

template <>
struct edge_tensor_wtype_encoding<bfloat16_t> {
    static constexpr int value = EDGE_TENSOR_WTYPE_BF16;
};

template <>
struct edge_tensor_wtype_encoding<int8_t> {
    static constexpr int value = EDGE_TENSOR_WTYPE_INT8;
};
#endif

template <int dtype, int wtype>
static inline void edge_tensor_setcsr()
{
    static_assert(dtype >= 0 && dtype < 16, "tensor dtype must fit imm4");
    static_assert(wtype >= 0 && wtype < 16, "tensor wtype must fit imm4");
    // RTL decodes imm8[3:0] as dtype and imm8[7:4] as wtype.
    edge32::emit<edge32::command::tensor_setcsr,
                 static_cast<uint8_t>((wtype << 4) | dtype)>();
}

#ifdef __cplusplus
template <typename DType, typename WType>
static inline void edge_tensor_setcsr()
{
    constexpr int dtype = edge_tensor_dtype_encoding<DType>::value;
    constexpr int wtype = edge_tensor_wtype_encoding<WType>::value;
    static_assert(dtype >= 0 && dtype < 16,
                  "unsupported tensor data type");
    static_assert(wtype >= 0 && wtype < 16,
                  "unsupported tensor weight type");
    edge_tensor_setcsr<dtype, wtype>();
}
#endif

template <unsigned Options = 0>
static inline void edge_tensor_wld(addr_t weight_addr = 0)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.wld option");
    if constexpr (Options & EDGE_TENSOR_LOAD_OPT_REUSE)
        edge32::emit<edge32::command::tensor_wld,
                     static_cast<uint8_t>(Options)>();
    else
        edge32::tensor_wld(weight_addr);
}

#ifdef __cplusplus
template <unsigned Options = 0>
static inline void edge_tensor_wld(const void *weight_ptr)
{ edge_tensor_wld<Options>(edge_addr_from_ptr(weight_ptr)); }
#endif

template <unsigned Options = 0>
static inline void edge_tensor_wld_t(addr_t weight_addr = 0)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.wld_t option");
    if constexpr (Options & EDGE_TENSOR_LOAD_OPT_REUSE)
        edge32::emit<edge32::command::tensor_wld_t,
                     static_cast<uint8_t>(Options)>();
    else
        edge32::tensor_wld_t(weight_addr);
}

#ifdef __cplusplus
template <unsigned Options = 0>
static inline void edge_tensor_wld_t(const void *weight_ptr)
{ edge_tensor_wld_t<Options>(edge_addr_from_ptr(weight_ptr)); }
#endif

static inline void edge_tensor_setin(addr_t addr)
{ edge32::tensor_setin(addr); }
static inline void edge_tensor_setout(addr_t addr)
{ edge32::tensor_setout(addr); }
static inline void edge_tensor_setpsum(addr_t addr)
{ edge32::tensor_setpsum(addr); }
template <unsigned Options = 0>
static inline void edge_tensor_sld(addr_t addr = 0)
{
    static_assert((Options & ~EDGE_TENSOR_LOAD_OPT_KNOWN_MASK) == 0,
                  "unknown tensor.sld option");
    if constexpr (Options & EDGE_TENSOR_LOAD_OPT_REUSE)
        edge32::emit<edge32::command::tensor_sld,
                     static_cast<uint8_t>(Options)>();
    else
        edge32::tensor_sld(addr);
}
static inline void edge_tensor_sld_stream(addr_t addr)
{ edge32::tensor_sld_stream(addr); }
static inline void edge_tensor_setn(uintptr_t n)
{ edge32::tensor_setn(static_cast<uint32_t>(n)); }

#ifdef __cplusplus
static inline void edge_tensor_setin(const void *ptr)
{ edge_tensor_setin(edge_addr_from_ptr(ptr)); }
static inline void edge_tensor_setout(void *ptr)
{ edge_tensor_setout(edge_addr_from_ptr(ptr)); }
static inline void edge_tensor_setpsum(const void *ptr)
{ edge_tensor_setpsum(edge_addr_from_ptr(ptr)); }
template <unsigned Options = 0>
static inline void edge_tensor_sld(const void *ptr)
{ edge_tensor_sld<Options>(edge_addr_from_ptr(ptr)); }
static inline void edge_tensor_sld_stream(const void *ptr)
{ edge_tensor_sld_stream(edge_addr_from_ptr(ptr)); }
#endif

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
static inline void edge_tensor_wld_circular(void)
{ edge32::emit<edge32::command::tensor_wld_circular>(); }
static inline void edge_tensor_sld_circular(void)
{ edge32::emit<edge32::command::tensor_sld_circular>(); }

#define EDGE_ACCEL_CSR_CMPU_MAX_VALUE  0
#define EDGE_ACCEL_CSR_CMPU_ARGMAX_IDX 1
#define EDGE_ACCEL_CSR_CMPU_MIN_VALUE  2
#define EDGE_ACCEL_CSR_CMPU_ARGMIN_IDX 3
#define EDGE_ACCEL_CSR_ACTU_EXP_SUM    4

template <int dtype, int mode>
static inline void edge_actu_setcsr()
{
    static_assert(dtype >= 0 && dtype < 16, "actu dtype must fit imm4");
    static_assert(mode >= 0 && mode < 16, "actu mode must fit imm4");
    edge32::emit<edge32::command::actu_setcsr,
                 static_cast<uint8_t>((mode << 4) | dtype)>();
}

static inline void edge_actu_setin(const void *ptr)
{ edge32::actu_setin(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(ptr))); }
static inline void edge_actu_setout(void *ptr)
{ edge32::actu_setout(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(ptr))); }
static inline void edge_actu_setn(uintptr_t n)
{ edge32::actu_setn(static_cast<uint32_t>(n)); }
static inline void edge_actu_setscalar(uintptr_t value)
{ edge32::actu_setscalar(static_cast<uint32_t>(value)); }

template <uintptr_t value>
static inline void edge_actu_setscalar_imm()
{
    static_assert(value <= 0xffffffffu,
                  "actu scalar immediate must fit RV32");
    edge32::actu_setscalar(static_cast<uint32_t>(value));
}

static inline void edge_actu_start(void) { edge32::actu_start(); }
static inline void edge_actu_sync(void)
{
    edge32::actu_sync();
#if defined(__riscv)
    __asm__ volatile("fence rw, rw" ::: "memory");
#endif
}

template <int mode>
static inline void edge_cmpu_setcsr()
{
    static_assert(mode >= 0 && mode < 16, "cmpu mode must fit imm4");
    edge32::emit<edge32::command::cmpu_setcsr,
                 static_cast<uint8_t>(mode)>();
}

static inline void edge_cmpu_setlhs(const void *ptr)
{ edge32::cmpu_setlhs(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(ptr))); }
static inline void edge_cmpu_setrhs(const void *ptr)
{ edge32::cmpu_setrhs(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(ptr))); }
static inline void edge_cmpu_setmask(const uint8_t *ptr)
{ edge32::cmpu_setmask(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(ptr))); }
static inline void edge_cmpu_setout(void *ptr)
{ edge32::cmpu_setout(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(ptr))); }
static inline void edge_cmpu_setn(uintptr_t n)
{ edge32::cmpu_setn(static_cast<uint32_t>(n)); }
static inline void edge_cmpu_start(void) { edge32::cmpu_start(); }
static inline void edge_cmpu_sync(void)
{
    edge32::cmpu_sync();
#if defined(__riscv)
    __asm__ volatile("fence rw, rw" ::: "memory");
#endif
}

template <int csr_id>
static inline uintptr_t edge_accel_getcsr()
{
    static_assert(csr_id >= EDGE_ACCEL_CSR_CMPU_MAX_VALUE &&
                  csr_id <= EDGE_ACCEL_CSR_ACTU_EXP_SUM,
                  "accelerator CSR ID is out of range");
    return edge32::emit_result<edge32::command::accel_getcsr,
                               static_cast<uint8_t>(csr_id)>();
}

static inline uintptr_t edge_cmpu_get_max_value()
{ return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_MAX_VALUE>(); }
static inline uintptr_t edge_cmpu_get_argmax_idx()
{ return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_ARGMAX_IDX>(); }
static inline uintptr_t edge_cmpu_get_min_value()
{ return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_MIN_VALUE>(); }
static inline uintptr_t edge_cmpu_get_argmin_idx()
{ return edge_accel_getcsr<EDGE_ACCEL_CSR_CMPU_ARGMIN_IDX>(); }
static inline uintptr_t edge_actu_get_exp_sum()
{ return edge_accel_getcsr<EDGE_ACCEL_CSR_ACTU_EXP_SUM>(); }

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
