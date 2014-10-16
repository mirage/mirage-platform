(* Lightweight thread library for Objective Caml
 * http://www.ocsigen.org/lwt
 * Module Lwt_main
 * Copyright (C) 2009 Jérémie Dimino
 * Copyright (C) 2010 Anil Madhavapeddy <anil@recoil.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, with linking exceptions;
 * either version 2.1 of the License, or (at your option) any later
 * version. See COPYING file for details.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *)

open Lwt

external block_domain : float -> unit = "caml_block_domain"

let evtchn = Eventchn.init ()

let exit_hooks = Lwt_sequence.create ()
let enter_hooks = Lwt_sequence.create ()

let rec call_hooks hooks  =
  match Lwt_sequence.take_opt_l hooks with
    | None ->
        return ()
    | Some f ->
        (* Run the hooks in parallel *)
        let _ =
          try_lwt
            f ()
          with exn ->
            Printf.printf "call_hooks: exn %s\n%!" (Printexc.to_string exn);
            return ()
        in
        call_hooks hooks

external look_for_work: unit -> bool = "stub_evtchn_look_for_work"

(* Execute one iteration and register a callback function *)
let run t =
  let t = call_hooks enter_hooks <&> t in
  let rec aux () =
    Lwt.wakeup_paused ();
    Time.restart_threads Clock.time;
    match Lwt.poll t with
    | Some () ->
        ()
    | None ->
        if look_for_work () then begin
          (* Some event channels have triggered, wake up threads
           * and continue without blocking. *)
          Activations.run evtchn;
          aux ()
        end else begin
          let timeout =
            match Time.select_next Clock.time with
            |None -> Clock.time () +. 86400.0 (* one day = 24 * 60 * 60 s *)
            |Some tm -> tm
          in
          block_domain timeout;
          aux ()
        end in
  try
    aux ()
  with exn ->
    Printf.printf "Top level exception: %s\n%!"
      (Printexc.to_string exn)

let () = at_exit (fun () -> run (call_hooks exit_hooks))
let at_exit f = ignore (Lwt_sequence.add_l f exit_hooks)
let at_enter f = ignore (Lwt_sequence.add_l f enter_hooks)
