export interface BooruObject {
  csrfToken: string;
  spoilerType: 'click' | 'hover' | 'off';
}

declare global {
  interface Window {
    booru: BooruObject;
  }
}
