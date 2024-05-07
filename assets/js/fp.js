/**
 * Thanks uBlock for breaking our JS!
 */

// http://stackoverflow.com/a/34842797
function hashCode(str) {
  return str.split('').reduce((prevHash, currVal) =>
    ((prevHash << 5) - prevHash) + currVal.charCodeAt(0), 0) >>> 0;
}

function createFp() {
  const prints = [
    navigator.userAgent,
    navigator.cpuClass,
    navigator.oscpu,
    navigator.platform,

    navigator.browserLanguage,
    navigator.language,
    navigator.systemLanguage,
    navigator.userLanguage,

    screen.availLeft,
    screen.availTop,
    screen.availWidth,
    screen.height,
    screen.width,

    window.devicePixelRatio,
    new Date().getTimezoneOffset(),
  ];

  return hashCode(prints.join(''));
}

function setFpCookie() {
  let fp;

  // The prepended 'c' acts as a crude versioning mechanism.
  try {
    fp = `c${createFp()}`;
  }
  // If it fails, use fakeprint "c1836832948" as a last resort.
  catch (err) {
    fp = 'c1836832948';
  }

  document.cookie = `_ses=${fp}; path=/; SameSite=Lax`;
}

export { setFpCookie };
