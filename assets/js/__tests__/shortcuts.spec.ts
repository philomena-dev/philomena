import { fireEvent } from '@testing-library/dom';
import { listenForKeys } from '../shortcuts';

interface WritableWindow {
  location: Location | string;
}

describe('Keyboard shortcuts', () => {
  let hovered: Element | null;

  beforeAll(() => {
    listenForKeys();

    // jsdom never matches :hover, so the pointer is simulated by answering those queries directly
    const querySelector = Document.prototype.querySelector;
    vi.spyOn(document, 'querySelector').mockImplementation(function (this: Document, selector: string) {
      if (selector.endsWith(':hover')) {
        return hovered && hovered.matches(selector.replace(':hover', '')) ? hovered : null;
      }
      return querySelector.call(this, selector);
    });
  });

  beforeEach(() => {
    hovered = null;
    document.body.innerHTML = `
      <div class="image-metabar">
        <a class="js-prev" href="#prev"></a><a class="js-up" href="#up"></a><a class="js-next" href="#next"></a>
        <a class="js-rand" href="#rand"></a>
        <a class="js-interaction-fave" data-image-id="1" href="#"></a>
        <a class="js-interaction-upvote" data-image-id="1" href="#"></a>
      </div>
      <a class="js-source-link" href="#source"></a>
      <button class="js-tag-sauce-toggle"></button>
      <div class="media-box" data-image-id="2">
        <a class="js-interaction-fave" data-image-id="2" href="#"></a>
        <a class="js-interaction-upvote" data-image-id="2" href="#"></a>
      </div>
      <div class="image-target" data-uris='{"full": "/full.png"}'></div>
      <input type="text">
    `;
  });

  const clicks = (selector: string) => {
    const handler = vi.fn((event: Event) => event.preventDefault());
    document.querySelectorAll(selector).forEach(el => el.addEventListener('click', handler));
    return handler;
  };

  const press = (key: string, target: Element = document.body, init: KeyboardEventInit = {}) =>
    fireEvent.keyDown(target, { key, code: `Key${key.toUpperCase()}`, ...init });

  it.each([
    ['j', '.js-prev'],
    ['i', '.js-up'],
    ['k', '.js-next'],
    ['r', '.js-rand'],
    ['s', '.js-source-link'],
    ['l', '.js-tag-sauce-toggle'],
    ['f', '.image-metabar .js-interaction-fave'],
    ['u', '.image-metabar .js-interaction-upvote'],
  ])('pressing %s clicks %s', (key, selector) => {
    const handler = clicks(selector);

    press(key);

    expect(handler).toHaveBeenCalledTimes(1);
  });

  it('faves and upvotes the thumbnail under the pointer instead of the image page', () => {
    hovered = document.querySelector('.media-box');
    const page = clicks('.image-metabar a');
    const fave = clicks('.media-box .js-interaction-fave');
    const upvote = clicks('.media-box .js-interaction-upvote');

    press('f');
    press('u');

    expect(fave).toHaveBeenCalledTimes(1);
    expect(upvote).toHaveBeenCalledTimes(1);
    expect(page).not.toHaveBeenCalled();
  });

  it('treats a hovered thumbnail without an image as no thumbnail', () => {
    hovered = document.querySelector('.media-box');
    hovered!.removeAttribute('data-image-id');
    const page = clicks('.image-metabar .js-interaction-fave');

    press('f');

    expect(page).toHaveBeenCalledTimes(1);
  });

  it('does nothing when the page lacks the target', () => {
    document.body.innerHTML = '';

    expect(() => press('j')).not.toThrow();
  });

  it('ignores keys typed into a field and keys with a modifier', () => {
    const handler = clicks('.js-next');
    const input = document.querySelector('input')!;
    input.focus();

    press('k', input);
    input.blur();
    press('k', document.body, { ctrlKey: true });
    press('q');

    expect(handler).not.toHaveBeenCalled();
  });

  describe('full view', () => {
    let realLocation: Location;

    beforeEach(() => {
      realLocation = window.location;
      delete (window as Partial<WritableWindow>).location;
      (window as WritableWindow).location = 'about:blank';
    });

    afterEach(() => {
      delete (window as Partial<WritableWindow>).location;
      (window as WritableWindow).location = realLocation;
    });

    it('opens the full image under the pointer, here and in a new tab', () => {
      const open = vi.spyOn(window, 'open').mockReturnValue(null);
      hovered = document.querySelector('.image-target');

      press('o');
      press('v');

      expect(window.location).toBe('/full.png');
      expect(open).toHaveBeenCalledWith('/full.png');
    });

    it('opens nothing without an image under the pointer', () => {
      const open = vi.spyOn(window, 'open').mockReturnValue(null);

      press('o');
      press('v');
      hovered = document.querySelector('.media-box');
      press('o');
      press('v');

      expect(window.location).toBe('about:blank');
      expect(open).not.toHaveBeenCalled();
    });
  });
});
