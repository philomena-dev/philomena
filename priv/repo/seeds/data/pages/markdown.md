This page is here to help you get a better grasp on the syntax of Markdown, the text processing engine this site uses.

## Inline formatting

Inline formatting is the most commonly seen type of text formatting in Markdown. It can be applied almost anywhere else and doesn't depend on specific context (most of the time).

| Operator      | Example                                 | Result                                |
| ------------- | -------------------------------------   | ----------------------------------    |
| Bold          | `This is **huge**`                      | This is **huge**                      |
| Italic        | `*very* clever, Connor... _very..._`    | _very_ clever, Connor... _very..._    |
| Underline     | `And I consider this __important__`     | And I consider this **important**     |
| Strikethrough | `I am ~~wrong~~ right`                  | I am ~~wrong~~ right                  |
| Superscript   | `normal text ^superscripted text^`      | normal text ^superscripted text^      |
| Subscript     | `normal text ~subscripted text~`        | normal text ~subscripted text~        |
| Spoiler       | `Psst! ||Count Dracula is a vampire!||` | Psst! ||Count Dracula is a vampire!|| |
| Code          | ``Use `**bold**` to make text bold!``   | Use `**bold**` to make text bold!     |

#### Multi-line inlines

Most inline formatting can extend beyond just a single line and travel to other lines. However, it does have certain quirks, especially if you're unused to the Markdown syntax.

```
**I am a very
bold text**
```

<div class="block">
  <div class="block__header">
    <span class="block__header__title">Result</span>
  </div>
  <div class="block__content">
    <div class="paragraph">
      <strong>I am a very<br />bold text</strong>
    </div>
  </div>
</div>

However, if you try to insert a newline in the middle of it, it won't work.

```
**I am not a very

bold text**
```

<div class="block">
  <div class="block__header">
    <span class="block__header__title">Result</span>
  </div>
  <div class="block__content">
    <div class="paragraph">**I am not a very</div>
    <div class="paragraph">bold text**</div>
  </div>
</div>

If you really need an empty line in the middle of your inline-formatted text, you must _escape_ the line ending. In order to do so, Markdown provides us with the `\` (backslash) character. Backslash is a very special character and is used for _escaping_ other special characters. _Escaping_ forces the character immediately after the backslash to be ignored by the parser.

As such, we can write our previous example like so to preserve the empty line:

```
**I am a very
\
bold text**
```

<div class="block">
  <div class="block__header">
    <span class="block__header__title">Result</span>
  </div>
  <div class="block__content">
    <div class="paragraph"><strong>I am a very<br>
    <br>
    bold text</strong></div>
  </div>
</div>

#### Combining inlines

Most inline operators may be combined with each other (with the exception of the `code` syntax).

```
_I am an italic text **with some bold in it**._
```

<div class="block">
  <div class="block__header">
    <span class="block__header__title">Result</span>
  </div>
  <div class="block__content">
    <div class="paragraph"><em>I am an italic text <strong>with some bold in it</strong>.</em></div>
  </div>
</div>

## Block formatting

Block formatting is the kind of formatting that cannot be written within a single line and typically requires to be written on its own line. Many block formatting styles extend past just one line.

#### Blockquotes

Philomena's flavor of Markdown makes some changes to the blockquote syntax compared to regular CommonMark. The basic syntax is a > followed by a space.

```
> quote text
```

> quote text

---

Please note, that if > is not followed by a space, it will not become a blockquote!

```
>not a quote
```

> not a quote

---

Same goes for >>, even if followed by a space.

```
>> not a quote
```

> > not a quote

---

You may continue a quote by adding > followed by a space on a new line, even if the line is otherwise empty.

```
> quote text
>
> continuation of quote
```

> quote text
>
> continuation of quote

---

To nest a quote, simply repeat > followed by a space as many times as you wish to have nested blockquotes.

```
> quote text
> > nested quote
> > > even deeper nested quote
```

> quote text
>
> > nested quote
> >
> > > even deeper nested quote

#### Headers

Markdown supports adding headers to your text. The syntax is # repeated up to 6 times.

```
# Header 1
## Header 2
### Header 3
#### Header 4
##### Header 5
###### Header 6
```

# Header 1

## Header 2

### Header 3

#### Header 4

##### Header 5

###### Header 6

#### Code block

Another way to write code is by writing a code block. Code blocks, unlike inline code syntax, are styled similar to blockquotes and are more appropriate for sharing larger snippets of code. In fact, this very page has been using this very structure to show examples of code.

````
```
<div>
  <h1>Hello World!</h1>
</div>
```
````

```
<div>
  <h1>Hello World!</h1>
