#ifndef EDGE32_INTRINSIC_C_H
#define EDGE32_INTRINSIC_C_H

#include <stdint.h>

static inline uintptr_t edge_get_cycle(void)
{
    uintptr_t cycle;
    __asm__ volatile("csrr %0, cycle" : "=r"(cycle) : : "memory");
    return cycle;
}

static inline void edge_sim_putchar(char ch)
{
    uintptr_t value = (uintptr_t)(unsigned char)ch;
    __asm__ volatile("csrw 0x7e1, %0" : : "r"(value) : "memory");
}

static inline void edge_dcache_clean_range(addr_t addr, uintptr_t len)
{
    (void)addr;
    (void)len;
    __asm__ volatile("fence rw, rw" ::: "memory");
}

__attribute__((noreturn)) static inline void edge_exit(uintptr_t value)
{
    __asm__ volatile("csrw 0x7e0, %0" : : "r"(value) : "memory");
    for (;;) __asm__ volatile("wfi" ::: "memory");
}

#endif
