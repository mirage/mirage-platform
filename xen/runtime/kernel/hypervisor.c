/******************************************************************************
 * hypervisor.c
 * 
 * Communication to/from hypervisor.
 * 
 * Copyright (c) 2002-2003, K A Fraser
 * Copyright (c) 2005, Grzegorz Milos, gm281@cam.ac.uk,Intel Research Cambridge
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
 * DEALINGS IN THE SOFTWARE.
 */

#include <mini-os/x86/os.h>
#include <mini-os/lib.h>
#include <mini-os/hypervisor.h>
#include <mini-os/events.h>

void do_hypervisor_callback(struct pt_regs *regs)
{
  int            cpu = 0;
  shared_info_t *s = HYPERVISOR_shared_info;
  vcpu_info_t   *vcpu_info = &s->vcpu_info[cpu];

  /* We don't do any work in the callback itself, instead we rely on the
     vcpu blocking in SCHEDOP_block being woken, and calling evtchn_poll.
     However we do need to clear the evtchn_upcall_pending flag to acknowlege
     this interrupt (otherwise it'll happen again immediately) */
  vcpu_info->evtchn_upcall_pending = 0;
}

void force_evtchn_callback(void)
{
    int save;
    vcpu_info_t *vcpu;
    vcpu = &HYPERVISOR_shared_info->vcpu_info[smp_processor_id()];
    save = vcpu->evtchn_upcall_mask;

    while (vcpu->evtchn_upcall_pending) {
        vcpu->evtchn_upcall_mask = 1;
        barrier();
        do_hypervisor_callback(NULL);
        barrier();
        vcpu->evtchn_upcall_mask = save;
        barrier();
    };
}


inline void mask_evtchn(uint32_t port)
{
    shared_info_t *s = HYPERVISOR_shared_info;
    synch_set_bit(port, &s->evtchn_mask[0]);
}

inline void unmask_evtchn(uint32_t port)
{
    shared_info_t *s = HYPERVISOR_shared_info;
    vcpu_info_t *vcpu_info = &s->vcpu_info[smp_processor_id()];

    synch_clear_bit(port, &s->evtchn_mask[0]);
}

inline void clear_evtchn(uint32_t port)
{
    shared_info_t *s = HYPERVISOR_shared_info;
    synch_clear_bit(port, &s->evtchn_pending[0]);
}
