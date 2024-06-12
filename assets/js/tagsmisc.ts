/**
 * Tags Misc
 */

import { $, $$ } from './utils/dom';
import store from './utils/store';
import { initTagDropdown } from './tags';
import { setupTagsInput, reloadTagsInput } from './tagsinput';
import { TagSourceEvent } from './sources';

type TagInputActionFunction = (tagInput: HTMLTextAreaElement | null) => void
type TagInputActionList = {
  save: TagInputActionFunction,
  load: TagInputActionFunction,
  clear: TagInputActionFunction,
}

function tagInputButtons({target}: PointerEvent) {
  const actions: TagInputActionList = {
    save(tagInput: HTMLTextAreaElement | null) {
      if (tagInput) store.set('tag_input', tagInput.value);
    },
    load(tagInput: HTMLTextAreaElement | null) {
      if (!tagInput) { return; }

      // If entry 'tag_input' does not exist, try to use the current list
      tagInput.value = store.get('tag_input') || tagInput.value;
      reloadTagsInput(tagInput);
    },
    clear(tagInput: HTMLTextAreaElement | null) {
      if (!tagInput) { return; }

      tagInput.value = '';
      reloadTagsInput(tagInput);
    },
  };

  for (const action in actions) {
    if (target && (target as HTMLElement).matches(`#tagsinput-${action}`)) {
      actions[action as keyof TagInputActionList]($<HTMLTextAreaElement>('image_tag_input'));
    }
  }
}

function setupTags() {
  $$<HTMLDivElement>('.js-tag-block').forEach(el => {
    setupTagsInput(el);
    el.classList.remove('js-tag-block');
  });
}

function updateTagSauce({target, detail}: TagSourceEvent) {
  const tagSauce = $<HTMLDivElement>('.js-tagsauce');

  if (tagSauce && target.matches('#tags-form')) {
    detail.text().then(text => {
      tagSauce.outerHTML = text;
      setupTags();
      initTagDropdown();
    });
  }
}

function setupTagEvents() {
  setupTags();
  document.addEventListener('fetchcomplete', updateTagSauce as EventListener);
  document.addEventListener('click', tagInputButtons as EventListener);
}

export { setupTagEvents };
