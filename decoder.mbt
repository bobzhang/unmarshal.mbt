// Prefix tags for compact representations

///|
const PREFIX_SMALL_INT : Byte = 0x40

///|
const PREFIX_SMALL_STRING : Byte = 0x20

///|
const PREFIX_SMALL_BLOCK : Byte = 0x80

// Code tags for various data types

///|
const CODE_INT8 : Byte = 0x00

///|
const CODE_INT16 : Byte = 0x01

///|
const CODE_INT32 : Byte = 0x02

///|
const CODE_INT64 : Byte = 0x03

///|
const CODE_SHARED8 : Byte = 0x04

///|
const CODE_SHARED16 : Byte = 0x05

///|
const CODE_SHARED32 : Byte = 0x06

///|
const CODE_SHARED64 : Byte = 0x14

///|
const CODE_BLOCK32 : Byte = 0x08

///|
const CODE_BLOCK64 : Byte = 0x13

///|
const CODE_STRING8 : Byte = 0x09

///|
const CODE_STRING32 : Byte = 0x0A

///|
const CODE_STRING64 : Byte = 0x15

///|
const CODE_DOUBLE_BIG : Byte = 0x0B

///|
const CODE_DOUBLE_LITTLE : Byte = 0x0C

///|
const CODE_DOUBLE_ARRAY8_BIG : Byte = 0x0D

///|
const CODE_DOUBLE_ARRAY8_LITTLE : Byte = 0x0E

///|
const CODE_DOUBLE_ARRAY32_BIG : Byte = 0x0F

///|
const CODE_DOUBLE_ARRAY32_LITTLE : Byte = 0x07

///|
const CODE_DOUBLE_ARRAY64_BIG : Byte = 0x16

///|
const CODE_DOUBLE_ARRAY64_LITTLE : Byte = 0x17

///|
const CODE_CODEPOINTER : Byte = 0x10

///|
const CODE_INFIXPOINTER : Byte = 0x11

///|
const CODE_CUSTOM_LEN : Byte = 0x18

///|
const CODE_CUSTOM_FIXED : Byte = 0x19

