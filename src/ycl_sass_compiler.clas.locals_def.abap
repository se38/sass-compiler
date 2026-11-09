CLASS lcl_value DEFINITION DEFERRED.
CLASS lcl_node DEFINITION DEFERRED.
CLASS lcl_out DEFINITION DEFERRED.
CLASS lcl_scope DEFINITION DEFERRED.
CLASS lcl_evaluator DEFINITION DEFERRED.

TYPES tt_values TYPE STANDARD TABLE OF REF TO lcl_value WITH EMPTY KEY.
TYPES tt_nodes TYPE STANDARD TABLE OF REF TO lcl_node WITH EMPTY KEY.
TYPES tt_outs TYPE STANDARD TABLE OF REF TO lcl_out WITH EMPTY KEY.

TYPES: BEGIN OF ty_argument,
         name TYPE string,
         item TYPE REF TO lcl_value,
       END OF ty_argument.
TYPES tt_arguments TYPE STANDARD TABLE OF ty_argument WITH EMPTY KEY.

TYPES: BEGIN OF ty_out_item,
         kind     TYPE string,
         property TYPE string,
         text     TYPE string,
       END OF ty_out_item.

TYPES: BEGIN OF ty_context,
         container TYPE REF TO lcl_out,
         rule      TYPE REF TO lcl_out,
         selectors TYPE string_table,
         prefix    TYPE string,
         scope     TYPE REF TO lcl_scope,
       END OF ty_context.

TYPES: BEGIN OF ty_definition,
         name   TYPE string,
         params TYPE string,
         body   TYPE REF TO lcl_node,
         scope  TYPE REF TO lcl_scope,
       END OF ty_definition.
TYPES tt_definitions TYPE HASHED TABLE OF ty_definition WITH UNIQUE KEY name.

TYPES: BEGIN OF ty_extend,
         target   TYPE string,
         extender TYPE string,
       END OF ty_extend.

TYPES: BEGIN OF ty_content,
         node  TYPE REF TO lcl_node,
         scope TYPE REF TO lcl_scope,
       END OF ty_content.

"----------------------------------------------------------------------
" Helpers
"----------------------------------------------------------------------
CLASS lcl_util DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS char_at
      IMPORTING text          TYPE string
                pos           TYPE i
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS is_space
      IMPORTING character     TYPE string
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS is_digit
      IMPORTING character     TYPE string
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS is_letter
      IMPORTING character     TYPE string
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS is_ident_char
      IMPORTING character     TYPE string
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS trim_text
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS squash
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS normalize
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS split_top
      IMPORTING text          TYPE string
                separator     TYPE string
      RETURNING VALUE(result) TYPE string_table.
    CLASS-METHODS find_matching
      IMPORTING text          TYPE string
                start         TYPE i
                open          TYPE string
                close         TYPE string
      RETURNING VALUE(result) TYPE i.
    CLASS-METHODS format_number
      IMPORTING number        TYPE decfloat34
      RETURNING VALUE(result) TYPE string.
ENDCLASS.

"----------------------------------------------------------------------
" Values
"----------------------------------------------------------------------
CLASS lcl_value DEFINITION FINAL.
  PUBLIC SECTION.
    DATA kind TYPE string.
    DATA num TYPE decfloat34.
    DATA unit TYPE string.
    DATA str TYPE string.
    DATA quoted TYPE abap_bool.
    DATA red TYPE decfloat34.
    DATA green TYPE decfloat34.
    DATA blue TYPE decfloat34.
    DATA alpha TYPE decfloat34.
    DATA original TYPE string.
    DATA flag TYPE abap_bool.
    DATA separator TYPE string.
    DATA items TYPE tt_values.
    DATA keys TYPE tt_values.
    DATA computed TYPE abap_bool.

    CLASS-METHODS make_number
      IMPORTING number        TYPE decfloat34
                unit          TYPE string DEFAULT ``
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS make_string
      IMPORTING text          TYPE string
                quoted        TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS make_bool
      IMPORTING flag          TYPE abap_bool
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS make_null
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS make_color
      IMPORTING red           TYPE decfloat34
                green         TYPE decfloat34
                blue          TYPE decfloat34
                alpha         TYPE decfloat34
                original      TYPE string DEFAULT ``
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS make_list
      IMPORTING items         TYPE tt_values
                separator     TYPE string
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS make_map
      IMPORTING keys          TYPE tt_values
                items         TYPE tt_values
      RETURNING VALUE(result) TYPE REF TO lcl_value.

    METHODS clone RETURNING VALUE(result) TYPE REF TO lcl_value.
    METHODS to_css RETURNING VALUE(result) TYPE string.
    METHODS to_text RETURNING VALUE(result) TYPE string.
    METHODS is_true RETURNING VALUE(result) TYPE abap_bool.
    METHODS equals
      IMPORTING other         TYPE REF TO lcl_value
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.

