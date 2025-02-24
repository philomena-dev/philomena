import { retry } from './retry';

interface RequestParams extends RequestInit {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  query?: Record<string, string>;
  headers?: Record<string, string>;
}

/**
 * Generic HTTP Client with some batteries included:
 *
 * - Handles rendering of the URL with query parameters
 * - Throws an error on non-OK responses
 * - Automatically retries failed requests
 * - Embeds a `X-Request-Id` and `X-Retry-Attempt` in the headers.
 * - ...Some other method-specific goodies
 */
export class HttpClient {
  // There isn't any state in this class at the time of this writing, but
  // we may add some in the future to allow for more advanced base configuration.

  /**
   * Issues a request, expecting a JSON response.
   */
  async fetchJson<T>(path: string, params: RequestParams): Promise<T> {
    if (params.headers?.Accept) {
      throw new Error('Manually defined "Accept" header is not allowed in "fetchJson"');
    }

    // TODO: figure out how to enable `Accept: application/json` plug in
    // the routes on backend.
    // (params.headers ??= {}).Accept = 'application/json';

    const response = await this.fetch(path, params);
    return response.json();
  }

  async fetch(path: string, params: RequestParams): Promise<Response> {
    const url = new URL(path, window.location.origin);

    for (const [key, value] of Object.entries(params.query ?? {})) {
      url.searchParams.set(key, value);
    }

    params.headers ??= {};

    // This header serves as an idempotency token that identifies the sequence
    // of retries of the same request. The backend may use this information to
    // ensure that the same retried request doesn't result in multiple accumulated
    // side-effects.
    params.headers['X-Retry-Sequence-Id'] = generateId('rs-');

    return retry(
      async (attempt: number) => {
        params.headers!['X-Request-Id'] = generateId('req-');
        params.headers!['X-Retry-Attempt'] = String(attempt);

        // TODO: we should respect the `Retry-After` header from the response,
        // to allow for granular rerty control from the backend side.
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Retry-After
        const response = await fetch(url, params);

        if (!response.ok) {
          throw new Error('Received error from server', { cause: response });
        }

        return response;
      },
      { isRetryable, label: `HTTP ${params.method ?? 'GET'} ${url}` },
    );
  }
}

function isRetryable(error: unknown): boolean {
  return !(error instanceof Error && error.name === 'AbortError');
}

/**
 * Generates a base32 ID with the given prefix as the request ID discriminator.
 * The prefix is useful when reading or grepping thru logs to identify the type
 * of the ID (i.e. it's visually clear that strings that start with `req-` are
 * request IDs).
 */
function generateId(prefix: string) {
  // Base32 alphabet without any ambiguous characters.
  // (details: https://github.com/maksverver/key-encoding#eliminating-ambiguous-characters)
  const alphabet = '23456789abcdefghjklmnpqrstuvwxyz';

  const chars = [prefix];

  for (let i = 0; i < 10; i++) {
    chars.push(alphabet[Math.floor(Math.random() * alphabet.length)]);
  }

  return chars.join('');
}
