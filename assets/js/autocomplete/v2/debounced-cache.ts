export interface DebouncedCacheParams {
  /**
   * Time in milliseconds to wait before calling the function.
   */
  debounceThresholdMs?: number;
}

/**
 * Wraps a function, caches its results and debounces calls to its.
 *
 * See more details about the concept of debouncing here:
 * https://lodash.com/docs/4.17.15#debounce.
 *
 * If the function is called multiple times within the `waitMs` interval,
 * only the last call will be actually made.
 *
 * If the function is called with the arguments that were already cached,
 * then the cached result will be returned immediately and the previous
 * scheduled call will be cancelled.
 */
export class DebouncedCache<Args extends unknown[], R> {
  private debounceThresholdMs: number;
  private func: (...args: [...Args, AbortSignal]) => Promise<R>;
  private cache = new Map<string, Promise<R>>();

  private lastSchedule?: {
    timeout: ReturnType<typeof setTimeout>;
    abortController: AbortController;
  };

  constructor(func: (...args: [...Args, abortSignal: AbortSignal]) => Promise<R>, params?: DebouncedCacheParams) {
    this.debounceThresholdMs = params?.debounceThresholdMs ?? 300;
    this.func = func;
  }

  schedule(...params: [...Args, onResult: (result: R) => void]): void {
    this.abortLastCall();

    // There is no native support for destructuring after an ellipsis, so we have
    // to do some type casting work here.
    const onResult = params.pop() as (result: R) => void;
    const args = params as unknown as Args;

    const key = JSON.stringify(args);

    if (this.cache.has(key)) {
      this.onFulfilled(this.cache.get(key)!, onResult);
      return;
    }

    const abortController = new AbortController();

    const afterTimeout = () => {
      const promise = this.func.call(null, ...(args as unknown as Args), abortController.signal);

      // We don't remove an entry from the cache if the promise is rejected.
      // We expect that the underlying function will handle the errors and
      // do the retries if necessary.
      this.cache.set(key, promise);

      this.onFulfilled(promise, onResult);
    };

    this.lastSchedule = {
      timeout: setTimeout(afterTimeout, this.debounceThresholdMs),
      abortController,
    };
  }

  async onFulfilled(resultPromise: Promise<R>, onResult: (result: R) => void): Promise<void> {
    let result;
    try {
      result = await resultPromise;
    } catch (error) {
      if (error instanceof DOMException && error.name !== 'AbortError') {
        console.debug(`A call to ${this.func.name} was aborted while it was in progress.`, error);
        return;
      }

      throw error;
    }

    onResult(result);
  }

  abortLastCall(): void {
    if (!this.lastSchedule) {
      return;
    }

    clearTimeout(this.lastSchedule.timeout);
    this.lastSchedule.abortController.abort();
  }
}
