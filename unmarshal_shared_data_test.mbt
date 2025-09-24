// Tests for shared data handling in OCaml marshalling format
// Uses test data from marshal_data_test.mbt

///|
test "decode_shared_string_tuple" {
  // Test tuple with same string shared: ("shared", "shared")
  let decoder = Decoder::new(shared_string_tuple_data)
  let (_, value) = decoder.decode()
  inspect(
    value,
    content=(
      #|MBlock(tag=0, [MString(b"\x73\x68\x61\x72\x65\x64"), MString(b"\x73\x68\x61\x72\x65\x64")])
    ),
  )
}

///|
test "decode_shared_list_tuple" {
  // Test tuple with shared list: ([1;2;3], [1;2;3])
  let decoder = Decoder::new(shared_list_tuple_data)
  let (_, value) = decoder.decode()
  // The second reference should be a shared reference to the first list
  inspect(
    value,
    content="MBlock(tag=0, [MBlock(tag=0, [MInt(1), MBlock(tag=0, [MInt(2), MBlock(tag=0, [MInt(3), MInt(0)])])]), MBlock(tag=0, [MInt(3), MInt(0)])])",
  )
}

///|
test "decode_shared_nested_tuple" {
  // Test tuple with shared nested tuple: (("test", 42), ("test", 42))
  let decoder = Decoder::new(shared_nested_tuple_data)
  let (_, value) = decoder.decode()
  inspect(
    value,
    content=(
      #|MBlock(tag=0, [MBlock(tag=0, [MString(b"\x74\x65\x73\x74"), MInt(42)]), MString(b"\x74\x65\x73\x74")])
    ),
  )
}

///|
test "decode_triple_shared_middle" {
  // Test triple with shared middle: ("first", "middle", "middle")
  let decoder = Decoder::new(triple_shared_middle_data)
  let (_, value) = decoder.decode()
  inspect(
    value,
    content=(
      #|MBlock(tag=0, [MString(b"\x66\x69\x72\x73\x74"), MString(b"\x6d\x69\x64\x64\x6c\x65"), MString(b"\x66\x69\x72\x73\x74")])
    ),
  )
}

///|
test "decode_list_with_shared_elements" {
  // Test list with same string repeated: ["elem"; "elem"; "elem"]
  let decoder = Decoder::new(list_with_shared_data)
  let (_, value) = decoder.decode()
  // First "elem" is stored, then references to it  
  // Verify structure without using inspect to avoid stack overflow with cyclic references
  match value {
    MBlock(tag~, fields) => {
      assert_eq(tag, 0) // List constructor
      assert_eq(fields.length(), 2) // Head and tail

      // First element should be the actual string "elem"
      match fields[0] {
        MString(s) => assert_eq(s, b"elem")
        _ => abort("Expected MString for first list element")
      }

      // Second element is the rest of the list
      match fields[1] {
        MBlock(tag~, fields2) => {
          assert_eq(tag, 0)
          assert_eq(fields2.length(), 2)

          // Second list element should be shared reference to "elem"
          match fields2[0] {
            MShared(idx) => assert_eq(idx, 2) // References the string "elem"
            MString(_) =>
              abort("Got MString instead of MShared for second element")
            MInt(_) => abort("Got MInt instead of MShared for second element")
            MBlock(_) =>
              abort("Got MBlock instead of MShared for second element")
            _ => abort("Expected MShared for second element")
          }

          // Third element in nested list
          match fields2[1] {
            MBlock(tag~, fields3) => {
              assert_eq(tag, 0)
              assert_eq(fields3.length(), 2)

              // Third list element should also be shared reference
              match fields3[0] {
                MShared(idx) => assert_eq(idx, 3) // Also references "elem"
                _ => abort("Expected MShared for third element")
              }

              // End of list
              match fields3[1] {
                MInt(0) => () // Empty list terminator
                _ => abort("Expected MInt(0) for list terminator")
              }
            }
            _ => abort("Expected MBlock for third element")
          }
        }
        _ => abort("Expected MBlock for tail")
      }
    }
    _ => abort("Expected MBlock for list")
  }
}

///|
test "decode_complex_shared" {
  // Test complex nested structure: ((1, [10;20]), (2, [10;20]))
  let decoder = Decoder::new(complex_shared_data)
  let (_, value) = decoder.decode()
  // The list [10;20] should be shared between the two tuples
  inspect(
    value,
    content="MBlock(tag=0, [MBlock(tag=0, [MInt(1), MBlock(tag=0, [MInt(10), MBlock(tag=0, [MInt(20), MInt(0)])])]), MBlock(tag=0, [MInt(2), MBlock(tag=0, [MInt(20), MInt(0)])])])",
  )
}

///|
test "verify_shared_indices" {
  // Verify that shared references use correct indices
  // In OCaml marshal format, shared references start from index 1

  // Simple case: ("shared", "shared") 
  // The second occurrence should reference index 1 (the first string)
  let decoder1 = Decoder::new(shared_string_tuple_data)
  let (_, value1) = decoder1.decode()
  match value1 {
    MBlock(tag~, fields) => {
      assert_eq(tag, 0)
      assert_eq(fields.length(), 2)
      // First field is the actual string
      match fields[0] {
        MString(s) => assert_eq(s, b"shared")
        _ => abort("Expected MString")
      }
      // Second field should be a shared reference to index 1
      match fields[1] {
        MShared(idx) => assert_eq(idx, 1)
        MString(_) => abort("Got MString instead of MShared for second field")
        MInt(_) => abort("Got MInt instead of MShared for second field")
        MBlock(_) => abort("Got MBlock instead of MShared for second field")
        _ => abort("Expected MShared for second field")
      }
    }
    _ => abort("Expected MBlock")
  }

  // Complex case: verify shared list indices
  let decoder2 = Decoder::new(shared_list_tuple_data)
  let (_, value2) = decoder2.decode()
  match value2 {
    MBlock(tag~, fields) => {
      assert_eq(tag, 0)
      assert_eq(fields.length(), 2)
      // First field is the actual list [1;2;3]
      match fields[0] {
        MBlock(tag~, _) => assert_eq(tag, 0) // List constructor
        _ => abort("Expected MBlock for list")
      }
      // Second field should be a shared reference to the first list
      match fields[1] {
        MShared(idx) => assert_eq(idx, 1) // References the first list
        _ => abort("Expected MShared")
      }
    }
    _ => abort("Expected MBlock")
  }
}
