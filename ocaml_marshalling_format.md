# OCaml Marshalling Format Documentation

## Overview

OCaml's marshalling format is a compact binary representation for serializing OCaml values. The format uses a tag-based encoding system where the first byte (or bytes) identifies the type and size of the data that follows.

## Header Format

The marshalled data begins with a header that contains metadata about the serialized content. There are three header formats:

### Small Header (20 bytes)
- **Offset 0-3**: Magic number `0x8495A6BE` 
- **Offset 4-7**: Length of marshaled data (32-bit big-endian)
- **Offset 8-11**: Number of shared blocks (32-bit big-endian)
- **Offset 12-15**: Size in words when read on 32-bit platform (32-bit big-endian)
- **Offset 16-19**: Size in words when read on 64-bit platform (32-bit big-endian)

### Big Header (32 bytes) - Used for large objects on 64-bit platforms
- **Offset 0-3**: Magic number `0x8495A6BF`
- **Offset 4-7**: Reserved (set to 0)
- **Offset 8-15**: Length of marshaled data (64-bit big-endian)
- **Offset 16-23**: Number of shared blocks (64-bit big-endian)
- **Offset 24-31**: Size in words when read on 64-bit platform (64-bit big-endian)

### Compressed Header (10-55 bytes)
- **Offset 0-3**: Magic number `0x8495A6BD`
- **Offset 4**: Header size (low 6 bits) and reserved bits (high 2 bits)
- **Offset 5+**: Variable-length integers (VLQ format) containing:
  - Length of compressed marshaled data
  - Length of uncompressed marshaled data
  - Number of shared blocks
  - Size in words for 32-bit platform
  - Size in words for 64-bit platform

## Simple Encoding Examples

Let's start with the simplest possible examples to understand how basic values are encoded. Each example shows the complete byte sequence including the header.

### Example 1: Integer 1

```
Complete marshalled data (21 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 01    # Length of data (1 byte)
00 00 00 00    # Number of shared blocks (0)
00 00 00 01    # Size on 32-bit platform (1 word)
00 00 00 01    # Size on 64-bit platform (1 word)
41             # Data: PREFIX_SMALL_INT + 1 = 0x40 + 1 = 0x41
```

### Example 2: String "a"

```
Complete marshalled data (22 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 02    # Length of data (2 bytes)
00 00 00 00    # Number of shared blocks (0)
00 00 00 01    # Size on 32-bit platform (1 word)
00 00 00 01    # Size on 64-bit platform (1 word)
21             # PREFIX_SMALL_STRING + 1 = 0x20 + 1 = 0x21
61             # ASCII 'a' = 0x61
```

### Example 3: Integer 100

```
Complete marshalled data (22 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 02    # Length of data (2 bytes)
00 00 00 00    # Number of shared blocks (0)
00 00 00 01    # Size on 32-bit platform (1 word)
00 00 00 01    # Size on 64-bit platform (1 word)
00             # CODE_INT8 = 0x00
64             # Value 100 = 0x64
```

### Example 4: Empty list []

```
Complete marshalled data (21 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 01    # Length of data (1 byte)
00 00 00 00    # Number of shared blocks (0)
00 00 00 01    # Size on 32-bit platform (1 word)
00 00 00 01    # Size on 64-bit platform (1 word)
80             # PREFIX_SMALL_BLOCK + tag 0 + (size 0 << 4) = 0x80
```

### Example 5: Tuple (1, 2)

```
Complete marshalled data (23 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 03    # Length of data (3 bytes)
00 00 00 00    # Number of shared blocks (0)
00 00 00 03    # Size on 32-bit platform (3 words)
00 00 00 03    # Size on 64-bit platform (3 words)
A0             # PREFIX_SMALL_BLOCK + tag 0 + (size 2 << 4) = 0x80 + 0x20 = 0xA0
41             # First element: integer 1 = 0x41
42             # Second element: integer 2 = 0x42
```

### Example 6: String "Hello"

```
Complete marshalled data (26 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 06    # Length of data (6 bytes)
00 00 00 00    # Number of shared blocks (0)
00 00 00 02    # Size on 32-bit platform (2 words)
00 00 00 01    # Size on 64-bit platform (1 word)
25             # PREFIX_SMALL_STRING + 5 = 0x20 + 5 = 0x25
48 65 6C 6C 6F # "Hello" in ASCII
```

### Example 7: List [1; 2]

```
Complete marshalled data (25 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 05    # Length of data (5 bytes)
00 00 00 01    # Number of shared blocks (1 - the tail is shared)
00 00 00 05    # Size on 32-bit platform (5 words)
00 00 00 05    # Size on 64-bit platform (5 words)
A0             # List cons cell: PREFIX_SMALL_BLOCK + tag 0 + (size 2 << 4)
41             # Head: integer 1
A0             # Tail: another cons cell
42             # Head: integer 2
80             # Tail: empty list
```

