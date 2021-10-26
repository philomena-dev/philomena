/// <reference lib="WebWorker" />

import { evenlyDivide } from 'utils/array';
import { fetchBackoff } from 'utils/requests';
import { Zip } from 'utils/zip';

declare const self: ServiceWorkerGlobalScope;

const wait = (ms: number): Promise<void> => new Promise(resolve => setTimeout(resolve, ms));
const buffer = (blob: Blob) => blob.arrayBuffer().then(buf => new Uint8Array(buf));
const json = (resp: Response) => resp.json();
const blob = (resp: Response) => resp.blob();

interface Image {
  id: number;
  name: string;
  view_url: string; // eslint-disable-line camelcase
}

interface PageResult {
  images: Image[];
  total: number;
}

function handleStream(event: FetchEvent, url: URL): void {
  const concurrency = parseInt(url.searchParams.get('concurrency') || '1', 5);
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

      return fetchBackoff(`/search/download?q=${nextQuery}`)
        .then(json)
        .then(({ images, total }: PageResult): Promise<void> => {
          if (total === 0) {
            // Done, no results left
            // Finalize zip and close stream to prevent any further pulls
            return buffer(zipper.finalize())
              .then(buf => {
                controller.enqueue(buf);
                controller.close();
              });
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
            .then(() => fetchBackoff(view_url)).then(blob).then(buffer)
            .then(file => zipper.storeFile(name, file.buffer)).then(buffer)
            .then(entry => controller.enqueue(entry))
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

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // Streaming path
  if (url.pathname === '/js/stream') return handleStream(event, url);

  // Otherwise, not destined for us
  return event.respondWith(fetch(event.request));
});

export default null;
