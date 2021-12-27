type SpoilerType = 'click' | 'hover' | 'off';

interface BooruObject {
  csrfToken: string;
  spoilerType: SpoilerType;
}

interface Window {
  booru: BooruObject;
}
