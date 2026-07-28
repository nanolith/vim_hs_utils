Vim Haskell Utilities
=====================

These utilities are integrated with Vim9's channel and messaging service to
perform some utility functions.

To install these utilities, you can clone this repository into your
`~/.vim/pack` directory. Each of these utilities are in opt, and require a
`packadd` command to enable them.

v9\_hs\_uuid2c
----------

The `v9\_hs\_uuid2c` utility reads a variable name from the current line and
generates code to initialize this variable with the contents from a call to
`uuidgen`. It currently supports three code generation styles: raw C arrays,
RCPR uuid instances in C, and Java UUID initializers.
