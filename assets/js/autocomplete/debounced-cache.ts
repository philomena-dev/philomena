export interface DebouncedCacheParams {
  /**
   * Time in milliseconds to wait before calling the function.
   */
  thresholdMs?: number;
}

/**
 * Wraps a function, caches its results and debounces calls to it.
 *
 * *Debouncing* means that if the function is called multiple times within
 * the `thresholdMs` interval, then every new call resets the timer
 * and only the last call to the function will be executed after the timer
 * reaches the `thresholdMs` value. Also, in-progress operation
 * will be aborted.
 *
 * See more details about the concept of debouncing here:
 * https://lodash.com/docs/4.17.15#debounce.
 *
 *
 * If the function is called with the arguments that were already cached,
 * then the cached result will be returned immediately and the previous
 * scheduled call will be cancelled.
 */
export class DebouncedCache<Args extends unknown[], R> {
  private thresholdMs: number;
  private cache = new Map<string, Promise<R>>();
  private func: (...args: [...Args, AbortSignal]) => Promise<R>;

  private lastSchedule?: {
    timeout: ReturnType<typeof setTimeout>;
    abortController: AbortController;
  };

  /**
   * The `func`'s arguments' JSON representation will be used as the cache key.
   * The `func` will also be provided with an `AbortSignal` as the last argument.
   * that it can use to abort the operation when a new call is scheduled while
   * it's executing.
   */
  constructor(func: (...args: [...Args, abortSignal: AbortSignal]) => Promise<R>, params?: DebouncedCacheParams) {
    this.thresholdMs = params?.thresholdMs ?? 300;
    this.func = func;
  }

  /**
   * Schedules a call to the wrapped function, that will take place only after
   * a `thresholdMs` delay given no new calls to `schedule` are made within that
   * time frame. If they are made, than the scheduled call will be canceled and
   * the abort signal will be triggered for the previous call.
   */
  schedule(...params: [...Args, onResult: (result: R) => void]): void {
    this.abortLastSchedule(`[DebouncedCache] A new call to '${this.func.name}' was scheduled`);

    // There is no native support for destructuring after an ellipsis, so we have
    // to do some type casting work here.
    const callback = params.pop() as (result: R) => void;
    const args = params as unknown as Args;

    const key = JSON.stringify(args);

    if (this.cache.has(key)) {
      this.onFulfilled(this.cache.get(key)!, callback);
      return;
    }

    const abortController = new AbortController();

    const afterTimeout = () => {
      const promise = this.func.call(null, ...(args as unknown as Args), abortController.signal);

      // We don't remove an entry from the cache if the promise is rejected.
      // We expect that the underlying function will handle the errors and
      // do the retries if necessary.
      this.cache.set(key, promise);

      this.onFulfilled(promise, callback);
    };

    this.lastSchedule = {
      timeout: setTimeout(afterTimeout, this.thresholdMs),
      abortController,
    };
  }

  async onFulfilled(resultPromise: Promise<R>, onResult: (result: R) => void): Promise<void> {
    let result;
    try {
      result = await resultPromise;
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        console.debug(`A call to '${this.func.name}' was aborted while it was in progress.`, error);
        return;
      }

      throw error;
    }

    onResult(result);
  }

  abortLastSchedule(reason: string): void {
    if (!this.lastSchedule) {
      return;
    }

    clearTimeout(this.lastSchedule.timeout);
    this.lastSchedule.abortController.abort(new DOMException(reason, 'AbortError'));
  }
}
