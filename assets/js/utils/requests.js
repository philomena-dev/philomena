/**
 * Request Utils
 */

import { wait } from './async';

function fetchJson(verb, endpoint, body) {
  const data = {
    method: verb,
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json',
      'x-csrf-token': window.booru.csrfToken,
      'x-requested-with': 'xmlhttprequest'
    },
  };

  if (body) {
    body._method = verb;
    data.body = JSON.stringify(body);
  }

  return fetch(endpoint, data);
}

function fetchHtml(endpoint) {
  return fetch(endpoint, {
    credentials: 'same-origin',
    headers: {
      'x-csrf-token': window.booru.csrfToken,
      'x-requested-with': 'xmlhttprequest'
    },
  });
}

function handleError(response) {
  if (!response.ok) {
    throw new Error('Received error from server');
  }
  return response;
}

/** @returns {Promise<Response>} */
function fetchBackoff(...fetchArgs) {
  /**
   * @param timeout {number}
   * @returns {Promise<Response>}
   */
  function fetchBackoffTimeout(timeout) {
    // Adjust timeout
    const newTimeout = Math.min(timeout * 2, 300000);

    // Try to fetch the thing
    return fetch(...fetchArgs)
      .then(handleError)
      .catch(() =>
        wait(timeout).then(fetchBackoffTimeout(newTimeout))
      );
  }

  return fetchBackoffTimeout(5000);
}

/**
 * Escape a filename for inclusion in a Content-Disposition
 * response header.
 *
 * @param {string} name
 * @returns {string}
 */
function escapeFilename(name) {
  return name
    .replace(/[^.-_+a-zA-Z0-9]/, '_')
    .substring(0, 150);
}

/**
 * Run the wrapped function if the response was okay,
 * otherwise return the response.
 * @param {(_: Response) => Response} responseGenerator
 * @returns {(_: Response) => Response}
 */
function ifOk(responseGenerator) {
  return resp => {
    if (resp.ok) return responseGenerator(resp);
    return resp;
  };
}

export { fetchJson, fetchHtml, fetchBackoff, handleError, escapeFilename, ifOk };
