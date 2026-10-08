"""Independent streaming PNG validator, no full-image allocation."""
import struct, zlib, sys
patterns = [bytes([0]) + b''.join(bytes(((x*7+y)%256,(y*3+x)%256,(x^y)&255,(x+y)%256)) for x in range(2000)) for y in range(256)]
rows=0; pending=bytearray(); decoder=zlib.decompressobj(); ended=False
with open(sys.argv[1],'rb') as f:
 assert f.read(8)==b'\x89PNG\r\n\x1a\n'
 while True:
  header=f.read(8)
  if not header: break
  length,kind=struct.unpack('>I4s',header);data=f.read(length);crc=struct.unpack('>I',f.read(4))[0]
  assert zlib.crc32(kind+data)&0xffffffff==crc
  if kind==b'IHDR': assert struct.unpack('>IIBBBBB',data)==(2000,100000,8,6,0,0,0)
  if kind==b'IDAT':
   while data:
    pending.extend(decoder.decompress(data,32768));data=decoder.unconsumed_tail
    while len(pending)>=8001:
     assert pending[:8001]==patterns[rows%256], f'Pixel mismatch on row {rows}'
     del pending[:8001];rows+=1
  if kind==b'IEND': ended=True;break
assert ended and decoder.eof and rows==100000 and not pending
print('PASS: 200,000,000 RGBA pixels and all PNG CRCs match; streamed verification')
