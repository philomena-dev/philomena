/**
 * @file This is a special file that isn't imported by our root `app.ts` in any
 * way, but it lives here to test that our build fails if we try to use any
 * features of the ECMAScript standard newer than our support target as
 * specified in the tsconfig.json.
 */

function _ecmascript2021() {
  // @ts-expect-error Safari 14 lacks the ES2021 `WeakRef`, which is past the
  // `lib` of tsconfig.json.
  return WeakRef;
}
