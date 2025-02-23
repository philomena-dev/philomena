export interface RetryParams {
  /**
   * Maximum number of attempts to retry the operation. The first attempt counts
   * too, so setting this to 1 is equivalent to no retries.
   */
  maxAttempts?: number;

  /**
   * Initial delay for the first retry. Subsequent retries will be exponentially
   * delayed up to `maxDelayMs`.
   */
  minDelayMs?: number;

  /**
   * Max value a delay can reach. This is useful to avoid unreasonably long
   * delays that can be reached at a larger number of retries where the delay
   * grows exponentially very fast.
   */
  maxDelayMs?: number;

  /**
   * If present determines if the error should be retried or immediately re-thrown.
   */
  isRetryable?(error: unknown): boolean;

  /**
   * Human-readable message to identify the operation being retried. By default
   * the function name is used.
   */
  label?: string;
}

/**
 * Retry an async operation with exponential backoff and jitter.
 *
 * This is based on the following AWS paper:
 * https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
 */
export async function retry<R>(func: (attempt: number) => Promise<R>, params?: RetryParams): Promise<R> {
  const maxAttempts = params?.maxAttempts ?? 3;

  if (maxAttempts < 1) {
    throw new Error(`Invalid 'maxAttempts' for retry: ${maxAttempts}`);
  }

  const minDelayMs = params?.minDelayMs ?? 200;

  if (minDelayMs < 0) {
    throw new Error(`Invalid 'minDelayMs' for retry: ${minDelayMs}`);
  }

  const maxDelayMs = params?.maxDelayMs ?? 1500;

  if (maxDelayMs < 0) {
    throw new Error(`Invalid 'maxDelayMs' for retry: ${maxDelayMs}`);
  }

  const label = params?.label || func.name || '{unnamed routine}';

  const backoffExponent = 2;

  let attempt = 1;
  let delay = 200;

  while (true) {
    try {
      // XXX: an `await` is important in this block to make sure the exception is caught
      // in this scope. Doing a `return func()` would be a big mistake, so don't try
      // to "refactor" that!
      const result = await func(attempt);
      return result;
    } catch (error) {
      if (params?.isRetryable && !params.isRetryable(error)) {
        throw error;
      }

      // Equal jitter algorithm taken from AWS blog post's code reference:
      // https://github.com/aws-samples/aws-arch-backoff-simulator/blob/66cb169277051eea207dbef8c7f71767fe6af144/src/backoff_simulator.py#L35-L38
      const expo = Math.min(maxDelayMs, minDelayMs * backoffExponent ** attempt);
      const halfExpo = expo / 2;
      delay = halfExpo + randomBetween(0, halfExpo);

      attempt += 1;

      if (attempt > maxAttempts) {
        throw new Error(`All ${maxAttempts} attempts of running ${label} failed`, {
          cause: error,
        });
      }

      console.warn(
        `[Attempt ${attempt}/${maxAttempts}] Error when running ${label}. Retrying in ${delay} milliseconds...`,
        error,
      );

      await sleep(delay);
    }
  }
}

function randomBetween(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
