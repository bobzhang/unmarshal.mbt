let () =
  let values = [0; 1; 42; 123; 255; 256; 1000; -1; -42] in
  List.iter (fun v ->
    let data = Marshal.to_string v [] in
    Printf.printf "Value %d: " v;
    String.iter (fun c -> Printf.printf "\\x%02x" (Char.code c)) data;
    Printf.printf " (length: %d)\n" (String.length data)
  ) values
