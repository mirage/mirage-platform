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

type id = string

let id_of_string s = s
let string_of_id i = i

exception Device_down of id

type dev_type =
| PCAP
| ETH

type stats = {
  mutable rx_bytes : int64;
  mutable rx_pkts : int32;
  mutable tx_bytes : int64;
  mutable tx_pkts : int32; 
}

type t = {
          id: id;
          typ: dev_type;
          buf_sz: int;
  mutable buf: Cstruct.t;
          dev: Lwt_unix.file_descr;
  mutable active: bool;
          mac: Macaddr.t;
          stats : stats;
}

type vif_info = {
  vif_id: id;
  vif_dev_type: dev_type;
  vif_fd: Unix.file_descr;
}

external eth_opendev: string -> Unix.file_descr = "pcap_opendev"
external pcap_get_buf_len: Unix.file_descr -> int = "pcap_get_buf_len"

exception Ethif_closed

let devices = Hashtbl.create 1

(* Stream of network interface records *)
let vifs, push_vif = Lwt_stream.create ()

let add_vif vif_id vif_dev_type vif_fd = push_vif (Some {vif_id; vif_dev_type; vif_fd})

let plug dev_type id fd =
  match dev_type with
    | ETH ->
      let dev = Lwt_unix.of_unix_file_descr ~blocking:false fd in
      let mac = Macaddr.make_local (fun _ -> Random.int 256) in
      printf "plugging into %s with mac %s..\n%!" id (Macaddr.to_string mac);
      let active = true in
      let t = { id; dev; active; mac; typ=ETH;buf_sz=4096;
                stats={rx_bytes=0L;rx_pkts=0l;
                tx_bytes=0L; tx_pkts=0l;};
                buf=Io_page.to_cstruct (Lwt_bytes.create 0) } in
      Hashtbl.add devices id t;
      printf "Netif: plug %s\n%!" id;
      t

    | PCAP ->
      let dev = Lwt_unix.of_unix_file_descr ~blocking:false fd in
      let mac = Tuntap.get_macaddr id in
      printf "attaching %s with mac %s..\n%!" id (Macaddr.to_string mac);
      let buf_sz = pcap_get_buf_len fd in
      let active = true in
      let t = { id; dev; active; mac; typ=PCAP; buf_sz;
                stats={rx_bytes=0L;rx_pkts=0l;
                tx_bytes=0L; tx_pkts=0l;};
                buf=Io_page.to_cstruct (Lwt_bytes.create 0);} in
      Hashtbl.add devices id t;
      printf "Netif: plug %s\n%!" id;
      t

let unplug id =
  try
    let t = Hashtbl.find devices id in
    t.active <- false;
    let _ = Lwt_unix.close t.dev in
    printf "Netif: unplug %s\n%!" id;
    Hashtbl.remove devices id
  with Not_found -> ()


(* TODO: Properly unplug the created devices *)
let rec create () =
  try_lwt 
    let devs = Lwt_stream.get_available vifs in
    let ret = 
      List.map (fun vif -> 
          (plug vif.vif_dev_type vif.vif_id vif.vif_fd)) devs in 
    return ret

cstruct bpf_hdr {
  uint32 tv_sec;
  uint32 tv_usec;
  uint32 caplen;
  uint32 bh_datapen;
  uint16 bh_hdrlen
} as little_endian

