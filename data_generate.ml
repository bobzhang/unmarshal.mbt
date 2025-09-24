
let f data = 
    Marshal.to_string data []

;;

let print_to_mbt_fmt data =
   let s =  ref "[" in 
  f data |>
  String.iter  (fun x -> s := !s ^  Printf.sprintf "b'\\x%02x'," (Char.code x));
  !s ^ "]" |>print_endline


;; print_to_mbt_fmt(1)  