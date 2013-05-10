(*
 * Copyright (c) 2011-2012 Anil Madhavapeddy <anil@recoil.org>
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
 *)

(** Memory allocation. *)

(** Type of memory blocks. *)
type t = (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

(** [get ~ppb ()] allocates a memory block of size [ppb] pages. If
    there is not enough memory, the unikernel will terminate. *)
val get : ?pages_per_block:int -> unit -> t

(** [get_n ~ppb nb_blocks] allocates a list of [nb_blocks], each block
    being of size [ppb] pages. *)
val get_n : ?pages_per_block:int -> int -> t list

(** [get_order i] allocates a memory block of size [2**i] pages. *)
val get_order : int -> t

(** [length t] is the size of [t], in bytes. *)
val length : t -> int

val to_cstruct : t -> Cstruct.t
val to_string : t -> string

(** [to_pages t] is a list of [size] memory blocks of one page each,
    where [size] is the size of [t] in pages. *)
val to_pages : t -> t list

(** [string_blit src srcoff dst dstoff len] copies [len] bytes from
    string [src], starting at byte number [srcoff], to memory block
    [dst], starting at byte number dstoff. *)
val string_blit : string -> int -> t -> int -> int -> unit

(** [blit t1 t2] is the same as {!Bigarray.Array1.blit}. *)
val blit : t -> t -> unit
