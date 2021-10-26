// http://stackoverflow.com/a/5306832/1726690
function moveElement(array, from, to) {
  array.splice(to, 0, array.splice(from, 1)[0]);
}

function arraysEqual(array1, array2) {
  for (let i = 0; i < array1.length; ++i) {
    if (array1[i] !== array2[i]) return false;
  }
  return true;
}

/**
 * @template T
 * @param {T[]} array
 * @param {number} numBins
 * @returns {T[][]}
 */
function evenlyDivide(array, numBins) {
  const bins = [];

  for (let i = 0; i < numBins; i++) {
    bins[i] = [];
  }

  for (let i = 0; i < array.length; i++) {
    bins[i % numBins].push(array[i]);
  }

  return bins;
}

export { moveElement, arraysEqual, evenlyDivide };
