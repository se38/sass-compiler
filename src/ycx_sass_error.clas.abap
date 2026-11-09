CLASS ycx_sass_error DEFINITION PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    DATA line TYPE i READ-ONLY.
    DATA text TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING text     TYPE string OPTIONAL
                line     TYPE i DEFAULT 0
                previous LIKE previous OPTIONAL.

    METHODS get_text REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.



CLASS ycx_sass_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->text = text.
    me->line = line.
  ENDMETHOD.

  METHOD get_text.
    IF line > 0.
      result = |{ text } (line { line })|.
    ELSE.
      result = text.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

