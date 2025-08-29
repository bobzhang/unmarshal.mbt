test {
  // Marshal.to_bytes 1 [];;
  // - : bytes =
  // let data = b"\132\149\166\190\000\000\000\001\000\000\000\000\000\000\000\000\000\000\000\000A"
  let data = b"\x84\x95\xA6\xBE\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00A"
  // let data = b""
  let state = @unmarshal.DecoderState::{
    objects: [],
    position: 0,
    data,
  }
  let (a, b) = state.decode()
  //TODO:upstream Tuple2 impl ToJson
  @json.inspect(a)
  @json.inspect(b)
}