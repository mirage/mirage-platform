(*
 * Copyright (c) 2010 Anil Madhavapeddy <anil@recoil.org>
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

(** Text console input/output operations. *)

(** Abstract type of a console instance. *)
type t

(** The default console, attached from the start of the program. *)
val t : t

(** [create ()] creates an additional console. Not implemented yet. *)
val create : unit -> t

(** [write t buf off len] writes up to [len] chars of [String.sub buf
    off len] to the console [t] and returns the number of bytes
    written. Raises {!Invalid_argument} if [len > buf - off]. *)
val write : t -> string -> int -> int -> int

(** [log str] writes as much characters of [str] that can be written
    in one write operation to the default console [t], then writes
    "\r\n" to it. Note that it might not write all of string into the
    console! *)
val log : string -> unit

(** [log_s str] is a thread that writes [str ^ "\r\n"] in the default
    console [t]. *)
val log_s : string -> unit Lwt.t
