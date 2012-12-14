/******************************************************************************
 * common.c
 * 
 * Common stuff special to x86 goes here.
 * 
 * Copyright (c) 2002-2003, K A Fraser & R Neugebauer
 * Copyright (c) 2005, Grzegorz Milos, Intel Research Cambridge
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
 *
 */

#include <mini-os/x86/os.h>
#include <mini-os/lib.h> /* for printk, memcpy */
#include <log.h>

/*
 * Shared page for communicating with the hypervisor.
 * Events flags go here, for example.
 */
shared_info_t *HYPERVISOR_shared_info;

/*
 * This structure contains start-of-day info, such as pagetable base pointer,
 * address of the shared_info structure, and things like that.
 */
start_info_t *xen_info;

/*
 * Just allocate the kernel stack here. SS:ESP is set up to point here
 * in head.S.
 */
char stack[2*STACK_SIZE];

extern char shared_info[PAGE_SIZE];

/* Assembler interface fns in entry.S. */
void hypervisor_callback(void);
void failsafe_callback(void);

#define __pte(x) ((pte_t) { (x) } )


shared_info_t *map_shared_info(unsigned long pa)
{
    int rc;

    if ( (rc = HYPERVISOR_update_va_mapping(
              (unsigned long)shared_info, __pte(pa | 7), UVMF_INVLPG)) )
    {
        printk("Failed to map shared_info!! rc=%d\n", rc);
        do_exit();
    }
    return (shared_info_t *)shared_info;
}

void unmap_shared_info()
{
  HYPERVISOR_update_va_mapping((uintptr_t)HYPERVISOR_shared_info,
			       __pte((virt_to_mfn(shared_info)<<L1_PAGETABLE_SHIFT) | L1_PROT), UVMF_INVLPG);
}


void
arch_init(start_info_t *si)
{
    /* Set up our start_info pointer */
    xen_info = si;

    /* set up minimal memory infos */
    phys_to_machine_mapping = (unsigned long *)start_info.mfn_list;

    /* Grab the shared_info pointer and put it in a safe place. */
    HYPERVISOR_shared_info = map_shared_info(start_info.shared_info);

    /* Set up event and failsafe callback addresses. */
    HYPERVISOR_set_callbacks(
        (unsigned long)hypervisor_callback,
        (unsigned long)failsafe_callback, 0);
}

void
arch_fini(void)
{
    HYPERVISOR_set_callbacks(0, 0, 0);
}

void
arch_print_info(void)
{
    printk("  stack:      %p-%p\n", stack, stack + sizeof(stack));
}