CLASS lcl_color DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS parse_hex
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS named
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS to_css
      IMPORTING color         TYPE REF TO lcl_value
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS from_hsl
      IMPORTING hue           TYPE decfloat34
                saturation    TYPE decfloat34
                lightness     TYPE decfloat34
                alpha         TYPE decfloat34
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    CLASS-METHODS to_hsl
      IMPORTING color         TYPE REF TO lcl_value
      EXPORTING hue           TYPE decfloat34
                saturation    TYPE decfloat34
                lightness     TYPE decfloat34.
    CLASS-METHODS coerce
      IMPORTING input         TYPE REF TO lcl_value
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
  PRIVATE SECTION.
    CLASS-METHODS hue_to_rgb
      IMPORTING p             TYPE decfloat34
                q             TYPE decfloat34
                t             TYPE decfloat34
      RETURNING VALUE(result) TYPE decfloat34.
    CLASS-METHODS hex_pair
      IMPORTING channel       TYPE decfloat34
      RETURNING VALUE(result) TYPE string.
    CLASS-METHODS hex_value
      IMPORTING pair          TYPE string
      RETURNING VALUE(result) TYPE i.
ENDCLASS.

CLASS lcl_functions DEFINITION FINAL.
  PUBLIC SECTION.
    "! Calls a built-in function. Returns an initial reference if the function is unknown.
    CLASS-METHODS call
      IMPORTING name          TYPE string
                arguments     TYPE tt_arguments
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
  PRIVATE SECTION.
    CLASS-METHODS arg
      IMPORTING arguments     TYPE tt_arguments
                index         TYPE i
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    CLASS-METHODS number_arg
      IMPORTING arguments     TYPE tt_arguments
                index         TYPE i
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    CLASS-METHODS find_key
      IMPORTING map           TYPE REF TO lcl_value
                key           TYPE REF TO lcl_value
      RETURNING VALUE(result) TYPE i.
    CLASS-METHODS adjust_lightness
      IMPORTING arguments     TYPE tt_arguments
                direction     TYPE i
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    CLASS-METHODS adjust_alpha
      IMPORTING arguments     TYPE tt_arguments
                direction     TYPE i
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    CLASS-METHODS mix
      IMPORTING arguments     TYPE tt_arguments
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    CLASS-METHODS rgba
      IMPORTING arguments     TYPE tt_arguments
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    CLASS-METHODS min_max
      IMPORTING arguments     TYPE tt_arguments
                maximum       TYPE abap_bool
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
ENDCLASS.

"----------------------------------------------------------------------
" Syntax tree, scopes and output model
"----------------------------------------------------------------------
CLASS lcl_node DEFINITION FINAL.
  PUBLIC SECTION.
    DATA kind TYPE string.
    DATA name TYPE string.
    DATA target TYPE string.
    DATA text TYPE string.
    DATA line TYPE i.
    DATA children TYPE tt_nodes.
    DATA has_block TYPE abap_bool.
    DATA flag_default TYPE abap_bool.
    DATA flag_global TYPE abap_bool.
ENDCLASS.

CLASS lcl_out DEFINITION FINAL.
  PUBLIC SECTION.
    DATA kind TYPE string.
    DATA selectors TYPE string_table.
    DATA header TYPE string.
    DATA items TYPE STANDARD TABLE OF ty_out_item WITH EMPTY KEY.
    DATA children TYPE tt_outs.
