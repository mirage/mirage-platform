/*
 * Copyright (C) 2006-2009,2013-2014 Citrix Systems Inc.
 * Copyright (C) 2010 Anil Madhavapeddy <anil@recoil.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 */

#include <mini-os/os.h>
#include <mini-os/time.h>
#include <mini-os/events.h>

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/bigarray.h>
#include <caml/fail.h>

#define NR_EVENTS 4096 /* max for x86_64 using old ABI */
static uint8_t ev_callback_ml[NR_EVENTS];

#define active_evtchns(cpu,sh,idx)              \
    ((sh)->evtchn_pending[idx] &                \
     ~(sh)->evtchn_mask[idx])

/* Override the default Mini-OS implementation. We don't want to call the event
   handlers here (from within the interrupt handler). Instead, we'll call
   evtchn_look_for_work later. */
void do_hypervisor_callback(struct pt_regs *regs)
{
    int            cpu = 0;
    shared_info_t *s = HYPERVISOR_shared_info;
    vcpu_info_t   *vcpu_info = &s->vcpu_info[cpu];

    vcpu_info->evtchn_upcall_pending = 0;
}

/* Walk through the ports, setting the OCaml callback
   mask for any active ones, and clear the Xen side.
   Return true if any OCaml callbacks are needed. */
int
evtchn_look_for_work(void)
{
  unsigned long  l1, l2, l1i, l2i;
  unsigned int   port;
  int            cpu = 0;
  int            work_to_do = 0;
  shared_info_t *s = HYPERVISOR_shared_info;
  vcpu_info_t   *vcpu_info = &s->vcpu_info[cpu];

  vcpu_info->evtchn_upcall_pending = 0;
  /* NB x86. No need for a barrier here -- XCHG is a barrier on x86. */
#if !defined(__i386__) && !defined(__x86_64__)
    wmb();
#endif
  l1 = xchg(&vcpu_info->evtchn_pending_sel, 0);
  while ( l1 != 0 ) {
    l1i = __ffs(l1);
    l1 &= ~(1UL << l1i);

    while ( (l2 = active_evtchns(cpu, s, l1i)) != 0 ) {
      l2i = __ffs(l2);
      l2 &= ~(1UL << l2i);

      port = (l1i * (sizeof(unsigned long) * 8)) + l2i;
      clear_evtchn(port);
      ev_callback_ml[port] = 1;
      work_to_do = 1;
    }
  }
  return work_to_do;
}

CAMLprim value
stub_evtchn_look_for_work(value v_unit)
{
    CAMLparam1(v_unit);
    CAMLlocal1(work_to_do);
    work_to_do = Val_bool(evtchn_look_for_work());
    CAMLreturn(work_to_do);
}

CAMLprim value
stub_evtchn_init(value v_unit)
{
    CAMLparam1(v_unit);
    CAMLreturn(Val_unit);
}

CAMLprim value
stub_evtchn_close(value v_unit)
{
    CAMLparam1(v_unit);
    CAMLreturn(Val_unit);
}

CAMLprim value
stub_nr_events(value v_unit)
{
   return Val_int(NR_EVENTS);
}

CAMLprim value
stub_evtchn_test_and_clear(value v_idx)
{
   int idx = Int_val(v_idx) % NR_EVENTS;
   if (ev_callback_ml[idx] > 0) {
      ev_callback_ml[idx] = 0;
      return Val_int(1);
   } else
      return Val_int(0);
}

CAMLprim value
stub_evtchn_alloc_unbound(value v_unit, value v_domid)
{
    CAMLparam2(v_unit, v_domid);
    domid_t domid = Int_val(v_domid);
    int rc;
    evtchn_port_t port;

    rc = evtchn_alloc_unbound(domid, NULL, NULL, &port);
    if (rc)
       caml_failwith("evtchn_alloc_unbound");
    else
       CAMLreturn(Val_int(port)); 
}

CAMLprim value
stub_evtchn_bind_interdomain(value v_unit, value v_domid, value v_remote_port)
{
    CAMLparam3(v_unit, v_domid, v_remote_port);
    domid_t domid = Int_val(v_domid);
    evtchn_port_t remote_port = Int_val(v_remote_port);
    evtchn_port_t local_port;
    int rc;

    rc = evtchn_bind_interdomain(domid, remote_port, NULL, NULL, &local_port);
    if (rc)
       caml_failwith("evtchn_bind_interdomain");
    else
       CAMLreturn(Val_int(local_port)); 
}

CAMLprim value
stub_evtchn_unmask(value v_unit, value v_port)
{
    CAMLparam2(v_unit, v_port);
    unmask_evtchn(Int_val(v_port));
    CAMLreturn(Val_unit);
}

CAMLprim value
stub_evtchn_notify(value v_unit, value v_port)
{
        CAMLparam2(v_unit, v_port);
        notify_remote_via_evtchn(Int_val(v_port));
        CAMLreturn(Val_unit);
}

CAMLprim value
stub_evtchn_bind_virq(value v_unit, value virq)
{
	CAMLparam2(v_unit, virq);
	evtchn_port_t port;
	port = bind_virq(Int_val(virq), NULL, NULL);
    	CAMLreturn(Val_int(port)); 
}

CAMLprim value
stub_evtchn_virq_dom_exc(value unit)
{
	CAMLparam1(unit);
	CAMLreturn(Val_int(VIRQ_DOM_EXC));
}

CAMLprim value
stub_evtchn_unbind(value v_unit, value v_port)
{
	CAMLparam2(v_unit, v_port);
	unbind_evtchn(Int_val(v_port));
	CAMLreturn(Val_unit);
}
