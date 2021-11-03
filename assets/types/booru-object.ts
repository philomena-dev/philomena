export interface BooruObject {
  csrfToken: string;
}

declare global {
  interface Window {
    booru: BooruObject;
  }
}
