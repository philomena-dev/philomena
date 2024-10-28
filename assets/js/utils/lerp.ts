// Simple linear interpolation.
// Returns a value between min and max based on a delta.
// The delta is a number between 0 and 1.
// If the delta is not within the 0-1 range, this function will
// clamp the value between min and max, depending on whether
// the delta >= 1 or <= 0.
export function lerp(delta: number, from: number, to: number): number {
  if (delta >= 1) {
    return to;
  } else if (delta <= 0) {
    return from;
  }

  return from + (to - from) * delta;
}