</div>
```

Code blocks may also use tildes (\~) instead of backticks (\`).

```
~~~
code block
~~~
```

```
code block
```

## Links

Links have the basic syntax of

```
[Link Text](https://example.com)
```

[Link Text](https://example.com)

Most links pasted as plaintext will be automatically converted into a proper clickable link, as long as they don't begin with dangerous protocols.
As such...

```
https://example.com
```

https://example.com

On-site links may be written as either a relative or absolute path. If the on-site link is written as the absolute path, it will be automatically converted into a relative link for the convenience of other users.

```
[Link to the first image](https://philomena.local/images/0)
[Link to the first image](/images/0)
```

[Link to the first image](https://philomena.local/images/0)
[Link to the first image](/images/0)

## On-site images

If you wish to link an on-site image, you should use the >>:id syntax. It respects filters currently in-use by the reader and spoilers content they do not wish to see.
**You should always use this for on-site uploads!** (as this will let other users filter the image if they wish to, and it is against the rules to not show content with care)
Here's a brief explanation of its usage.

| Operator | Description of result                    |
| -------- | ---------------------------------------- |
| \>\>5    | Simple link to image                     |
| \>\>5s   | Small (150x150) thumbnail of the image   |
| \>\>5t   | Regular (320x240) thumbnail of the image |
| \>\>5p   | Preview (800x600) size of the image      |

> > 5
> > 5s
> > 5t
> > 5p

## External images

Some images you may wish to link may not exist on the site. To link them Markdown provides us with a special syntax. All images embedded this way are proxied by our image proxy (Go-Camo).

```
![](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
```

![](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)

You may control the size of your externally-linked image by specifying the alt text. Certain keywords are recognized as size modifiers. The modifiers are case-sensitive!

| Modifier        | Resulting size             |
| --------------- | -------------------------- |
| tiny            | 64x64                      |
| small           | 128x128                    |
| medium          | 256x256                    |
| large           | 512x512                    |
| (anything else) | (actual size of the image) |

```
![tiny](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![small](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![medium](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![large](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
```

![tiny](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![small](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![medium](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![large](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)
![](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)

#### Image links

To make an image link, simply combine the external image syntax with the link syntax.

```
[![](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)](https://github.com/philomena-dev/philomena)
```

[![](https://raw.githubusercontent.com/philomena-dev/philomena/master/assets/static/images/phoenix.svg)](https://github.com/philomena-dev/philomena)

## Lists

#### Unordered list

Unordered lists can be written fairly intuitively, by putting one of the special characters in front of each line that should be a part of the list.

```
Shopping list:
* Milk
* Eggs
* Soda
```

Shopping list:

- Milk
- Eggs
- Soda

You may use any of the following characters at the beginning of the line to make an unordered list:

```
*
+
-
```

Lists may be nested and have sublists within them. Simply prefix your sublist items with three spaces while within another list.

```
* Item one
* Item two
   * Sublist item one
   * Sublist item two
```

- Item one
- Item two
  - Sublist item one
  - Sublist item two

#### Ordered list

To write an ordered list, simply put a number at the beginning of the line followed by a dot or closing bracket. It doesn't actually matter which order your numbers are written in, the list will always maintain its incremental order. Note the 4 in the example, it isn't a typo.

```
1. Item one
2. Item two
4. Item three
```

1. Item one
2. Item two
3. Item three

**Ordered lists cannot be sublists to other ordered lists.** They can, however, be sublists to unordered lists. Unordered lists, in turn, may be sublists in ordered lists.

```
1) Item one
2) Item two
   * Sublist item one
   * Sublist item two
```

1. Item one
2. Item two
   - Sublist item one
   - Sublist item two

## Tables

Philomena's Markdown implementation supports GitHub-style tables. This isn't a part of the core Markdown specification, but we support them. The colons are used to specify the alignment of columns.

```
| Left         | Center         | Right         |
| ------------ |:--------------:| -------------:|
| left-aligned | center-aligned | right-aligned |
| *formatting* | **works**      | __here__      |
```

| Left         |     Center     |         Right |
| ------------ | :------------: | ------------: |
| left-aligned | center-aligned | right-aligned |
| _formatting_ |   **works**    |      **here** |

In tables, the pipes (|) at the edges of the table are optional. To separate table head from body, you need to put in at least three - symbols. As such, example above could have also been written like so:

```
Left | Center | Right
--- | :---: | ---:
left-aligned | center-aligned | right-aligned
*formatting* | **works** | __here__
```

| Left         |     Center     |         Right |
| ------------ | :------------: | ------------: |
| left-aligned | center-aligned | right-aligned |
| _formatting_ |   **works**    |      **here** |

# Escaping the syntax.

Sometimes you may wish certain characters to not be interpreted as Markdown syntax. This is where the backslash comes in! Prefixing any markup with a backslash will cause the markup immediately following the backslash to not be parsed, for example:

```
\*\*grr grr, I should not be bold!\*\*
```

\*\*grr grr, I should not be bold\*\*

Code blocks and code inlines will also escape the syntax to a limited extent (except for backticks themselves).

```
`**not bold!**`
```

`**not bold!**`
