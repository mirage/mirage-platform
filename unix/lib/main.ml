open Lwt.Infix

let exit_hooks = Lwt_sequence.create ()
let enter_hooks = Lwt_sequence.create ()

let rec call_hooks hooks  =
  match Lwt_sequence.take_opt_l hooks with
    | None ->
        Lwt.return_unit
    | Some f ->
        (* Run the hooks in parallel *)
        let _ =
          Lwt.catch f
          (fun exn ->
            Logs.warn (fun m -> m "call_hooks: exn %s" (Printexc.to_string exn));
            Lwt.return_unit
          ) in
        call_hooks hooks

open Printf

(* Main runloop, which registers a callback so it can be invoked
   when timeouts expire. Thus, the program may only call this function
   once and once only. *)
let run t =
  (* If the platform doesn't have SIGPIPE, then Sys.set_signal will
     raise an Invalid_argument exception. If the signal does not exist
     then we don't need to ignore it, so it's safe to continue. *)
  (try Sys.(set_signal sigpipe Signal_ignore) with Invalid_argument _ -> ());
  let t = call_hooks enter_hooks <&> t in
  Lwt_main.run (
    Lwt.catch
      (fun () -> t)
      (fun e -> Logs.err (fun m -> m "main: %s\n%s" (Printexc.to_string e) (Printexc.get_backtrace ())); Lwt.return_unit))

let () = at_exit (fun () -> run (call_hooks exit_hooks))
let at_exit f = ignore (Lwt_sequence.add_l f exit_hooks)
let at_enter f = ignore (Lwt_sequence.add_l f enter_hooks)
let at_exit_iter f = ignore (Lwt_sequence.add_r f Lwt_main.leave_iter_hooks)
let at_enter_iter f = ignore (Lwt_sequence.add_r f Lwt_main.enter_iter_hooks)
