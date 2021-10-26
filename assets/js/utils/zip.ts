import { crc32, asciiEncode, serialize } from './binary';

interface FileInfo {
    headerOffset: number;
    byteLength: number;
    crc32: number;
    name: ArrayBuffer;
}

// See https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
// for full details of the ZIP format.
export class Zip {
    fileInfo: { [key: string]: FileInfo };
    offset: number;

    constructor() {
      this.fileInfo = {};
      this.offset = 0;
    }

    storeFile(name: string, file: ArrayBuffer): Blob {
      const crc = crc32(file);
      const ns = asciiEncode(name);

      this.fileInfo[name] = {
        headerOffset: this.offset,
        byteLength: file.byteLength,
        crc32: crc,
        name: ns
      };

      const localField = serialize([
        [2, 0x0001],                /* zip64 local field */
        [2, 0x0010],                /* local field length (excl. header) */
        [8, file.byteLength],       /* compressed size */
        [8, file.byteLength]        /* uncompressed size */
      ]);

      const header = serialize([
        [4, 0x04034b50],            /* local header signature */
        [2, 0x002d],                /* version = zip64 */
        [2, 0x0000],                /* flags = none */
        [2, 0x0000],                /* compression = store */
        [2, 0x0000],                /* time = 00:00 */
        [2, 0x0000],                /* date = 1980-01-01 */
        [4, crc],                   /* file crc32 */
        [4, 0xffffffff],            /* zip64 compressed size */
        [4, 0xffffffff],            /* zip64 uncompressed size */
        [2, ns.byteLength],         /* length of name */
        [2, localField.byteLength]  /* length of local field */
      ]);

      this.offset += header.byteLength + ns.byteLength + localField.byteLength + file.byteLength;
      return new Blob([header, ns, localField, file]);
    }

    finalize(): Blob {
      const segments = [];
      const cdOff = this.offset;
      let numFiles = 0;

      for (const name in this.fileInfo) {
        const info = this.fileInfo[name];

        const cdField = serialize([
          [2, 0x0001],                /* zip64 central field */
          [2, 0x0018],                /* central field length (excl. header) */
          [8, info.byteLength],       /* compressed size */
          [8, info.byteLength],       /* uncompressed size */
          [8, info.headerOffset]      /* local header offset */
        ]);

        const cdEntry = serialize([
          [4, 0x02014b50],            /* CD entry signature */
          [2, 0x002d],                /* created with zip64 */
          [2, 0x002d],                /* extract with zip64 */
          [2, 0x0000],                /* flags = none */
          [2, 0x0000],                /* compression = store */
          [2, 0x0000],                /* time = 00:00 */
          [2, 0x0000],                /* date = 1980-01-01 */
          [4, info.crc32],            /* file crc32 */
          [4, 0xffffffff],            /* zip64 compressed size */
          [4, 0xffffffff],            /* zip64 uncompressed size */
          [2, info.name.byteLength],  /* length of name */
          [2, cdField.byteLength],    /* length of central field */
          [2, 0x0000],                /* comment length */
          [2, 0x0000],                /* disk number */
          [2, 0x0000],                /* internal attributes */
          [4, 0x00000000],            /* external attributes */
          [4, 0xffffffff],            /* zip64 local header offset */
        ]);

        this.offset += cdEntry.byteLength + info.name.byteLength + cdField.byteLength;
        segments.push(cdEntry, info.name, cdField);

        numFiles++;
      }

      const endCdOff = this.offset;
      const endCd64 = serialize([
        [4, 0x06064b50],        /* zip64 end of CD signature */
        [8, 44],                /* size of end of CD */
        [2, 0x002d],            /* created with zip64 */
        [2, 0x002d],            /* extract with zip64 */
        [4, 0x00000000],        /* this disk number */
        [4, 0x00000000],        /* starting disk number */
        [8, numFiles],          /* number of files on this disk */
        [8, numFiles],          /* total number of files */
        [8, endCdOff - cdOff],  /* size of CD */
        [8, cdOff]              /* location of CD */
      ]);

      const endLoc64 = serialize([
        [4, 0x07064b50],        /* zip64 end of CD locator */
        [4, 0x00000000],        /* disk number of CD */
        [8, endCdOff],          /* location of end of CD */
        [4, 1]                  /* number of disks */
      ]);

      const endCd = serialize([
        [4, 0x06054b50],        /* end of CD */
        [2, 0x0000],            /* this disk number */
        [2, 0x0000],            /* starting disk number */
        [2, numFiles],          /* number of files on this disk */
        [2, numFiles],          /* total number of files */
        [4, endCdOff - cdOff],  /* size of CD */
        [4, 0xffffffff],        /* zip64 location of CD */
        [2, 0x0000]             /* comment length */
      ]);

      this.offset += endCd64.byteLength + endLoc64.byteLength + endCd.byteLength;
      segments.push(endCd64, endLoc64, endCd);

      return new Blob(segments);
    }
}
