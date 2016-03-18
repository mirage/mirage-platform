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

(* Mirage transport for XenStore. *)
module IO = struct
    type 'a t = 'a Lwt.t
    type channel = {
      mutable page: Cstruct.t;
      mutable evtchn: Eventchn.t;
    }
    let return = Lwt.return
    let (>>=) = Lwt.bind
    exception Already_connected
    exception Cannot_destroy

    let h = Eventchn.init ()

    type backend = [ `unix | `xen ]
    let backend = `xen

    let singleton_client = ref None

    let create () =
      match !singleton_client with 
      | Some x -> Lwt.return x 
      | None -> 
        let page = Io_page.to_cstruct Start_info.(xenstore_start_page ()) in
        Xenstore_ring.Ring.init page;
        let evtchn = Eventchn.of_int Start_info.((get ()).store_evtchn) in
        Eventchn.unmask h evtchn;
        let c = { page; evtchn } in
        singleton_client := Some c;
        Lwt.return c

    let refresh () =
      match !singleton_client with
      | Some x -> 
        x.page <- Io_page.to_cstruct Start_info.(xenstore_start_page ());
        Xenstore_ring.Ring.init x.page;
        x.evtchn <- Eventchn.of_int Start_info.((get ()).store_evtchn);
        Eventchn.unmask h x.evtchn
      | None -> ()

    let destroy t =
      Printf.printf "ERROR: It's not possible to destroy the default xenstore connection\n%!";
      fail Cannot_destroy

    (* XXX: unify with ocaml-xenstore-xen/xen/lib/xs_transport_domain *)
    let read t buf ofs len =
      let rec loop event =
        let n = Xenstore_ring.Ring.Front.unsafe_read t.page buf ofs len in
        if n = 0 then begin
          Activations.after t.evtchn event
          >>= fun event ->
          MProf.Trace.label "Xs.read waiting";
          loop event
        end else begin
          Eventchn.notify h t.evtchn;
          return n
        end in
      loop Activations.program_start

    (* XXX: unify with ocaml-xenstore-xen/xen/lib/xs_transport_domain *)
    let write t buf ofs len =
      let rec loop event buf ofs len =
        let n = Xenstore_ring.Ring.Front.unsafe_write t.page buf ofs len in
        if n > 0 then Eventchn.notify h t.evtchn;
        if n < len then begin
          Activations.after t.evtchn event
          >>= fun event ->
          MProf.Trace.label "Xs.write waiting";
          loop event buf (ofs + n) (len - n)
        end else return () in
      loop Activations.program_start buf ofs len
end

include Xs_client_lwt.Client(IO)

let resume client =
  IO.refresh();
  resume client

