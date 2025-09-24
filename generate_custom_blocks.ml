(* Generate test data for OCaml custom blocks *)

let generate_custom_int32_test () =
  (* Create various Int32 values *)
  let values = [
    Int32.zero;
    Int32.one;
    Int32.of_int 42;
    Int32.of_int 1000;
    Int32.of_int (-1);
    Int32.of_int (-42);
    Int32.max_int;
    Int32.min_int;
    Int32.of_int 0x12345678;
  ] in
  
  List.iteri (fun i v ->
    let filename = Printf.sprintf "int32_%d.marshal" i in
    let oc = open_out_bin filename in
    Marshal.to_channel oc v [];
    close_out oc;
    Printf.printf "Generated %s: %ld (0x%lx)\n" filename v v
  ) values

let generate_custom_int64_test () =
  (* Create various Int64 values *)
  let values = [
    Int64.zero;
    Int64.one;
    Int64.of_int 42;
    Int64.of_int 1000000;
    Int64.of_int (-1);
    Int64.max_int;
    Int64.min_int;
    Int64.of_string "0x123456789ABCDEF0";
  ] in
  
  List.iteri (fun i v ->
    let filename = Printf.sprintf "int64_%d.marshal" i in
    let oc = open_out_bin filename in
    Marshal.to_channel oc v [];
    close_out oc;
    Printf.printf "Generated %s: %Ld (0x%Lx)\n" filename v v
  ) values

let generate_custom_nativeint_test () =
  (* Create various Nativeint values *)
  let values = [
    Nativeint.zero;
    Nativeint.one;
    Nativeint.of_int 42;
    Nativeint.of_int (-100);
    Nativeint.max_int;
    Nativeint.min_int;
  ] in
  
  List.iteri (fun i v ->
    let filename = Printf.sprintf "nativeint_%d.marshal" i in
    let oc = open_out_bin filename in
    Marshal.to_channel oc v [];
    close_out oc;
    Printf.printf "Generated %s: %nd (0x%nx)\n" filename v v
  ) values

let generate_mixed_test () =
  (* Create a tuple with custom blocks and regular values *)
  let data = (
    Int32.of_int 42,
    "Hello",
    Int64.of_int 1000000,
    [1; 2; 3],
    Int32.of_int (-100)
  ) in
  
  let filename = "mixed_custom.marshal" in
  let oc = open_out_bin filename in
  Marshal.to_channel oc data [];
  close_out oc;
  Printf.printf "Generated %s: mixed tuple with custom blocks\n" filename

let () =
  Printf.printf "Generating custom block test data...\n";
  generate_custom_int32_test ();
  Printf.printf "\n";
  generate_custom_int64_test ();
  Printf.printf "\n";
  generate_custom_nativeint_test ();
  Printf.printf "\n";
  generate_mixed_test ();
  Printf.printf "\nDone!\n"
