// https://stackoverflow.com/q/21001659
export function crc32(buf: ArrayBuffer): number {
  const view = new DataView(buf);
  let crc = 0 ^ -1;

  for (let i = 0; i < view.byteLength; i++) {
    crc ^= view.getUint8(i);
    for (let j = 0; j < 8; j++) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }

  return ~crc;
}

// https://caniuse.com/textencoder
export function asciiEncode(s: string): ArrayBuffer {
  const buf = new ArrayBuffer(s.length);
  const view = new DataView(buf);

  for (let i = 0; i < s.length; i++) {
    view.setUint8(i, s.charCodeAt(i) & 0xff);
  }

  return buf;
}

export type LEInt = [1 | 2 | 4 | 8, number];
export function serialize(values: LEInt[]): ArrayBuffer {
  const bufSize = values.reduce((acc, int) => acc + int[0], 0);
  const buf = new ArrayBuffer(bufSize);
  const view = new DataView(buf);
  let offset = 0;

  for (const [size, value] of values) {
    if (size === 1) view.setUint8(offset, value);
    if (size === 2) view.setUint16(offset, value, true);
    if (size === 4) view.setUint32(offset, value, true);
    if (size === 8) view.setBigUint64(offset, BigInt(value), true);

    offset += size;
  }

  return buf;
}
