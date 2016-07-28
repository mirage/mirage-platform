type +'a io = 'a Lwt.t

let sleep_ns x = Lwt_unix.sleep (Int64.to_float x /. 1_000_000_000.)
