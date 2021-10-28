import { wait, json, u8Array } from 'utils/async';
import { evenlyDivide } from 'utils/array';
import { fetchBackoff } from 'utils/requests';
import { Zip } from 'utils/zip';

interface Image {
  id: number;
  name: string;
  view_url: string; // eslint-disable-line camelcase
}

interface PageResult {
  images: Image[];
  total: number;
}

export function handleBulk(event: FetchEvent, url: URL): void {
  const concurrency = parseInt(url.searchParams.get('concurrency') || '1', 10);
  const queryString = url.searchParams.get('q');
  const failures = [];
  const zipper = new Zip();

  if (!queryString) {
    return event.respondWith(new Response('No query specified', { status: 400 }));
  }

  // Maximum ID to fetch -- start with largest possible ID
  let maxId = (2 ** 31) - 1;

  const stream = new ReadableStream({
    pull(controller) {
      // Path to fetch next
      const nextQuery = encodeURIComponent(`(${queryString}),id.lte:${maxId}`);
      const consumer = (buf: Uint8Array) => controller.enqueue(buf);

      return fetchBackoff(`/search/download?q=${nextQuery}`)
        .then(json)
        .then(({ images, total }: PageResult): Promise<void> => {
          if (total === 0) {
            // Finalize zip
            zipper.finalize(consumer);

            // Close stream
            controller.close();

            // Done
            return Promise.resolve();
          }

          // Decrease maximum ID for next round below current minimum
          maxId = images[images.length - 1].id - 1;

          // Set up concurrent fetches
          const imageBins = evenlyDivide(images, concurrency);
          const fetchers = imageBins.map(downloadIntoZip);

          // Run all concurrent fetches
          return Promise
            .all(fetchers)
            .then(() => wait(5000));
        });


      // Function to fetch each image and push it into the zip stream
      function downloadIntoZip(images: Image[]): Promise<void> {
        let promise = Promise.resolve();

        // eslint-disable-next-line camelcase
        for (const { name, view_url } of images) {
          promise = promise
            .then(() => fetchBackoff(view_url).then(u8Array))
            .then(file => zipper.storeFile(name, file.buffer, consumer))
            .catch(() => { failures.push(view_url); });
        }

        return promise;
      }
    }
  });

  event.respondWith(new Response(stream, {
    headers: {
      'content-type': 'application/x-zip',
      'content-disposition': 'attachment; filename="image_export.zip"'
    }
  }));
}
