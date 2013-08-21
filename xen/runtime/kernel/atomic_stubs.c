/*
 * Copyright (c) 2013 Citrix Systems Inc
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

#include <stdint.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

CAMLprim value stub_atomic_or_fetch_uint8(value buf, value idx, value val)
{
  CAMLparam3(buf, idx, val);
  // Finding the address of buf+idx
  uint8_t c_val = (uint8_t)Int_val(val);
  uint8_t *ptr = Caml_ba_data_val(buf) + Int_val(idx);

  if (Int_val(idx) >= Caml_ba_array_val(buf)->dim[0])
    caml_invalid_argument("idx");

  CAMLreturn(Val_int((uint8_t)__sync_or_and_fetch(ptr, c_val)));
}

CAMLprim value stub_atomic_fetch_and_uint8(value buf, value idx, value val)
{
  CAMLparam3(buf, idx, val);
  uint8_t c_val = (uint8_t)Int_val(val);
  uint8_t *ptr = Caml_ba_data_val(buf) + Int_val(idx);

  if (Int_val(idx) >= Caml_ba_array_val(buf)->dim[0])
    caml_invalid_argument("idx");

  CAMLreturn(Val_int((uint8_t)__sync_fetch_and_and(ptr, c_val)));
}