ENDCLASS.

CLASS lcl_scope DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_variable,
             name TYPE string,
             item TYPE REF TO lcl_value,
           END OF ty_variable.

    DATA vars TYPE HASHED TABLE OF ty_variable WITH UNIQUE KEY name.
    DATA parent TYPE REF TO lcl_scope.
    DATA flow TYPE abap_bool.

    METHODS constructor
      IMPORTING parent TYPE REF TO lcl_scope OPTIONAL
                flow   TYPE abap_bool DEFAULT abap_false.
    METHODS lookup
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    METHODS declare
      IMPORTING name TYPE string
                item TYPE REF TO lcl_value.
    METHODS assign
      IMPORTING name   TYPE string
                item   TYPE REF TO lcl_value
                global TYPE abap_bool DEFAULT abap_false.
ENDCLASS.

"----------------------------------------------------------------------
" Front end
"----------------------------------------------------------------------
CLASS lcl_sass_converter DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS convert
      IMPORTING source        TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.

CLASS lcl_parser DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor IMPORTING source TYPE string.
    METHODS parse
      RETURNING VALUE(result) TYPE tt_nodes
      RAISING   ycx_sass_error.
  PRIVATE SECTION.
    DATA source TYPE string.
    DATA position TYPE i.
    DATA size TYPE i.
    DATA line_cache_position TYPE i.
    DATA line_cache_value TYPE i VALUE 1.

    METHODS at
      IMPORTING offset        TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE string.
    METHODS line_at
      IMPORTING pos           TYPE i
      RETURNING VALUE(result) TYPE i.
    METHODS fail
      IMPORTING message TYPE string
                line    TYPE i
      RAISING   ycx_sass_error.
    METHODS parse_block
      RETURNING VALUE(result) TYPE tt_nodes
      RAISING   ycx_sass_error.
    METHODS read_statement
      EXPORTING text       TYPE string
                terminator TYPE string
      RAISING   ycx_sass_error.
    METHODS make_statement
      IMPORTING text          TYPE string
                terminator    TYPE string
                line          TYPE i
      RETURNING VALUE(result) TYPE REF TO lcl_node
      RAISING   ycx_sass_error.
ENDCLASS.

"----------------------------------------------------------------------
" Evaluation
"----------------------------------------------------------------------
CLASS lcl_expr DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING text      TYPE string
                scope     TYPE REF TO lcl_scope
                evaluator TYPE REF TO lcl_evaluator.
    METHODS parse
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_call_arguments
      RETURNING VALUE(result) TYPE tt_arguments
      RAISING   ycx_sass_error.
  PRIVATE SECTION.
    DATA source TYPE string.
    DATA position TYPE i.
    DATA size TYPE i.
    DATA scope TYPE REF TO lcl_scope.
    DATA evaluator TYPE REF TO lcl_evaluator.
    DATA depth TYPE i.

    METHODS at
      IMPORTING offset        TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE string.
    METHODS skip_spaces
      RETURNING VALUE(skipped) TYPE abap_bool.
    METHODS fail
      IMPORTING message TYPE string
      RAISING   ycx_sass_error.
    METHODS looking_at_word
      IMPORTING word          TYPE string
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS read_name
      RETURNING VALUE(result) TYPE string.
    METHODS starts_number
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS parse_comma_list
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_space_list
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_or
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_and
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_equality
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_relational
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_additive
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_multiplicative
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_unary
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_primary
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_group
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_string
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_variable
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_hex_color
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    METHODS parse_number
      RETURNING VALUE(result) TYPE REF TO lcl_value.
    METHODS parse_identifier
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS parse_function
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS expect_close RAISING ycx_sass_error.
    METHODS binary
      IMPORTING operator      TYPE string
                left          TYPE REF TO lcl_value
                right         TYPE REF TO lcl_value
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS numeric
      IMPORTING operator      TYPE string
                left          TYPE REF TO lcl_value
                right         TYPE REF TO lcl_value
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS compare
      IMPORTING operator      TYPE string
                left          TYPE REF TO lcl_value
                right         TYPE REF TO lcl_value
      RETURNING VALUE(result) TYPE abap_bool
      RAISING   ycx_sass_error.
