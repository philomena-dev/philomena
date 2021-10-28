/*
 * Miscellaneous utilities for asynchronous code.
 */

export function wait(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export function json(resp: Response): Promise<any> {
  return resp.json();
}

export function u8Array(resp: Response): Promise<Uint8Array> {
  return resp
    .arrayBuffer()
    .then(buf => new Uint8Array(buf));
}
