/**
 * Gallery rearrangement.
 */

import { arraysEqual } from './utils/array';
import { $, $$ } from './utils/dom';
import { initDraggables } from './utils/draggable';
import { fetchJson } from './utils/requests';

export function setupGalleryEditing() {
  if (!$<HTMLElement>('.rearrange-button')) return;

  const [ rearrangeEl, saveEl ] = $$<HTMLElement>('.rearrange-button');
  const sortableEl = $<HTMLDivElement>('#sortable');
  const containerEl = $<HTMLDivElement>('.media-list');

  if (!sortableEl || !containerEl || !saveEl || !rearrangeEl) { return; }

  // Copy array
  let oldImages = window.booru.galleryImages.slice();
  let newImages = window.booru.galleryImages.slice();

  initDraggables();

  $$<HTMLDivElement>('.media-box', containerEl).forEach(i => i.draggable = true);

  rearrangeEl.addEventListener('click', () => {
    sortableEl.classList.add('editing');
    containerEl.classList.add('drag-container');
  });

  saveEl.addEventListener('click', () => {
    sortableEl.classList.remove('editing');
    containerEl.classList.remove('drag-container');

    newImages = $$<HTMLDivElement>('.image-container', containerEl).map(i => parseInt(i.dataset.imageId || '-1', 10));

    // If nothing changed, don't bother.
    if (arraysEqual(newImages, oldImages)) return;

    if (saveEl.dataset.reorderPath) {
      fetchJson('PATCH', saveEl.dataset.reorderPath, {
        image_ids: newImages,

      // copy the array again so that we have the newly updated set
      }).then(() => oldImages = newImages.slice());
    }
  });
}
