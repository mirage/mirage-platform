(*
 * Copyright (c) 2015 Thomas Leonard <talex5@gmail.com>
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

open Lwt.Infix

let await_shutdown_request () =
  Xs.make () >>= fun xs ->
  Xs.wait xs (fun h ->
    Xs.read h "control/shutdown" >>= function
    | "poweroff" -> Lwt.return `Poweroff
    | "reboot" -> Lwt.return `Reboot
    | "suspend"
    | "" -> Lwt.fail Xs_protocol.Eagain
    | state ->
        (* The Xen documentation says:
           "The precise protocol is not yet documented."
           http://xenbits.xen.org/docs/unstable/misc/xenstore-paths.html
        *)
        Printf.printf "Unknown power state %S\n%!" state;
        Lwt.fail Xs_protocol.Eagain
  ) >>= fun reason ->
  (* Ack request *)
  Xs.immediate xs (fun h -> Xs.write h "control/shutdown" "") >>= fun () ->
  Lwt.return reason
