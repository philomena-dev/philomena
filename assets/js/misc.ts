/**
 * Misc
 */

import store from './utils/store';
import { $, $$, hideEl, showEl } from './utils/dom';
import { assertNotNull, assertType } from './utils/assert';

let touchMoved = false;

function formResult({ target, detail }: FetchcompleteEvent) {
  const elements: Record<string, string> = {
    '#description-form': '.js-image-description',
    '#uploader-form': '.image-uploader',
  };

  function showResult(formEl: HTMLFormElement, resultEl: HTMLElement, response: string) {
    resultEl.innerHTML = response;
    hideEl(formEl);
    showEl(resultEl);

    $$<HTMLInputElement | HTMLButtonElement>('input[type="submit"],button', formEl).forEach(button => {
      button.disabled = false;
    });
  }

  for (const [formSelector, resultSelector] of Object.entries(elements)) {
    if (target.matches(formSelector)) {
      const form = assertType(target, HTMLFormElement);
      const result = assertNotNull($<HTMLElement>(resultSelector));

      detail.text().then(text => showResult(form, result, text));
    }
  }
}

function revealSpoiler(event: MouseEvent | TouchEvent) {
  const target = assertType(event.target, HTMLElement);
  const spoiler = target.closest('.spoiler:not(.revealed)');
  const showContainer = target.closest('.image-show-container');
  let imgspoiler = target.closest('.spoiler .imgspoiler');

  // Prevent reveal if touchend came after touchmove event
  if (touchMoved) {
    touchMoved = false;
    return;
  }

  if (spoiler) {
    if (showContainer) {
      const imageShow = assertNotNull($<HTMLDivElement>('.js-image-show', showContainer));

      if (!imageShow.classList.contains('hidden') && imageShow.classList.contains('js-spoiler-pending')) {
        imageShow.classList.remove('js-spoiler-pending');
        return;
      }
    }

    spoiler.classList.add('revealed');
    // Prevent click-through to links on mobile platforms
    if (event.type === 'touchend') event.preventDefault();

    if (!imgspoiler) {
      imgspoiler = $<HTMLElement>('.imgspoiler', spoiler);
    }
  }

  if (imgspoiler) {
    imgspoiler.classList.remove('imgspoiler');
    imgspoiler.classList.add('js-imgspoiler-revealed');

    if (event.type === 'touchend' && !event.defaultPrevented) {
      event.preventDefault();
    }
  }
}

export function setupEvents() {
  const extrameta = $<HTMLElement>('#extrameta');

  if (extrameta && store.get('hide_uploader')) {
    hideEl(extrameta);
  }

  if (store.get('hide_score')) {
    $$<HTMLElement>('.js-upvote-count,.js-score,.js-downvote-count').forEach(s => hideEl(s));
  }

  document.addEventListener('fetchcomplete', formResult);
  document.addEventListener('click', revealSpoiler);
  document.addEventListener('touchend', revealSpoiler);
  document.addEventListener('touchmove', () => {
    touchMoved = true;
  });
}
