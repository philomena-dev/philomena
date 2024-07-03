import { $, $$ } from './utils/dom';
import { addTag } from './tagsinput';

function showHelp(subject: string, type: string | null) {
  $$<HTMLElement>('[data-search-help]').forEach((helpBox) => {
    if (helpBox.getAttribute('data-search-help') === type) {
      const searchSubject = $<HTMLElement>('.js-search-help-subject', helpBox);

      if (searchSubject) {
        searchSubject.textContent = subject;
      }

      helpBox.classList.remove('hidden');
    } else {
      helpBox.classList.add('hidden');
    }
  });
}

function prependToLast(field: HTMLInputElement, value: string) {
  const separatorIndex = field.value.lastIndexOf(',');
  const advanceBy = field.value[separatorIndex + 1] === ' ' ? 2 : 1;
  field.value =
    field.value.slice(0, separatorIndex + advanceBy) + value + field.value.slice(separatorIndex + advanceBy);
}

function selectLast(field: HTMLInputElement, characterCount: number) {
  field.focus();

  field.selectionStart = field.value.length - characterCount;
  field.selectionEnd = field.value.length;
}

function executeFormHelper(e: PointerEvent) {
  if (!e.target) {
    return;
  }

  const searchField = $<HTMLInputElement>('.js-search-field');
  const attr = (name: string) => e.target && (e.target as HTMLElement).getAttribute(name);

  if (attr('data-search-add')) addTag(searchField, attr('data-search-add'));
  if (attr('data-search-show-help')) showHelp((e.target as Node).textContent || '', attr('data-search-show-help'));
  if (attr('data-search-select-last') && searchField) {
    selectLast(searchField, parseInt(attr('data-search-select-last') || '', 10));
  }
  if (attr('data-search-prepend') && searchField) prependToLast(searchField, attr('data-search-prepend') || '');
}

export function setupSearch() {
  const form = $<HTMLInputElement>('.js-search-form');

  if (form) form.addEventListener('click', executeFormHelper as EventListener);
}
