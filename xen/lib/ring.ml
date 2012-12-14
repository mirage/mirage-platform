(*
 * Copyright (c) 2010-2011 Anil Madhavapeddy <anil@recoil.org>
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

open Lwt
open Printf

let rec pow2 = function
  | 0 -> 1
  | n -> 2 * (pow2 (n - 1))

(*
  struct sring {
    RING_IDX req_prod, req_event;
    RING_IDX rsp_prod, rsp_event;
    uint8_t  netfront_smartpoll_active;
    uint8_t  pad[47];
  };
*)

cstruct ring_hdr {
  uint32_t req_prod;
  uint32_t req_event;
  uint32_t rsp_prod;
  uint32_t rsp_event;
  uint64_t stuff
} as little_endian

exception Shutdown

(* Allocate a multi-page ring, returning the grants and pages *)
let allocate ~domid ~order =
  lwt gnt = Gnttab.get () in
  let ring = Io_page.get ~pages_per_block:(pow2 order) () in

  (* initialise the *_event fields to 1, and the rest to 0 *)
  set_ring_hdr_req_prod ring 0l;
  set_ring_hdr_req_event ring 1l;
  set_ring_hdr_rsp_prod ring 0l;
  set_ring_hdr_rsp_event ring 1l;
  set_ring_hdr_stuff ring 0L;

  let pages = Io_page.to_pages ring in
  lwt gnts = Gnttab.get_n (List.length pages) in
  let perm = Gnttab.RW in
  List.iter (fun (gnt, page) -> Gnttab.grant_access ~domid ~perm gnt page) (List.combine gnts pages);
  return (gnts, ring)

type sring = {
  buf: Io_page.t;   (* Overall I/O buffer *)
  header_size: int; (* Header of shared ring variables, in bits *)
  idx_size: int;    (* Size in bits of an index slot *)
  nr_ents: int;     (* Number of index entries *)
  name: string;     (* For pretty printing only *)
}

let of_buf ~buf ~idx_size ~name =
  let header_size = 4+4+4+4+48 in (* header bytes size of struct sring *)
  (* Round down to the nearest power of 2, so we can mask indices easily *)
  let round_down_to_nearest_2 x =
    int_of_float (2. ** (floor ( (log (float x)) /. (log 2.)))) in
  (* Free space in shared ring after header is accounted for *)
  let free_bytes = Io_page.length buf - header_size in
  let nr_ents = round_down_to_nearest_2 (free_bytes / idx_size) in
  { name; buf; idx_size; nr_ents; header_size }

external sring_rsp_prod: sring -> int = "caml_sring_rsp_prod" "noalloc"
external sring_req_prod: sring -> int = "caml_sring_req_prod" "noalloc"
external sring_req_event: sring -> int = "caml_sring_req_event" "noalloc"
external sring_rsp_event: sring -> int = "caml_sring_rsp_event" "noalloc"
external sring_push_requests: sring -> int -> unit = "caml_sring_push_requests" "noalloc"
external sring_push_responses: sring -> int -> unit = "caml_sring_push_responses" "noalloc"
external sring_set_rsp_event: sring -> int -> unit = "caml_sring_set_rsp_event" "noalloc"
external sring_set_req_event: sring -> int -> unit = "caml_sring_set_req_event" "noalloc"

let nr_ents sring = sring.nr_ents

let slot sring idx =
  (* TODO should precalculate these and store in the sring? this is fast-path *)
  let idx = idx land (sring.nr_ents - 1) in
  let off = sring.header_size + (idx * sring.idx_size) in
  Io_page.sub sring.buf off sring.idx_size

module Front = struct

  type ('a,'b) t = {
    mutable req_prod_pvt: int;
    mutable rsp_cons: int;
    sring: sring;
    wakers: ('b, 'a Lwt.u) Hashtbl.t; (* id * wakener *)
    waiters: unit Lwt.u Lwt_sequence.t;
  }

  let init ~sring =
    let req_prod_pvt = 0 in
    let rsp_cons = 0 in
    let wakers = Hashtbl.create 7 in
    let waiters = Lwt_sequence.create () in
    { req_prod_pvt; rsp_cons; sring; wakers; waiters }

  let slot t idx = slot t.sring idx
  let nr_ents t = t.sring.nr_ents

  let get_free_requests t =
    t.sring.nr_ents - (t.req_prod_pvt - t.rsp_cons)

  let is_ring_full t =
    get_free_requests t = 0

  let has_unconsumed_responses t =
    ((sring_rsp_prod t.sring) - t.rsp_cons) > 0

  let push_requests t =
    sring_push_requests t.sring t.req_prod_pvt

  let push_requests_and_check_notify t =
    let old_idx = sring_req_prod t.sring in
    let new_idx = t.req_prod_pvt in
    push_requests t;
    (new_idx - (sring_req_event t.sring)) < (new_idx - old_idx)

  let check_for_responses t =
    if has_unconsumed_responses t then
      true
    else begin
      sring_set_rsp_event t.sring (t.rsp_cons + 1);
      has_unconsumed_responses t
    end 

  let next_req_id t =
    let s = t.req_prod_pvt in
    t.req_prod_pvt <- t.req_prod_pvt + 1;
    s

  let rec ack_responses t fn =
    let rsp_prod = sring_rsp_prod t.sring in
    while t.rsp_cons != rsp_prod do
      let slot_id = t.rsp_cons in
      let slot = slot t slot_id in
      fn slot;
      t.rsp_cons <- t.rsp_cons + 1;
    done;
    if check_for_responses t then ack_responses t fn

  let poll t respfn =
    ack_responses t (fun slot ->
      let id, resp = respfn slot in
      try
         let u = Hashtbl.find t.wakers id in
         Hashtbl.remove t.wakers id;
         Lwt.wakeup_later u resp
       with Not_found ->
         printf "RX: ack id wakener not found\n%!"
    );
    (* Check for any sleepers waiting for free space *)
    match Lwt_sequence.take_opt_l t.waiters with
    |None -> ()
    |Some u -> Lwt.wakeup u ()

  let wait_for_free_slot t =
    if get_free_requests t > 0 then
      return ()
    else begin
      let th, u = Lwt.task () in
      let node = Lwt_sequence.add_r u t.waiters in
      Lwt.on_cancel th (fun _ -> Lwt_sequence.remove node);
      th
    end 

  let rec push_request_and_wait t reqfn =
    if get_free_requests t > 0 then begin
      let slot_id = next_req_id t in
      let slot = slot t slot_id in
      let th,u = Lwt.task () in
      let id = reqfn slot in
      Lwt.on_cancel th (fun _ -> Hashtbl.remove t.wakers id);
      Hashtbl.add t.wakers id u;
      th
    end else begin
      let th,u = Lwt.task () in
      let node = Lwt_sequence.add_r u t.waiters in
      Lwt.on_cancel th (fun _ -> Lwt_sequence.remove node);
      th >>
      push_request_and_wait t reqfn
    end

   let push_request_async t reqfn freefn =
     lwt () = wait_for_free_slot t in
     let slot_id = next_req_id t in
     let slot = slot t slot_id in
     let th,u = Lwt.task () in
     let id = reqfn slot in
     Lwt.on_cancel th (fun _ -> Hashtbl.remove t.wakers id);
     Hashtbl.add t.wakers id u;
     let _ = freefn th in
     return ()

   let shutdown t =
     Hashtbl.iter (fun id th -> 
       Lwt.wakeup_exn th Shutdown) t.wakers;
    (* Check for any sleepers waiting for free space *)
     let rec loop () = 
       match Lwt_sequence.take_opt_l t.waiters with
	 | None -> ()
	 | Some u -> Lwt.wakeup_exn u Shutdown; loop () 
     in loop ()
       
end

module Back = struct

  type ('a,'b) t = {
    mutable rsp_prod_pvt: int;
    mutable req_cons: int;
    sring: sring;
    wakers: ('b, 'a Lwt.u) Hashtbl.t; (* id * wakener *)
    waiters: unit Lwt.u Lwt_sequence.t;
  }

  let init ~sring =
    let rsp_prod_pvt = 0 in
    let req_cons = 0 in
    let wakers = Hashtbl.create 7 in
    let waiters = Lwt_sequence.create () in
    { rsp_prod_pvt; req_cons; sring; wakers; waiters }

  let slot t idx = slot t.sring idx

  let nr_ents t = t.sring.nr_ents
 
  let has_unconsumed_requests t =
    let req = (sring_req_prod t.sring) - t.req_cons in
    let rsp = t.sring.nr_ents - (t.req_cons - t.rsp_prod_pvt) in
    if req < rsp then (req > 0) else (rsp > 0)
 
  let push_responses t =
    sring_push_responses t.sring t.rsp_prod_pvt 

  let push_responses_and_check_notify t =
    let old_idx = sring_rsp_prod t.sring in
    let new_idx = t.rsp_prod_pvt in
    push_responses t;
    (new_idx - (sring_rsp_event t.sring)) < (new_idx - old_idx)

  let check_for_requests t =
    if has_unconsumed_requests t then
      true
    else begin
      sring_set_req_event t.sring (t.req_cons + 1);
      has_unconsumed_requests t
    end

  let next_res_id t =
    let s = t.rsp_prod_pvt in
    t.rsp_prod_pvt <- t.rsp_prod_pvt + 1;
    s

  let rec ack_requests t fn =
    let req_prod = sring_req_prod t.sring in
    while t.req_cons != req_prod do
      let slot_id = t.req_cons in
      let slot = slot t slot_id in
      t.req_cons <- t.req_cons + 1;
      fn slot;
    done;
    if check_for_requests t then ack_requests t fn

  let service_thread t evtchn fn =
    let rec inner () =
      ack_requests t fn;
      Activations.wait evtchn >>
      inner ()
    in inner ()
end

(* Raw ring handling section *)
(* TODO both of these can be combined into one set of bindings now *)
module Console = struct
    type t
    let initial_grant_num : Gnttab.r = Gnttab.of_int32 2l
    external start_page: unit -> t = "caml_console_start_page"
    external zero: t -> unit = "caml_console_ring_init"
    external unsafe_write: t -> string -> int -> int = "caml_console_ring_write"
    external unsafe_read: t -> string -> int -> int = "caml_console_ring_read"
    let alloc_initial () =
      let page = start_page () in
      initial_grant_num, page
end

module Xenstore = struct
    type t = Io_page.t
    let initial_grant_num : Gnttab.r = Gnttab.of_int32 1l
    external start_page: unit -> t = "caml_xenstore_start_page"
    let of_buf t = t
    external zero: t -> unit = "caml_xenstore_ring_init"
    external unsafe_write: t -> string -> int -> int = "caml_xenstore_ring_write"
    external unsafe_read: t -> string -> int -> int = "caml_xenstore_ring_read"
	module Back = struct
		external unsafe_write : t -> string -> int -> int = "caml_xenstore_back_ring_write"
		external unsafe_read : t -> string -> int -> int = "caml_xenstore_back_ring_read"
	end
    let alloc_initial () =
      let page = start_page () in
      zero page;
      initial_grant_num, page
end

