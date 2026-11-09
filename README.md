# ABAP SCSS/SASS Compiler

A pure-ABAP compiler that turns **SCSS** or indented **SASS** source into plain **CSS**.
It works only on internal tables: no file access, no external dependencies, no
transport-specific objects.

```abap
DATA(compiler) = NEW ycl_sass_compiler( ).

TRY.
    compiler->compile(
      EXPORTING i_source = VALUE string_table(
                  ( `$brand: #336699;` )
                  ( `.nav {` )
                  ( `  color: $brand;` )
                  ( `  &:hover { color: darken($brand, 10%); }` )
                  ( `}` ) )
      IMPORTING e_css    = DATA(css) ).
  CATCH ycx_sass_error INTO DATA(error).
    " error->line and error->text describe what went wrong
ENDTRY.
```

Result in `css`:

```css
.nav {
  color: #336699;
}

.nav:hover {
  color: #264d73;
}
```

## Objects

| Object | Type | Purpose |
| --- | --- | --- |
| `YCL_SASS_COMPILER` | Class | The compiler. Parser, evaluator and renderer are local classes of this class pool. Unit tests are in the test include (`LTC_SASS_COMPILER`). |
| `YCX_SASS_ERROR` | Exception class (`CX_STATIC_CHECK`) | Raised on syntax and evaluation errors. Attributes `TEXT` and `LINE`. |

Package: `$SASS` (local, no transport required).

## API

```abap
METHODS compile
  IMPORTING i_source TYPE string_table
            i_sass   TYPE abap_bool DEFAULT abap_false
  EXPORTING e_css    TYPE string_table
  RAISING   ycx_sass_error.
```

| Parameter | Description |
| --- | --- |
| `i_source` | Source lines. |
| `i_sass` | `abap_false` (default): input is SCSS. `abap_true`: input is indented SASS. |
| `e_css` | Resulting CSS lines in Sass *expanded* style (one declaration per line, 2-space indent, blank line between rules). |

## Supported features

- Variables, including `!default` and `!global`, with correct scoping
- Nesting, the parent selector `&`, selector lists, nested properties (`font: { family: ... }`)
- Comments: `//` is dropped, `/* ... */` is kept
- `#{...}` interpolation in selectors, property names, values and strings
- `@mixin` / `@include` with default and named arguments, and `@content`
- `@function` / `@return`
- `@if` / `@else if` / `@else`, `@each`, `@for ... from ... through|to`, `@while`
- Maps and lists (`map-get`, `map-has-key`, `map-keys`, `map-values`, `nth`, `length`)
- `@extend` and placeholder selectors (`%name`)
- `@media` / `@supports` bubbling, `@keyframes`, `@font-face`, other at-rules passed through
- Arithmetic with units, comparison and boolean operators, literal `12px/1.5`
- Built-in functions for colors (`lighten`, `darken`, `mix`, `rgba`, `opacify`, `transparentize`),
  numbers (`percentage`, `round`, `ceil`, `floor`, `abs`, `min`, `max`),
  strings (`quote`, `unquote`, `to-upper-case`, `to-lower-case`, `str-length`) and `if()`
- `calc()`, `clamp()`, `url()`, `var()`, `env()` and `attr()` are kept as written
  (variables and interpolation inside are resolved)
- Indented SASS syntax, including the `=mixin` and `+include` shorthands
- `@error` raises `ycx_sass_error`

## Limitations

- `@import`, `@use` and `@forward` are **not supported** and raise `ycx_sass_error`
  (the class does no file handling, so there is nothing to load).
- Only the expanded output style exists; there is no compressed mode and no source maps.
- `@extend` handles simple selector matches only.
- Only a subset of Sass's built-in functions is implemented.
- In indented SASS, multi-line `/* ... */` comments are not handled.
- The compiler was checked against hand-written expected output, not against Dart Sass.
  Whitespace in edge cases (for example blank lines inside nested `@media` blocks) may
  differ from the reference implementation.

## Requirements

- ABAP language version supporting inline declarations, string templates and
  `VALUE`/`NEW`/`COND` constructor expressions (ABAP 7.5x or later).
  Developed and tested on SAP_BASIS 816.
- `ycl_sass_compiler` uses `cl_abap_char_utilities` and POSIX regular expressions
  (the activation shows the standard "POSIX regex is deprecated" warning).

## Testing

Run the ABAP unit tests of `YCL_SASS_COMPILER` (ADT: *Run As > ABAP Unit Test*).
The suite has 39 tests covering SCSS and SASS input, every feature group above, and
error cases with line numbers.

## Installation

Create the two objects in your system from the sources (for example with
[abapGit](https://abapgit.org/) once they are committed to a repository), or copy the
source of `YCX_SASS_ERROR` first and `YCL_SASS_COMPILER` (main, local definitions,
local implementations, local test classes) second.
