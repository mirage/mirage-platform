/*
 * Copyright (c) 2011 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <mini-os/x86/os.h>
#include <mini-os/sched.h>

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/callback.h>

void _exit(int);
int errno;
static char *argv[] = { "mirage", NULL };
static unsigned long irqflags;

CAMLprim value
caml_block_domain(value v_timeout)
{
  CAMLparam1(v_timeout);
  s_time_t block_nsecs = (s_time_t)(Double_val(v_timeout) * 1000000000);
  HYPERVISOR_set_timer_op(NOW() + block_nsecs);
  /* xen/common/schedule.c:do_block clears evtchn_upcall_mask
     to re-enable interrupts. It blocks the domain and immediately
     checks for pending events which otherwise may be missed. */
  HYPERVISOR_sched_op(SCHEDOP_block, 0);
  /* set evtchn_upcall_mask: there's no need to be interrupted
     when we know we have outstanding work to do. When we next
     call this function, the call to SCHEDOP_block will check
     for pending events. */
  local_irq_disable();
  CAMLreturn(Val_unit);
}

#define CAML_ENTRYPOINT "OS.Main.run"

void app_main(start_info_t *si)
{
  value *v_main;
  int caml_completed = 0;
  local_irq_save(irqflags);
  caml_startup(argv);
  v_main = caml_named_value(CAML_ENTRYPOINT);
  if (v_main == NULL){
	printk("ERROR: CAML_ENTRYPOINT %s is NULL\n", CAML_ENTRYPOINT);
	_exit(1);
  }
  while (caml_completed == 0) {
    caml_completed = Bool_val(caml_callback(*v_main, Val_unit));
  }
  _exit(0);
}

void _exit(int ret)
{
  printk("main returned %d\n", ret);
  stop_kernel();
  if (!ret) {
    /* No problem, just shutdown.  */
    struct sched_shutdown sched_shutdown = { .reason = SHUTDOWN_poweroff };
    HYPERVISOR_sched_op(SCHEDOP_shutdown, &sched_shutdown);
  }
  do_exit();
}
