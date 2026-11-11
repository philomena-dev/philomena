/**
 * @file This is a special file that isn't imported by our root `app.ts` in any
 * way, but it lives here to test that our build fails if we try to use any
 * features of the ECMAScript standard newer than our support target as
 * specified in the tsconfig.json.
 */

function _ecmascript2022(list: number[]) {
  // @ts-expect-error The floor Safari lacks the ES2022 `Array.prototype.at`,
  // which is past the `lib` of tsconfig.json.
  return list.at(-1);
}
