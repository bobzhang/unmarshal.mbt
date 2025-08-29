/// OCaml Marshal header structure (20 bytes total)
/// 
/// Contains metadata about the marshaled data including magic number for
/// format validation, data length, and platform-specific size information.
/// 
/// ## Fields
/// - `magic`: Format identifier (0x8495A6BE or 0x8495A6BF)
/// - `data_len`: Length of data section (excluding 20-byte header)
/// - `num_objects`: Number of objects that can be shared/referenced
/// - `size_32`: Size of integers/pointers on 32-bit platforms
/// - `size_64`: Size of integers/pointers on 64-bit platforms

///|
pub struct MarshalHeader {
  magic : UInt
  data_len : Int
  num_objects : Int
  size_32 : Int
  size_64 : Int
} derive(Show, Eq, ToJson)

///|
/// Wrapper for byte arrays with JSON serialization support
/// 
/// Provides a clean JSON representation of byte data as an array of numbers
/// for debugging and testing purposes.
//TODO:(upstream) impl ToJson for Bytes
pub struct MBytes(Bytes) derive(Eq, Show)

///|
pub impl ToJson for MBytes with to_json(self) {
  Json::array(self.0.to_array().map(x => Json::number(x.to_double())))
}

/// Represents all possible OCaml values that can be unmarshaled
/// 
/// This enum covers the complete range of OCaml data types that can be
/// serialized with the Marshal module. Each variant corresponds to specific
/// OCaml runtime representations.
/// 
/// ## Variants
/// - `MInt(Int)`: OCaml integers (31-bit on 32-bit, 63-bit on 64-bit platforms)
/// - `MString(String)`: OCaml strings with UTF-8 encoding
/// - `MFloat(Double)`: OCaml floats (IEEE 754 double precision)
/// - `MBlock(Int, Array[MarshalValue])`: Structured data with tag and fields
///   - Used for tuples, records, variants, lists, arrays
///   - Tag indicates the specific OCaml constructor or structure type
/// - `MCustom(String, MBytes)`: User-defined serializable objects (PLANNED)
/// - `MShared(Int)`: Reference to shared object by index (PLANNED)
/// 
/// ## Sharing System
/// Objects are automatically registered in a shared object table during parsing
/// to handle OCaml's object sharing and cyclic reference support.

///|
pub enum MarshalValue {
  MInt(Int)
  MString(String)
  MFloat(Double)
  MBlock(tag~ : Int, Array[MarshalValue]) // tag, fields
  MCustom(String, MBytes) // identifier, data
  MShared(Int) // reference to shared object
} derive(Show, Eq, ToJson(style="flat"))
