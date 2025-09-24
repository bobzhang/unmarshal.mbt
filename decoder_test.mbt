test {

  // ocaml 1 marshalled 
  let data: Bytes = 
    [b'\x84',b'\x95',b'\xa6',b'\xbe',b'\x00',b'\x00',b'\x00',b'\x02',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x00',b'\x7b',]
  
  let state = @unmarshal.Decoder::new(data)
  let (a, b) = state.decode()
  //TODO:upstream Tuple2 impl ToJson
  @json.inspect((a,b))
  
}