CLASS ycl_sass_compiler DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    "! Compiles SCSS (default) or indented SASS source into CSS (expanded style).
    "! @parameter i_source | Source lines
    "! @parameter i_sass | abap_true: indented SASS syntax, abap_false (default): SCSS syntax
    "! @parameter r_css | Resulting CSS lines
    "! @raising ycx_sass_error | Syntax or evaluation error
    METHODS compile
      IMPORTING i_source TYPE string_table
                i_sass   TYPE abap_bool DEFAULT abap_false
      returning value(r_css)   TYPE string_table
      RAISING   ycx_sass_error.

ENDCLASS.



CLASS ycl_sass_compiler IMPLEMENTATION.

  METHOD compile.
    CLEAR r_css.
    DATA(source) = concat_lines_of( table = i_source sep = cl_abap_char_utilities=>newline ).
    source = replace( val = source sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 ).
    IF i_sass = abap_true.
      source = lcl_sass_converter=>convert( source ).
    ENDIF.
    DATA(parser) = NEW lcl_parser( source ).
    DATA(nodes) = parser->parse( ).
    DATA(evaluator) = NEW lcl_evaluator( ).
    DATA(root) = evaluator->evaluate( nodes ).
    r_css = lcl_renderer=>render( root ).
  ENDMETHOD.

ENDCLASS.

