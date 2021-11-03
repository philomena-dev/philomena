import { showBlock, showThumb } from '../image';
import { getRandomArrayItem } from '../../../test/randomness';
import { mockStorageGetItem } from '../../../test/mock-storage-get-item';

describe('Image utils', () => {
  const hiddenClass = 'hidden';
  const spoilerOverlayClass = 'js-spoiler-info-overlay';
  const serveHidpiStorageKey = 'serve_hidpi';

  describe('showThumb', () => {
    const getMockImageSizeUrls = (extension: string) => ({
      thumb: `https://example.com/thumb.${extension}`,
      small: `https://example.com/small.${extension}`,
      medium: `https://example.com/medium.${extension}`,
      large: `https://example.com/large.${extension}`,
    });
    type ImageSize = keyof ReturnType<typeof getMockImageSizeUrls>;
    const PossibleImageSizes: ImageSize[] = ['thumb', 'small', 'medium', 'large'];

    const applyMockDataAttributes = (element: HTMLElement, extension: string, size?: ImageSize) => {
      const mockSize = size || getRandomArrayItem(PossibleImageSizes);
      const mockSizeUrls = getMockImageSizeUrls(extension);
      element.setAttribute('data-size', mockSize);
      element.setAttribute('data-uris', JSON.stringify(mockSizeUrls));
      return { mockSize, mockSizeUrls };
    };
    const createMockSpoilerOverlay = () => {
      const mockSpoilerOverlay = document.createElement('div');
      mockSpoilerOverlay.classList.add(spoilerOverlayClass);
      return mockSpoilerOverlay;
    };
    const createMockElementWithPicture = (extension: string, size?: ImageSize) => {
      const mockElement = document.createElement('div');
      const { mockSizeUrls, mockSize } = applyMockDataAttributes(mockElement, extension, size);

      const mockPicture = document.createElement('picture');
      mockElement.appendChild(mockPicture);

      const mockSizeImage = new Image();
      mockPicture.appendChild(mockSizeImage);

      const mockSpoilerOverlay = createMockSpoilerOverlay();
      mockElement.appendChild(mockSpoilerOverlay);

      return {
        mockElement,
        mockPicture,
        mockSize,
        mockSizeImage,
        mockSizeUrls,
        mockSpoilerOverlay,
      };
    };
    let mockServeHidpiValue: string | null = null;
    mockStorageGetItem((key: string) => {
      if (key !== serveHidpiStorageKey) return null;

      return mockServeHidpiValue;
    });

    describe('video thumbnail', () => {
      type CreateMockElementsOptions = {
        extension: string;
        videoClasses?: string[];
        imgClasses?: string[];
      }

      const createMockElements = ({ videoClasses, imgClasses, extension }: CreateMockElementsOptions) => {
        const mockElement = document.createElement('div');
        const { mockSize, mockSizeUrls } = applyMockDataAttributes(mockElement, extension);

        const mockImage = new Image();
        mockImage.src = 'data:image/gif;base64,R0lGODlhAQABAIAAAP///////yH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';
        if (imgClasses) {
          imgClasses.forEach(videoClass => {
            mockImage.classList.add(videoClass);
          });
        }
        mockElement.appendChild(mockImage);

        const mockVideo = document.createElement('video');
        if (videoClasses) {
          videoClasses.forEach(videoClass => {
            mockVideo.classList.add(videoClass);
          });
        }
        mockElement.appendChild(mockVideo);
        const playSpy = jest.spyOn(mockVideo, 'play').mockReturnValue(Promise.resolve());

        const mockSpoilerOverlay = createMockSpoilerOverlay();
        mockElement.appendChild(mockSpoilerOverlay);

        return {
          mockElement,
          mockImage,
          mockSize,
          mockSizeUrls,
          mockSpoilerOverlay,
          mockVideo,
          playSpy,
        };
      };

      it('should hide the img element and show the video instead if no picture element is present', () => {
        const {
          mockElement,
          mockImage,
          playSpy,
          mockVideo,
          mockSize,
          mockSizeUrls,
          mockSpoilerOverlay
        } = createMockElements({
          extension: 'webm',
          videoClasses: ['hidden'],
        });

        const result = showThumb(mockElement);

        expect(mockImage).toHaveClass(hiddenClass);
        expect(mockVideo.children).toHaveLength(2);

        const webmSourceElement = mockVideo.children[0];
        const webmSource = mockSizeUrls[mockSize];
        expect(webmSourceElement.nodeName).toEqual('SOURCE');
        expect(webmSourceElement.getAttribute('type')).toEqual('video/webm');
        expect(webmSourceElement.getAttribute('src')).toEqual(webmSource);

        const mp4SourceElement = mockVideo.children[1];
        expect(mp4SourceElement.nodeName).toEqual('SOURCE');
        expect(mp4SourceElement.getAttribute('type')).toEqual('video/mp4');
        expect(mp4SourceElement.getAttribute('src')).toEqual(webmSource.replace('webm', 'mp4'));

        expect(mockVideo).not.toHaveClass(hiddenClass);
        expect(playSpy).toHaveBeenCalledTimes(1);

        expect(mockSpoilerOverlay).toHaveClass(hiddenClass);

        expect(result).toBe(true);
      });

      it('should return early if there is no video element', () => {
        const { mockElement, mockVideo, playSpy } = createMockElements({
          extension: 'webm',
        });

        mockElement.removeChild(mockVideo);

        const result = showThumb(mockElement);
        expect(result).toBe(false);
        expect(playSpy).not.toHaveBeenCalled();
      });

      it('should return early if img element is missing', () => {
        const { mockElement, mockImage, playSpy } = createMockElements({
          extension: 'webm',
          imgClasses: ['hidden'],
        });

        mockElement.removeChild(mockImage);

        const result = showThumb(mockElement);
        expect(result).toBe(false);
        expect(playSpy).not.toHaveBeenCalled();
      });

      it('should return early if img element already has the hidden class', () => {
        const { mockElement, playSpy } = createMockElements({
          extension: 'webm',
          imgClasses: ['hidden'],
        });

        const result = showThumb(mockElement);
        expect(result).toBe(false);
        expect(playSpy).not.toHaveBeenCalled();
      });
    });

    it('should show the correct thumbnail image for jpg extension', () => {
      const {
        mockElement,
        mockSizeImage,
        mockSizeUrls,
        mockSize,
        mockSpoilerOverlay
      } = createMockElementWithPicture('jpg');
      const result = showThumb(mockElement);

      expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize]);
      expect(mockSizeImage.srcset).toBe('');

      expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
      expect(result).toBe(true);
    });

    it('should show the correct thumbnail image for gif extension', () => {
      const {
        mockElement,
        mockSizeImage,
        mockSizeUrls,
        mockSize,
        mockSpoilerOverlay
      } = createMockElementWithPicture('gif');
      const result = showThumb(mockElement);

      expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize]);
      expect(mockSizeImage.srcset).toBe('');

      expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
      expect(result).toBe(true);
    });

    it('should show the correct thumbnail image for webm extension', () => {
      const {
        mockElement,
        mockSpoilerOverlay,
        mockSizeImage,
        mockSizeUrls,
        mockSize
      } = createMockElementWithPicture('webm');
      const result = showThumb(mockElement);

      expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize].replace('webm', 'gif'));
      expect(mockSizeImage.srcset).toBe('');

      expect(mockSpoilerOverlay).not.toHaveClass(hiddenClass);
      expect(mockSpoilerOverlay).toHaveTextContent('WebM');

      expect(result).toBe(true);
    });

    describe('high DPI srcset handling', () => {
      beforeEach(() => {
        mockServeHidpiValue = 'true';
      });

      const checkSrcsetAttribute = (size: ImageSize, x2size: ImageSize) => {
        const {
          mockElement,
          mockSizeImage,
          mockSizeUrls,
          mockSpoilerOverlay
        } = createMockElementWithPicture('jpg', size);
        const result = showThumb(mockElement);

        expect(mockSizeImage.src).toBe(mockSizeUrls[size]);
        expect(mockSizeImage.srcset).toContain(`${mockSizeUrls[size]} 1x`);
        expect(mockSizeImage.srcset).toContain(`${mockSizeUrls[x2size]} 2x`);

        expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
        return result;
      };

      it('should set correct srcset on img if thumbUri is NOT a gif at small size', () => {
        const result = checkSrcsetAttribute('small', 'medium');
        expect(result).toBe(true);
      });

      it('should set correct srcset on img if thumbUri is NOT a gif at medium size', () => {
        const result = checkSrcsetAttribute('medium', 'large');
        expect(result).toBe(true);
      });

      it('should NOT set srcset on img if thumbUri is a gif at small size', () => {
        const mockSize = 'small';
        const {
          mockElement,
          mockSizeImage,
          mockSizeUrls,
          mockSpoilerOverlay
        } = createMockElementWithPicture('gif', mockSize);
        const result = showThumb(mockElement);

        expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize]);
        expect(mockSizeImage.srcset).toBe('');

        expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
        expect(result).toBe(true);
      });
    });

    it('should return false if img cannot be found', () => {
      const { mockElement, mockPicture, mockSizeImage } = createMockElementWithPicture('jpg');
      mockPicture.removeChild(mockSizeImage);
      const result = showThumb(mockElement);
      expect(result).toBe(false);
    });

    it('should return false if img source already matches thumbUri', () => {
      const { mockElement, mockSizeImage, mockSizeUrls, mockSize } = createMockElementWithPicture('jpg');
      mockSizeImage.src = mockSizeUrls[mockSize];
      const result = showThumb(mockElement);
      expect(result).toBe(false);
    });
  });

  describe('showBlock', () => {
    const imageFilteredClass = 'image-filtered';
    const imageShowClass = 'image-show';
    const spoilerPendingClass = 'spoiler-pending';

    it('should hide the filtered image element and show the image', () => {
      const mockElement = document.createElement('div');

      const mockFilteredImageElement = document.createElement('div');
      mockFilteredImageElement.classList.add(imageFilteredClass);
      mockElement.appendChild(mockFilteredImageElement);

      const mockShowElement = document.createElement('div');
      mockShowElement.classList.add(imageShowClass);
      mockShowElement.classList.add(hiddenClass);
      mockElement.appendChild(mockShowElement);

      showBlock(mockElement);

      expect(mockFilteredImageElement).toHaveClass(hiddenClass);
      expect(mockShowElement).not.toHaveClass(hiddenClass);
      expect(mockShowElement).toHaveClass(spoilerPendingClass);
    });
  });

  describe('hideThumb', () => {
    describe('hideVideoThumb', () => {
      it.todo('should return early if picture element is missing AND img element is missing');

      it.todo('should hide video thumbnail if picture element is missing BUT img element is present');
    });

    it.todo('should return early if picture element is present AND img element is missing');

    it.todo('should hide img thumbnail if picture element is present AND img element is present');
  });

  describe('spoilerThumb', () => {
    it.todo('should hide image thumbnail');

    it.todo('should hide video thumbnail');

    it.todo('should call add click and mouseleave handlers for click spoiler type');

    it.todo('should call add mouseenter and mouseleave handlers for click spoiler type');
  });

  describe('spoilerBlock', () => {
    it.todo('should do nothing if image element is missing');

    it.todo('should update the elements with the parameters and set classes if image element is found');
  });
});