### Example 8: Integer 1000

```
Complete marshalled data (23 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 03    # Length of data (3 bytes)
00 00 00 00    # Number of shared blocks (0)
00 00 00 01    # Size on 32-bit platform (1 word)
00 00 00 01    # Size on 64-bit platform (1 word)
01             # CODE_INT16 = 0x01
03 E8          # Value 1000 = 0x03E8 (big-endian)
```

### Example 9: Boolean true and false

In OCaml, `true` is represented as integer 1 and `false` as integer 0:

```
true:
84 95 A6 BE 00 00 00 01 00 00 00 00 00 00 00 01 00 00 00 01
41             # PREFIX_SMALL_INT + 1 = 0x41

false:
84 95 A6 BE 00 00 00 01 00 00 00 00 00 00 00 01 00 00 00 01
40             # PREFIX_SMALL_INT + 0 = 0x40
```

### Example 10: Float 3.14

```
Complete marshalled data (29 bytes):
84 95 A6 BE    # Magic number (small header)
00 00 00 09    # Length of data (9 bytes)
00 00 00 00    # Number of shared blocks (0)
00 00 00 03    # Size on 32-bit platform (3 words)
00 00 00 02    # Size on 64-bit platform (2 words)
0C             # CODE_DOUBLE_LITTLE (or 0x0B for big-endian)
1F 85 EB 51 B8 1E 09 40  # IEEE 754 double: 3.14
```

### Tips for Decoder Implementation

1. **Start with the header**: Always read and validate the 20-byte header first
2. **Check magic number**: Verify it's `0x8495A6BE` for small header
3. **Read data length**: This tells you how many bytes of actual data follow
4. **Decode by first byte**: The first data byte tells you the type:
   - `0x40-0x7F`: Small integer (value = byte - 0x40)
   - `0x20-0x3F`: Small string (length = byte - 0x20)
   - `0x80-0xFF`: Small block (parse tag and size from byte)
   - `0x00-0x1F`: Various CODE_* operations

5. **Test incrementally**: Start with integers, then strings, then simple structures

## Tag Encoding System

The encoding uses a combination of prefix tags and code tags:

### Prefix Tags (Single Byte Encodings)

| Prefix | Value | Description |
|--------|-------|-------------|
| `PREFIX_SMALL_INT` | `0x40` | Small integers (0-63): byte = `0x40 + n` |
| `PREFIX_SMALL_STRING` | `0x20` | Small strings (length < 32): byte = `0x20 + len` |
| `PREFIX_SMALL_BLOCK` | `0x80` | Small blocks: byte = `0x80 + tag + (size << 4)` <br/> For blocks with tag < 16 and size < 8 |

### Code Tags (Multi-byte Encodings)

| Code | Value | Description |
|------|-------|-------------|
| `CODE_INT8` | `0x00` | 8-bit signed integer |
| `CODE_INT16` | `0x01` | 16-bit signed integer |
| `CODE_INT32` | `0x02` | 32-bit signed integer |
| `CODE_INT64` | `0x03` | 64-bit signed integer |
| `CODE_SHARED8` | `0x04` | 8-bit reference to shared data |
| `CODE_SHARED16` | `0x05` | 16-bit reference to shared data |
| `CODE_SHARED32` | `0x06` | 32-bit reference to shared data |
| `CODE_SHARED64` | `0x14` | 64-bit reference to shared data |
| `CODE_BLOCK32` | `0x08` | Block with 32-bit header |
| `CODE_BLOCK64` | `0x13` | Block with 64-bit header |
| `CODE_STRING8` | `0x09` | String with 8-bit length |
| `CODE_STRING32` | `0x0A` | String with 32-bit length |
| `CODE_STRING64` | `0x15` | String with 64-bit length |
| `CODE_DOUBLE_NATIVE` | `0x0B/0x0C` | 64-bit float (endianness-dependent) |
| `CODE_DOUBLE_ARRAY8_NATIVE` | `0x0D/0x0E` | Float array with 8-bit count |
| `CODE_DOUBLE_ARRAY32_NATIVE` | `0x0F/0x07` | Float array with 32-bit count |
| `CODE_DOUBLE_ARRAY64_NATIVE` | `0x16/0x17` | Float array with 64-bit count |

## Data Type Encodings

### 1. Small Integers (Immediate Values)

Small integers are encoded very efficiently:

- **Range 0-63**: Single byte `0x40 + n`
- **Range -128 to 127**: `CODE_INT8` (0x00) + 1 byte
- **Range -32768 to 32767**: `CODE_INT16` (0x01) + 2 bytes (big-endian)
- **32-bit range**: `CODE_INT32` (0x02) + 4 bytes (big-endian)
- **64-bit range**: `CODE_INT64` (0x03) + 8 bytes (big-endian)

