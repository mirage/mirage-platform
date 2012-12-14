(*
 * Copyright (C) 2006-2009 Citrix Systems Inc.
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

open Lwt

type channel = {
	mutable page: Ring.Xenstore.t;
	mutable evtchn: Evtchn.t;
}
(* An inter-domain client is always via a shared memory page
   and an event channel. *)
		
let t = ref None
(* Unfortunately there is only one connection and it cannot
   be closed or reopened. *)

let open_channel () =
	let _, page = Ring.Xenstore.alloc_initial () in
	let evtchn = Evtchn.xenstore_port () in
	return { page; evtchn }

module Client = Xs_client.Client(struct
	type t = channel
				
	exception Already_connected

	exception Cannot_destroy

	let create () =
		match !t with
		| Some _ ->
			Console.log "ERROR: Already connected to xenstore: cannot reconnect";
			fail Already_connected
		| None ->
			lwt ch = open_channel () in
			t := Some ch;
			return ch

	let destroy t =
		Console.log "ERROR: It's not possible to destroy the default xenstore connection";
		fail Cannot_destroy

	(* XXX: unify with ocaml-xenstore-xen/xen/lib/xs_transport_domain *)
	let rec read t buf ofs len =
		let tmp = String.create len in
		let n = Ring.Xenstore.unsafe_read t.page tmp len in
		if n = 0 then begin
			lwt () = Activations.wait t.evtchn in
			read t buf ofs len
		end else begin
			Evtchn.notify t.evtchn;
		    String.blit tmp 0 buf ofs n;
			return n
		end

	(* XXX: unify with ocaml-xenstore-xen/xen/lib/xs_transport_domain *)
	let rec write t buf ofs len =
		let tmp = String.create len in
		(* XXX: change low-level signature to avoid unnecessary copy *)
		String.blit buf ofs tmp 0 len;
		let n = Ring.Xenstore.unsafe_write t.page tmp len in
		if n > 0 then Evtchn.notify t.evtchn;
		if n < len then begin
			lwt () = Activations.wait t.evtchn in
			write t buf (ofs + n) (len - n)
		end else return ()
end)

include Client

let client = make ()

let immediate f =
	lwt client = client in
	with_xs client f

let transaction f =
	lwt client = client in
	with_xst client f

let wait f =
	lwt client = client in
	wait client f

let suspend () =
	lwt client = client in
	suspend client

let resume () =
	lwt ch = open_channel () in
	begin match !t with 
		| Some ch' ->
			ch'.page <- ch.page;
			ch'.evtchn <- ch.evtchn;
		| None -> 
			();
	end;
	lwt client = client in
	resume client
