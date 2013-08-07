(*
 * Copyright (C) 2006-2012 Citrix Systems Inc.
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
 *)

(** Client interface to the XenStore. *)

type client
(** Handle to the XenStore. *)

type handle
(** Handle to a XenStore connection; may be "immediate", "transaction"
    or "wait". *)

val make : unit -> client Lwt.t

val immediate: client -> (handle -> 'a Lwt.t) -> 'a Lwt.t
(** Access xenstore with individual operations. *)

val transaction: client -> (handle -> 'a Lwt.t) -> 'a Lwt.t
(** Access xenstore with a single transaction.  On conflict the
    operation will be repeated. *)

val wait: client -> (handle -> 'a Lwt.t) -> 'a Lwt.t
(** Wait for some condition to become true and return a value.  The
    function argument should throw Eagain if the condition is not
    met, and the condition will be re-evaluated when paths
    change. *)

val directory : handle -> string -> string list Lwt.t
(** [directory h path] returns the directory listing of [path]. *)

val read : handle -> string -> string Lwt.t
(** [read h path] returns the value at [path] or raises [Enoent]. *)

val write : handle -> string -> string -> unit Lwt.t
(** [write h k v] writes [v] at [k]. *)

val rm : handle -> string -> unit Lwt.t
(** [rm h k] removes [k]. *)

val mkdir: handle -> string -> unit Lwt.t

val suspend : client -> unit Lwt.t
(** [suspend ()] suspends the xenstore client, waiting for outstanding
    RPCs to be completed, cancelling all watches and causing new
    requests to be queued. This function is called by {!Sched.suspend}
    in order to suspend an unikernel. Do not use it unless you know
    what you are doing. *)

val resume : client -> unit Lwt.t
(** [resume ()] resumes the xenstore client. This function is called
    by {!Sched.resume} in order to resume an unikernel. Do not use it
    unless you know what you are doing. *)

(** XenStore transport over Mirage that can be used to instanciate a
    Xs_client_lwt functor. *)
module IO : sig
  type 'a t = 'a Lwt.t
  val return: 'a -> 'a t
  val ( >>= ): 'a t -> ('a -> 'b t) -> 'b t

  type channel
  val create: unit -> channel t
  val destroy: channel -> unit t
  val read: channel -> string -> int -> int -> int t
  val write: channel -> string -> int -> int -> unit t
end
