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

open Lwt
open Printf
open Gc

type id = string
let resolve t = Lwt.on_success t (fun _ -> ())

(** Exception raised when trying to read from a DOWN interface *)
exception Device_down of id

type stats = {
  mutable rx_bytes : int64;
  mutable rx_pkts : int32;
  mutable tx_bytes : int64;
  mutable tx_pkts : int32; 
}

type t = {
  id: id;
  fd_read : Cstruct.t Lwt_condition.t;
  fd_read_ret : unit Lwt_condition.t;
  fd_write : unit Lwt_condition.t;
  mutable active: bool;
  mac: string;
  stats : stats;
}

external pkt_write: string -> int -> Io_page.t -> int -> int -> unit = "caml_pkt_write"
external queue_check: string -> int -> bool = "caml_queue_check"
external register_check_queue: string -> int -> unit =
  "caml_register_check_queue"
exception Ethif_closed

let devices = Hashtbl.create 1

let ethernet_mac_to_string x =
    let chri i = Char.code x.[i] in
    Printf.sprintf "%02x:%02x:%02x:%02x:%02x:%02x"
       (chri 0) (chri 1) (chri 2) (chri 3) (chri 4) (chri 5)

let plug node_name id mac =
 let active = true in
 let fd_read = Lwt_condition.create () in
 let fd_read_ret = Lwt_condition.create  () in 
 let fd_write = Lwt_condition.create () in
 let t = { id=(string_of_int id); fd_read; fd_read_ret;
           active; fd_write; mac; stats={rx_pkts=0l;rx_bytes=0L;tx_pkts=0l;tx_bytes=0L;};} in
 let _ = 
   if (Hashtbl.mem devices node_name) then (
     let devs = Hashtbl.find devices node_name in 
       Hashtbl.replace devices node_name (devs @ [t])
   ) else (
     Hashtbl.replace devices node_name [t]
   )
 in
   printf "Netif: plug %s.%d\n%!" node_name id;
   return t


let demux_pkt node_name dev_id frame = 
  try
    let pkt_len = String.length frame in
      if ((pkt_len < 10) || (pkt_len > 1514)) then
        printf "MALAKIA %d\n%!" pkt_len
      else
        let devs = Hashtbl.find devices node_name in 
        let dev = 
          List.find (
            fun dev -> (dev.id = (string_of_int dev_id)) ) devs in
        let pkt = Io_page.to_cstruct (Io_page.get 1) in 
        let _ = (Cstruct.blit_from_string frame 0 pkt 0 pkt_len) in
        let pkt = Cstruct.sub pkt 0 pkt_len in 

        let _ = Lwt_condition.signal dev.fd_read pkt in
        let _ = resolve (Lwt_condition.wait dev.fd_read_ret) in
        let _ = Lwt.wakeup_paused () in 
        let _ = Lwt.wakeup_paused () in 
        let _ = Lwt.wakeup_paused () in 
        let _ = Lwt.wakeup_paused () in 
        let _ = Lwt.wakeup_paused () in () 
  with 
  | Not_found ->
    Printf.printf "Packet cannot be processed for node %s\n" node_name
  | ex ->
    printf "Error %s\n" (Printexc.to_string ex)
let _ = Callback.register "demux_pkt" demux_pkt


let unplug node_name id =
  try
    let devs = Hashtbl.find devices node_name in
    let _ = List.iter ( 
        fun t ->
          if (t.id = id) then
            t.active <- false
      ) devs in
    let new_devs = List.filter (fun t -> t.id <> id) devs in
      Hashtbl.replace devices node_name new_devs;
      printf "Netif: unplug %s.%s\n%!" node_name id
(*     Hashtbl.remove devices id *)
  with Not_found -> ()

let create () =
  let name = 
    match Lwt.get Topology.node_name with 
      | None -> failwith "thread hasn't got a name"
      | Some(name) -> name
  in
    try_lwt
      let devs = Hashtbl.find devices name in
(*      Lwt_list.fold_lefy_p (
        fun t ret -> 
          let user = fn t.id t in
          let th,_ = Lwt.task () in
            Lwt.on_cancel th (fun _ -> unplug name t.id);
            th <?> user) devs [] *)
      return devs
    with exn -> 
      let _ = printf "manager error %s\n%!" (Printexc.to_string exn) in 
      return []

let get_writebuf t =
  let page = Io_page.to_cstruct (Io_page.get 1) in
    (* TODO: record statistics for requesting thread here (in debug mode?)
     * *)
    return page


(* Loop and listen for packets permanently *)
let rec listen t fn =
  match t.active with
  |true ->
    lwt _ = 
      try_lwt 
        lwt frame = Lwt_condition.wait t.fd_read in
        lwt _ = fn frame in
        let _ = Lwt_condition.signal t.fd_read_ret in
        let _ = Lwt.wakeup_paused () in 
          return ()
      with exn ->
        return (printf "EXN: %s bt: %s\n%!" (Printexc.to_string exn) 
                  (Printexc.get_backtrace()))
    in
      listen t fn
  |false ->
    return ()

(* Shutdown a netfront *)
let destroy nf = return ()

let unblock_device name ix = 
  try
    let devs = Hashtbl.find devices name in 
    let dev = List.find 
      (fun dev -> (dev.id = (string_of_int ix))) devs in
    let _ =  Lwt_condition.signal dev.fd_write () in
    let _ = Lwt.wakeup_paused () in 
     ()
  with Not_found ->
    Printf.printf "Packet cannot be processed for node %s\n" name

(* Transmit a packet from an Io_page *)
let write t page =
  let rec wait_for_queue t node_name = 
    match (queue_check node_name (int_of_string t.id)) with
    | true -> return ()
    | false ->
(*       let _ = printf "%03.6f: traffic blocked %s\n%!" (Clock.time ()) 
         node_name in   *)
      let _ = register_check_queue node_name (int_of_string t.id) in
      lwt _ = Lwt_condition.wait t.fd_write in

(*      let _ = printf "%03.6f: traffic unblocked %s\n%!" (Clock.time ())
        node_name in  *)

        wait_for_queue t node_name
    in
  lwt _ = 
    match (Lwt.get Topology.node_name) with
    | None -> return ()
    | Some(node_name) ->  
      lwt _ = wait_for_queue t node_name in
      return (pkt_write node_name (int_of_string t.id) 
                page.Cstruct.buffer page.Cstruct.off page.Cstruct.len) 
  in
  return ()


(* TODO use writev: but do a copy for now *)
let writev t pages =
  match pages with
  |[] -> return ()
  |[page] -> write t page
  |pages ->
    let page = Io_page.to_cstruct (Io_page.get 1) in
    let off = ref 0 in
    let _ = List.iter (fun p ->
      let len = Cstruct.len p in
      Cstruct.blit p 0 page !off len;
      off := !off + len;
    ) pages in 
    let v = Cstruct.sub page 0 !off in
      write t v
  
let id t = t.id
let id_of_string id = id 
let string_of_id id = id 
let mac t = Macaddr.of_bytes_exn t.mac 

let get_stats_counters t = t.stats

let reset_stats_counters t =
  t.stats.rx_bytes <- 0L;
  t.stats.rx_pkts  <- 0l;
  t.stats.tx_bytes <- 0L;
  t.stats.tx_pkts  <- 0l



let _ = Callback.register "plug_dev" plug
let _ = Callback.register "get_frame" Io_page.get
let _ = Callback.register "unblock_device" unblock_device