(* Input a frame, and block if nothing is available *)
let rec input t =
  match t.typ with 
    | ETH -> begin
        let page = Io_page.get 1 in
        lwt len = Lwt_bytes.read t.dev page 0 t.buf_sz in
          match len with
            |(-1) -> (* EAGAIN or EWOULDBLOCK *)
                input t
            |0 -> (* EOF *)
                t.active <- false;
                input t
            |n -> 
                t.stats.rx_pkts <- Int32.succ t.stats.rx_pkts; 
                t.stats.rx_bytes <- Int64.add t.stats.rx_bytes (Int64.of_int len); 
                return (Cstruct.sub (Io_page.to_cstruct page) 0 len)
      end
    | PCAP -> begin 
      (* very ineficient mechanism, but fine for now *)
        (*reading pcap header first*)
        lwt _ =
          if (0 >= (Cstruct.len t.buf)) then (
            let page = Io_page.get 1 in
            lwt len = Lwt_bytes.read t.dev page 0 t.buf_sz in
           let _ = t.buf <- Cstruct.sub (Io_page.to_cstruct page) 0 len in 
(*             let _ = printf "fetched new data %d\n%!" (len) in *)
              return ()
          ) else  return ()
        in
        let caplen = Int32.to_int (get_bpf_hdr_caplen t.buf) in
        t.stats.rx_pkts <- Int32.succ t.stats.rx_pkts; 
        t.stats.rx_bytes <- Int64.add t.stats.rx_bytes (Int64.of_int caplen); 
        let bh_hdrlen = get_bpf_hdr_bh_hdrlen t.buf in
        (* Equivalent of the BPFWORDALIGN macro *)
        let bpf_wordalign = (caplen + bh_hdrlen + 3) land 0x7ffffffc in
(*        let _ = Cstruct.hexdump (Cstruct.sub t.buf 0 18) in 
         let _ = printf "caplen:%d, bh_hdrlen: %d, len:%d bpf_wordalig=%d, ndata:%d\n%!" caplen
         bh_hdrlen (caplen + bh_hdrlen) bpf_wordalign (Cstruct.len t.buf) in  *)
        let ret = Cstruct.sub t.buf bh_hdrlen caplen in
        
        let _ = 
          if (bpf_wordalign < (Cstruct.len t.buf)) then
            t.buf <- Cstruct.shift t.buf bpf_wordalign 
          else
            t.buf <- Cstruct.create 0  
        in
         return ret
    end

(* Get write buffer for Netif output *)
let get_writebuf t =
  let page = Io_page.to_cstruct (Io_page.get 1) in
  (* TODO: record statistics for requesting thread here (in debug mode?) *)
  return page

(* Loop and listen for packets permanently *)
let rec listen t fn =
  match t.active with
  |true -> begin
      try_lwt
        lwt frame = input t in
          Lwt.ignore_result (
            try_lwt 
              fn frame
            with exn ->
            return (printf "EXN: %s bt: %s\n%!" (Printexc.to_string exn) (Printexc.get_backtrace()))
          );
          listen t fn
      with 
      |  Unix.Unix_error(Unix.ENXIO, _, _) -> 
          let _ = printf "[netif-input] device %s is down\n%!" t.id in 
            raise (Device_down t.id)
      | exn -> 
        let _ = eprintf "[netif-input] error : %s\n%!" (Printexc.to_string exn ) in
        let _ = t.buf <- (Cstruct.create 0) in 
          listen t fn 
  end
  |false -> return ()

(* Shutdown a netfront *)
let destroy nf =
  let _ = unplug nf.id in 
  return (printf "tap_destroy\n%!")

(* Transmit a packet from an Io_page *)
let write t page =
 (* Unfortunately we peek inside the cstruct type here: *)
  lwt len' = Lwt_bytes.write t.dev page.Cstruct.buffer page.Cstruct.off page.Cstruct.len in
  t.stats.tx_pkts <- Int32.succ t.stats.tx_pkts; 
  t.stats.tx_bytes <- Int64.add t.stats.tx_bytes (Int64.of_int page.Cstruct.len); 
  if len' <> page.Cstruct.len then
    raise_lwt (Failure (sprintf "tap: partial write (%d, expected %d)" len' page.Cstruct.len))
  else
    return ()


(* TODO use writev: but do a copy for now *)
let writev t pages =
  match pages with
  |[] -> return ()
  |[page] -> write t page
  |pages ->
    let page = Io_page.(to_cstruct (get 1)) in
    let off = ref 0 in
    List.iter (fun p ->
      let len = Cstruct.len p in
      Cstruct.blit p 0 page !off len;
      off := !off + len;
    ) pages;
    let v = Cstruct.sub page 0 !off in
    write t v

let id t = t.id

let mac t = t.mac

let get_stats_counters t = t.stats

let reset_stats_counters t =
  t.stats.rx_bytes <- 0L;
  t.stats.rx_pkts  <- 0l;
  t.stats.tx_bytes <- 0L;
  t.stats.tx_pkts  <- 0l
