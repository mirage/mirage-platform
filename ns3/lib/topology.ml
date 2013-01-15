(* 
 *  Copyright (c) 2012 Charalampos Rotsos <cr409@cl.cam.ac.uk>
 * 
 *  Permission to use, copy, modify, and distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 * 
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt
open Printf 

external ns3_add_node : string -> unit = "ocaml_ns3_add_node"
external ns3_add_link : string -> string -> int -> int -> int -> bool -> unit 
= "ocaml_ns3_add_link_bytecode" "ocaml_ns3_add_link_native"
external ns3_add_net_intf : string -> string -> string -> string -> unit = "ns3_add_net_intf"
external ns3_get_dev_byte_counter : string -> string -> int = 
  "ocaml_ns3_get_dev_byte_counter"

(* Main run thread *) 
external ns3_run : int -> int = "ocaml_ns3_run" 

type node_t = {
  name: string;
  cb_init : (unit -> unit Lwt.t);
}

type topo_t = {
  nodes : (string, node_t) Hashtbl.t;
  mutable links : (string * string * float) list;
} 

let topo = 
  {nodes=(Hashtbl.create 64);links=[];}

let exec fn () =
  Lwt.ignore_result (fn ())

let load t =
  Printf.printf "OS.Topology started...\n%!";
  let _ = t () in
  let _ = ns3_run (Time.get_duration ()) in
    ()

let add_node name cb_init =
  let _ = ns3_add_node name in
    Hashtbl.replace topo.nodes name {name; cb_init;} 

let no_act_init () =
  return ()

let add_external_dev dev node ip mask =
(*  let (ip, mask) = 
    match config with 
    | `DHCP ->
      eprintf "DHCP cannot be assigned to an external dev\n%!";
      failwith "DHCP cannot be assigned to an external dev"
    | `IPv4 (ip, mask, gws) ->
      (ip, mask)
  in *)
  Hashtbl.replace topo.nodes dev {name=dev; cb_init=no_act_init;};
  ns3_add_net_intf dev node ip mask
  
(* rate is in Mbps. *)
let add_link ?(rate=1000) ?(prop_delay=0) ?(queue_size=100) ?(pcap=false)
    node_a node_b =
  try 
    let _ = Hashtbl.find topo.nodes node_a in 
    let _ = Hashtbl.find topo.nodes node_b in 
    let _ = topo.links <- topo.links @ [(node_a, node_b, 
    (float_of_int (rate*1000000)))] in 
      ns3_add_link node_a node_b rate prop_delay queue_size pcap  
  with Not_found -> ()

let node_name = Lwt.new_key ()


let init_node name =
  let _ = Printf.printf "Initialising node %s....\n%!" name in
    try
      let node = Hashtbl.find topo.nodes name in 
        Lwt.with_value node_name (Some(node.name)) (exec node.cb_init)
    with Not_found -> 
      printf "Node '%s' (len %d) was ot found\n%!" name (String.length name)


let _ = Callback.register "init" init_node