ENDCLASS.

CLASS lcl_evaluator DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS evaluate
      IMPORTING nodes         TYPE tt_nodes
      RETURNING VALUE(result) TYPE REF TO lcl_out
      RAISING   ycx_sass_error.
    METHODS eval_expression
      IMPORTING text          TYPE string
                scope         TYPE REF TO lcl_scope
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
    METHODS interpolate
      IMPORTING text          TYPE string
                scope         TYPE REF TO lcl_scope
      RETURNING VALUE(result) TYPE string
      RAISING   ycx_sass_error.
    METHODS substitute_variables
      IMPORTING text          TYPE string
                scope         TYPE REF TO lcl_scope
      RETURNING VALUE(result) TYPE string
      RAISING   ycx_sass_error.
    METHODS has_function
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS call_function
      IMPORTING name          TYPE string
                arguments     TYPE tt_arguments
      RETURNING VALUE(result) TYPE REF TO lcl_value
      RAISING   ycx_sass_error.
  PRIVATE SECTION.
    DATA mixins TYPE tt_definitions.
    DATA functions TYPE tt_definitions.
    DATA extends TYPE STANDARD TABLE OF ty_extend WITH EMPTY KEY.
    DATA content_stack TYPE STANDARD TABLE OF ty_content WITH EMPTY KEY.
    DATA returned TYPE abap_bool.
    DATA returned_value TYPE REF TO lcl_value.
    DATA call_depth TYPE i.

    METHODS fail
      IMPORTING message TYPE string
      RAISING   ycx_sass_error.
    METHODS exec_nodes
      IMPORTING nodes   TYPE tt_nodes
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_flow_block
      IMPORTING nodes   TYPE tt_nodes
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_if
      IMPORTING nodes   TYPE tt_nodes
                context TYPE ty_context
      CHANGING  index   TYPE i
      RAISING   ycx_sass_error.
    METHODS exec_node
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_comment
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context.
    METHODS exec_variable
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_declaration
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_rule
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_at_rule
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_include
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_content
      IMPORTING context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_each
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_for
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_while
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_extend
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_bubbling
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS exec_generic_at
      IMPORTING node    TYPE REF TO lcl_node
                context TYPE ty_context
      RAISING   ycx_sass_error.
    METHODS bind_parameters
      IMPORTING params           TYPE string
                definition_scope TYPE REF TO lcl_scope
                arguments        TYPE tt_arguments
      RETURNING VALUE(result)    TYPE REF TO lcl_scope
      RAISING   ycx_sass_error.
    METHODS evaluate_declaration_value
      IMPORTING property      TYPE string
                text          TYPE string
                scope         TYPE REF TO lcl_scope
      RETURNING VALUE(result) TYPE string
      RAISING   ycx_sass_error.
    METHODS combine_selector
      IMPORTING parent        TYPE string
                child         TYPE string
      RETURNING VALUE(result) TYPE string.
    METHODS finish_extends
      IMPORTING root TYPE REF TO lcl_out.
    METHODS apply_extends
      IMPORTING node          TYPE REF TO lcl_out
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS replace_target
      IMPORTING selector      TYPE string
                target        TYPE string
                extender      TYPE string
      RETURNING VALUE(result) TYPE string.
    METHODS remove_placeholders
      IMPORTING node TYPE REF TO lcl_out.
ENDCLASS.

CLASS lcl_renderer DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS render
      IMPORTING root          TYPE REF TO lcl_out
      RETURNING VALUE(result) TYPE string_table.
  PRIVATE SECTION.
    CLASS-METHODS render_children
      IMPORTING parent TYPE REF TO lcl_out
                depth  TYPE i
      CHANGING  lines  TYPE string_table.
    CLASS-METHODS render_items
      IMPORTING node  TYPE REF TO lcl_out
                depth TYPE i
      CHANGING  lines TYPE string_table.
    CLASS-METHODS append_text
      IMPORTING text   TYPE string
                indent TYPE string
      CHANGING  lines  TYPE string_table.
    CLASS-METHODS has_output
      IMPORTING node          TYPE REF TO lcl_out
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.
