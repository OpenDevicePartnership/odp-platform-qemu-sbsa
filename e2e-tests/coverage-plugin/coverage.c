// QEMU TCG coverage plugin: records executed PCs in a configurable range to a bitmap.
//
// SPDX-License-Identifier: MIT
//
// Records unique instruction program counters (PCs) executed within a
// configurable address range. Designed for collecting code coverage of
// the EC Secure Partition during e2e tests.
//
// Uses a lock-free bitmap: each bit represents one 4-byte AArch64
// instruction. Bits are set atomically via __atomic_fetch_or so no
// mutex is needed even with multiple vCPUs.
//
// Plugin arguments (comma-separated in -plugin):
//   range_lo=0x...   start of monitored range (default: 0x20802000)
//   range_hi=0x...   end of monitored range   (default: 0x21002000)
//   outfile=<path>   output file for PCs       (default: Build/coverage.log)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include "qemu-plugin.h"

QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

/* Default address range matches the SP linker script (qemu.ld) */
static uint64_t range_lo = 0x20802000;
static uint64_t range_hi = 0x21002000; /* range_lo + 2 MiB */
static const char *outfile = "Build/coverage.log";

/*
 * Bitmap: one bit per 4-byte instruction in [range_lo, range_hi).
 * For the default 2 MiB range this is 64 KiB.
 */
static uint8_t *bitmap;
static size_t bitmap_bytes;

static inline void mark_pc(uint64_t pc)
{
    uint64_t idx = (pc - range_lo) >> 2;
    __atomic_fetch_or(&bitmap[idx >> 3], (uint8_t)(1u << (idx & 7)),
                      __ATOMIC_RELAXED);
}

/* Per-instruction execution callback — records the instruction's PC */
static void insn_exec(unsigned int vcpu_index, void *userdata)
{
    (void)vcpu_index;
    mark_pc((uint64_t)(uintptr_t)userdata);
}

/* Translation callback — instruments every instruction in the SP range */
static void tb_trans(qemu_plugin_id_t id, struct qemu_plugin_tb *tb)
{
    (void)id;
    size_t n = qemu_plugin_tb_n_insns(tb);
    for (size_t i = 0; i < n; i++)
    {
        struct qemu_plugin_insn *insn = qemu_plugin_tb_get_insn(tb, i);
        uint64_t vaddr = qemu_plugin_insn_vaddr(insn);
        if (vaddr >= range_lo && vaddr < range_hi)
        {
            qemu_plugin_register_vcpu_insn_exec_cb(
                insn, insn_exec, QEMU_PLUGIN_CB_NO_REGS,
                (void *)(uintptr_t)vaddr);
        }
    }
}

/* Atexit callback — writes sorted unique PCs to the output file */
static void plugin_atexit(qemu_plugin_id_t id, void *userdata)
{
    (void)id;
    (void)userdata;

    FILE *f = fopen(outfile, "w");
    if (!f)
    {
        fprintf(stderr, "coverage plugin: cannot open %s\n", outfile);
        return;
    }

    size_t count = 0;
    uint64_t max_idx = (range_hi - range_lo) >> 2;
    for (uint64_t idx = 0; idx < max_idx; idx++)
    {
        if (bitmap[idx >> 3] & (1u << (idx & 7)))
        {
            fprintf(f, "0x%" PRIx64 "\n", range_lo + (idx << 2));
            count++;
        }
    }

    fclose(f);
    fprintf(stderr, "coverage plugin: wrote %zu unique PCs to %s\n",
            count, outfile);
    free(bitmap);
}

static int parse_u64(const char *s, uint64_t *out)
{
    char *end;
    *out = strtoull(s, &end, 0);
    return *end == '\0' ? 0 : -1;
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id,
                                           const qemu_info_t *info,
                                           int argc, char **argv)
{
    (void)info;

    for (int i = 0; i < argc; i++)
    {
        const char *arg = argv[i];
        const char *eq = strchr(arg, '=');
        if (!eq)
            continue;
        const char *val = eq + 1;
        size_t key_len = (size_t)(eq - arg);

        if (key_len == strlen("range_lo") &&
            strncmp(arg, "range_lo", key_len) == 0)
        {
            if (parse_u64(val, &range_lo) != 0)
                return -1;
        }
        else if (key_len == strlen("range_hi") &&
                 strncmp(arg, "range_hi", key_len) == 0)
        {
            if (parse_u64(val, &range_hi) != 0)
                return -1;
        }
        else if (key_len == strlen("outfile") &&
                 strncmp(arg, "outfile", key_len) == 0)
        {
            outfile = val; /* argv remains valid for plugin lifetime */
        }
    }

    if (range_hi <= range_lo)
    {
        fprintf(stderr,
                "coverage plugin: invalid range 0x%" PRIx64 "-0x%" PRIx64 "\n",
                range_lo, range_hi);
        return -1;
    }

    uint64_t range_size = range_hi - range_lo;
    size_t max_insns = (size_t)(range_size / 4);
    bitmap_bytes = (max_insns + 7) / 8;
    bitmap = calloc(bitmap_bytes, 1);
    if (!bitmap)
    {
        fprintf(stderr, "coverage plugin: cannot allocate %zu bytes\n",
                bitmap_bytes);
        return -1;
    }

    fprintf(stderr,
            "coverage plugin: monitoring 0x%" PRIx64 "-0x%" PRIx64
            " (%zu bytes bitmap), output: %s\n",
            range_lo, range_hi, bitmap_bytes, outfile);

    qemu_plugin_register_vcpu_tb_trans_cb(id, tb_trans);
    qemu_plugin_register_atexit_cb(id, plugin_atexit, NULL);
    return 0;
}
