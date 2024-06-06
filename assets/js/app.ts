// This is the Vite entry point of Philomena's clientside code.
// It is used as a sort of 'manifest' for what to include, and shouldn't
// have any code on its own.
//
// Only edit this file as described by the comment about CSS development below.

// Our code
import './ujs';
import './when-ready';

// When developing CSS, include the relevant CSS you're working on here
// in order to enable HMR (live reload) on it.
// Would typically be either the theme file, or any additional file
// you later intend to put in the <link> tag.

import '../css/application.css';
import '../css/themes/dark-blue.css';
// import '../css/themes/dark.scss';
// import '../css/themes/red.scss';
