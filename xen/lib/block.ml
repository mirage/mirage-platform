(* 
 * Copyright (c) Citrix Inc
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

type name = string

module type S = V1.BLOCK_DEVICE
  with type page_aligned_buffer := Cstruct.t
  and type 'a io := 'a Lwt.t

let table = Hashtbl.create 16
let waiters = Hashtbl.create 16

let register id m =
  Printf.printf "Registering block driver %s\n" id;
  Hashtbl.replace table id m;
  if Hashtbl.mem waiters id
  then
    let seq = Hashtbl.find waiters id in
    Lwt_sequence.iter_l (fun u -> Lwt.wakeup_later u m) seq;
    Hashtbl.remove waiters id
  else ()

let find id =
  if Hashtbl.mem table id
  then return (Hashtbl.find table id)
  else
    let t, u = Lwt.task () in
    let seq =
      if Hashtbl.mem waiters id
      then Hashtbl.find waiters id
      else
        let seq = Lwt_sequence.create () in
        Hashtbl.add waiters id seq;
        seq in
    Lwt_sequence.add_r u seq;
    t
