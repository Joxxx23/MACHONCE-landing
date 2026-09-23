import js from '@eslint/js';
import globals from 'globals';

export default [
  { ignores: ['dist/**', '.qa/**'] },
  js.configs.recommended,
  {
    files: ['src/**/*.js'],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['tests/**/*.js'],
    languageOptions: { globals: globals.node },
  },
];
