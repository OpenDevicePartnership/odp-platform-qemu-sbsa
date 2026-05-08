// Minimal QEMU plugin API header (Plugin API v4) used by the coverage plugin.
//
// SPDX-License-Identifier: MIT
//
// Contains only the declarations needed by the coverage plugin.
// Avoids the glib dependency of the full qemu-plugin.h.
//
// This header provides a minimal set of declarations for interacting
// with the QEMU plugin interface, based on the publicly documented
// plugin API. No original QEMU source code is included.

#ifndef QEMU_PLUGIN_H
#define QEMU_PLUGIN_H

#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>

#define QEMU_PLUGIN_EXPORT __attribute__((visibility("default")))
#define QEMU_PLUGIN_API

typedef uint64_t qemu_plugin_id_t;

extern QEMU_PLUGIN_EXPORT int qemu_plugin_version;

#define QEMU_PLUGIN_VERSION 4

typedef struct
{
    const char *target_name;
    struct
    {
        int min;
        int cur;
    } version;
    bool system_emulation;
    union
    {
        struct
        {
            int smp_vcpus;
            int max_vcpus;
        } system;
    };
} qemu_info_t;

struct qemu_plugin_tb;
struct qemu_plugin_insn;

typedef void (*qemu_plugin_simple_cb_t)(qemu_plugin_id_t id);
typedef void (*qemu_plugin_udata_cb_t)(qemu_plugin_id_t id, void *userdata);
typedef void (*qemu_plugin_vcpu_udata_cb_t)(unsigned int vcpu_index,
                                            void *userdata);
typedef void (*qemu_plugin_vcpu_tb_trans_cb_t)(qemu_plugin_id_t id,
                                               struct qemu_plugin_tb *tb);

enum qemu_plugin_cb_flags
{
    QEMU_PLUGIN_CB_NO_REGS,
    QEMU_PLUGIN_CB_R_REGS,
    QEMU_PLUGIN_CB_RW_REGS,
};

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id,
                                           const qemu_info_t *info,
                                           int argc, char **argv);

QEMU_PLUGIN_API
void qemu_plugin_register_vcpu_tb_trans_cb(qemu_plugin_id_t id,
                                           qemu_plugin_vcpu_tb_trans_cb_t cb);

QEMU_PLUGIN_API
void qemu_plugin_register_vcpu_insn_exec_cb(struct qemu_plugin_insn *insn,
                                            qemu_plugin_vcpu_udata_cb_t cb,
                                            enum qemu_plugin_cb_flags flags,
                                            void *userdata);

QEMU_PLUGIN_API
uint64_t qemu_plugin_tb_vaddr(const struct qemu_plugin_tb *tb);

QEMU_PLUGIN_API
size_t qemu_plugin_tb_n_insns(const struct qemu_plugin_tb *tb);

QEMU_PLUGIN_API
struct qemu_plugin_insn *qemu_plugin_tb_get_insn(const struct qemu_plugin_tb *tb,
                                                 size_t idx);

QEMU_PLUGIN_API
uint64_t qemu_plugin_insn_vaddr(const struct qemu_plugin_insn *insn);

QEMU_PLUGIN_API
void qemu_plugin_register_atexit_cb(qemu_plugin_id_t id,
                                    qemu_plugin_udata_cb_t cb,
                                    void *userdata);

QEMU_PLUGIN_API
void qemu_plugin_outs(const char *string);

#endif /* QEMU_PLUGIN_H */
