import { $ } from './utils/dom';

function unmarshal(data) {
  try { return JSON.parse(data); } catch (_) { return data; }
}

export function loadBooruData() {
  const booruData = document.querySelector('.js-datastore').dataset;

  // Assign all elements to booru because lazy
  for (const prop in booruData) {
    window.booru[prop] = unmarshal(booruData[prop]);
  }

  // CSRF
  window.booru.csrfToken = $('meta[name="csrf-token"]').content;
}

window.booru = {};
