type SpoilerType = 'click' | 'hover' | 'off';

interface BooruObject {
  csrfToken: string;
  /**
   * One of the specified values, based on user setting
   */
  spoilerType: SpoilerType;
  /**
   * List of numeric image IDs as strings
   */
  imagesWithDownvotingDisabled: string[];
  /**
   * Array of watched tag IDs as numbers
   */
  watchedTagList: number[];
  /**
   * Array of spoilered tag IDs as numbers
   */
  spoileredTagList: number[];
  /**
   * Array of hidden tag IDs as numbers
   */
  hiddenTagList: number[];
  /**
   * Stores the URL of the default "tag blocked" image
   */
  hiddenTag: string;
  userIsSignedIn: boolean;
  /**
   * Indicates if the current user has edit rights to the currently selected filter
   */
  userCanEditFilter: boolean;
}

interface Window {
  booru: BooruObject;
}