**Example**: 
- Integer `42` → `0x6A` (single byte: `0x40 + 42`)
- Integer `1000` → `0x01 0x03 0xE8` (CODE_INT16 + big-endian 1000)

### 2. Strings

Strings are encoded with a length prefix followed by the raw bytes:

- **Length < 32**: `PREFIX_SMALL_STRING + len` (1 byte) + string data
- **Length < 256**: `CODE_STRING8` (0x09) + length (1 byte) + string data
- **Length < 2³²**: `CODE_STRING32` (0x0A) + length (4 bytes) + string data
- **Length ≥ 2³²** (64-bit only): `CODE_STRING64` (0x15) + length (8 bytes) + string data

**Example**:
- String `"Hello"` → `0x25 0x48 0x65 0x6C 0x6C 0x6F` 
  - `0x25` = `PREFIX_SMALL_STRING + 5`
  - Followed by ASCII bytes for "Hello"

### 3. Blocks (Tuples, Lists, Records, Variants)

Blocks represent structured data and are encoded with a header containing tag and size:

#### Small Blocks (tag < 16, size < 8)
- Single byte: `PREFIX_SMALL_BLOCK + tag + (size << 4)`
- Followed by marshalled values of each field

#### Regular Blocks
- `CODE_BLOCK32` (0x08) + 4-byte header
- Or `CODE_BLOCK64` (0x13) + 8-byte header (for large blocks on 64-bit)
- Header format: OCaml header with size, tag, and color bits
- Followed by marshalled values of each field

**Example**:
- Empty list `[]` → `0x80` (small block with tag 0, size 0)
- Tuple `(1, 2)` → `0x80 0x41 0x42`
  - `0x80` = small block, tag 0, size 2
  - `0x41` = integer 1
  - `0x42` = integer 2

### 4. Shared Data (Cyclic Structures)

When marshalling with sharing enabled (default), previously seen heap blocks are encoded as references:

- First occurrence: Normal encoding + record position in hash table
- Subsequent occurrences: Shared reference encoding

**Shared Reference Encoding**:
- **Distance < 256**: `CODE_SHARED8` (0x04) + 1-byte offset
- **Distance < 65536**: `CODE_SHARED16` (0x05) + 2-byte offset  
- **Distance < 2³²**: `CODE_SHARED32` (0x06) + 4-byte offset
- **Distance ≥ 2³²**: `CODE_SHARED64` (0x14) + 8-byte offset

The distance is either:
- Relative: Number of objects back from current position (default)
- Absolute: Absolute position in object stream (when `COMPRESSED` flag is set)

**Example**:
```ocaml
let rec cyclic = 1 :: 2 :: cyclic
```
When marshalled, the second occurrence of the list would be encoded as a shared reference pointing back to the first occurrence.

### 5. Special Types

#### Floats (Double_tag)
- `CODE_DOUBLE_NATIVE` + 8 bytes (IEEE 754 format)
- Endianness depends on platform

#### Float Arrays (Double_array_tag)
- Count < 256: `CODE_DOUBLE_ARRAY8_NATIVE` + count (1 byte) + data
- Count < 2³²: `CODE_DOUBLE_ARRAY32_NATIVE` + count (4 bytes) + data
- Count ≥ 2³² (64-bit): `CODE_DOUBLE_ARRAY64_NATIVE` + count (8 bytes) + data

#### Custom Blocks
- `CODE_CUSTOM_LEN` (0x18) or `CODE_CUSTOM_FIXED` (0x19)
- Followed by null-terminated identifier string
- Custom serialization data (format depends on custom operations)

## Marshalling Process

1. **Initialization**: Set up output buffer and position tracking table
2. **Traversal**: Depth-first traversal of the value graph
3. **Sharing Detection**: Check hash table for previously marshalled objects
4. **Encoding**: Write appropriate tag and data for each value
5. **Position Recording**: Add heap blocks to position table for sharing
6. **Compression** (optional): Compress the output using Zstandard

## Flags

Marshalling behavior can be modified with flags:

- **NO_SHARING** (1): Disable sharing detection (may duplicate shared values)
- **CLOSURES** (2): Allow marshalling of function closures
- **COMPAT_32** (4): Ensure output is readable on 32-bit platforms
- **COMPRESSED** (8): Enable Zstandard compression

## Size Considerations

The marshaller tracks two size metrics:
- **size_32**: Size in words when read on a 32-bit platform
- **size_64**: Size in words when read on a 64-bit platform

These ensure proper memory allocation during unmarshalling on different architectures.

## Limitations

- Abstract values cannot be marshalled
- Continuation values cannot be marshalled
- Custom blocks require registered serialization functions
- Objects with closures require the `CLOSURES` flag
- Very large objects may not be compatible with 32-bit platforms
