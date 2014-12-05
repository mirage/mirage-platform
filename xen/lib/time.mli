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

type +'a io = 'a Lwt.t

(** Timeout operations. *)

module Monotonic : sig
  (** Monotonic time is time since boot (dom0 or domU, depending on platform).
   * Unlike Clock.time, it does not go backwards when the system clock is
   * adjusted. *)

  type time_kind = [`Time | `Interval]
  type 'a t constraint 'a = [< time_kind]

  val time : unit -> [`Time] t
  (** Read the current monotonic time. *)

  val ( + ) : 'a t -> [`Interval] t -> 'a t
  val ( - ) : 'a t -> [`Interval] t -> 'a t
  val interval : [`Time] t -> [`Time] t -> [`Interval] t

  (** Conversions. Note: these floats are still seconds since boot. *)

  val of_seconds : float -> _ t
  val to_seconds : _ t -> float
end

val restart_threads: (unit -> [`Time] Monotonic.t) -> unit
(** [restart_threads time_fun] restarts threads that are sleeping and
    whose wakeup time is before [time_fun ()]. *)

val select_next : unit -> [`Time] Monotonic.t option
(** [select_next ()] is [Some t] where [t] is the earliest time
    when one sleeping thread will wake up, or [None] if there is no
    sleeping threads. *)

val sleep : float -> unit Lwt.t
(** [sleep d] is a threads which remain suspended for [d] seconds and
    then terminates. *)

exception Timeout
(** Exception raised by timeout operations *)

val with_timeout : float -> (unit -> 'a Lwt.t) -> 'a Lwt.t
(** [with_timeout d f] is a short-hand for:

    {[
    Lwt.pick [Lwt_unix.timeout d; f ()]
    ]}
*)
