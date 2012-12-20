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

type t = int Generation.t 

external stub_xenstore_port: unit -> int = "stub_xenstore_evtchn_port"
external stub_console_port: unit -> int = "stub_console_evtchn_port"
external stub_alloc_unbound_port: int -> int = "stub_evtchn_alloc_unbound"
external stub_bind_interdomain: int -> int -> int = "stub_evtchn_bind_interdomain"
external stub_unmask: int -> unit = "stub_evtchn_unmask" 
external stub_notify: int -> unit = "stub_evtchn_notify" "noalloc"
external stub_unbind: int -> unit = "stub_evtchn_unbind"
external stub_virq_dom_exc: unit -> int = "stub_virq_dom_exc"
external stub_bind_virq: int -> int = "stub_bind_virq"

let construct f x = Generation.wrap (f x)
let xenstore_port = construct stub_xenstore_port
let console_port = construct stub_console_port
let alloc_unbound_port = construct stub_alloc_unbound_port
let bind_interdomain remote_domid = construct (stub_bind_interdomain remote_domid)

let maybe t f d = Generation.maybe t f d
let unmask t = maybe t stub_unmask ()
let notify t = maybe t stub_notify ()
let unbind t = maybe t stub_unbind ()
let is_valid t = maybe t (fun _ -> true) false

let port t = Generation.extract t

module Virq = struct
	type vt = Dom_exc

	let bind = function
		| Dom_exc -> 
			let port = stub_bind_virq (stub_virq_dom_exc ()) in
			construct (fun () -> port) ()
end
