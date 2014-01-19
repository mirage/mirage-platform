/*
 * Copyright (c) 2010-2011 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2006 Steven Smith <sos22@cam.ac.uk>
 * Copyright (c) 2006 Grzegorz Milos <gm281@cam.ac.uk>
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
#include <mini-os/mm.h>
#include <mini-os/gnttab.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/bigarray.h>
#include <caml/alloc.h>
#include <caml/fail.h>

/* For printk() */
#include <log.h>

static grant_entry_t *the_grant_table = NULL;

static void map_grant_table(void)
{
	struct gnttab_setup_table setup;
	unsigned long frames[NR_GRANT_FRAMES];

	setup.dom = DOMID_SELF;
	setup.nr_frames = NR_GRANT_FRAMES;
	set_xen_guest_handle(setup.frame_list, frames);

	HYPERVISOR_grant_table_op(GNTTABOP_setup_table, &setup, 1);
	the_grant_table = map_frames(frames, NR_GRANT_FRAMES);
	printk("gnttab_table mapped at %p\n", the_grant_table);
}

static void unmap_grant_table(void)
{
    struct gnttab_setup_table setup;

    if (the_grant_table == NULL) return;

    setup.dom = DOMID_SELF;
    setup.nr_frames = 0;

    HYPERVISOR_grant_table_op(GNTTABOP_setup_table, &setup, 1);

    unmap_frames((unsigned long)the_grant_table, NR_GRANT_FRAMES);
    the_grant_table = NULL;
}

/* Map the grant table on first use. This avoids relying on a side-effect
   of a top-level binding which can be re-ordered. */
static grant_entry_t *get_grant_table(void)
{
	if (the_grant_table == NULL)
		map_grant_table();
	return the_grant_table;
}

CAMLprim value stub_gnttab_interface_open(value unit)
{
	CAMLparam1(unit);
	CAMLlocal1(result);
	result = Val_unit;
	CAMLreturn(result);
}

CAMLprim value stub_gnttab_interface_close(value unit)
{
	CAMLparam1(unit);
	CAMLlocal1(result);
	result = Val_unit;
	CAMLreturn(result);
}

CAMLprim value stub_gnttab_allocates(void)
{
	CAMLparam0();
	CAMLreturn(Val_bool(0));
}

CAMLprim value
stub_gnttab_unmap(value i, value v_handle)
{
  CAMLparam2(i, v_handle);
  struct gnttab_unmap_grant_ref op;
  /* There's no need to resupply these values. 0 means "ignore" */
  op.host_addr = 0;
  op.dev_bus_addr = 0;
  op.handle = Int_val(v_handle);

  HYPERVISOR_grant_table_op(GNTTABOP_unmap_grant_ref, &op, 1);

  if (op.status != GNTST_okay) {
    printk("GNTTABOP_unmap_grant_ref handle = %x failed", op.handle);
    caml_failwith("Failed to unmap grant.");
  }

  CAMLreturn(Val_unit);
}

static void *
base_page_of(value v_iopage)
{
    /* The grant API takes page-alignted addresses. */
    struct caml_ba_array *a = (struct caml_ba_array *)Caml_ba_array_val(v_iopage);
    unsigned long page_aligned_view = (unsigned long)a->data & ~(PAGE_SIZE - 1);
    return (void*) page_aligned_view;
}

CAMLprim value
stub_gnttab_map_onto(value i, value v_ref, value v_iopage, value v_domid, value v_writable)
{
    CAMLparam5(i, v_ref, v_iopage, v_domid, v_writable);
    void *page = base_page_of(v_iopage);

    struct gnttab_map_grant_ref op;
    op.ref = Int_val(v_ref);
    op.dom = Int_val(v_domid);
    op.host_addr = (unsigned long) page;
    op.flags = GNTMAP_host_map;
    if (!Bool_val(v_writable)) op.flags |= GNTMAP_readonly;

    HYPERVISOR_grant_table_op(GNTTABOP_map_grant_ref, &op, 1);
    if (op.status != GNTST_okay) {
      printk("GNTTABOP_map_grant_ref ref = %d domid = %d failed with status = %d\n", op.ref, op.dom, op.status);
      caml_failwith("caml_gnttab_map");
    }

    printk("GNTTABOP_map_grant_ref mapped to %x\n", op.host_addr);
    CAMLreturn(Val_int(op.handle));
}

CAMLprim value stub_gnttab_map_fresh(value i, value r, value d, value w)
{
    CAMLparam4(i, r, d, w);
    /* The OCaml code will never call this because gnttab_allocates is false */
    printk("FATAL ERROR: stub_gnttab_map_fresh called\n");
    caml_failwith("stub_gnttab_map_fresh");
}

CAMLprim value stub_gnttab_mapv_batched(value xgh, value array, value writable)
{
    CAMLparam3(xgh, array, writable);
    /* The OCaml code will never call this because gnttab_allocates is false */
    printk("FATAL ERROR: stub_gnttab_mapv_batched called\n");
    caml_failwith("stub_gnttab_mapv_batched");
}


/* Disable grant tables */
CAMLprim value
stub_gnttab_fini(value unit)
{
    unmap_grant_table();
    return Val_unit;
}

CAMLprim value
stub_gnttab_init(value unit)
{
    return Val_unit;
}

/* Return the number of reserved grant entries at the start */
CAMLprim value
stub_gnttab_reserved(value unit)
{
    return Val_int(NR_RESERVED_ENTRIES);
}

