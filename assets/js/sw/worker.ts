import { handleBulk } from './bulk';
import { handleDownload } from './download';

// Declarations for TypeScript
declare const self: ServiceWorkerGlobalScope;
export default null;

/**
 * Performs routing under the ServiceWorker path scope.
 */
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  if (url.pathname === '/js/stream') return handleBulk(event, url);
  if (url.pathname === '/js/download') return handleDownload(event, url);

  return event.respondWith(fetch(event.request));
});
