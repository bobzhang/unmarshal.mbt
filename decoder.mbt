///|
const Tag_int : Byte = 0x01

///|
const Tag_pointer : Byte = 0x02

///|
const Tag_string : Byte = 0x09

///|
const Tag_double : Byte = 0x0C

///|
const Tag_double_array : Byte = 0x0D

///|
const Tag_custom : Byte = 0x12

///|
const Tag_int64 : Byte = 0x13

///|
const Tag_shared : Byte = 0x04

///|
const Tag_block : Byte = 0x10

///|
struct DecoderState {
  objects : Array[MarshalValue] // Shared object table - mutated via methods
  mut position : Int // Current parsing position
  data : Bytes
}

///|
fn DecoderState::view(self : Self) -> @bytes.View {
  self.data[:]
}

/// Adds a decoded object to the shared object table
/// 
/// Every decoded object (except shared references) is automatically registered
/// in the shared object table. This enables OCaml's sharing mechanism where
/// later references can point back to previously decoded objects.
/// 
/// ## Parameters
/// - `state`: Decoder state containing the shared object table
/// - `value`: The decoded MarshalValue to register
/// 
/// ## Returns
/// The index assigned to this object in the shared table
/// 
/// ## Example
/// ``` text
/// let state = { objects: Array::new(), position: 0 }
/// let value = MInt(42)
/// let index = add_shared_object(state, value) // Returns 0
/// // Later: get_shared_object(state, 0) returns MInt(42)
/// ```

///|
fn add_shared_object(state : DecoderState, value : MarshalValue) -> Int {
  let index = state.objects.length()
  state.objects.push(value) // This mutates the objects array
  index
}

/// Retrieves a previously decoded object from the shared object table
/// 
/// Used when encountering a shared reference (tag_shared) that points back
/// to an object decoded earlier in the stream. This is essential for OCaml's
/// sharing mechanism and cyclic reference support.
/// 
/// ## Parameters
/// - `state`: Decoder state containing the shared object table
/// - `index`: Zero-based index of the object to retrieve
/// 
/// ## Returns
/// The MarshalValue at the specified index
/// 
/// ## Panics
/// Aborts if the index is out of bounds (invalid shared reference)

///|
fn get_shared_object(state : DecoderState, index : Int) -> MarshalValue raise {
  if index >= state.objects.length() {
    fail(
      "Invalid shared object reference: index " +
      index.to_string() +
      " >= " +
      state.objects.length().to_string(),
    )
  }
  state.objects[index]
}

/// Parses the 20-byte OCaml Marshal format header
/// 
/// The header contains essential metadata about the marshaled data including
/// format validation, data size, and platform compatibility information.
/// 
/// ## Header Structure (20 bytes)
/// ``` text
/// [0-3]:   Magic number (0x8495A6BE little-endian, 0x8495A6BF big-endian)
/// [4-7]:   Data length (bytes following header)
/// [8-11]:  Number of objects that can be shared
/// [12-15]: Size of integers/pointers on 32-bit platform
/// [16-19]: Size of integers/pointers on 64-bit platform
/// ```
/// 
/// ## Parameters
/// - `data`: Byte view containing at least 20 bytes of marshal data
/// 
/// ## Returns
/// Parsed and validated MarshalHeader structure
/// 
/// ## Panics
/// - If data is shorter than 20 bytes
/// - If magic number is invalid (not a recognized OCaml marshal format)
/// 
/// ## Example
/// ``` text
/// let data = // ... marshal data bytes
/// let header = parse_marshal_header(data[:])
/// println("Data length: " + header.data_len.to_string())
/// ```

///|
pub fn DecoderState::decode_header(data : Self) -> MarshalHeader raise {
  match data.view() {
    [
      u32be(0x8495A6BE | 0x8495A6BF as magic),
      u32be(data_len),
      u32be(num_objects),
      u32be(size_32),
      u32be(size_64),
      ..,
    ] =>
      {
        magic,
        data_len: data_len.reinterpret_as_int(),
        num_objects: num_objects.reinterpret_as_int(),
        size_32: size_32.reinterpret_as_int(),
        size_64: size_64.reinterpret_as_int(),
      }
    _ => fail("Failed to parse marshal header")
  }
}