CAMLprim value
stub_gnttab_nr_entries(value unit)
{
    return Val_int(NR_GRANT_ENTRIES);
}

/* Exporting (sharing) pages */

CAMLprim value stub_gntshr_open(value unit)
{
	CAMLparam1(unit);
	CAMLlocal1(result);
	result = Val_unit;
	CAMLreturn(result);
}

CAMLprim value stub_gntshr_close(value unit)
{
	CAMLparam1(unit);
	CAMLlocal1(result);
	result = Val_unit;
	CAMLreturn(result);
}

static void
gnttab_grant_transfer(grant_ref_t ref, void *page, int domid)
{
    grant_entry_t *gnttab_table = get_grant_table ();
    gnttab_table[ref].frame = virt_to_mfn(page);
    gnttab_table[ref].domid = domid;
    wmb();
    gnttab_table[ref].flags = GTF_accept_transfer;
}

/* From the reference implementation
   http://git.kernel.org/?p=linux/kernel/git/torvalds/linux.git;a=blob;f=drivers/xen/grant-table.c;hb=HEAD */
static unsigned long
gnttab_end_transfer(grant_ref_t ref)
{
    unsigned long frame;
    uint16_t flags;
    grant_entry_t *gnttab_table = get_grant_table ();
    uint16_t *pflags = &gnttab_table[ref].flags;

    /*
     * If a transfer is not even yet started, try to reclaim the grant
     * reference and return failure (== 0).
     */
    while (!((flags = *pflags) & GTF_transfer_committed)) {
      if (synch_cmpxchg(pflags, flags, 0) == flags)
        return 0;
    }

    /* If a transfer is in progress then wait until it is completed. */
    while (!(flags & GTF_transfer_completed)) {
      flags = *pflags;
    }

    rmb();  /* Read the frame number /after/ reading completion status. */
    frame = gnttab_table[ref].frame;
    BUG_ON(frame == 0);

    return frame;
}

static void
gntshr_grant_access(grant_ref_t ref, void *page, int domid, int ro)
{
    grant_entry_t *gnttab_table = get_grant_table();
    gnttab_table[ref].frame = virt_to_mfn(page);
    gnttab_table[ref].domid = domid;
    wmb();
    gnttab_table[ref].flags = GTF_permit_access | (ro * GTF_readonly);
}

static void
gntshr_grant_transfer(grant_ref_t ref, void *page, int domid)
{
    grant_entry_t *gnttab_table = get_grant_table();
    gnttab_table[ref].frame = virt_to_mfn(page);
    gnttab_table[ref].domid = domid;
    wmb();
    gnttab_table[ref].flags = GTF_accept_transfer;
}

/* From the reference implementation
   http://git.kernel.org/?p=linux/kernel/git/torvalds/linux.git;a=blob;f=drivers/xen/grant-table.c;hb=HEAD */
static unsigned long
gntshr_end_transfer(grant_ref_t ref)
{
    unsigned long frame;
    uint16_t flags;
    grant_entry_t *gnttab_table = get_grant_table();
    uint16_t *pflags = &gnttab_table[ref].flags;

    /*
     * If a transfer is not even yet started, try to reclaim the grant
     * reference and return failure (== 0).
     */
    while (!((flags = *pflags) & GTF_transfer_committed)) {
      if (synch_cmpxchg(pflags, flags, 0) == flags)
        return 0;
    }

    /* If a transfer is in progress then wait until it is completed. */
    while (!(flags & GTF_transfer_completed)) {
      flags = *pflags;
    }

    rmb();  /* Read the frame number /after/ reading completion status. */
    frame = gnttab_table[ref].frame;
    BUG_ON(frame == 0);

    return frame;
}

CAMLprim value
stub_gntshr_grant_access(value v_ref, value v_iopage, value v_domid, value v_writable)
{
    grant_ref_t ref = Int_val(v_ref);
    void *page = base_page_of(v_iopage);
    gntshr_grant_access(ref, page, Int_val(v_domid), !Bool_val(v_writable));
    return Val_unit;
}

CAMLprim value
stub_gntshr_end_access(value v_ref)
{
    grant_ref_t ref = Int_val(v_ref);
    uint16_t flags, nflags;

    grant_entry_t *gnttab_table = get_grant_table();

    BUG_ON(ref >= NR_GRANT_ENTRIES || ref < NR_RESERVED_ENTRIES);

    nflags = gnttab_table[ref].flags;
    do {
        if ((flags = nflags) & (GTF_reading|GTF_writing)) {
            printk("WARNING: g.e. %d still in use! (%x)\n", ref, flags);
            return Val_unit;
        }
    } while ((nflags = synch_cmpxchg(&gnttab_table[ref].flags, flags, 0)) !=
            flags);

    return Val_unit;
}

CAMLprim value stub_gntshr_share_pages_batched(value xgh, value domid, value count, value writable) {
    CAMLparam4(xgh, domid, count, writable);
    /* The OCaml code will never call this because gnttab_allocates is false */
    printk("FATAL ERROR: stub_gntshr_share_pages_batched called\n");
    caml_failwith("stub_gntshr_share_pages_batched");
}

CAMLprim value stub_gntshr_munmap_batched(value xgh, value share) {
    CAMLparam2(xgh, share);
    /* The OCaml code will never call this because gnttab_allocates is false */
    printk("FATAL ERROR: stub_gntshr_munmap_batched called\n");
    caml_failwith("stub_gntshr_munmap_batched");
}
