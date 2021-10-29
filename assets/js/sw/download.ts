import { escapeFilename, ifOk } from 'utils/requests';

function allowedOrigin(target: string): boolean {
  const selfUrl = new URL(self.location.toString());
  const cdnHost = selfUrl.searchParams.get('cdn');

  return new URL(target).hostname === cdnHost;
}

export function handleDownload(event: FetchEvent, url: URL): void {
  const target = url.searchParams.get('target');
  const name = url.searchParams.get('name');

  if (!target || !name || !allowedOrigin(target)) {
    return event.respondWith(new Response('Don\'t know what to download!', { status: 400 }));
  }

  const response =
    fetch(target)
      .then(ifOk((upstream: Response) => {
        const headers = new Headers(upstream.headers);

        headers.set('content-disposition', `attachment; filename="${escapeFilename(name)}"`);

        return new Response(upstream.body, { headers });
      }));

  event.respondWith(response);
}
