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
pub(all) struct Decoder {
  object_table : Map[MarshalValue, Int] // Shared object table - mutated via methods
  object_array : Array[MarshalValue] // Shared object array - mutated via methods
  mut position : Int // Current parsing position
  data : Bytes
}

///|
pub fn Decoder::new(data : Bytes) -> Self {
  Decoder::{ object_table: {}, object_array: [], position: 0, data }
}

///|
fn Decoder::view(self : Self) -> @bytes.View {
  self.data[self.position:]
}

///|
fn Decoder::update_view(self : Self, view : BytesView) -> Unit {
  self.position = view.start_offset()
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
/// let index = state.add_shared_object(value) // Returns 0
/// // Later: get_shared_object(state, 0) returns MInt(42)
/// ```

///|
fn Decoder::add_shared_object(state : Decoder, value : MarshalValue) -> Unit {
  // TODO:upstream add length method for Map
  let index = state.object_table.size()
  state.object_table[value] = index // This mutates the objects array
  state.object_array.push(value)
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
fn get_shared_object(state : Decoder, index : Int) -> MarshalValue raise {
  if index >= state.object_array.length() {
    fail(
      "Invalid shared object reference: index " +
      index.to_string() +
      " >= " +
      state.object_array.length().to_string(),
    )
  }
  state.object_array[index]
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
pub fn Decoder::decode_header(data : Self) -> MarshalHeader raise {
  match data.view() {
    [
      u32(0x8495A6BE | 0x8495A6BF as magic),
      u32(data_len),
      u32(num_objects),
      u32(size_32),
      u32(size_64),
      .. rest,
    ] => {
      // TODO(upstream): improve error message when missing `{` and `}`
      data.update_view(rest)
      MarshalHeader::{
        magic,
        data_len: data_len.reinterpret_as_int(),
        num_objects: num_objects.reinterpret_as_int(),
        size_32: size_32.reinterpret_as_int(),
        size_64: size_64.reinterpret_as_int(),
      }
    }
    _ => fail("Failed to parse marshal header")
  }
}

///|
pub fn Decoder::decode(self : Self) -> (MarshalHeader, MarshalValue) raise {
  let header = self.decode_header()
  let value = self.decode_value()
  (header, value)
}

///|
pub fn Decoder::decode_value(self : Self) -> MarshalValue raise {
  match self.view() {
    // Small integers (0-63): encoded as 0x40 + value
    [0x40..=0x7F as b, .. rest] => {
      self.update_view(rest)
      let value = b.to_int() - 0x40
      let marshal_value = MInt(value)
      marshal_value
    }

    // String tag
    [Tag_string, .. rest] => {
      self.update_view(rest)
      self.decode_string()
    }
    // Double tag
    [Tag_double, .. rest] => {
      self.update_view(rest)
      self.decode_double()
    }
    // Block tag
    [Tag_block, .. rest] => {
      self.update_view(rest)
      self.decode_block()
    }
    // Shared object reference
    [Tag_shared, .. rest] => {
      self.update_view(rest)
      self.decode_shared_reference()
    }
    [tag, ..] =>
      fail("Unknown or unsupported marshal tag \{tag} at \{self.position}")
    [] => fail("unepected end of data")
  }
}

///|
fn Decoder::decode_string(self : Self) -> MarshalValue raise {
  match self.view() {
    [u32(length), .. rest] => {
      let len = length.reinterpret_as_int()
      guard rest.length() >= len else {
        fail("Insufficient data for string of length ")
      }
      let string_bytes = rest[:len]
      let remaining = rest[len:]
      self.update_view(remaining)
      let marshal_value = MString(string_bytes.to_bytes())
      self.add_shared_object(marshal_value)
      marshal_value
    }
    _ => fail("Failed to parse string length")
  }
}

///|
fn Decoder::decode_double(self : Self) -> MarshalValue raise {
  match self.view() {
    [u64(value), .. rest] => {
      self.update_view(rest)
      let marshal_value = MFloat(value.reinterpret_as_double())
      self.add_shared_object(marshal_value)
      marshal_value
    }
    _ => fail("Failed to parse double")
  }
}

///|
fn Decoder::decode_block(self : Self) -> MarshalValue raise {
  match self.view() {
    [tag_byte, size_byte, .. rest] => {
      let tag = tag_byte.to_int()
      let size = size_byte.to_int()
      self.update_view(rest)

      // Create placeholder for recursive structures
      let fields = Array::new()
      let marshal_value = MBlock(tag~, fields)
      let obj_index = self.add_shared_object(marshal_value)

      // Decode all fields
      for i = 0; i < size; i = i + 1 {
        let field_value = self.decode_value()
        fields.push(field_value)
      }
      marshal_value
    }
    _ => fail("Failed to parse block header")
  }
}

///|
fn Decoder::decode_shared_reference(self : Self) -> MarshalValue raise {
  match self.view() {
    [u32(index), .. rest] => {
      self.update_view(rest)
      let idx = index.reinterpret_as_int()
      get_shared_object(self, idx)
    }
    _ => fail("Failed to parse shared reference index")
  }
}
