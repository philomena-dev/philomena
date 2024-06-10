import { $ } from './utils/dom';
import { inputDuplicatorCreator } from './input-duplicator';

export interface TagSourceEvent extends CustomEvent<Response> {
  target: HTMLElement,
}

function setupInputs() {
  inputDuplicatorCreator({
    addButtonSelector: '.js-image-add-source',
    fieldSelector: '.js-image-source',
    maxInputCountSelector: '.js-max-source-count',
    removeButtonSelector: '.js-source-remove',
  });
}

function imageSourcesCreator() {
  setupInputs();

  document.addEventListener('fetchcomplete', (({ target, detail }: TagSourceEvent) => {
    const sourceSauce = $<HTMLElement>('.js-sourcesauce');

    if (sourceSauce && target && target.matches('#source-form')) {
      detail.text().then(text => {
        sourceSauce.outerHTML = text;
        setupInputs();
      });
    }
  }) as EventListener);
}

export { imageSourcesCreator };
