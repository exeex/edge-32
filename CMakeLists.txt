cmake_minimum_required(VERSION 3.20)
project(edge_32 LANGUAGES NONE)

find_program(VERILATOR verilator REQUIRED)
find_program(CLANGXX clang++ REQUIRED)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
enable_testing()

get_filename_component(EDGE32_LLVM_BIN "${CLANGXX}" DIRECTORY)
set(EDGE32_CLANG "${EDGE32_LLVM_BIN}/clang")
set(EDGE32_OBJDUMP "${EDGE32_LLVM_BIN}/llvm-objdump")
set(EDGE32_OBJCOPY "${EDGE32_LLVM_BIN}/llvm-objcopy")
find_program(EDGE32_LLD ld.lld REQUIRED)
get_filename_component(EDGE32_LLD_BIN "${EDGE32_LLD}" DIRECTORY)
get_filename_component(EDGE32_LLD_PREFIX "${EDGE32_LLD_BIN}" DIRECTORY)
set(EDGE32_RISCV_TARGET "riscv32-unknown-elf")
set(EDGE32_RISCV_MARCH "rv32imf_zba")
set(EDGE32_RISCV_ABI "ilp32f")

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/edge32_intrinsic_compile_test
  COMMAND ${CLANGXX} -std=c++17 -Wall -Wextra -Werror
          -I${CMAKE_CURRENT_LIST_DIR}/include
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge32_intrinsic_compile.cpp
          -o ${CMAKE_CURRENT_BINARY_DIR}/edge32_intrinsic_compile_test
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/include/intrinsic.hpp
          ${CMAKE_CURRENT_LIST_DIR}/include/edge32_intrinsic.hpp
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge32_intrinsic_compile.cpp)
add_custom_target(edge32_intrinsic_compile ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/edge32_intrinsic_compile_test)
add_test(NAME edge32_intrinsic_compile
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/edge32_intrinsic_compile_test)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/dma_addr_split_obj/Vedge32_dma_addr_split_tb
  COMMAND ${VERILATOR} --binary --timing --Wno-fatal
          --top-module edge32_dma_addr_split_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/dma_addr_split_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_accel_pipe.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge32_dma_addr_split_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_accel_pipe.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge32_dma_addr_split_tb.v)
add_custom_target(edge32_dma_addr_split_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/dma_addr_split_obj/Vedge32_dma_addr_split_tb)
add_test(NAME edge32_dma_addr_split
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/dma_addr_split_obj/Vedge32_dma_addr_split_tb)

set(RTL
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_instruction_classifier.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_decode.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_pipeline.v)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/alu32_obj/Vedge_32_alu_tb
  COMMAND ${VERILATOR} --binary --timing --top-module edge_32_alu_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/alu32_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_alu.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_alu_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_alu.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_alu_tb.v)
add_custom_target(edge_32_alu_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/alu32_obj/Vedge_32_alu_tb)
add_test(NAME edge_32_alu
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/alu32_obj/Vedge_32_alu_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/branch32_obj/Vedge_32_branch_tb
  COMMAND ${VERILATOR} --binary --timing --top-module edge_32_branch_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/branch32_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_branch.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_branch_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_branch.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_branch_tb.v)
add_custom_target(edge_32_branch_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/branch32_obj/Vedge_32_branch_tb)
add_test(NAME edge_32_branch
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/branch32_obj/Vedge_32_branch_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_obj/Vedge_32_muldiv_tb
  COMMAND ${VERILATOR} --binary --timing --top-module edge_32_muldiv_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_muldiv.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_muldiv_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_muldiv.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_muldiv_tb.v)
add_custom_target(edge_32_muldiv_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_obj/Vedge_32_muldiv_tb)
add_test(NAME edge_32_muldiv
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_obj/Vedge_32_muldiv_tb)

