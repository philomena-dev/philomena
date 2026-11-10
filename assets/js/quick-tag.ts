/**
 * Quick Tag
 */

import store from './utils/store';
import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$, toggleEl } from './utils/dom';
import { fetchJson, handleError } from './utils/requests';
import { delegate, leftClick } from './utils/events';

const imageQueueStorage = 'quickTagQueue';
const currentTagStorage = 'quickTagName';

function currentQueue(): string[] {
  return store.get<string[]>(imageQueueStorage) || [];
}

function currentTags(): string {
  return store.get<string>(currentTagStorage) || '';
}

function setTagButton(text: string) {
  assertNotNull($('.js-quick-tag--submit span')).textContent = text;
}

// While tagging, the boxes of the queued images are marked as selected and the others as unselected
function markQueuedImages() {
  const tagging = Boolean(currentTags());
  const queue = currentQueue();

  for (const mediaBox of $$<HTMLElement>('.media-box[data-image-id]')) {
    const queued = queue.includes(assertNotUndefined(mediaBox.dataset.imageId));

    mediaBox.classList.toggle('media-success', tagging && queued);
    mediaBox.classList.toggle('media-danger', tagging && !queued);
  }
}

function toggleActiveState() {
  toggleEl($$<HTMLElement>('.js-quick-tag,.js-quick-tag--abort,.js-quick-tag--all,.js-quick-tag--submit'));

  setTagButton(`Submit (${currentTags()})`);

  markQueuedImages();
}

function activate(event: Event) {
  event.preventDefault();

  store.set(currentTagStorage, window.prompt('A comma-delimited list of tags you want to add:'));

  if (currentTags()) {
    toggleActiveState();
  }
}

function reset() {
  store.remove(currentTagStorage);
  store.remove(imageQueueStorage);

  toggleActiveState();
}

function promptReset(event: Event) {
  event.preventDefault();

  if (window.confirm('Are you sure you want to abort batch tagging?')) {
    reset();
  }
}

function submit(event: Event) {
  event.preventDefault();

  setTagButton(`Wait... (${currentTags()})`);

  fetchJson('PUT', '/admin/batch/tags', {
    tag_list: currentTags(),
    image_ids: currentQueue(),
  })
    .then(handleError)
    .then(r => r.json())
    .then((data: { failed: number }) => {
      if (data.failed > 0) window.alert(`Failed to add tags to ${data.failed} images.`);

      reset();
    });
}

function modifyImageQueue(event: Event, mediaBox: HTMLDivElement) {
  if (!currentTags()) {
    return;
  }

  const imageId = assertNotUndefined(mediaBox.dataset.imageId);
  const queue = currentQueue();
  const isSelected = queue.includes(imageId);

  if (isSelected) {
    queue.splice(queue.indexOf(imageId), 1);
  } else {
    queue.push(imageId);
  }

  store.set(imageQueueStorage, queue);
  markQueuedImages();
  event.preventDefault();
}

function toggleAllImages(event: Event, _target: Element) {
  for (const mediaBox of $$<HTMLDivElement>('#imagelist-container .media-box')) {
    modifyImageQueue(event, mediaBox);
  }
}

delegate(document, 'click', {
  '.js-quick-tag': leftClick(activate),
  '.js-quick-tag--abort': leftClick(promptReset),
  '.js-quick-tag--submit': leftClick(submit),
  '.js-quick-tag--all': leftClick(toggleAllImages),
  '.media-box': leftClick(modifyImageQueue),
});

export function setupQuickTag() {
  const tagButton = $<HTMLAnchorElement>('.js-quick-tag');

  if (tagButton && currentTags()) {
    toggleActiveState();
  }
}
