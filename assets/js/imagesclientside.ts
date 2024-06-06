/**
 * Client-side image filtering/spoilering.
 */

import { $$, escapeHtml } from './utils/dom';
import { setupInteractions } from './interactions';
import { showThumb, showBlock, spoilerThumb, spoilerBlock, hideThumb } from './utils/image';
import { TagData, getHiddenTags, getSpoileredTags, imageHitsTags, imageHitsComplex, displayTags } from './utils/tag';
import { AstMatcher } from './query/types';

type RunFilterCallback = (img: HTMLDivElement, test: TagData[]) => void;

function runFilter(img: HTMLDivElement, test: TagData[] | boolean, runCallback: RunFilterCallback) {
  if (!test || typeof test !== 'boolean' && test.length === 0) { return false; }

  runCallback(img, test as TagData[]);

  // I don't like this.
  img.dataset.imageId && window.booru.imagesWithDownvotingDisabled.push(img.dataset.imageId);

  return true;
}

// ---

function filterThumbSimple(img: HTMLDivElement, tagsHit: TagData[]) {
  hideThumb(img, tagsHit[0].spoiler_image_uri || window.booru.hiddenTag, `[HIDDEN] ${displayTags(tagsHit)}`);
}

function spoilerThumbSimple(img: HTMLDivElement, tagsHit: TagData[]) {
  spoilerThumb(img, tagsHit[0].spoiler_image_uri || window.booru.hiddenTag, displayTags(tagsHit));
}

function filterThumbComplex(img: HTMLDivElement)  {
  hideThumb(img, window.booru.hiddenTag, '[HIDDEN] <i>(Complex Filter)</i>');
}

function spoilerThumbComplex(img: HTMLDivElement) {
  spoilerThumb(img, window.booru.hiddenTag, '<i>(Complex Filter)</i>');
}

function filterBlockSimple(img: HTMLDivElement, tagsHit: TagData[]) {
  spoilerBlock(
    img,
    tagsHit[0].spoiler_image_uri || window.booru.hiddenTag,
    `This image is tagged <code>${escapeHtml(tagsHit[0].name)}</code>, which is hidden by `
  );
}

function spoilerBlockSimple(img: HTMLDivElement, tagsHit: TagData[]) {
  spoilerBlock(
    img,
    tagsHit[0].spoiler_image_uri || window.booru.hiddenTag,
    `This image is tagged <code>${escapeHtml(tagsHit[0].name)}</code>, which is spoilered by `
  );
}

function filterBlockComplex(img: HTMLDivElement) {
  spoilerBlock(img, window.booru.hiddenTag, 'This image was hidden by a complex tag expression in ');
}

function spoilerBlockComplex(img: HTMLDivElement) {
  spoilerBlock(img, window.booru.hiddenTag, 'This image was spoilered by a complex tag expression in ');
}

// ---

function thumbTagFilter(tags: TagData[], img: HTMLDivElement)         {
  return runFilter(img, imageHitsTags(img, tags), filterThumbSimple);
}

function thumbComplexFilter(complex: AstMatcher, img: HTMLDivElement)  {
  return runFilter(img, imageHitsComplex(img, complex), filterThumbComplex);
}

function thumbTagSpoiler(tags: TagData[], img: HTMLDivElement)        {
  return runFilter(img, imageHitsTags(img, tags), spoilerThumbSimple);
}

function thumbComplexSpoiler(complex: AstMatcher, img: HTMLDivElement) {
  return runFilter(img, imageHitsComplex(img, complex), spoilerThumbComplex);
}

function blockTagFilter(tags: TagData[], img: HTMLDivElement)         {
  return runFilter(img, imageHitsTags(img, tags), filterBlockSimple);
}

function blockComplexFilter(complex: AstMatcher, img: HTMLDivElement)  {
  return runFilter(img, imageHitsComplex(img, complex), filterBlockComplex);
}

function blockTagSpoiler(tags: TagData[], img: HTMLDivElement)        {
  return runFilter(img, imageHitsTags(img, tags), spoilerBlockSimple);
}

function blockComplexSpoiler(complex: AstMatcher, img: HTMLDivElement) {
  return runFilter(img, imageHitsComplex(img, complex), spoilerBlockComplex);
}

// ---

function filterNode(node: Pick<Document, 'querySelectorAll'>) {
  const hiddenTags = getHiddenTags(), spoileredTags = getSpoileredTags();
  const { hiddenFilter, spoileredFilter } = window.booru;

  // Image thumb boxes with vote and fave buttons on them
  $$<HTMLDivElement>('.image-container', node)
    .filter(img => !thumbTagFilter(hiddenTags, img))
    .filter(img => !thumbComplexFilter(hiddenFilter, img))
    .filter(img => !thumbTagSpoiler(spoileredTags, img))
    .filter(img => !thumbComplexSpoiler(spoileredFilter, img))
    .forEach(img => showThumb(img));

  // Individual image pages and images in posts/comments
  $$<HTMLDivElement>('.image-show-container', node)
    .filter(img => !blockTagFilter(hiddenTags, img))
    .filter(img => !blockComplexFilter(hiddenFilter, img))
    .filter(img => !blockTagSpoiler(spoileredTags, img))
    .filter(img => !blockComplexSpoiler(spoileredFilter, img))
    .forEach(img => showBlock(img));
}

function initImagesClientside() {
  window.booru.imagesWithDownvotingDisabled = [];
  // This fills the imagesWithDownvotingDisabled array
  filterNode(document);
  // Once the array is populated, we can initialize interactions
  setupInteractions();
}

export { initImagesClientside, filterNode };
