Uploading content is a piece of cake. You just hit the 'Upload' button and fill in the form. However, there's a few little details we'd like to explain better to you if you're interested.

## Metadata

We provide a few fields for metadata - tags are designed to let you group images together, and describe things in terms of their content. We also have a description field, which is intended mostly for people uploading original content to the site, or for more detailed description of images or context around the image. It can also be used for audio description of images for people with screenreaders.

For instance, the fact that an image contains **count dracula** belongs as a tag, and if it's the **Christmas**, that's a tag, too. Fully describing an image like `Count Dracula standing in the snow beside a Christmas tree` should be done in the description.

We also have some "meta" tags — **artist:artist name** tags should be used to link an artist name to an image. There are also spoilered or hidden by default tags, which stop NSFW things from popping up when not wanted. These should be used where appropriate.

Finally, there is the source URL field. This should link to the page on which the image was originally found. If you don't know, leave it blank, but try to find it first.

## Scalable Vector Graphic uploads

We support SVG uploads - once we get them on the server we make PNG images out of them, but people can still download and view the SVG version on the links on the image. `librsvg` is used to render the images.

We recommend you provide a sensible default resolution with your document - a couple of thousand pixels is plenty!

## Optimization

When you upload a GIF, JPEG or PNG, we do some checks on the image once it's been uploaded. Most images have un-needed data in them, which can be safely removed without affecting quality. We use a few tools to do this on your uploads, resulting in smaller file sizes for us to store, and faster page loads for everybody.

#### PNG

We use `optipng` to deinterlace and compress PNG images, fixing any encoding issues on the way.

#### JPEG

We use `jpegtran` to sort out JPEGs, which supports lossless optimization of the entropy encoding scheme used in JPEG compression.

#### GIF

GIFs are a bit more complex, as we treat all GIFs as probably animated, and so have to deal with all the frame processing. We use `gifsicle` and `ffmpeg` to process GIFs.

#### SVG

SVG images are left unchanged by uploads.

## Deduplication

We perform perceptual image deduplication using a simple image intensity based mechanism which has proven to be scalable and reasonably reliable over the years. We also provide SHA512 hashes of images in the site, though these are no longer used internally for deduplication.

## Workflow

We do all the processing in the background, and while we're doing it, we continue to serve the unoptimized file, so there's no noticeable difference for anyone. It is, however, noteworthy if you intend to download a file, you may wish to wait for the fully processed image to be available.

Basically, upload, and don't worry about it! We'll handle all the heavy lifting on our end, and once we finish processing the image, it'll be served instead of the old unoptimized one immediately.
