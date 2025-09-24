# TODO: Missing OCaml Marshal Format Support

This document lists the OCaml marshal formats that are not yet supported in our decoder implementation, based on the OCaml marshalling specification.

## ✅ Currently Supported

### Integers
- ✅ Small integers (0-63): `PREFIX_SMALL_INT`
- ✅ INT8: `CODE_INT8` (8-bit signed)
- ✅ INT16: `CODE_INT16` (16-bit signed, big-endian)
- ✅ INT32: `CODE_INT32` (32-bit signed, big-endian)
- ✅ INT64: `CODE_INT64` (64-bit signed, big-endian)

### Strings
- ✅ Small strings (< 32 chars): `PREFIX_SMALL_STRING`
- ✅ STRING8: `CODE_STRING8` (8-bit length)
- ✅ STRING32: `CODE_STRING32` (32-bit length)
- ✅ STRING64: `CODE_STRING64` (64-bit length)

### Blocks/Structures
- ✅ Small blocks: `PREFIX_SMALL_BLOCK` (tag < 16, size < 8)
- ✅ BLOCK32: `CODE_BLOCK32` (32-bit header)
- ✅ BLOCK64: `CODE_BLOCK64` (64-bit header)

### Floats
- ✅ Double: `CODE_DOUBLE_LITTLE` / `CODE_DOUBLE_BIG`
- ✅ Double Arrays: All variants (8/32/64-bit counts, both endianness)

### Shared Data
- ✅ SHARED8: `CODE_SHARED8` (8-bit reference)
- ✅ SHARED16: `CODE_SHARED16` (16-bit reference)
- ✅ SHARED32: `CODE_SHARED32` (32-bit reference)
- ✅ SHARED64: `CODE_SHARED64` (64-bit reference)

## ❌ Missing/Incomplete Support

### 1. Float Arrays (Double Arrays) ✅
- [x] `CODE_DOUBLE_ARRAY8_BIG` (0x0D) - Float array with 8-bit count (big-endian)
- [x] `CODE_DOUBLE_ARRAY8_LITTLE` (0x0E) - Float array with 8-bit count (little-endian)
- [x] `CODE_DOUBLE_ARRAY32_BIG` (0x0F) - Float array with 32-bit count (big-endian)
- [x] `CODE_DOUBLE_ARRAY32_LITTLE` (0x07) - Float array with 32-bit count (little-endian)
- [x] `CODE_DOUBLE_ARRAY64_BIG` (0x16) - Float array with 64-bit count (big-endian)
- [x] `CODE_DOUBLE_ARRAY64_LITTLE` (0x17) - Float array with 64-bit count (little-endian)

**Implementation Notes**: 
- ✅ Added `MDoubleArray(Array[Double])` variant to `MarshalValue` enum
- ✅ All constants are now handled in `decode_value()`
- ✅ Both endianness variants are properly supported
- ✅ Empty float arrays are encoded as empty blocks with tag 0
- ✅ Comprehensive tests added and passing

### 2. Custom Blocks ✅
- [x] `CODE_CUSTOM_LEN` (0x18) - Custom block with length prefix
- [x] `CODE_CUSTOM_FIXED` (0x19) - Custom block with fixed size

**Implementation Notes**:
- ✅ `MCustom(String, Bytes)` variant fully implemented
- ✅ Parses identifier string (null-terminated)
- ✅ Supports common custom types: Int32 ("_i"), Int64 ("_j"), Nativeint ("_n")
- ✅ Custom data stored as raw bytes for application-specific interpretation
- ✅ Comprehensive tests added and passing

### 3. Code Pointers (Functions/Closures)
- [ ] `CODE_CODEPOINTER` (0x10) - Code pointer representation
- [ ] `CODE_INFIXPOINTER` (0x11) - Infix pointer (internal runtime structure)

**Implementation Notes**:
- These represent function closures and code pointers
- Cannot be meaningfully deserialized in non-OCaml contexts
- Could add `MCodePointer` variant for completeness
- Typically should fail with appropriate error message

### 4. Big Header Support
- [ ] Magic number `0x8495A6BF` - For objects > 4GB on 64-bit platforms
- [ ] 32-byte header format parsing

**Implementation Notes**:
- Currently only supports small header (20 bytes)
- Need to detect magic number and handle 32-byte header
- Important for large data structures

### 5. Object Table Extensions
- [ ] Large object table support (> 2^32 objects)
- [ ] Proper handling of `num_objects` field from header

**Implementation Notes**:
- Currently creates object table but doesn't validate against header count
- May need better memory management for large object counts

## 🔧 Improvements Needed

### Error Handling
- [ ] Better error messages with position information
- [ ] Validate data length against header
- [ ] Check for truncated data
- [ ] Validate shared reference indices

### Testing
- [ ] Add tests for float arrays
- [ ] Add tests for custom blocks (at least error handling)
- [ ] Add tests for malformed data
- [ ] Add tests for big header format

### Documentation
- [ ] Document which custom block types are supported
- [ ] Document limitations (e.g., code pointers)
- [ ] Add examples for each supported type

## Priority Order

1. **High Priority** (Common data types):
   - Float arrays (used for numerical computations)
   - Better error handling and validation

2. **Medium Priority** (Less common but useful):
   - Custom blocks (at least common types like Int32, Int64)
   - Big header support for large data

3. **Low Priority** (Rarely needed or impossible):
   - Code pointers (cannot be meaningfully deserialized)
   - Infix pointers (OCaml runtime internals)

## Notes

- Some formats like code pointers cannot be meaningfully deserialized outside OCaml
- Custom blocks require knowledge of the specific custom operations used
- The decoder should fail gracefully when encountering unsupported formats