// Legacy tags (kept for reference)

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
    // Small integers (0-63): encoded as PREFIX_SMALL_INT + value
    [0x40..=0x7F as b, .. rest] => {
      self.update_view(rest)
      let value = b.to_int() - PREFIX_SMALL_INT.to_int()
      let marshal_value = MInt(value)
      marshal_value
    }

    // Small blocks (tag < 16, size < 8): PREFIX_SMALL_BLOCK + tag + (size << 4)
    [0x80..=0xFF as b, .. rest] => {
      self.update_view(rest)
      let byte_val = b.to_int() - PREFIX_SMALL_BLOCK.to_int()
      let tag = byte_val & 0x0F // Lower 4 bits
      let size = byte_val >> 4 // Upper 4 bits
      self.decode_block_with_tag_size(tag, size)
    }

    // INT8: 8-bit signed integer
    [CODE_INT8, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [b, .. rest2] => {
          self.update_view(rest2)
          // Convert unsigned byte to signed int8
          let value = if b.to_int() >= 128 {
            b.to_int() - 256
          } else {
            b.to_int()
          }
          MInt(value)
        }
        _ => fail("Failed to read INT8 value")
      }
    }

    // INT16: 16-bit signed integer (big-endian)
    [CODE_INT16, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [b1, b2, .. rest2] => {
          self.update_view(rest2)
          let value = (b1.to_int() << 8) | b2.to_int()
          // Convert to signed int16
          let signed_value = if value >= 32768 { value - 65536 } else { value }
          MInt(signed_value)
        }
        _ => fail("Failed to read INT16 value")
      }
    }

    // INT32: 32-bit signed integer (big-endian)
    [CODE_INT32, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u32(value), .. rest2] => {
          self.update_view(rest2)
          MInt(value.reinterpret_as_int())
        }
        _ => fail("Failed to read INT32 value")
      }
    }

    // INT64: 64-bit signed integer (big-endian)
    [CODE_INT64, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u64(value), .. rest2] => {
          self.update_view(rest2)
          MInt(value.reinterpret_as_int64().to_int())
        }
        _ => fail("Failed to read INT64 value")
      }
    }

    // Small strings (length < 32): PREFIX_SMALL_STRING + length
    [0x20..=0x3F as b, .. rest] => {
      self.update_view(rest)
      let len = b.to_int() - PREFIX_SMALL_STRING.to_int()
      self.decode_string_with_length(len)
    }

    // STRING8: String with 8-bit length
    [CODE_STRING8, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [len_byte, .. rest2] => {
          self.update_view(rest2)
          self.decode_string_with_length(len_byte.to_int())
        }
        _ => fail("Failed to read STRING8 length")
      }
    }

    // STRING32: String with 32-bit length
    [CODE_STRING32, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u32(length), .. rest2] => {
          self.update_view(rest2)
          self.decode_string_with_length(length.reinterpret_as_int())
        }
        _ => fail("Failed to read STRING32 length")
      }
    }

    // STRING64: String with 64-bit length (64-bit platforms only)
    [CODE_STRING64, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u64(length), .. rest2] => {
          self.update_view(rest2)
          self.decode_string_with_length(length.reinterpret_as_int64().to_int())
        }
        _ => fail("Failed to read STRING64 length")
      }
    }

    // BLOCK32: Block with 32-bit header
    [CODE_BLOCK32, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u32(header), .. rest2] => {
          self.update_view(rest2)
          // OCaml header format: size in high bits, tag in low 8 bits
          let hdr = header.reinterpret_as_int()
          let tag = hdr & 0xFF
          let size = hdr >> 10 // Size is stored starting at bit 10
          self.decode_block_with_tag_size(tag, size)
        }
        _ => fail("Failed to read BLOCK32 header")
      }
    }

    // BLOCK64: Block with 64-bit header (64-bit platforms only)
    [CODE_BLOCK64, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u64(header), .. rest2] => {
          self.update_view(rest2)
          let hdr = header.reinterpret_as_int64().to_int()
          let tag = hdr & 0xFF
          let size = hdr >> 10
          self.decode_block_with_tag_size(tag, size)
        }
        _ => fail("Failed to read BLOCK64 header")
      }
    }

    // Double/Float
    [CODE_DOUBLE_LITTLE | CODE_DOUBLE_BIG, .. rest] => {
      self.update_view(rest)
      self.decode_double()
    }

    // Shared references
    [CODE_SHARED8, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [idx_byte, .. rest2] => {
          self.update_view(rest2)
          get_shared_object(self, idx_byte.to_int())
        }
        _ => fail("Failed to read SHARED8 index")
      }
    }
    [CODE_SHARED16, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [b1, b2, .. rest2] => {
          self.update_view(rest2)
          let index = (b1.to_int() << 8) | b2.to_int()
          get_shared_object(self, index)
        }
        _ => fail("Failed to read SHARED16 index")
      }
    }
    [CODE_SHARED32, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u32(index), .. rest2] => {
          self.update_view(rest2)
          get_shared_object(self, index.reinterpret_as_int())
        }
        _ => fail("Failed to read SHARED32 index")
      }
    }
    [CODE_SHARED64, .. rest] => {
      self.update_view(rest)
      match self.view() {
        [u64(index), .. rest2] => {
          self.update_view(rest2)
          get_shared_object(self, index.reinterpret_as_int64().to_int())
        }
        _ => fail("Failed to read SHARED64 index")
      }
    }
    [tag, ..] =>
      fail(
        "Unknown or unsupported marshal tag \{tag} at position \{self.position}",
      )
    [] => fail("Unexpected end of data")
  }
}

///|
fn Decoder::decode_string_with_length(
  self : Self,
  len : Int,
) -> MarshalValue raise {
  let view = self.view()
  guard view.length() >= len else {
    fail("Insufficient data for string of length \{len}")
  }
  let string_bytes = view[:len]
  let remaining = view[len:]
  self.update_view(remaining)
  let marshal_value = MString(string_bytes.to_bytes())
  self.add_shared_object(marshal_value)
  marshal_value
}

///|
fn Decoder::decode_string(self : Self) -> MarshalValue raise {
  match self.view() {
    [u32(length), .. rest] => {
      let len = length.reinterpret_as_int()
      self.update_view(rest)
      self.decode_string_with_length(len)
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
fn Decoder::decode_block_with_tag_size(
  self : Self,
  tag : Int,
  size : Int,
) -> MarshalValue raise {
  // Create placeholder for recursive structures
  let fields = Array::new()
  let marshal_value = MBlock(tag~, fields)
  self.add_shared_object(marshal_value)

  // Decode all fields
  for i = 0; i < size; i = i + 1 {
    let field_value = self.decode_value()
    fields.push(field_value)
  }
  marshal_value
}

///|
fn Decoder::decode_block(self : Self) -> MarshalValue raise {
  match self.view() {
    [tag_byte, size_byte, .. rest] => {
      let tag = tag_byte.to_int()
      let size = size_byte.to_int()
      self.update_view(rest)
      self.decode_block_with_tag_size(tag, size)
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
