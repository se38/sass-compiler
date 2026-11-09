CLASS ltc_sass_compiler DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA cut TYPE REF TO ycl_sass_compiler.

    METHODS setup.
    METHODS check
      IMPORTING source   TYPE string_table
                expected TYPE string_table
                sass     TYPE abap_bool DEFAULT abap_false
      RAISING   ycx_sass_error.
    METHODS check_error
      IMPORTING source       TYPE string_table
                message_part TYPE string
                line         TYPE i DEFAULT 0
                sass         TYPE abap_bool DEFAULT abap_false.

    METHODS plain_css FOR TESTING RAISING cx_static_check.
    METHODS empty_input FOR TESTING RAISING cx_static_check.
    METHODS variables FOR TESTING RAISING cx_static_check.
    METHODS variable_default FOR TESTING RAISING cx_static_check.
    METHODS variable_scoping FOR TESTING RAISING cx_static_check.
    METHODS nesting FOR TESTING RAISING cx_static_check.
    METHODS selector_lists FOR TESTING RAISING cx_static_check.
    METHODS comments FOR TESTING RAISING cx_static_check.
    METHODS mixin_with_arguments FOR TESTING RAISING cx_static_check.
    METHODS mixin_content_block FOR TESTING RAISING cx_static_check.
    METHODS extend_placeholder FOR TESTING RAISING cx_static_check.
    METHODS extend_class FOR TESTING RAISING cx_static_check.
    METHODS user_function FOR TESTING RAISING cx_static_check.
    METHODS if_else FOR TESTING RAISING cx_static_check.
    METHODS each_loop FOR TESTING RAISING cx_static_check.
    METHODS for_loop FOR TESTING RAISING cx_static_check.
    METHODS while_loop FOR TESTING RAISING cx_static_check.
    METHODS maps FOR TESTING RAISING cx_static_check.
    METHODS color_functions FOR TESTING RAISING cx_static_check.
    METHODS arithmetic FOR TESTING RAISING cx_static_check.
    METHODS slash_literal FOR TESTING RAISING cx_static_check.
    METHODS string_functions FOR TESTING RAISING cx_static_check.
    METHODS media_bubbling FOR TESTING RAISING cx_static_check.
    METHODS media_at_root FOR TESTING RAISING cx_static_check.
    METHODS interpolation FOR TESTING RAISING cx_static_check.
    METHODS nested_properties FOR TESTING RAISING cx_static_check.
    METHODS keyframes FOR TESTING RAISING cx_static_check.
    METHODS font_face FOR TESTING RAISING cx_static_check.
    METHODS important_flag FOR TESTING RAISING cx_static_check.
    METHODS calc_function FOR TESTING RAISING cx_static_check.
    METHODS sass_syntax FOR TESTING RAISING cx_static_check.
    METHODS sass_if_else FOR TESTING RAISING cx_static_check.
    METHODS error_import FOR TESTING RAISING cx_static_check.
    METHODS error_undefined_variable FOR TESTING RAISING cx_static_check.
    METHODS error_unterminated_block FOR TESTING RAISING cx_static_check.
    METHODS error_missing_colon FOR TESTING RAISING cx_static_check.
    METHODS error_directive FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_sass_compiler IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( ).
  ENDMETHOD.

  METHOD check.
    DATA(css) = cut->compile( EXPORTING i_source = source i_sass = sass ).
    cl_abap_unit_assert=>assert_equals( act = css exp = expected ).
  ENDMETHOD.

  METHOD check_error.
    TRY.
        DATA(css) = cut->compile( EXPORTING i_source = source i_sass = sass ).
        cl_abap_unit_assert=>fail( `Expected exception ycx_sass_error` ).
      CATCH ycx_sass_error INTO DATA(error).
        cl_abap_unit_assert=>assert_true( xsdbool( error->text CS message_part ) ).
        IF line > 0.
          cl_abap_unit_assert=>assert_equals( act = error->line exp = line ).
        ENDIF.
    ENDTRY.
  ENDMETHOD.

  METHOD plain_css.
    check( source = VALUE #( ( `a { color: red; }` ) )
           expected = VALUE #( ( `a {` ) ( `  color: red;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD empty_input.
    check( source = VALUE #( ) expected = VALUE #( ) ).
  ENDMETHOD.

  METHOD variables.
    check( source = VALUE #( ( `$c: #333;` ) ( `$w: 10px;` ) ( `a { color: $c; width: $w * 2; }` ) )
           expected = VALUE #( ( `a {` ) ( `  color: #333;` ) ( `  width: 20px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD variable_default.
    check( source = VALUE #( ( `$a: 1;` ) ( `$a: 2 !default;` ) ( `$b: 3 !default;` ) ( `.x { w: $a; v: $b; }` ) )
           expected = VALUE #( ( `.x {` ) ( `  w: 1;` ) ( `  v: 3;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD variable_scoping.
    check( source = VALUE #( ( `$x: 1;` ) ( `.a { $x: 2; w: $x; }` ) ( `.b { w: $x; }` ) )
           expected = VALUE #( ( `.a {` ) ( `  w: 2;` ) ( `}` ) ( `` ) ( `.b {` ) ( `  w: 1;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD nesting.
    check( source = VALUE #( ( `.nav {` )
                             ( `  margin: 0;` )
                             ( `  ul { padding: 0; }` )
                             ( `  &:hover { color: blue; }` )
                             ( `  &-item { color: red; }` )
                             ( `  .dark & { color: white; }` )
                             ( `  > li { top: 1px; }` )
                             ( `}` ) )
           expected = VALUE #( ( `.nav {` ) ( `  margin: 0;` ) ( `}` ) ( `` )
                               ( `.nav ul {` ) ( `  padding: 0;` ) ( `}` ) ( `` )
                               ( `.nav:hover {` ) ( `  color: blue;` ) ( `}` ) ( `` )
                               ( `.nav-item {` ) ( `  color: red;` ) ( `}` ) ( `` )
                               ( `.dark .nav {` ) ( `  color: white;` ) ( `}` ) ( `` )
                               ( `.nav > li {` ) ( `  top: 1px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD selector_lists.
    check( source = VALUE #( ( `a, b { c, d { x: y; } }` ) )
           expected = VALUE #( ( `a c, a d, b c, b d {` ) ( `  x: y;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD comments.
    check( source = VALUE #( ( `// removed` ) ( `/* kept */` ) ( `a {` ) ( `  color: red; // trailing` ) ( `}` ) )
           expected = VALUE #( ( `/* kept */` ) ( `` ) ( `a {` ) ( `  color: red;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD mixin_with_arguments.
    check( source = VALUE #( ( `@mixin box($w, $h: 5px) { width: $w; height: $h; }` )
                             ( `.a { @include box(10px); }` )
                             ( `.b { @include box(1px, $h: 2px); }` ) )
           expected = VALUE #( ( `.a {` ) ( `  width: 10px;` ) ( `  height: 5px;` ) ( `}` ) ( `` )
                               ( `.b {` ) ( `  width: 1px;` ) ( `  height: 2px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD mixin_content_block.
    check( source = VALUE #( ( `@mixin hover { &:hover { @content; } }` )
                             ( `a { @include hover { color: red; } }` ) )
           expected = VALUE #( ( `a:hover {` ) ( `  color: red;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD extend_placeholder.
    check( source = VALUE #( ( `%message { border: 1px solid #ccc; }` )
                             ( `.success { @extend %message; color: green; }` ) )
           expected = VALUE #( ( `.success {` ) ( `  border: 1px solid #ccc;` ) ( `}` ) ( `` )
                               ( `.success {` ) ( `  color: green;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD extend_class.
    check( source = VALUE #( ( `.a { x: y; }` ) ( `.b { @extend .a; z: w; }` ) )
           expected = VALUE #( ( `.a, .b {` ) ( `  x: y;` ) ( `}` ) ( `` ) ( `.b {` ) ( `  z: w;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD user_function.
    check( source = VALUE #( ( `@function double($n) { @return $n * 2; }` ) ( `a { width: double(5px); }` ) )
           expected = VALUE #( ( `a {` ) ( `  width: 10px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD if_else.
    check( source = VALUE #( ( `$t: dark;` )
                             ( `a {` )
                             ( `  @if $t == light { color: black; }` )
                             ( `  @else if $t == dark { color: white; }` )
                             ( `  @else { color: gray; }` )
                             ( `}` ) )
           expected = VALUE #( ( `a {` ) ( `  color: white;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD each_loop.
    check( source = VALUE #( ( `@each $n in a, b { .#{$n} { x: 1; } }` ) )
           expected = VALUE #( ( `.a {` ) ( `  x: 1;` ) ( `}` ) ( `` ) ( `.b {` ) ( `  x: 1;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD for_loop.
    check( source = VALUE #( ( `@for $i from 1 through 3 { .m-#{$i} { margin: 4px * $i; } }` ) )
           expected = VALUE #( ( `.m-1 {` ) ( `  margin: 4px;` ) ( `}` ) ( `` )
                               ( `.m-2 {` ) ( `  margin: 8px;` ) ( `}` ) ( `` )
                               ( `.m-3 {` ) ( `  margin: 12px;` ) ( `}` ) ) ).
    check( source = VALUE #( ( `@for $i from 1 to 3 { .n-#{$i} { x: $i; } }` ) )
           expected = VALUE #( ( `.n-1 {` ) ( `  x: 1;` ) ( `}` ) ( `` ) ( `.n-2 {` ) ( `  x: 2;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD while_loop.
    check( source = VALUE #( ( `$i: 1;` )
                             ( `@while $i <= 2 { .w-#{$i} { width: 10px * $i; } $i: $i + 1; }` ) )
           expected = VALUE #( ( `.w-1 {` ) ( `  width: 10px;` ) ( `}` ) ( `` ) ( `.w-2 {` ) ( `  width: 20px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD maps.
    check( source = VALUE #( ( `$m: (a: 1px, b: 2px);` )
                             ( `.x { w: map-get($m, b); has: map-has-key($m, c); }` )
                             ( `@each $k, $v in $m { .#{$k} { h: $v; } }` ) )
           expected = VALUE #( ( `.x {` ) ( `  w: 2px;` ) ( `  has: false;` ) ( `}` ) ( `` )
                               ( `.a {` ) ( `  h: 1px;` ) ( `}` ) ( `` )
                               ( `.b {` ) ( `  h: 2px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD color_functions.
    check( source = VALUE #( ( `a {` )
                             ( `  c1: lighten(#000, 20%);` )
                             ( `  c2: darken(#fff, 10%);` )
                             ( `  c3: rgba(#000, 0.5);` )
                             ( `  c4: mix(#000, #fff);` )
                             ( `  c5: rgba(255, 0, 0, .25);` )
                             ( `}` ) )
           expected = VALUE #( ( `a {` )
                               ( `  c1: #333333;` )
                               ( `  c2: #e6e6e6;` )
                               ( `  c3: rgba(0, 0, 0, 0.5);` )
                               ( `  c4: #808080;` )
                               ( `  c5: rgba(255, 0, 0, 0.25);` )
                               ( `}` ) ) ).
  ENDMETHOD.

  METHOD arithmetic.
    check( source = VALUE #( ( `$x: 3px;` )
                             ( `a {` )
                             ( `  w: 10px + 5px;` )
                             ( `  h: 10px * 2;` )
                             ( `  r: (10px / 4);` )
                             ( `  n: -$x;` )
                             ( `  m: 7 % 3;` )
                             ( `  p: percentage(0.25);` )
                             ( `  q: 10px - 4px - 1px;` )
                             ( `  v: round(2.5);` )
                             ( `}` ) )
           expected = VALUE #( ( `a {` )
                               ( `  w: 15px;` )
                               ( `  h: 20px;` )
                               ( `  r: 2.5px;` )
                               ( `  n: -3px;` )
                               ( `  m: 1;` )
                               ( `  p: 25%;` )
                               ( `  q: 5px;` )
                               ( `  v: 3;` )
                               ( `}` ) ) ).
  ENDMETHOD.

  METHOD slash_literal.
    check( source = VALUE #( ( `$w: 12px;` ) ( `a { font: 12px/1.5 Arial; half: $w/2; }` ) )
           expected = VALUE #( ( `a {` ) ( `  font: 12px/1.5 Arial;` ) ( `  half: 6px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD string_functions.
    check( source = VALUE #( ( `a { content: "a" + "b"; f: unquote("x y"); q: to-upper-case(abc); l: str-length("abcd"); }` ) )
           expected = VALUE #( ( `a {` ) ( `  content: "ab";` ) ( `  f: x y;` ) ( `  q: ABC;` ) ( `  l: 4;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD media_bubbling.
    check( source = VALUE #( ( `$bp: 100px;` )
                             ( `.a { color: red; @media (min-width: $bp) { color: blue; } }` ) )
           expected = VALUE #( ( `.a {` ) ( `  color: red;` ) ( `}` ) ( `` )
                               ( `@media (min-width: 100px) {` )
                               ( `  .a {` )
                               ( `    color: blue;` )
                               ( `  }` )
                               ( `}` ) ) ).
  ENDMETHOD.

  METHOD media_at_root.
    check( source = VALUE #( ( `@media screen { .a { x: y; } }` ) )
           expected = VALUE #( ( `@media screen {` ) ( `  .a {` ) ( `    x: y;` ) ( `  }` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD interpolation.
    check( source = VALUE #( ( `$n: foo;` ) ( `.a-#{$n} { prop-#{$n}: 1px; content: "x#{$n}"; }` ) )
           expected = VALUE #( ( `.a-foo {` ) ( `  prop-foo: 1px;` ) ( `  content: "xfoo";` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD nested_properties.
    check( source = VALUE #( ( `a { font: { family: Arial; size: 12px; } }` ) )
           expected = VALUE #( ( `a {` ) ( `  font-family: Arial;` ) ( `  font-size: 12px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD keyframes.
    check( source = VALUE #( ( `@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }` ) )
           expected = VALUE #( ( `@keyframes spin {` )
                               ( `  from {` ) ( `    transform: rotate(0deg);` ) ( `  }` ) ( `` )
                               ( `  to {` ) ( `    transform: rotate(360deg);` ) ( `  }` )
                               ( `}` ) ) ).
  ENDMETHOD.

  METHOD font_face.
    check( source = VALUE #( ( `@font-face { font-family: X; src: url(x.woff); }` ) )
           expected = VALUE #( ( `@font-face {` ) ( `  font-family: X;` ) ( `  src: url(x.woff);` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD important_flag.
    check( source = VALUE #( ( `a { color: red !important; }` ) )
           expected = VALUE #( ( `a {` ) ( `  color: red !important;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD calc_function.
    check( source = VALUE #( ( `$g: 10px;` ) ( `a { w: calc(100% - #{$g}); h: calc(100% - $g); }` ) )
           expected = VALUE #( ( `a {` ) ( `  w: calc(100% - 10px);` ) ( `  h: calc(100% - 10px);` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD sass_syntax.
    check( sass = abap_true
           source = VALUE #( ( `$c: red` )
                             ( `.a` )
                             ( `  color: $c` )
                             ( `  &:hover` )
                             ( `    color: blue` )
                             ( `=m($x)` )
                             ( `  width: $x` )
                             ( `.b` )
                             ( `  +m(2px)` ) )
           expected = VALUE #( ( `.a {` ) ( `  color: red;` ) ( `}` ) ( `` )
                               ( `.a:hover {` ) ( `  color: blue;` ) ( `}` ) ( `` )
                               ( `.b {` ) ( `  width: 2px;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD sass_if_else.
    check( sass = abap_true
           source = VALUE #( ( `$t: dark` )
                             ( `a` )
                             ( `  @if $t == light` )
                             ( `    color: black` )
                             ( `  @else` )
                             ( `    color: white` ) )
           expected = VALUE #( ( `a {` ) ( `  color: white;` ) ( `}` ) ) ).
  ENDMETHOD.

  METHOD error_import.
    check_error( source = VALUE #( ( `@import "foo";` ) ) message_part = `not supported` line = 1 ).
  ENDMETHOD.

  METHOD error_undefined_variable.
    check_error( source = VALUE #( ( `a {` ) ( `  color: $missing;` ) ( `}` ) ) message_part = `Undefined variable` line = 2 ).
  ENDMETHOD.

  METHOD error_unterminated_block.
    check_error( source = VALUE #( ( `a {` ) ( `  color: red;` ) ) message_part = `Expected "}"` line = 1 ).
  ENDMETHOD.

  METHOD error_missing_colon.
    check_error( source = VALUE #( ( `.a {` ) ( `  color red;` ) ( `}` ) ) message_part = `Expected ":"` line = 2 ).
  ENDMETHOD.

  METHOD error_directive.
    check_error( source = VALUE #( ( `a { @error "boom"; }` ) ) message_part = `boom` line = 1 ).
  ENDMETHOD.

ENDCLASS.
