export default {
  collectCoverage: true,
  collectCoverageFrom: [
    'js/**/*.{js,ts}',
  ],
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/.*\\.test\\.ts$',
    '.*\\.d\\.ts$',
  ],
  coverageDirectory: '<rootDir>/coverage/',
  coverageThreshold: {
    global: {
      statements: 100,
      branches: 100,
      functions: 100,
      lines: 100,
    },
  },
  preset: 'ts-jest/presets/js-with-ts-esm',
  testEnvironment: 'node',
  testPathIgnorePatterns: ['/node_modules/', '/dist/'],
  moduleNameMapper: {
    './js/(.*)': '<rootDir>/js/$1',
  },
  globals: {
      extensionsToTreatAsEsm: ['.ts', '.js'],
      'ts-jest': {
          useESM: true
      }
  },
};
