import { lerp } from '../lerp';

describe('Linear interpolation', () => {
  describe('lerp', () => {
    it('should interpolate the min-max range based on a delta', () => {
      expect(lerp(0.5, 0, 100)).toEqual(50);
      expect(lerp(0.75, 0, 100)).toEqual(75);
    });

    it('should clamp the value between min and max', () => {
      expect(lerp(-999, 0, 100)).toEqual(0);
      expect(lerp(0, 0, 100)).toEqual(0);
      expect(lerp(999, 0, 100)).toEqual(100);
      expect(lerp(1, 0, 100)).toEqual(100);
    });
  });
});
