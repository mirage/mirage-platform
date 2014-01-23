type +'a io = 'a Lwt.t

let sleep x = Lwt_unix.sleep x
