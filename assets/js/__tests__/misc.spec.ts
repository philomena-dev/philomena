import { fireEvent, waitFor } from '@testing-library/dom';
import { fixEventListeners } from '../../test/fix-event-listeners';
import { $ } from '../utils/dom';
import store from '../utils/store';
import { setupEvents } from '../misc';

fixEventListeners(document);

describe('misc.ts setupEvents', () => {
  afterEach(() => {
    localStorage.clear();
  });

  describe('spoilers', () => {
    beforeEach(() => {
      setupEvents();
    });

    it('reveals spoiler text for good on click', () => {
      document.body.innerHTML = '<p><span class="spoiler">the <a href="#">butler</a></span> did it</p>';
      const spoiler = $<HTMLElement>('.spoiler')!;

      fireEvent.click($<HTMLElement>('a', spoiler)!);
      expect(spoiler.className).toBe('spoiler revealed');

      fireEvent.click(spoiler);
      expect(spoiler.className).toBe('spoiler revealed');

      fireEvent.click($<HTMLElement>('p')!);
      expect(spoiler.className).toBe('spoiler revealed');
    });

    it('reveals the image in a spoiler, without following its link on a touch screen', () => {
      document.body.innerHTML = `
        <span class="spoiler"><a href="/images/1"><span class="imgspoiler"><img></span></a></span>
        <span class="spoiler">text, <span class="imgspoiler"><img></span><span class="imgspoiler"><img id="second"></span></span>
      `;
      const [linked, unlinked] = document.querySelectorAll<HTMLElement>('.spoiler');

      expect(fireEvent.touchEnd($<HTMLElement>('img', linked)!)).toBe(false);
      expect(linked.className).toBe('spoiler revealed');
      expect($('.js-imgspoiler-revealed', linked)).toBeTruthy();

      fireEvent.click(unlinked);
      expect(unlinked.className).toBe('spoiler revealed');
      expect(unlinked.querySelectorAll('.js-imgspoiler-revealed')).toHaveLength(1);

      expect(fireEvent.touchEnd($<HTMLElement>('#second')!)).toBe(false);
      expect(unlinked.querySelectorAll('.js-imgspoiler-revealed')).toHaveLength(2);
    });

    it('ignores the touch that ends a scroll', () => {
      document.body.innerHTML = '<span class="spoiler">text</span>';
      const spoiler = $<HTMLElement>('.spoiler')!;

      fireEvent.touchMove(spoiler);
      fireEvent.touchEnd(spoiler);
      expect(spoiler.className).toBe('spoiler');

      fireEvent.touchEnd(spoiler);
      expect(spoiler.className).toBe('spoiler revealed');
    });

    it('first shows a spoilered embedded image, then reveals the spoiler around it', () => {
      document.body.innerHTML = `
        <span class="spoiler">
          <div class="image-show-container">
            <div class="js-image-show js-spoiler-pending"><span class="imgspoiler"><img></span></div>
          </div>
        </span>
      `;
      const spoiler = $<HTMLElement>('.spoiler')!;
      const imageShow = $<HTMLElement>('.js-image-show')!;

      fireEvent.click($<HTMLElement>('img')!);
      expect(imageShow.classList).not.toContain('js-spoiler-pending');
      expect(spoiler.className).toBe('spoiler');

      fireEvent.click($<HTMLElement>('img')!);
      expect(spoiler.className).toBe('spoiler revealed');
      expect($('.js-imgspoiler-revealed')).toBeTruthy();
    });

    it('reveals a spoiler around an embedded image that is filtered out', () => {
      document.body.innerHTML = `
        <span class="spoiler">
          <div class="image-show-container"><div class="js-image-show hidden js-spoiler-pending"></div></div>
        </span>
      `;

      fireEvent.click($<HTMLElement>('.image-show-container')!);
      expect($<HTMLElement>('.spoiler')!.className).toBe('spoiler revealed');
    });
  });

  it('hides the uploader and the scores when the settings say so', () => {
    store.set('hide_uploader', true);
    store.set('hide_score', true);
    document.body.innerHTML = `
      <div id="extrameta"></div>
      <span class="upvotes"></span><span class="score"></span><span class="downvotes"></span>
    `;

    setupEvents();

    for (const selector of ['#extrameta', '.upvotes', '.score', '.downvotes']) {
      expect($<HTMLElement>(selector)!.classList).toContain('hidden');
    }
  });

  it('shows what an edit form answered in place of the form', async () => {
    setupEvents();
    document.body.innerHTML = `
      <div class="js-image-description hidden">old</div>
      <form id="description-form"><input type="submit" disabled></form>
      <form id="other-form"></form>
    `;
    const form = $<HTMLFormElement>('#description-form')!;
    const result = $<HTMLElement>('.js-image-description')!;

    fireEvent(
      $<HTMLFormElement>('#other-form')!,
      new CustomEvent('fetchcomplete', { bubbles: true, detail: new Response('other') }),
    );
    fireEvent(form, new CustomEvent('fetchcomplete', { bubbles: true, detail: new Response('<p>new</p>') }));

    await waitFor(() => expect(result.innerHTML).toBe('<p>new</p>'));
    expect(result.classList).not.toContain('hidden');
    expect(form.classList).toContain('hidden');
    expect($<HTMLInputElement>('input', form)!.disabled).toBe(false);
  });
});