set(EDGE32_ASAP7_MULDIV_RTL
  ${CMAKE_CURRENT_LIST_DIR}/rtl/muldiv/edge_mul32_booth_code_33.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/muldiv/edge_mul32_booth_compressor.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/muldiv/edge_add16_carry_select8.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/muldiv/edge_add64_carry_select16.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/muldiv/edge_mul32_booth_lane.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_div_srt4_native.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_muldiv_asap7.v)
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_asap7_obj/Vedge_32_muldiv_tb
  COMMAND ${VERILATOR} --binary --timing --Wno-fatal -DEDGE32_ASAP7
          --top-module edge_32_muldiv_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_asap7_obj
          ${EDGE32_ASAP7_MULDIV_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_muldiv_tb.v
  DEPENDS ${EDGE32_ASAP7_MULDIV_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_muldiv_tb.v)
add_custom_target(edge_32_muldiv_asap7_vvp
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_asap7_obj/Vedge_32_muldiv_tb)
add_test(NAME edge_32_muldiv_asap7
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_asap7_obj/Vedge_32_muldiv_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/obj_dir/Vedge_32_pipeline_tb
  COMMAND ${VERILATOR} --binary --timing --top-module edge_32_pipeline_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/obj_dir
          ${RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_pipeline_tb.v
  DEPENDS ${RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_pipeline_tb.v)
add_custom_target(edge_32_pipeline_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/obj_dir/Vedge_32_pipeline_tb)
add_test(NAME edge_32_pipeline
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/obj_dir/Vedge_32_pipeline_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/redirect_obj/Vedge_32_frontend_redirect_tb
  COMMAND ${VERILATOR} --binary --timing
          --top-module edge_32_frontend_redirect_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/redirect_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_frontend.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_frontend_redirect_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_frontend.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_frontend_redirect_tb.v)
add_custom_target(edge_32_frontend_redirect_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/redirect_obj/Vedge_32_frontend_redirect_tb)
add_test(NAME edge_32_frontend_redirect
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/redirect_obj/Vedge_32_frontend_redirect_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/assembler_obj/Vedge_32_instruction_assembler_tb
  COMMAND ${VERILATOR} --binary --timing
          --top-module edge_32_instruction_assembler_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/assembler_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_instruction_assembler.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_instruction_assembler_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_instruction_assembler.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_instruction_assembler_tb.v)
add_custom_target(edge_32_instruction_assembler_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/assembler_obj/Vedge_32_instruction_assembler_tb)
add_test(NAME edge_32_instruction_assembler
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/assembler_obj/Vedge_32_instruction_assembler_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/lsu32_obj/Vedge_32_lsu_tb
  COMMAND ${VERILATOR} --binary --timing --top-module edge_32_lsu_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/lsu32_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_lsu.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_lsu_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_lsu.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_lsu_tb.v)
add_custom_target(edge_32_lsu_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/lsu32_obj/Vedge_32_lsu_tb)
add_test(NAME edge_32_lsu
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/lsu32_obj/Vedge_32_lsu_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/dtcm_router_obj/Vedge_32_dtcm_router_tb
  COMMAND ${VERILATOR} --binary --timing
          --top-module edge_32_dtcm_router_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/dtcm_router_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_dtcm_router.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_dtcm_router_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_dtcm_router.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_dtcm_router_tb.v)
add_custom_target(edge_32_dtcm_router_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/dtcm_router_obj/Vedge_32_dtcm_router_tb)
add_test(NAME edge_32_dtcm_router
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/dtcm_router_obj/Vedge_32_dtcm_router_tb)

set(EDGE_RV_ROOT "${CMAKE_CURRENT_LIST_DIR}/../edge-rv" CACHE PATH
    "Path to the shared edge-rv execution-unit repository")
set(EDGE_COREMARK_MEM64
    "${CMAKE_CURRENT_LIST_DIR}/../../build/cmake-harness/tests/hardware/EDGE_SOC/software/coremark_bench/coremark_bench.data64.memh"
    CACHE FILEPATH "CoreMark RV64 memory image built by the edge-e3 harness")
set(FPU_RTL
  ${EDGE_RV_ROOT}/edge_fpu_misc/edge_fpu_misc.v
  ${EDGE_RV_ROOT}/edge_fpu_cvt/edge_fpu_cvt.v
  ${EDGE_RV_ROOT}/edge_fpu_slow/edge_fpu_slow.v
  ${EDGE_RV_ROOT}/edge_fpu_fmac/rtl/edge_fpu_fmac_align_add.v
  ${EDGE_RV_ROOT}/edge_fpu_fmac/rtl/edge_fpu_fmac_narrow_fmadd.v
  ${EDGE_RV_ROOT}/edge_fpu_fmac/rtl/edge_fpu_fmac_fp32_round_pack.v
  ${EDGE_RV_ROOT}/edge_fpu_fmac/rtl/edge_fpu_fmac_narrow_shift_sticky_2stage.v
  ${EDGE_RV_ROOT}/edge_fpu_fmac/rtl/edge_fpu_fmac_fp32_unpack.v
  ${EDGE_RV_ROOT}/edge_fpu_fmac/rtl/edge_fpu_fmac_fp32_fused_round_pack.v
  ${EDGE_RV_ROOT}/edge_fpu_fmac/edge_fpu_fmac.v
  ${EDGE_RV_ROOT}/edge_fpu_alu/edge_fpu_alu.v)
set(CORE_RTL
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_instruction_classifier.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_decode.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_alu.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_muldiv.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_branch.v
  ${FPU_RTL}
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_frontend.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_instruction_assembler.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_pipeline.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_lsu.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_fp_mem_format.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_core.v)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_core_obj/Vedge_32_muldiv_core_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_muldiv_core_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_core_obj
          ${CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_muldiv_core_tb.v
  DEPENDS ${CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_muldiv_core_tb.v)
add_custom_target(edge_32_muldiv_core_vvp
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_core_obj/Vedge_32_muldiv_core_tb)
add_test(NAME edge_32_muldiv_core
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/muldiv32_core_obj/Vedge_32_muldiv_core_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/branch32_core_obj/Vedge_32_branch_core_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_branch_core_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/branch32_core_obj
          ${CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_branch_core_tb.v
  DEPENDS ${CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_branch_core_tb.v)
add_custom_target(edge_32_branch_core_vvp
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/branch32_core_obj/Vedge_32_branch_core_tb)
add_test(NAME edge_32_branch_core
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/branch32_core_obj/Vedge_32_branch_core_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/fpu_alu_obj/Vedge_fpu_alu_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_fpu_alu_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/fpu_alu_obj
          ${FPU_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_fpu_alu_tb.v
  DEPENDS ${FPU_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_fpu_alu_tb.v)
add_custom_target(edge_fpu_alu_vvp
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/fpu_alu_obj/Vedge_fpu_alu_tb)
add_test(NAME edge_fpu_alu
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/fpu_alu_obj/Vedge_fpu_alu_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/lite_fpu_obj/Vedge_32_fpu_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_fpu_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/lite_fpu_obj
          ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_fpu_tb.v
  DEPENDS ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_fpu_tb.v)
add_custom_target(edge_32_fpu_vvp
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/lite_fpu_obj/Vedge_32_fpu_tb)
add_test(NAME edge_32_fpu
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/lite_fpu_obj/Vedge_32_fpu_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/lite_fcsr_obj/Vedge_32_fcsr_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_fcsr_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/lite_fcsr_obj
          ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_fcsr_tb.v
  DEPENDS ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_fcsr_tb.v)
add_custom_target(edge_32_fcsr_vvp
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/lite_fcsr_obj/Vedge_32_fcsr_tb)
add_test(NAME edge_32_fcsr
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/lite_fcsr_obj/Vedge_32_fcsr_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj/Vedge_32_coremark_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_coremark_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj
          ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_coremark_tb.v
  DEPENDS ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_coremark_tb.v)
add_custom_target(edge_32_coremark_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj/Vedge_32_coremark_tb)
add_test(NAME edge_32_coremark
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj/Vedge_32_coremark_tb
          +mem64=${EDGE_COREMARK_MEM64})
set_tests_properties(edge_32_coremark PROPERTIES
  REQUIRED_FILES "${EDGE_COREMARK_MEM64}" TIMEOUT 30)

set(EDGE32_SOFTWARE_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/software/rv32imf_zba_smoke")
set(EDGE32_SOFTWARE_SOURCE
    "${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_zba_smoke.s")
set(EDGE32_SOFTWARE_OBJECT "${EDGE32_SOFTWARE_DIR}/rv32imf_zba_smoke.o")
set(EDGE32_SOFTWARE_ELF "${EDGE32_SOFTWARE_DIR}/rv32imf_zba_smoke.elf")
set(EDGE32_SOFTWARE_MEM128 "${EDGE32_SOFTWARE_DIR}/rv32imf_zba_smoke.memh")
set(EDGE32_SOFTWARE_WORDS "${EDGE32_SOFTWARE_DIR}/rv32imf_zba_smoke.words")
set(EDGE32_SOFTWARE_MEM64 "${EDGE32_SOFTWARE_DIR}/rv32imf_zba_smoke.data64.memh")
set(EDGE32_SOFTWARE_MEM64_WORDS
    "${EDGE32_SOFTWARE_DIR}/rv32imf_zba_smoke.data64.words")

add_custom_command(
  OUTPUT ${EDGE32_SOFTWARE_MEM64}
         ${EDGE32_SOFTWARE_MEM128}
         ${EDGE32_SOFTWARE_ELF}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${EDGE32_SOFTWARE_DIR}
  COMMAND ${EDGE32_CLANG}
          --target=${EDGE32_RISCV_TARGET}
          -march=${EDGE32_RISCV_MARCH} -mabi=${EDGE32_RISCV_ABI}
          -mcmodel=medany -x assembler-with-cpp
          -c ${EDGE32_SOFTWARE_SOURCE} -o ${EDGE32_SOFTWARE_OBJECT}
  COMMAND ${EDGE32_CLANG}
          --target=${EDGE32_RISCV_TARGET}
          -march=${EDGE32_RISCV_MARCH} -mabi=${EDGE32_RISCV_ABI}
          -mcmodel=medany -fuse-ld=lld -B${EDGE32_LLD_BIN}
          -nostdlib -nostartfiles
          -Wl,-T,${CMAKE_CURRENT_LIST_DIR}/tests/rv64im_lite_flat.ld
          ${EDGE32_SOFTWARE_OBJECT} -o ${EDGE32_SOFTWARE_ELF}
  COMMAND ${Python3_EXECUTABLE}
          ${CMAKE_CURRENT_LIST_DIR}/../../tools/elf2mem128.py
          ${EDGE32_SOFTWARE_ELF}
          -o ${EDGE32_SOFTWARE_MEM128}
          --words-file ${EDGE32_SOFTWARE_WORDS}
          --mem64-output ${EDGE32_SOFTWARE_MEM64}
          --mem64-words-file ${EDGE32_SOFTWARE_MEM64_WORDS}
  DEPENDS ${EDGE32_SOFTWARE_SOURCE}
          ${CMAKE_CURRENT_LIST_DIR}/tests/rv64im_lite_flat.ld
          ${CMAKE_CURRENT_LIST_DIR}/../../tools/elf2mem128.py
  VERBATIM)
add_custom_target(edge32_software_rv32imf_zba_smoke
  DEPENDS ${EDGE32_SOFTWARE_MEM64})
add_custom_target(edge32_software_rv32imf_zba_smoke_vvp
  DEPENDS edge32_software_rv32imf_zba_smoke
          ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj/Vedge_32_coremark_tb)
add_test(NAME edge32_software_rv32imf_zba_smoke
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj/Vedge_32_coremark_tb
          +mem64=${EDGE32_SOFTWARE_MEM64})
set_tests_properties(edge32_software_rv32imf_zba_smoke PROPERTIES
  REQUIRED_FILES "${EDGE32_SOFTWARE_MEM64}" TIMEOUT 30)

set(EDGE32_COREMARK_DIR "${CMAKE_CURRENT_BINARY_DIR}/software/edge32_coremark")
set(EDGE32_COREMARK_SOURCE
    "${CMAKE_CURRENT_LIST_DIR}/../../tests/software/bench/coremark_bench.c")
set(EDGE32_COREMARK_MEM64
    "${EDGE32_COREMARK_DIR}/edge32_coremark.data64.memh")
set(EDGE32_COREMARK_DEPENDS
  ${EDGE32_COREMARK_SOURCE}
  ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/bench/platform.hpp
  ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/include/edge_intrinsic.hpp
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/core_list_join.c
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/core_matrix.c
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/core_state.c
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/core_util.c
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/core_portme.c
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/core_portme.h
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/core_main.c
  ${CMAKE_CURRENT_LIST_DIR}/../../third_party/coremark/coremark.h
  ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_crt0.s
  ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_flat.ld
  ${CMAKE_CURRENT_LIST_DIR}/../../tools/build_rv64im_rom.py)
add_custom_command(
  OUTPUT ${EDGE32_COREMARK_MEM64}
  COMMAND ${Python3_EXECUTABLE}
          ${CMAKE_CURRENT_LIST_DIR}/../../tools/build_rv64im_rom.py
          ${EDGE32_COREMARK_SOURCE}
          --name edge32_coremark --out-dir ${EDGE32_COREMARK_DIR}
          --build-dir ${CMAKE_CURRENT_BINARY_DIR}
          --crt0 ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_crt0.s
          --linker ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_flat.ld
          --clang ${EDGE32_CLANG} --objdump ${EDGE32_OBJDUMP}
          --objcopy ${EDGE32_OBJCOPY} --lld-prefix ${EDGE32_LLD_PREFIX}
          --target ${EDGE32_RISCV_TARGET} --march ${EDGE32_RISCV_MARCH}
          --abi ${EDGE32_RISCV_ABI}
          --include-dir ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/bench
          --include-dir ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/include
          --size 0x100000
  DEPENDS ${EDGE32_COREMARK_DEPENDS}
  VERBATIM)
add_custom_target(edge32_software_coremark
  DEPENDS ${EDGE32_COREMARK_MEM64})
add_custom_target(edge32_software_coremark_vvp
  DEPENDS edge32_software_coremark
          ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj/Vedge_32_coremark_tb)
add_test(NAME edge32_software_coremark
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/coremark_obj/Vedge_32_coremark_tb
          +mem64=${EDGE32_COREMARK_MEM64})
set_tests_properties(edge32_software_coremark PROPERTIES
  REQUIRED_FILES "${EDGE32_COREMARK_MEM64}" TIMEOUT 60)

set(EDGE32_TENSOR_BF16_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/software/tensor_bf16_matmul8x8")
set(EDGE32_TENSOR_BF16_MEMH
    "${EDGE32_TENSOR_BF16_DIR}/edge32_tensor_bf16_matmul8x8.memh")
add_custom_command(
  OUTPUT ${EDGE32_TENSOR_BF16_MEMH}
  COMMAND ${Python3_EXECUTABLE}
          ${CMAKE_CURRENT_LIST_DIR}/../../tools/build_rv64im_rom.py
          ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/tensor/bf16_matmul8x8.cpp
          --name edge32_tensor_bf16_matmul8x8
          --out-dir ${EDGE32_TENSOR_BF16_DIR}
          --build-dir ${CMAKE_CURRENT_BINARY_DIR}
          --crt0 ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_crt0.s
          --linker ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_flat.ld
          --clang ${EDGE32_CLANG} --objdump ${EDGE32_OBJDUMP}
          --objcopy ${EDGE32_OBJCOPY} --lld-prefix ${EDGE32_LLD_PREFIX}
          --target ${EDGE32_RISCV_TARGET} --march ${EDGE32_RISCV_MARCH}
          --abi ${EDGE32_RISCV_ABI}
          --include-dir ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/include
          --size 0x200000
  DEPENDS
          ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/tensor/bf16_matmul8x8.cpp
          ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/include/edge_intrinsic.hpp
          ${CMAKE_CURRENT_LIST_DIR}/include/edge32_intrinsic.hpp
          ${CMAKE_CURRENT_LIST_DIR}/include/edge32_intrinsic_c.h
          ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_crt0.s
          ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_flat.ld
  VERBATIM)
add_custom_target(edge32_software_tensor_bf16_matmul8x8
  DEPENDS ${EDGE32_TENSOR_BF16_MEMH})

set(EDGE32_E3_ROOT "${CMAKE_CURRENT_LIST_DIR}/../edge-e3")
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/edge32_tensor_top_obj/Vedge_core_lite_tensor_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal --sv
          --top-module edge_core_lite_tensor_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/edge32_tensor_top_obj
          -f edge_core/filelists/edge_core_edge32_top_verilator.fl
          ../soc/logical/mem/edge_axi_ram.v
          ../edge-32/tests/edge_core_lite_tensor_tb.v
  WORKING_DIRECTORY ${EDGE32_E3_ROOT}
  DEPENDS
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_core_lite_tensor_tb.v
          ${EDGE32_E3_ROOT}/edge_core/filelists/edge_core_edge32_top_verilator.fl
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_accel_pipe.v)
add_custom_target(edge32_tensor_bf16_matmul8x8_vvp
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/edge32_tensor_top_obj/Vedge_core_lite_tensor_tb
          ${EDGE32_TENSOR_BF16_MEMH})
add_test(NAME edge32_tensor_bf16_matmul8x8
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/edge32_tensor_top_obj/Vedge_core_lite_tensor_tb
          +mem128=${EDGE32_TENSOR_BF16_MEMH} +mem128_words=116 +return_only)
set_tests_properties(edge32_tensor_bf16_matmul8x8 PROPERTIES
  REQUIRED_FILES "${EDGE32_TENSOR_BF16_MEMH}" TIMEOUT 60)

function(edge32_add_tensor_benchmark name source words check_arg)
  set(case_dir "${CMAKE_CURRENT_BINARY_DIR}/software/${name}")
  set(case_memh "${case_dir}/${name}.memh")
  add_custom_command(
    OUTPUT ${case_memh}
    COMMAND ${Python3_EXECUTABLE}
            ${CMAKE_CURRENT_LIST_DIR}/../../tools/build_rv64im_rom.py
            ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/tensor/${source}
            --name ${name} --out-dir ${case_dir}
            --build-dir ${CMAKE_CURRENT_BINARY_DIR}
            --crt0 ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_crt0.s
            --linker ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_flat.ld
            --clang ${EDGE32_CLANG} --objdump ${EDGE32_OBJDUMP}
            --objcopy ${EDGE32_OBJCOPY} --lld-prefix ${EDGE32_LLD_PREFIX}
            --target ${EDGE32_RISCV_TARGET} --march ${EDGE32_RISCV_MARCH}
            --abi ${EDGE32_RISCV_ABI}
            --include-dir ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/include
            --size 0x200000
    DEPENDS
            ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/tensor/${source}
            ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/tensor/matmul.hpp
            ${CMAKE_CURRENT_LIST_DIR}/../../tests/software/include/edge_intrinsic.hpp
            ${CMAKE_CURRENT_LIST_DIR}/include/edge32_intrinsic.hpp
            ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_crt0.s
            ${CMAKE_CURRENT_LIST_DIR}/tests/software/rv32imf_flat.ld
    VERBATIM)
  add_custom_target(${name}_vvp
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/edge32_tensor_top_obj/Vedge_core_lite_tensor_tb
            ${case_memh})
  add_test(NAME ${name}
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/edge32_tensor_top_obj/Vedge_core_lite_tensor_tb
            +mem128=${case_memh} +mem128_words=${words}
            +return_only +${check_arg})
  set_tests_properties(${name} PROPERTIES
    REQUIRED_FILES "${case_memh}" TIMEOUT 60)
endfunction()

edge32_add_tensor_benchmark(
  edge32_matmul64x64_64tokens_circular
  matmul64x64_runtime_shape_64tokens.cpp 1106 check_matmul64)
edge32_add_tensor_benchmark(
  edge32_matmul64x64_128tokens_circular
  matmul64x64_runtime_shape_128tokens.cpp 1622 check_matmul128)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/accel_serial_obj/Vedge_32_accel_serial_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_accel_serial_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/accel_serial_obj
          ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_accel_serial_tb.v
  DEPENDS ${CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_accel_serial_tb.v)
add_custom_target(edge_32_accel_serial_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/accel_serial_obj/Vedge_32_accel_serial_tb)
add_test(NAME edge_32_accel_serial
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/accel_serial_obj/Vedge_32_accel_serial_tb)
set_tests_properties(edge_32_accel_serial PROPERTIES TIMEOUT 30)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/fault_obj/Vedge_32_fault_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_fault_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/fault_obj
          ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_fault_tb.v
  DEPENDS ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_fault_tb.v)
add_custom_target(edge_32_fault_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/fault_obj/Vedge_32_fault_tb)
add_test(NAME edge_32_fault
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/fault_obj/Vedge_32_fault_tb)
set_tests_properties(edge_32_fault PROPERTIES TIMEOUT 30)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/halt_obj/Vedge_32_halt_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_halt_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/halt_obj
          ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_halt_tb.v
  DEPENDS ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_halt_tb.v)
add_custom_target(edge_32_halt_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/halt_obj/Vedge_32_halt_tb)
add_test(NAME edge_32_halt
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/halt_obj/Vedge_32_halt_tb)
set_tests_properties(edge_32_halt PROPERTIES TIMEOUT 30)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hardware_id_obj/Vedge_32_hardware_id_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_32_hardware_id_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/hardware_id_obj
          ${CORE_RTL} ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_hardware_id_tb.v
  DEPENDS ${CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_hardware_id_tb.v)
add_custom_target(edge_32_hardware_id_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/hardware_id_obj/Vedge_32_hardware_id_tb)
add_test(NAME edge_32_hardware_id
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/hardware_id_obj/Vedge_32_hardware_id_tb)
set_tests_properties(edge_32_hardware_id PROPERTIES TIMEOUT 30)

set(CACHED_CORE_RTL
  ${CORE_RTL}
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_icache_adapter.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_dcache_adapter.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_dtcm_router.v
  ${EDGE_RV_ROOT}/edge_ifu_icache/rtl/edge_ifu_icache_data_array.v
  ${EDGE_RV_ROOT}/edge_ifu_icache/rtl/edge_ifu_icache_tag_array.v
  ${EDGE_RV_ROOT}/edge_ifu_icache/edge_ifu_icache.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_mshr.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_hit_queue.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_lookup_buffer.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_registered_lookup_buffer.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_lookup_scheduler.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_pair_predictor.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_banked_data_array.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_tag_array.v
  ${EDGE_RV_ROOT}/edge_dcache/rtl/edge_dcache_dirty_array.v
  ${EDGE_RV_ROOT}/edge_dcache/edge_dcache.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_rv_lite_cached_core.v)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/cached_core_obj/Vedge_rv_lite_cached_core_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_rv_lite_cached_core_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/cached_core_obj
          ${CACHED_CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_cached_core_tb.v
  DEPENDS ${CACHED_CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_cached_core_tb.v)
add_custom_target(edge_rv_lite_cached_core_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/cached_core_obj/Vedge_rv_lite_cached_core_tb)
add_test(NAME edge_rv_lite_cached_core
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/cached_core_obj/Vedge_rv_lite_cached_core_tb)
set_tests_properties(edge_rv_lite_cached_core PROPERTIES TIMEOUT 30)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/cache_biu_obj/Vedge_rv_lite_cache_biu_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_rv_lite_cache_biu_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/cache_biu_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_rv_lite_cache_biu.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_cache_biu_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_rv_lite_cache_biu.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_cache_biu_tb.v)
add_custom_target(edge_rv_lite_cache_biu_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/cache_biu_obj/Vedge_rv_lite_cache_biu_tb)
add_test(NAME edge_rv_lite_cache_biu
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/cache_biu_obj/Vedge_rv_lite_cache_biu_tb)
set_tests_properties(edge_rv_lite_cache_biu PROPERTIES TIMEOUT 30)

set(AXI_CORE_RTL
  ${CACHED_CORE_RTL}
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_rv_lite_cache_biu.v
  ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_rv_lite_axi_core.v)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/axi_coremark_obj/Vedge_rv_lite_axi_coremark_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_rv_lite_axi_coremark_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/axi_coremark_obj
          ${AXI_CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_axi_coremark_tb.v
  DEPENDS ${AXI_CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_axi_coremark_tb.v)
add_custom_target(edge_rv_lite_axi_coremark_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/axi_coremark_obj/Vedge_rv_lite_axi_coremark_tb
          ${EDGE32_COREMARK_MEM64})
add_test(NAME edge_rv_lite_axi_coremark
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/axi_coremark_obj/Vedge_rv_lite_axi_coremark_tb
          +mem64=${EDGE32_COREMARK_MEM64})
set_tests_properties(edge_rv_lite_axi_coremark PROPERTIES
  REQUIRED_FILES "${EDGE32_COREMARK_MEM64}" TIMEOUT 60)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/cached_coremark_obj/Vedge_rv_lite_cached_coremark_tb
  COMMAND ${VERILATOR} --binary --timing -Wno-fatal
          --top-module edge_rv_lite_cached_coremark_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/cached_coremark_obj
          ${CACHED_CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_cached_coremark_tb.v
  DEPENDS ${CACHED_CORE_RTL}
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_rv_lite_cached_coremark_tb.v)
add_custom_target(edge_rv_lite_cached_coremark_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/cached_coremark_obj/Vedge_rv_lite_cached_coremark_tb)
add_test(NAME edge_rv_lite_cached_coremark
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/cached_coremark_obj/Vedge_rv_lite_cached_coremark_tb
          +mem64=${EDGE_COREMARK_MEM64})
set_tests_properties(edge_rv_lite_cached_coremark PROPERTIES
  REQUIRED_FILES "${EDGE_COREMARK_MEM64}" TIMEOUT 60)

foreach(adapter IN ITEMS icache dcache)
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${adapter}_adapter_obj/Vedge_32_${adapter}_adapter_tb
    COMMAND ${VERILATOR} --binary --timing
            --top-module edge_32_${adapter}_adapter_tb
            --Mdir ${CMAKE_CURRENT_BINARY_DIR}/${adapter}_adapter_obj
            ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_${adapter}_adapter.v
            ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_${adapter}_adapter_tb.v
    DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_${adapter}_adapter.v
            ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_${adapter}_adapter_tb.v)
  add_custom_target(edge_32_${adapter}_adapter_vvp ALL
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${adapter}_adapter_obj/Vedge_32_${adapter}_adapter_tb)
  add_test(NAME edge_32_${adapter}_adapter
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${adapter}_adapter_obj/Vedge_32_${adapter}_adapter_tb)
endforeach()

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/decode_obj/Vedge_32_decode_tb
  COMMAND ${VERILATOR} --binary --timing --top-module edge_32_decode_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/decode_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_instruction_classifier.v
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_decode.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_decode_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_instruction_classifier.v
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_32_decode.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_32_decode_tb.v)
add_custom_target(edge_32_decode_vvp ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/decode_obj/Vedge_32_decode_tb)
add_test(NAME edge_32_decode
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/decode_obj/Vedge_32_decode_tb)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/classifier_obj/Vedge_instruction_classifier_tb
  COMMAND ${VERILATOR} --binary --timing --Wno-fatal
          --top-module edge_instruction_classifier_tb
          --Mdir ${CMAKE_CURRENT_BINARY_DIR}/classifier_obj
          ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_instruction_classifier.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_instruction_classifier_tb.v
  DEPENDS ${CMAKE_CURRENT_LIST_DIR}/rtl/edge_instruction_classifier.v
          ${CMAKE_CURRENT_LIST_DIR}/tests/edge_instruction_classifier_tb.v)
add_custom_target(edge_instruction_classifier_verilator ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/classifier_obj/Vedge_instruction_classifier_tb)
add_test(NAME edge_instruction_classifier
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/classifier_obj/Vedge_instruction_classifier_tb)

# The CPU-side accelerator command emitter belongs to edge-32.  Its focused
# integration proofs need the parent repository's E3 blocks and shared
# Verilator test helper, so register them only in the parent build.
if(COMMAND edge_add_verilator_hardware_test AND DEFINED EDGE_ROOT)
  add_subdirectory(tests/accel_pipe)
endif()
