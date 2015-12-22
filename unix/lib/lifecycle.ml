(* No shutdown events on Unix. *)
let await_shutdown_request () = fst (Lwt.wait ())
