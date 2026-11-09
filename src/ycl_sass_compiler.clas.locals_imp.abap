CLASS lcl_util IMPLEMENTATION.

  METHOD char_at.
    IF pos >= 0 AND pos < strlen( text ).
      result = substring( val = text off = pos len = 1 ).
    ENDIF.
  ENDMETHOD.

  METHOD is_space.
    result = xsdbool( character = ` `
                   OR character = cl_abap_char_utilities=>newline
                   OR character = cl_abap_char_utilities=>horizontal_tab ).
  ENDMETHOD.

  METHOD is_digit.
    result = xsdbool( character <> `` AND character CA `0123456789` ).
  ENDMETHOD.

  METHOD is_letter.
    result = xsdbool( character <> `` AND character CA `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ` ).
  ENDMETHOD.

  METHOD is_ident_char.
    result = xsdbool( character <> `` AND character CA `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-` ).
  ENDMETHOD.

  METHOD trim_text.
    result = replace( val = text regex = `^\s+|\s+$` with = `` occ = 0 ).
  ENDMETHOD.

  METHOD squash.
    result = replace( val = text regex = `\s+` with = ` ` occ = 0 ).
    result = trim_text( result ).
  ENDMETHOD.

  METHOD normalize.
    result = replace( val = name sub = `_` with = `-` occ = 0 ).
  ENDMETHOD.

  METHOD split_top.
    DATA depth TYPE i.
    DATA quote TYPE string.
    DATA current TYPE string.
    DATA(index) = 0.
    DATA(length) = strlen( text ).
    WHILE index < length.
      DATA(character) = char_at( text = text pos = index ).
      IF quote IS NOT INITIAL.
        current = current && character.
        IF character = `\` AND index + 1 < length.
          index = index + 1.
          current = current && char_at( text = text pos = index ).
        ELSEIF character = quote.
          CLEAR quote.
        ENDIF.
      ELSE.
        IF character = `"` OR character = `'`.
          quote = character.
          current = current && character.
        ELSEIF character = `(` OR character = `[` OR character = `{`.
          depth = depth + 1.
          current = current && character.
        ELSEIF character = `)` OR character = `]` OR character = `}`.
          depth = depth - 1.
          current = current && character.
        ELSEIF character = separator AND depth = 0.
          APPEND current TO result.
          CLEAR current.
        ELSE.
          current = current && character.
        ENDIF.
      ENDIF.
      index = index + 1.
    ENDWHILE.
    APPEND current TO result.
  ENDMETHOD.

  METHOD find_matching.
    DATA depth TYPE i.
    DATA quote TYPE string.
    DATA(index) = start.
    DATA(length) = strlen( text ).
    result = -1.
    WHILE index < length.
      DATA(character) = char_at( text = text pos = index ).
      IF quote IS NOT INITIAL.
        IF character = `\`.
          index = index + 1.
        ELSEIF character = quote.
          CLEAR quote.
        ENDIF.
      ELSEIF character = `"` OR character = `'`.
        quote = character.
      ELSEIF character = open.
        depth = depth + 1.
      ELSEIF character = close.
        depth = depth - 1.
        IF depth = 0.
          result = index.
          RETURN.
        ENDIF.
      ENDIF.
      index = index + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD format_number.
    DATA(rounded) = round( val = number dec = 10 ).
    result = |{ rounded DECIMALS = 10 }|.
    IF result CS `.`.
      result = replace( val = result regex = `0+$` with = `` ).
      result = replace( val = result regex = `\.$` with = `` ).
    ENDIF.
    IF result = `-0`.
      result = `0`.
    ENDIF.
  ENDMETHOD.

ENDCLASS.



CLASS lcl_value IMPLEMENTATION.

  METHOD make_number.
    result = NEW #( ).
    result->kind = `num`.
    result->num = number.
    result->unit = unit.
  ENDMETHOD.

  METHOD make_string.
    result = NEW #( ).
    result->kind = `str`.
    result->str = text.
    result->quoted = quoted.
  ENDMETHOD.

  METHOD make_bool.
    result = NEW #( ).
    result->kind = `bool`.
    result->flag = flag.
  ENDMETHOD.

  METHOD make_null.
    result = NEW #( ).
    result->kind = `null`.
  ENDMETHOD.

  METHOD make_color.
    result = NEW #( ).
    result->kind = `col`.
    result->red = red.
    result->green = green.
    result->blue = blue.
    result->alpha = alpha.
    result->original = original.
  ENDMETHOD.

  METHOD make_list.
    result = NEW #( ).
    result->kind = `list`.
    result->items = items.
    result->separator = separator.
  ENDMETHOD.

  METHOD make_map.
    result = NEW #( ).
    result->kind = `map`.
    result->keys = keys.
    result->items = items.
  ENDMETHOD.

  METHOD clone.
    result = NEW #( ).
    result->kind = kind.
    result->num = num.
    result->unit = unit.
    result->str = str.
    result->quoted = quoted.
    result->red = red.
    result->green = green.
    result->blue = blue.
    result->alpha = alpha.
    result->original = original.
    result->flag = flag.
    result->separator = separator.
    result->items = items.
    result->keys = keys.
    result->computed = computed.
  ENDMETHOD.

  METHOD to_css.
    CASE kind.
      WHEN `num`.
        result = lcl_util=>format_number( num ) && unit.
      WHEN `str`.
        IF quoted = abap_true.
          result = `"` && str && `"`.
        ELSE.
          result = str.
        ENDIF.
      WHEN `col`.
        IF original IS NOT INITIAL.
          result = original.
        ELSE.
          result = lcl_color=>to_css( me ).
        ENDIF.
      WHEN `bool`.
        result = COND #( WHEN flag = abap_true THEN `true` ELSE `false` ).
      WHEN `null`.
        result = ``.
      WHEN `list`.
        DATA(parts) = VALUE string_table( ).
        LOOP AT items INTO DATA(item).
          IF item->kind = `null`.
            CONTINUE.
          ENDIF.
          APPEND item->to_css( ) TO parts.
        ENDLOOP.
        result = concat_lines_of( table = parts sep = COND #( WHEN separator = `,` THEN `, ` ELSE ` ` ) ).
      WHEN `map`.
        DATA(entries) = VALUE string_table( ).
        LOOP AT keys INTO DATA(key).
          DATA(entry_index) = sy-tabix.
          APPEND key->to_css( ) && `: ` && items[ entry_index ]->to_css( ) TO entries.
        ENDLOOP.
        result = `(` && concat_lines_of( table = entries sep = `, ` ) && `)`.
    ENDCASE.
  ENDMETHOD.

  METHOD to_text.
    IF kind = `str`.
      result = str.
    ELSE.
      result = to_css( ).
    ENDIF.
  ENDMETHOD.

  METHOD is_true.
    result = xsdbool( NOT ( kind = `null` OR ( kind = `bool` AND flag = abap_false ) ) ).
  ENDMETHOD.

  METHOD equals.
    IF other IS NOT BOUND.
      result = abap_false.
      RETURN.
    ENDIF.
    IF kind <> other->kind.
      result = xsdbool( to_text( ) = other->to_text( ) AND kind <> `null` AND other->kind <> `null` ).
      RETURN.
    ENDIF.
    CASE kind.
      WHEN `num`.
        result = xsdbool( num = other->num AND unit = other->unit ).
      WHEN `bool`.
        result = xsdbool( flag = other->flag ).
      WHEN `null`.
        result = abap_true.
      WHEN `str`.
        result = xsdbool( str = other->str ).
      WHEN OTHERS.
        result = xsdbool( to_css( ) = other->to_css( ) ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.



CLASS lcl_color IMPLEMENTATION.

  METHOD hex_value.
    result = find( val = `0123456789abcdef` sub = substring( val = pair off = 0 len = 1 ) ) * 16
           + find( val = `0123456789abcdef` sub = substring( val = pair off = 1 len = 1 ) ).
  ENDMETHOD.

  METHOD hex_pair.
    DATA(channel_value) = round( val = channel dec = 0 ).
    IF channel_value < 0.
      channel_value = 0.
    ELSEIF channel_value > 255.
      channel_value = 255.
    ENDIF.
    DATA(whole) = CONV i( channel_value ).
    DATA(high) = whole DIV 16.
    DATA(low) = whole MOD 16.
    result = substring( val = `0123456789abcdef` off = high len = 1 )
          && substring( val = `0123456789abcdef` off = low len = 1 ).
  ENDMETHOD.

  METHOD parse_hex.
    DATA(digits) = to_lower( substring( val = text off = 1 ) ).
    DATA(digit_count) = strlen( digits ).
    IF digit_count <> 3 AND digit_count <> 4 AND digit_count <> 6 AND digit_count <> 8.
      RETURN.
    ENDIF.
    IF NOT matches( val = digits regex = `[0-9a-f]+` ).
      RETURN.
    ENDIF.
    IF digit_count <= 4.
      DATA(expanded) = ``.
      DO digit_count TIMES.
        DATA(character) = substring( val = digits off = sy-index - 1 len = 1 ).
        expanded = expanded && character && character.
      ENDDO.
      digits = expanded.
    ENDIF.
    DATA(opacity) = CONV decfloat34( 1 ).
    IF strlen( digits ) = 8.
      opacity = CONV decfloat34( hex_value( substring( val = digits off = 6 len = 2 ) ) ) / 255.
    ENDIF.
    result = lcl_value=>make_color(
      red      = hex_value( substring( val = digits off = 0 len = 2 ) )
      green    = hex_value( substring( val = digits off = 2 len = 2 ) )
      blue     = hex_value( substring( val = digits off = 4 len = 2 ) )
      alpha    = opacity
      original = text ).
  ENDMETHOD.

  METHOD named.
    TYPES: BEGIN OF ty_named,
             name TYPE string,
             hex  TYPE string,
           END OF ty_named.
    TYPES tt_named TYPE STANDARD TABLE OF ty_named WITH EMPTY KEY.
    DATA(colors) = VALUE tt_named(
      ( name = `black` hex = `#000000` )
      ( name = `white` hex = `#ffffff` )
      ( name = `red` hex = `#ff0000` )
      ( name = `green` hex = `#008000` )
      ( name = `blue` hex = `#0000ff` )
      ( name = `yellow` hex = `#ffff00` )
      ( name = `orange` hex = `#ffa500` )
      ( name = `gray` hex = `#808080` )
      ( name = `grey` hex = `#808080` )
      ( name = `purple` hex = `#800080` )
      ( name = `pink` hex = `#ffc0cb` )
      ( name = `cyan` hex = `#00ffff` )
      ( name = `magenta` hex = `#ff00ff` )
      ( name = `silver` hex = `#c0c0c0` )
      ( name = `navy` hex = `#000080` )
      ( name = `teal` hex = `#008080` ) ).
    DATA(lower) = to_lower( name ).
    IF lower = `transparent`.
      result = lcl_value=>make_color( red = 0 green = 0 blue = 0 alpha = 0 ).
      RETURN.
    ENDIF.
    READ TABLE colors INTO DATA(found) WITH KEY name = lower.
    IF sy-subrc = 0.
      result = parse_hex( found-hex ).
      result->original = ``.
    ENDIF.
  ENDMETHOD.

  METHOD to_css.
    IF color->alpha < 1.
      result = |rgba({ lcl_util=>format_number( round( val = color->red dec = 0 ) ) }, |
            && |{ lcl_util=>format_number( round( val = color->green dec = 0 ) ) }, |
            && |{ lcl_util=>format_number( round( val = color->blue dec = 0 ) ) }, |
            && |{ lcl_util=>format_number( color->alpha ) })|.
    ELSE.
      result = `#` && hex_pair( color->red ) && hex_pair( color->green ) && hex_pair( color->blue ).
    ENDIF.
  ENDMETHOD.

  METHOD to_hsl.
    DATA(red_part) = color->red / 255.
    DATA(green_part) = color->green / 255.
    DATA(blue_part) = color->blue / 255.
    DATA(maximum) = red_part.
    IF green_part > maximum.
      maximum = green_part.
    ENDIF.
    IF blue_part > maximum.
      maximum = blue_part.
    ENDIF.
    DATA(minimum) = red_part.
    IF green_part < minimum.
      minimum = green_part.
    ENDIF.
    IF blue_part < minimum.
      minimum = blue_part.
    ENDIF.
    lightness = ( maximum + minimum ) / 2.
    IF maximum = minimum.
      hue = 0.
      saturation = 0.
      RETURN.
    ENDIF.
    DATA(delta) = maximum - minimum.
    IF lightness > CONV decfloat34( '0.5' ).
      saturation = delta / ( 2 - maximum - minimum ).
    ELSE.
      saturation = delta / ( maximum + minimum ).
    ENDIF.
    IF maximum = red_part.
      hue = ( green_part - blue_part ) / delta.
      IF green_part < blue_part.
        hue = hue + 6.
      ENDIF.
    ELSEIF maximum = green_part.
      hue = ( blue_part - red_part ) / delta + 2.
    ELSE.
      hue = ( red_part - green_part ) / delta + 4.
    ENDIF.
    hue = hue / 6.
  ENDMETHOD.

  METHOD hue_to_rgb.
    DATA(shifted) = t.
    IF shifted < 0.
      shifted = shifted + 1.
    ENDIF.
    IF shifted > 1.
      shifted = shifted - 1.
    ENDIF.
    DATA(one_sixth) = CONV decfloat34( 1 ) / 6.
    DATA(one_half) = CONV decfloat34( '0.5' ).
    DATA(two_thirds) = CONV decfloat34( 2 ) / 3.
    IF shifted < one_sixth.
      result = p + ( q - p ) * 6 * shifted.
    ELSEIF shifted < one_half.
      result = q.
    ELSEIF shifted < two_thirds.
      result = p + ( q - p ) * ( two_thirds - shifted ) * 6.
    ELSE.
      result = p.
    ENDIF.
  ENDMETHOD.

  METHOD from_hsl.
    DATA red_part TYPE decfloat34.
    DATA green_part TYPE decfloat34.
    DATA blue_part TYPE decfloat34.
    IF saturation = 0.
      red_part = lightness.
      green_part = lightness.
      blue_part = lightness.
    ELSE.
      DATA(upper) = COND decfloat34( WHEN lightness < CONV decfloat34( '0.5' )
                                     THEN lightness * ( 1 + saturation )
                                     ELSE lightness + saturation - lightness * saturation ).
      DATA(lower) = 2 * lightness - upper.
      DATA(third) = CONV decfloat34( 1 ) / 3.
      red_part = hue_to_rgb( p = lower q = upper t = hue + third ).
      green_part = hue_to_rgb( p = lower q = upper t = hue ).
      blue_part = hue_to_rgb( p = lower q = upper t = hue - third ).
    ENDIF.
    result = lcl_value=>make_color( red = red_part * 255 green = green_part * 255 blue = blue_part * 255 alpha = alpha ).
  ENDMETHOD.

  METHOD coerce.
    IF input->kind = `col`.
      result = input.
      RETURN.
    ENDIF.
    IF input->kind = `str` AND input->quoted = abap_false.
      IF find( val = input->str sub = `#` ) = 0.
        result = parse_hex( input->str ).
      ELSE.
        result = named( input->str ).
      ENDIF.
      IF result IS BOUND.
        RETURN.
      ENDIF.
    ENDIF.
    RAISE EXCEPTION NEW ycx_sass_error( text = |"{ input->to_css( ) }" is not a color.| ).
  ENDMETHOD.

ENDCLASS.



CLASS lcl_functions IMPLEMENTATION.

  METHOD arg.
    IF index > lines( arguments ).
      RAISE EXCEPTION NEW ycx_sass_error( text = |Missing argument { index }.| ).
    ENDIF.
    result = arguments[ index ]-item.
  ENDMETHOD.

  METHOD number_arg.
    result = arg( arguments = arguments index = index ).
    IF result->kind <> `num`.
      RAISE EXCEPTION NEW ycx_sass_error( text = |"{ result->to_css( ) }" is not a number.| ).
    ENDIF.
  ENDMETHOD.

  METHOD find_key.
    result = 0.
    LOOP AT map->keys INTO DATA(candidate).
      IF candidate->equals( key ) = abap_true.
        result = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD adjust_lightness.
    DATA(color) = lcl_color=>coerce( arg( arguments = arguments index = 1 ) ).
    DATA(amount) = number_arg( arguments = arguments index = 2 ).
    lcl_color=>to_hsl( EXPORTING color = color
                       IMPORTING hue = DATA(hue) saturation = DATA(saturation) lightness = DATA(lightness) ).
    lightness = lightness + direction * amount->num / 100.
    IF lightness < 0.
      lightness = 0.
    ELSEIF lightness > 1.
      lightness = 1.
    ENDIF.
    result = lcl_color=>from_hsl( hue = hue saturation = saturation lightness = lightness alpha = color->alpha ).
    result->computed = abap_true.
  ENDMETHOD.

  METHOD adjust_alpha.
    DATA(color) = lcl_color=>coerce( arg( arguments = arguments index = 1 ) ).
    DATA(amount) = number_arg( arguments = arguments index = 2 ).
    DATA(opacity) = color->alpha + direction * amount->num.
    IF opacity < 0.
      opacity = 0.
    ELSEIF opacity > 1.
      opacity = 1.
    ENDIF.
    result = lcl_value=>make_color( red = color->red green = color->green blue = color->blue alpha = opacity ).
  ENDMETHOD.

  METHOD mix.
    DATA(first) = lcl_color=>coerce( arg( arguments = arguments index = 1 ) ).
    DATA(second) = lcl_color=>coerce( arg( arguments = arguments index = 2 ) ).
    DATA weight TYPE decfloat34 VALUE '0.5'.
    IF lines( arguments ) >= 3.
      weight = number_arg( arguments = arguments index = 3 )->num / 100.
    ENDIF.
    DATA(factor) = weight * 2 - 1.
    DATA(difference) = first->alpha - second->alpha.
    DATA first_weight TYPE decfloat34.
    IF factor * difference = -1.
      first_weight = factor.
    ELSE.
      first_weight = ( factor + difference ) / ( 1 + factor * difference ).
    ENDIF.
    first_weight = ( first_weight + 1 ) / 2.
    DATA(second_weight) = 1 - first_weight.
    result = lcl_value=>make_color(
      red   = first->red * first_weight + second->red * second_weight
      green = first->green * first_weight + second->green * second_weight
      blue  = first->blue * first_weight + second->blue * second_weight
      alpha = first->alpha * weight + second->alpha * ( 1 - weight ) ).
  ENDMETHOD.

  METHOD rgba.
    DATA(argument_count) = lines( arguments ).
    IF argument_count = 2.
      DATA(color) = lcl_color=>coerce( arg( arguments = arguments index = 1 ) ).
      DATA(opacity) = number_arg( arguments = arguments index = 2 ).
      result = lcl_value=>make_color( red = color->red green = color->green blue = color->blue alpha = opacity->num ).
    ELSEIF argument_count = 3 OR argument_count = 4.
      DATA(red) = number_arg( arguments = arguments index = 1 ).
      DATA(green) = number_arg( arguments = arguments index = 2 ).
      DATA(blue) = number_arg( arguments = arguments index = 3 ).
      DATA alpha_value TYPE decfloat34 VALUE 1.
      IF argument_count = 4.
        DATA(alpha) = number_arg( arguments = arguments index = 4 ).
        alpha_value = COND #( WHEN alpha->unit = `%` THEN alpha->num / 100 ELSE alpha->num ).
      ENDIF.
      result = lcl_value=>make_color(
        red   = COND #( WHEN red->unit = `%` THEN red->num * 255 / 100 ELSE red->num )
        green = COND #( WHEN green->unit = `%` THEN green->num * 255 / 100 ELSE green->num )
        blue  = COND #( WHEN blue->unit = `%` THEN blue->num * 255 / 100 ELSE blue->num )
        alpha = alpha_value ).
    ENDIF.
  ENDMETHOD.

  METHOD min_max.
    DATA best TYPE REF TO lcl_value.
    LOOP AT arguments INTO DATA(argument).
      DATA(candidate) = argument-item.
      IF candidate->kind <> `num`.
        RETURN.
      ENDIF.
      IF best IS NOT BOUND.
        best = candidate.
        CONTINUE.
      ENDIF.
      IF best->unit <> candidate->unit AND best->unit IS NOT INITIAL AND candidate->unit IS NOT INITIAL.
        CLEAR best.
        RETURN.
      ENDIF.
      IF ( maximum = abap_true AND candidate->num > best->num )
      OR ( maximum = abap_false AND candidate->num < best->num ).
        best = candidate.
      ENDIF.
    ENDLOOP.
    result = best.
  ENDMETHOD.

  METHOD call.
    DATA(function) = lcl_util=>normalize( to_lower( name ) ).
    DATA number TYPE REF TO lcl_value.
    DATA subject TYPE REF TO lcl_value.
    CASE function.
      WHEN `percentage`.
        number = number_arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_number( number = number->num * 100 unit = `%` ).
      WHEN `round`.
        number = number_arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_number( number = round( val = number->num dec = 0 ) unit = number->unit ).
      WHEN `ceil`.
        number = number_arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_number( number = ceil( number->num ) unit = number->unit ).
      WHEN `floor`.
        number = number_arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_number( number = floor( number->num ) unit = number->unit ).
      WHEN `abs`.
        number = number_arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_number( number = abs( number->num ) unit = number->unit ).
      WHEN `min`.
        result = min_max( arguments = arguments maximum = abap_false ).
      WHEN `max`.
        result = min_max( arguments = arguments maximum = abap_true ).
      WHEN `unquote`.
        result = lcl_value=>make_string( text = arg( arguments = arguments index = 1 )->to_text( ) ).
      WHEN `quote`.
        result = lcl_value=>make_string( text = arg( arguments = arguments index = 1 )->to_text( ) quoted = abap_true ).
      WHEN `to-upper-case`.
        subject = arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_string( text = to_upper( subject->to_text( ) ) quoted = subject->quoted ).
      WHEN `to-lower-case`.
        subject = arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_string( text = to_lower( subject->to_text( ) ) quoted = subject->quoted ).
      WHEN `str-length`.
        result = lcl_value=>make_number( strlen( arg( arguments = arguments index = 1 )->to_text( ) ) ).
      WHEN `length`.
        subject = arg( arguments = arguments index = 1 ).
        IF subject->kind = `list` OR subject->kind = `map`.
          result = lcl_value=>make_number( lines( subject->items ) ).
        ELSE.
          result = lcl_value=>make_number( 1 ).
        ENDIF.
      WHEN `nth`.
        subject = arg( arguments = arguments index = 1 ).
        number = number_arg( arguments = arguments index = 2 ).
        DATA(entries) = COND tt_values( WHEN subject->kind = `list` THEN subject->items ELSE VALUE #( ( subject ) ) ).
        DATA(position) = CONV i( number->num ).
        IF position < 0.
          position = lines( entries ) + position + 1.
        ENDIF.
        IF position < 1 OR position > lines( entries ).
          RAISE EXCEPTION NEW ycx_sass_error( text = |Index { number->num } out of range.| ).
        ENDIF.
        result = entries[ position ].
      WHEN `map-get`.
        subject = arg( arguments = arguments index = 1 ).
        DATA(key_index) = find_key( map = subject key = arg( arguments = arguments index = 2 ) ).
        IF key_index > 0.
          result = subject->items[ key_index ].
        ELSE.
          result = lcl_value=>make_null( ).
        ENDIF.
      WHEN `map-has-key`.
        subject = arg( arguments = arguments index = 1 ).
        result = lcl_value=>make_bool( xsdbool( find_key( map = subject key = arg( arguments = arguments index = 2 ) ) > 0 ) ).
      WHEN `map-keys`.
        result = lcl_value=>make_list( items = arg( arguments = arguments index = 1 )->keys separator = `,` ).
      WHEN `map-values`.
        result = lcl_value=>make_list( items = arg( arguments = arguments index = 1 )->items separator = `,` ).
      WHEN `lighten`.
        result = adjust_lightness( arguments = arguments direction = 1 ).
      WHEN `darken`.
        result = adjust_lightness( arguments = arguments direction = -1 ).
      WHEN `opacify` OR `fade-in`.
        result = adjust_alpha( arguments = arguments direction = 1 ).
      WHEN `transparentize` OR `fade-out`.
        result = adjust_alpha( arguments = arguments direction = -1 ).
      WHEN `mix`.
        result = mix( arguments ).
      WHEN `rgba` OR `rgb`.
        TRY.
            result = rgba( arguments ).
          CATCH ycx_sass_error.
            CLEAR result.
        ENDTRY.
      WHEN `if`.
        IF arg( arguments = arguments index = 1 )->is_true( ) = abap_true.
          result = arg( arguments = arguments index = 2 ).
        ELSE.
          result = arg( arguments = arguments index = 3 ).
        ENDIF.
    ENDCASE.
    IF result IS BOUND AND result->kind = `col`.
      result = result->clone( ).
      result->computed = abap_true.
    ENDIF.
  ENDMETHOD.

ENDCLASS.



CLASS lcl_scope IMPLEMENTATION.

  METHOD constructor.
    me->parent = parent.
    me->flow = flow.
  ENDMETHOD.

  METHOD lookup.
    DATA(key) = lcl_util=>normalize( name ).
    DATA(current) = me.
    WHILE current IS BOUND.
      READ TABLE current->vars INTO DATA(variable) WITH TABLE KEY name = key.
      IF sy-subrc = 0.
        result = variable-item.
        RETURN.
      ENDIF.
      current = current->parent.
    ENDWHILE.
  ENDMETHOD.

  METHOD declare.
    DATA(entry) = VALUE ty_variable( name = lcl_util=>normalize( name ) item = item ).
    INSERT entry INTO TABLE vars.
    IF sy-subrc <> 0.
      MODIFY TABLE vars FROM entry.
    ENDIF.
  ENDMETHOD.

  METHOD assign.
    DATA(key) = lcl_util=>normalize( name ).
    IF global = abap_true.
      DATA(root) = me.
      WHILE root->parent IS BOUND.
        root = root->parent.
      ENDWHILE.
      root->declare( name = key item = item ).
      RETURN.
    ENDIF.
    DATA(search) = me.
    DO.
      IF line_exists( search->vars[ name = key ] ).
        search->declare( name = key item = item ).
        RETURN.
      ENDIF.
      IF search->flow = abap_true AND search->parent IS BOUND.
        search = search->parent.
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.
    declare( name = key item = item ).
  ENDMETHOD.

ENDCLASS.



CLASS lcl_sass_converter IMPLEMENTATION.

  METHOD convert.
    TYPES: BEGIN OF ty_entry,
             indent TYPE i,
             text   TYPE string,
           END OF ty_entry.
    DATA entries TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.
    DATA raw TYPE string_table.
    DATA stack TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA output TYPE string_table.

    SPLIT source AT cl_abap_char_utilities=>newline INTO TABLE raw.
    LOOP AT raw INTO DATA(raw_line).
      DATA(right_trimmed) = replace( val = raw_line regex = `\s+$` with = `` ).
      IF right_trimmed IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(stripped) = replace( val = right_trimmed regex = `^\s+` with = `` ).
      APPEND VALUE #( indent = strlen( right_trimmed ) - strlen( stripped ) text = stripped ) TO entries.
    ENDLOOP.

    " Join selector lists that continue on the next line
    DATA(index) = 1.
    WHILE index < lines( entries ).
      DATA(current_text) = entries[ index ]-text.
      IF substring( val = current_text off = strlen( current_text ) - 1 len = 1 ) = `,`
         AND find( val = current_text sub = `//` ) <> 0.
        entries[ index ]-text = current_text && ` ` && entries[ index + 1 ]-text.
        DELETE entries INDEX index + 1.
      ELSE.
        index = index + 1.
      ENDIF.
    ENDWHILE.

    LOOP AT entries INTO DATA(entry).
      DATA(entry_index) = sy-tabix.
      WHILE stack IS NOT INITIAL AND stack[ lines( stack ) ] >= entry-indent.
        APPEND `}` TO output.
        DELETE stack INDEX lines( stack ).
      ENDWHILE.

      DATA(text) = entry-text.
      IF find( val = text sub = `//` ) = 0 OR find( val = text sub = `/*` ) = 0.
        APPEND text TO output.
        CONTINUE.
      ENDIF.
      IF find( val = text sub = `=` ) = 0.
        text = `@mixin ` && substring( val = text off = 1 ).
      ELSEIF find( val = text sub = `+` ) = 0 AND lcl_util=>is_space( lcl_util=>char_at( text = text pos = 1 ) ) = abap_false.
        text = `@include ` && substring( val = text off = 1 ).
      ENDIF.

      DATA(next_indent) = -1.
      DATA(lookahead) = entry_index + 1.
      WHILE lookahead <= lines( entries ).
        DATA(candidate) = entries[ lookahead ].
        IF find( val = candidate-text sub = `//` ) = 0 OR find( val = candidate-text sub = `/*` ) = 0.
          lookahead = lookahead + 1.
        ELSE.
          next_indent = candidate-indent.
          EXIT.
        ENDIF.
      ENDWHILE.

      IF next_indent > entry-indent.
        APPEND text && ` {` TO output.
        APPEND entry-indent TO stack.
      ELSE.
        APPEND text && `;` TO output.
      ENDIF.
    ENDLOOP.

    WHILE stack IS NOT INITIAL.
      APPEND `}` TO output.
      DELETE stack INDEX lines( stack ).
    ENDWHILE.

    result = concat_lines_of( table = output sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.

ENDCLASS.



CLASS lcl_parser IMPLEMENTATION.

  METHOD constructor.
    me->source = source.
    size = strlen( source ).
  ENDMETHOD.

  METHOD at.
    result = lcl_util=>char_at( text = source pos = position + offset ).
  ENDMETHOD.

  METHOD line_at.
    IF pos < line_cache_position.
      line_cache_position = 0.
      line_cache_value = 1.
    ENDIF.
    IF pos > line_cache_position.
      DATA(chunk) = substring( val = source off = line_cache_position len = pos - line_cache_position ).
      line_cache_value = line_cache_value + count( val = chunk sub = cl_abap_char_utilities=>newline ).
      line_cache_position = pos.
    ENDIF.
    result = line_cache_value.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION NEW ycx_sass_error( text = message line = line ).
  ENDMETHOD.

  METHOD parse.
    result = parse_block( ).
    IF position < size.
      fail( message = `Unexpected "}".` line = line_at( position ) ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_block.
    DO.
      WHILE position < size AND ( lcl_util=>is_space( at( ) ) = abap_true OR at( ) = `;` ).
        position = position + 1.
      ENDWHILE.
      IF position >= size OR at( ) = `}`.
        EXIT.
      ENDIF.
      DATA(start_line) = line_at( position ).

      IF at( ) = `/` AND at( 1 ) = `*`.
        DATA(comment_end) = find( val = source sub = `*/` off = position + 2 ).
        IF comment_end < 0.
          fail( message = `Unterminated comment.` line = start_line ).
        ENDIF.
        DATA(comment) = NEW lcl_node( ).
        comment->kind = `comment`.
        comment->line = start_line.
        comment->text = substring( val = source off = position len = comment_end + 2 - position ).
        APPEND comment TO result.
        position = comment_end + 2.
        CONTINUE.
      ENDIF.

      IF at( ) = `/` AND at( 1 ) = `/`.
        WHILE position < size AND at( ) <> cl_abap_char_utilities=>newline.
          position = position + 1.
        ENDWHILE.
        CONTINUE.
      ENDIF.

      read_statement( IMPORTING text = DATA(text) terminator = DATA(terminator) ).
      DATA(node) = make_statement( text = text terminator = terminator line = start_line ).
      IF terminator = `{`.
        IF node IS NOT BOUND.
          fail( message = `Unexpected "{".` line = start_line ).
        ENDIF.
        node->has_block = abap_true.
        node->children = parse_block( ).
        IF at( ) <> `}`.
          fail( message = `Expected "}".` line = start_line ).
        ENDIF.
        position = position + 1.
      ENDIF.
      IF node IS BOUND.
        APPEND node TO result.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD read_statement.
    DATA depth TYPE i.
    DATA quote TYPE string.
    DATA buffer TYPE string.
    DATA(start_line) = line_at( position ).
    CLEAR: text, terminator.
    WHILE position < size.
      DATA(character) = at( ).
      IF quote IS NOT INITIAL.
        buffer = buffer && character.
        IF character = `\`.
          position = position + 1.
          buffer = buffer && at( ).
        ELSEIF character = quote.
          CLEAR quote.
        ENDIF.
        position = position + 1.
        CONTINUE.
      ENDIF.

      IF character = `"` OR character = `'`.
        quote = character.
      ELSEIF character = `(` OR character = `[`.
        depth = depth + 1.
      ELSEIF character = `)` OR character = `]`.
        depth = depth - 1.
      ELSEIF character = `#` AND at( 1 ) = `{`.
        DATA(close) = lcl_util=>find_matching( text = source start = position + 1 open = `{` close = `}` ).
        IF close < 0.
          fail( message = `Unterminated interpolation.` line = line_at( position ) ).
        ENDIF.
        buffer = buffer && substring( val = source off = position len = close + 1 - position ).
        position = close + 1.
        CONTINUE.
      ELSEIF character = `/` AND at( 1 ) = `/`
         AND lcl_util=>char_at( text = source pos = position - 1 ) <> `:`
         AND lcl_util=>char_at( text = source pos = position - 1 ) <> `(`.
        WHILE position < size AND at( ) <> cl_abap_char_utilities=>newline.
          position = position + 1.
        ENDWHILE.
        CONTINUE.
      ELSEIF character = `/` AND at( 1 ) = `*`.
        DATA(comment_end) = find( val = source sub = `*/` off = position + 2 ).
        IF comment_end < 0.
          fail( message = `Unterminated comment.` line = line_at( position ) ).
        ENDIF.
        position = comment_end + 2.
        buffer = buffer && ` `.
        CONTINUE.
      ELSEIF depth <= 0 AND ( character = `;` OR character = `{` OR character = `}` ).
        terminator = character.
        IF character <> `}`.
          position = position + 1.
        ENDIF.
        EXIT.
      ENDIF.
      buffer = buffer && character.
      position = position + 1.
    ENDWHILE.
    IF quote IS NOT INITIAL.
      fail( message = `Unterminated string.` line = start_line ).
    ENDIF.
    text = buffer.
  ENDMETHOD.

  METHOD make_statement.
    DATA(trimmed) = lcl_util=>trim_text( text ).
    IF trimmed IS INITIAL.
      RETURN.
    ENDIF.
    result = NEW #( ).
    result->line = line.
    DATA(first) = lcl_util=>char_at( text = trimmed pos = 0 ).

    IF first = `$`.
      DATA(colon) = find( val = trimmed sub = `:` ).
      IF colon < 0.
        fail( message = `Expected ":" after variable name.` line = line ).
      ENDIF.
      result->kind = `var`.
      result->name = lcl_util=>trim_text( substring( val = trimmed off = 1 len = colon - 1 ) ).
      DATA(value_text) = lcl_util=>trim_text( substring( val = trimmed off = colon + 1 ) ).
      IF find( val = value_text regex = `!default` ) >= 0.
        result->flag_default = abap_true.
        value_text = replace( val = value_text regex = `\s*!default` with = `` ).
      ENDIF.
      IF find( val = value_text regex = `!global` ) >= 0.
        result->flag_global = abap_true.
        value_text = replace( val = value_text regex = `\s*!global` with = `` ).
      ENDIF.
      result->text = value_text.
      RETURN.
    ENDIF.

    IF first = `@`.
      DATA(name_end) = 1.
      WHILE name_end < strlen( trimmed ) AND lcl_util=>is_ident_char( lcl_util=>char_at( text = trimmed pos = name_end ) ) = abap_true.
        name_end = name_end + 1.
      ENDWHILE.
      result->kind = `at`.
      result->name = to_lower( substring( val = trimmed off = 1 len = name_end - 1 ) ).
      DATA(rest) = lcl_util=>trim_text( substring( val = trimmed off = name_end ) ).
      CASE result->name.
        WHEN `mixin` OR `function` OR `include`.
          DATA(target_end) = 0.
          WHILE target_end < strlen( rest ) AND lcl_util=>is_ident_char( lcl_util=>char_at( text = rest pos = target_end ) ) = abap_true.
            target_end = target_end + 1.
          ENDWHILE.
          result->target = substring( val = rest len = target_end ).
          DATA(after_target) = lcl_util=>trim_text( substring( val = rest off = target_end ) ).
          IF lcl_util=>char_at( text = after_target pos = 0 ) = `(`.
            DATA(close) = lcl_util=>find_matching( text = after_target start = 0 open = `(` close = `)` ).
            IF close < 0.
              fail( message = `Expected ")".` line = line ).
            ENDIF.
            result->text = substring( val = after_target off = 1 len = close - 1 ).
          ENDIF.
        WHEN `else`.
          IF find( val = rest regex = `^if(\s|\()` ) = 0.
            result->target = `if`.
            result->text = lcl_util=>trim_text( substring( val = rest off = 2 ) ).
          ENDIF.
        WHEN OTHERS.
          result->text = rest.
      ENDCASE.
      RETURN.
    ENDIF.

    IF terminator = `{`.
      IF substring( val = trimmed off = strlen( trimmed ) - 1 len = 1 ) = `:`.
        result->kind = `decl`.
        result->name = lcl_util=>trim_text( substring( val = trimmed len = strlen( trimmed ) - 1 ) ).
      ELSE.
        result->kind = `rule`.
        result->text = trimmed.
      ENDIF.
      RETURN.
    ENDIF.

    DATA(property_end) = find( val = trimmed sub = `:` ).
    IF property_end < 0.
      fail( message = |Expected ":" in declaration "{ trimmed }".| line = line ).
    ENDIF.
    result->kind = `decl`.
    result->name = lcl_util=>trim_text( substring( val = trimmed len = property_end ) ).
    result->text = lcl_util=>trim_text( substring( val = trimmed off = property_end + 1 ) ).
  ENDMETHOD.

ENDCLASS.



CLASS lcl_expr IMPLEMENTATION.

  METHOD constructor.
    source = text.
    size = strlen( text ).
    me->scope = scope.
    me->evaluator = evaluator.
  ENDMETHOD.

  METHOD at.
    result = lcl_util=>char_at( text = source pos = position + offset ).
  ENDMETHOD.

  METHOD skip_spaces.
    skipped = abap_false.
    WHILE position < size AND lcl_util=>is_space( at( ) ) = abap_true.
      position = position + 1.
      skipped = abap_true.
    ENDWHILE.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION NEW ycx_sass_error( text = message ).
  ENDMETHOD.

  METHOD looking_at_word.
    DATA(word_length) = strlen( word ).
    result = abap_false.
    IF position + word_length > size.
      RETURN.
    ENDIF.
    IF substring( val = source off = position len = word_length ) = word
       AND lcl_util=>is_ident_char( at( word_length ) ) = abap_false.
      result = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD read_name.
    DATA(start) = position.
    WHILE position < size AND lcl_util=>is_ident_char( at( ) ) = abap_true.
      position = position + 1.
    ENDWHILE.
    result = substring( val = source off = start len = position - start ).
  ENDMETHOD.

  METHOD starts_number.
    DATA(first) = at( ).
    DATA(second) = at( 1 ).
    result = abap_false.
    IF lcl_util=>is_digit( first ) = abap_true.
      result = abap_true.
    ELSEIF first = `.` AND lcl_util=>is_digit( second ) = abap_true.
      result = abap_true.
    ELSEIF ( first = `-` OR first = `+` )
       AND ( lcl_util=>is_digit( second ) = abap_true
          OR ( second = `.` AND lcl_util=>is_digit( at( 2 ) ) = abap_true ) ).
      result = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD expect_close.
    skip_spaces( ).
    IF at( ) <> `)`.
      fail( |Expected ")" in "{ source }".| ).
    ENDIF.
    position = position + 1.
  ENDMETHOD.

  METHOD parse.
    skip_spaces( ).
    IF position >= size.
      result = lcl_value=>make_null( ).
      RETURN.
    ENDIF.
    result = parse_comma_list( ).
    skip_spaces( ).
    IF position < size.
      fail( |Unexpected "{ at( ) }" in expression "{ source }".| ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_call_arguments.
    DO.
      skip_spaces( ).
      IF position >= size OR at( ) = `)`.
        EXIT.
      ENDIF.
      DATA(argument) = VALUE ty_argument( ).
      IF at( ) = `$`.
        DATA(saved) = position.
        position = position + 1.
        DATA(keyword) = read_name( ).
        skip_spaces( ).
        IF at( ) = `:`.
          position = position + 1.
          skip_spaces( ).
          argument-name = lcl_util=>normalize( keyword ).
        ELSE.
          position = saved.
        ENDIF.
      ENDIF.
      argument-item = parse_space_list( ).
      IF at( ) = `.` AND at( 1 ) = `.` AND at( 2 ) = `.`.
        position = position + 3.
        IF argument-item->kind = `list`.
          LOOP AT argument-item->items INTO DATA(spread_item).
            APPEND VALUE #( item = spread_item ) TO result.
          ENDLOOP.
        ELSE.
          APPEND argument TO result.
        ENDIF.
      ELSE.
        APPEND argument TO result.
      ENDIF.
      skip_spaces( ).
      IF at( ) = `,`.
        position = position + 1.
      ELSEIF position < size AND at( ) <> `)`.
        fail( |Expected "," in arguments "{ source }".| ).
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD parse_comma_list.
    DATA items TYPE tt_values.
    DATA has_comma TYPE abap_bool.
    APPEND parse_space_list( ) TO items.
    DO.
      skip_spaces( ).
      IF at( ) <> `,`.
        EXIT.
      ENDIF.
      position = position + 1.
      has_comma = abap_true.
      skip_spaces( ).
      IF position >= size OR at( ) = `)`.
        EXIT.
      ENDIF.
      APPEND parse_space_list( ) TO items.
    ENDDO.
    IF has_comma = abap_false.
      result = items[ 1 ].
    ELSE.
      result = lcl_value=>make_list( items = items separator = `,` ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_space_list.
    DATA items TYPE tt_values.
    APPEND parse_or( ) TO items.
    DO.
      DATA(skipped) = skip_spaces( ).
      DATA(next) = at( ).
      IF skipped = abap_false OR position >= size OR next = `,` OR next = `)` OR next = `:` OR next = `]`.
        EXIT.
      ENDIF.
      IF next = `.` AND at( 1 ) = `.` AND at( 2 ) = `.`.
        EXIT.
      ENDIF.
      APPEND parse_or( ) TO items.
    ENDDO.
    IF lines( items ) = 1.
      result = items[ 1 ].
    ELSE.
      result = lcl_value=>make_list( items = items separator = ` ` ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_or.
    result = parse_and( ).
    DO.
      DATA(saved) = position.
      skip_spaces( ).
      IF looking_at_word( `or` ) = abap_false.
        position = saved.
        EXIT.
      ENDIF.
      position = position + 2.
      skip_spaces( ).
      DATA(right) = parse_and( ).
      result = lcl_value=>make_bool( xsdbool( result->is_true( ) = abap_true OR right->is_true( ) = abap_true ) ).
    ENDDO.
  ENDMETHOD.

  METHOD parse_and.
    result = parse_equality( ).
    DO.
      DATA(saved) = position.
      skip_spaces( ).
      IF looking_at_word( `and` ) = abap_false.
        position = saved.
        EXIT.
      ENDIF.
      position = position + 3.
      skip_spaces( ).
      DATA(right) = parse_equality( ).
      result = lcl_value=>make_bool( xsdbool( result->is_true( ) = abap_true AND right->is_true( ) = abap_true ) ).
    ENDDO.
  ENDMETHOD.

  METHOD parse_equality.
    result = parse_relational( ).
    DO.
      DATA(saved) = position.
      skip_spaces( ).
      DATA(operator) = ``.
      IF at( ) = `=` AND at( 1 ) = `=`.
        operator = `==`.
      ELSEIF at( ) = `!` AND at( 1 ) = `=`.
        operator = `!=`.
      ENDIF.
      IF operator IS INITIAL.
        position = saved.
        EXIT.
      ENDIF.
      position = position + 2.
      skip_spaces( ).
      DATA(right) = parse_relational( ).
      DATA(same) = result->equals( right ).
      IF operator = `==`.
        result = lcl_value=>make_bool( same ).
      ELSE.
        result = lcl_value=>make_bool( xsdbool( same = abap_false ) ).
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD parse_relational.
    result = parse_additive( ).
    DO.
      DATA(saved) = position.
      skip_spaces( ).
      DATA(operator) = ``.
      IF at( ) = `<` AND at( 1 ) = `=`.
        operator = `<=`.
      ELSEIF at( ) = `>` AND at( 1 ) = `=`.
        operator = `>=`.
      ELSEIF at( ) = `<` OR at( ) = `>`.
        operator = at( ).
      ENDIF.
      IF operator IS INITIAL.
        position = saved.
        EXIT.
      ENDIF.
      position = position + strlen( operator ).
      skip_spaces( ).
      DATA(right) = parse_additive( ).
      result = lcl_value=>make_bool( compare( operator = operator left = result right = right ) ).
    ENDDO.
  ENDMETHOD.

  METHOD parse_additive.
    result = parse_multiplicative( ).
    DO.
      DATA(saved) = position.
      DATA(space_before) = skip_spaces( ).
      DATA(operator) = at( ).
      IF operator <> `+` AND operator <> `-`.
        position = saved.
        EXIT.
      ENDIF.
      DATA(space_after) = lcl_util=>is_space( at( 1 ) ).
      IF space_before = abap_true AND space_after = abap_false.
        position = saved.
        EXIT.
      ENDIF.
      position = position + 1.
      skip_spaces( ).
      DATA(right) = parse_multiplicative( ).
      result = binary( operator = operator left = result right = right ).
    ENDDO.
  ENDMETHOD.

  METHOD parse_multiplicative.
    result = parse_unary( ).
    DO.
      DATA(saved) = position.
      DATA(space_before) = skip_spaces( ).
      DATA(operator) = at( ).
      DATA(is_operator) = xsdbool( operator = `*`
                                OR operator = `/`
                                OR ( operator = `%` AND space_before = abap_true AND lcl_util=>is_space( at( 1 ) ) = abap_true ) ).
      IF is_operator = abap_false.
        position = saved.
        EXIT.
      ENDIF.
      position = position + 1.
      skip_spaces( ).
      DATA(right) = parse_unary( ).
      result = binary( operator = operator left = result right = right ).
    ENDDO.
  ENDMETHOD.

  METHOD parse_unary.
    DATA(character) = at( ).
    IF character = `-` OR character = `+`.
      DATA(following) = at( 1 ).
      IF following = `$` OR following = `(`.
        position = position + 1.
        DATA(operand) = parse_unary( ).
        IF character = `+`.
          result = operand.
        ELSEIF operand->kind = `num`.
          result = lcl_value=>make_number( number = - operand->num unit = operand->unit ).
          result->computed = abap_true.
        ELSE.
          result = lcl_value=>make_string( `-` && operand->to_text( ) ).
        ENDIF.
        RETURN.
      ENDIF.
    ENDIF.
    IF looking_at_word( `not` ) = abap_true.
      position = position + 3.
      skip_spaces( ).
      DATA(negated) = parse_unary( ).
      result = lcl_value=>make_bool( xsdbool( negated->is_true( ) = abap_false ) ).
      RETURN.
    ENDIF.
    result = parse_primary( ).
  ENDMETHOD.

  METHOD parse_primary.
    IF position >= size.
      fail( |Expected expression in "{ source }".| ).
    ENDIF.
    DATA(character) = at( ).
    IF character = `(`.
      result = parse_group( ).
    ELSEIF character = `"` OR character = `'`.
      result = parse_string( ).
    ELSEIF character = `$`.
      result = parse_variable( ).
    ELSEIF character = `#` AND at( 1 ) <> `{`.
      result = parse_hex_color( ).
    ELSEIF character = `!`.
      position = position + 1.
      DATA(flag_word) = read_name( ).
      result = lcl_value=>make_string( `!` && flag_word ).
    ELSEIF character = `&`.
      position = position + 1.
      result = lcl_value=>make_string( `&` ).
    ELSEIF starts_number( ) = abap_true.
      result = parse_number( ).
    ELSEIF lcl_util=>is_ident_char( character ) = abap_true OR character = `#` OR character = `\`.
      result = parse_identifier( ).
    ELSE.
      fail( |Unexpected "{ character }" in "{ source }".| ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_group.
    position = position + 1.
    depth = depth + 1.
    skip_spaces( ).
    IF at( ) = `)`.
      position = position + 1.
      depth = depth - 1.
      result = lcl_value=>make_list( items = VALUE #( ) separator = ` ` ).
      RETURN.
    ENDIF.
    DATA(saved) = position.
    DATA(first) = parse_space_list( ).
    skip_spaces( ).
    IF at( ) = `:`.
      DATA keys TYPE tt_values.
      DATA entries TYPE tt_values.
      DATA(key) = first.
      DO.
        position = position + 1.
        skip_spaces( ).
        APPEND key TO keys.
        APPEND parse_space_list( ) TO entries.
        skip_spaces( ).
        IF at( ) <> `,`.
          EXIT.
        ENDIF.
        position = position + 1.
        skip_spaces( ).
        IF at( ) = `)`.
          EXIT.
        ENDIF.
        key = parse_space_list( ).
        skip_spaces( ).
        IF at( ) <> `:`.
          fail( |Expected ":" in map "{ source }".| ).
        ENDIF.
      ENDDO.
      expect_close( ).
      result = lcl_value=>make_map( keys = keys items = entries ).
    ELSE.
      position = saved.
      result = parse_comma_list( ).
      expect_close( ).
      result = result->clone( ).
      result->computed = abap_true.
    ENDIF.
    depth = depth - 1.
  ENDMETHOD.

  METHOD parse_string.
    DATA(quote) = at( ).
    position = position + 1.
    DATA(start) = position.
    WHILE position < size AND at( ) <> quote.
      IF at( ) = `\`.
        position = position + 1.
      ENDIF.
      position = position + 1.
    ENDWHILE.
    IF position >= size.
      fail( |Unterminated string in "{ source }".| ).
    ENDIF.
    DATA(content) = substring( val = source off = start len = position - start ).
    position = position + 1.
    IF content CS `#{`.
      content = evaluator->interpolate( text = content scope = scope ).
    ENDIF.
    result = lcl_value=>make_string( text = content quoted = abap_true ).
  ENDMETHOD.

  METHOD parse_variable.
    position = position + 1.
    DATA(variable_name) = read_name( ).
    DATA(found) = scope->lookup( variable_name ).
    IF found IS NOT BOUND.
      fail( |Undefined variable: "${ variable_name }".| ).
    ENDIF.
    result = found->clone( ).
    result->computed = abap_true.
  ENDMETHOD.

  METHOD parse_hex_color.
    DATA(start) = position.
    position = position + 1.
    read_name( ).
    DATA(literal) = substring( val = source off = start len = position - start ).
    result = lcl_color=>parse_hex( literal ).
    IF result IS NOT BOUND.
      result = lcl_value=>make_string( literal ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_number.
    DATA negative TYPE abap_bool.
    IF at( ) = `-`.
      negative = abap_true.
      position = position + 1.
    ELSEIF at( ) = `+`.
      position = position + 1.
    ENDIF.
    DATA(start) = position.
    WHILE lcl_util=>is_digit( at( ) ) = abap_true.
      position = position + 1.
    ENDWHILE.
    IF at( ) = `.` AND lcl_util=>is_digit( at( 1 ) ) = abap_true.
      position = position + 1.
      WHILE lcl_util=>is_digit( at( ) ) = abap_true.
        position = position + 1.
      ENDWHILE.
    ENDIF.
    DATA(digits) = substring( val = source off = start len = position - start ).
    IF digits CP `.*`.
      digits = `0` && digits.
    ENDIF.
    DATA(unit_start) = position.
    WHILE lcl_util=>is_letter( at( ) ) = abap_true.
      position = position + 1.
    ENDWHILE.
    IF position = unit_start AND at( ) = `%`.
      position = position + 1.
    ENDIF.
    DATA(unit) = substring( val = source off = unit_start len = position - unit_start ).
    DATA(magnitude) = CONV decfloat34( digits ).
    IF negative = abap_true.
      magnitude = - magnitude.
    ENDIF.
    result = lcl_value=>make_number( number = magnitude unit = unit ).
  ENDMETHOD.

  METHOD parse_identifier.
    DATA name TYPE string.
    DO.
      DATA(character) = at( ).
      IF character = `#` AND at( 1 ) = `{`.
        DATA(close) = lcl_util=>find_matching( text = source start = position + 1 open = `{` close = `}` ).
        IF close < 0.
          fail( |Unterminated interpolation in "{ source }".| ).
        ENDIF.
        DATA(inner) = substring( val = source off = position + 2 len = close - position - 2 ).
        name = name && evaluator->eval_expression( text = inner scope = scope )->to_text( ).
        position = close + 1.
      ELSEIF character = `\`.
        name = name && character && at( 1 ).
        position = position + 2.
      ELSEIF lcl_util=>is_ident_char( character ) = abap_true.
        name = name && character.
        position = position + 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.
    IF name IS INITIAL.
      fail( |Expected identifier in "{ source }".| ).
    ENDIF.
    IF at( ) = `(`.
      result = parse_function( name ).
      RETURN.
    ENDIF.
    CASE name.
      WHEN `true`.
        result = lcl_value=>make_bool( abap_true ).
      WHEN `false`.
        result = lcl_value=>make_bool( abap_false ).
      WHEN `null`.
        result = lcl_value=>make_null( ).
      WHEN OTHERS.
        result = lcl_value=>make_string( name ).
    ENDCASE.
  ENDMETHOD.

  METHOD parse_function.
    DATA(lower) = to_lower( name ).
    IF matches( val = lower regex = `(-[a-z]+-)?(calc|clamp|url|var|env|attr|format|local)` ).
      DATA(close) = lcl_util=>find_matching( text = source start = position open = `(` close = `)` ).
      IF close < 0.
        fail( |Unterminated "{ name }(" in "{ source }".| ).
      ENDIF.
      DATA(inner_start) = position + 1.
      DATA(raw) = substring( val = source off = inner_start len = close - inner_start ).
      position = close + 1.
      raw = evaluator->interpolate( text = raw scope = scope ).
      IF matches( val = lower regex = `(-[a-z]+-)?(calc|clamp)` ).
        raw = evaluator->substitute_variables( text = raw scope = scope ).
      ENDIF.
      result = lcl_value=>make_string( name && `(` && raw && `)` ).
      RETURN.
    ENDIF.

    position = position + 1.
    depth = depth + 1.
    DATA(arguments) = parse_call_arguments( ).
    skip_spaces( ).
    IF at( ) <> `)`.
      fail( |Expected ")" after arguments of "{ name }".| ).
    ENDIF.
    position = position + 1.
    depth = depth - 1.

    IF evaluator->has_function( name ) = abap_true.
      result = evaluator->call_function( name = name arguments = arguments ).
    ELSE.
      result = lcl_functions=>call( name = name arguments = arguments ).
      IF result IS NOT BOUND.
        DATA(parts) = VALUE string_table( ).
        LOOP AT arguments INTO DATA(argument).
          APPEND argument-item->to_css( ) TO parts.
        ENDLOOP.
        result = lcl_value=>make_string( name && `(` && concat_lines_of( table = parts sep = `, ` ) && `)` ).
        RETURN.
      ENDIF.
    ENDIF.
    result = result->clone( ).
    result->computed = abap_true.
  ENDMETHOD.

  METHOD binary.
    IF left->kind = `num` AND right->kind = `num`.
      result = numeric( operator = operator left = left right = right ).
      RETURN.
    ENDIF.
    CASE operator.
      WHEN `+`.
        result = lcl_value=>make_string(
          text   = left->to_text( ) && right->to_text( )
          quoted = xsdbool( left->kind = `str` AND left->quoted = abap_true ) ).
      WHEN `-`.
        result = lcl_value=>make_string( left->to_text( ) && `-` && right->to_text( ) ).
      WHEN `/`.
        result = lcl_value=>make_string( left->to_text( ) && `/` && right->to_text( ) ).
      WHEN OTHERS.
        fail( |Undefined operation "{ left->to_css( ) } { operator } { right->to_css( ) }".| ).
    ENDCASE.
  ENDMETHOD.

  METHOD numeric.
    DATA unit TYPE string.
    DATA number TYPE decfloat34.
    CASE operator.
      WHEN `+` OR `-`.
        IF left->unit = right->unit OR right->unit IS INITIAL.
          unit = left->unit.
        ELSEIF left->unit IS INITIAL.
          unit = right->unit.
        ELSE.
          fail( |Incompatible units: "{ left->unit }" and "{ right->unit }".| ).
        ENDIF.
        IF operator = `+`.
          number = left->num + right->num.
        ELSE.
          number = left->num - right->num.
        ENDIF.
      WHEN `*`.
        IF left->unit IS NOT INITIAL AND right->unit IS NOT INITIAL.
          fail( |Multiplying "{ left->unit }" by "{ right->unit }" is not supported.| ).
        ENDIF.
        unit = COND #( WHEN left->unit IS NOT INITIAL THEN left->unit ELSE right->unit ).
        number = left->num * right->num.
      WHEN `/`.
        IF depth = 0 AND left->computed = abap_false AND right->computed = abap_false.
          result = lcl_value=>make_string( left->to_css( ) && `/` && right->to_css( ) ).
          RETURN.
        ENDIF.
        IF right->num = 0.
          fail( `Division by zero.` ).
        ENDIF.
        IF left->unit = right->unit OR left->unit IS INITIAL.
          unit = ``.
        ELSE.
          unit = left->unit.
        ENDIF.
        number = left->num / right->num.
      WHEN `%`.
        IF right->num = 0.
          fail( `Modulo by zero.` ).
        ENDIF.
        unit = left->unit.
        number = left->num MOD right->num.
    ENDCASE.
    result = lcl_value=>make_number( number = number unit = unit ).
    result->computed = abap_true.
  ENDMETHOD.

  METHOD compare.
    IF left->kind = `num` AND right->kind = `num`.
      CASE operator.
        WHEN `<`.
          result = xsdbool( left->num < right->num ).
        WHEN `>`.
          result = xsdbool( left->num > right->num ).
        WHEN `<=`.
          result = xsdbool( left->num <= right->num ).
        WHEN `>=`.
          result = xsdbool( left->num >= right->num ).
      ENDCASE.
    ELSEIF left->kind = `str` AND right->kind = `str`.
      CASE operator.
        WHEN `<`.
          result = xsdbool( left->str < right->str ).
        WHEN `>`.
          result = xsdbool( left->str > right->str ).
        WHEN `<=`.
          result = xsdbool( left->str <= right->str ).
        WHEN `>=`.
          result = xsdbool( left->str >= right->str ).
      ENDCASE.
    ELSE.
      fail( |Cannot compare "{ left->to_css( ) }" and "{ right->to_css( ) }".| ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.



CLASS lcl_evaluator IMPLEMENTATION.

  METHOD fail.
    RAISE EXCEPTION NEW ycx_sass_error( text = message ).
  ENDMETHOD.

  METHOD evaluate.
    result = NEW #( ).
    result->kind = `root`.
    DATA(context) = VALUE ty_context( container = result scope = NEW lcl_scope( ) ).
    exec_nodes( nodes = nodes context = context ).
    finish_extends( result ).
  ENDMETHOD.

  METHOD eval_expression.
    result = NEW lcl_expr( text = text scope = scope evaluator = me )->parse( ).
  ENDMETHOD.

  METHOD interpolate.
    result = text.
    IF NOT text CS `#{`.
      RETURN.
    ENDIF.
    CLEAR result.
    DATA(index) = 0.
    DATA(length) = strlen( text ).
    WHILE index < length.
      IF lcl_util=>char_at( text = text pos = index ) = `#` AND lcl_util=>char_at( text = text pos = index + 1 ) = `{`.
        DATA(close) = lcl_util=>find_matching( text = text start = index + 1 open = `{` close = `}` ).
        IF close < 0.
          fail( `Unterminated interpolation.` ).
        ENDIF.
        DATA(inner) = substring( val = text off = index + 2 len = close - index - 2 ).
        result = result && eval_expression( text = inner scope = scope )->to_text( ).
        index = close + 1.
      ELSE.
        result = result && lcl_util=>char_at( text = text pos = index ).
        index = index + 1.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

  METHOD substitute_variables.
    result = text.
    IF NOT text CS `$`.
      RETURN.
    ENDIF.
    CLEAR result.
    DATA(index) = 0.
    DATA(length) = strlen( text ).
    WHILE index < length.
      DATA(character) = lcl_util=>char_at( text = text pos = index ).
      DATA(name_end) = index + 1.
      IF character = `$`.
        WHILE name_end < length AND lcl_util=>is_ident_char( lcl_util=>char_at( text = text pos = name_end ) ) = abap_true.
          name_end = name_end + 1.
        ENDWHILE.
      ENDIF.
      IF character = `$` AND name_end > index + 1.
        DATA(variable_name) = substring( val = text off = index + 1 len = name_end - index - 1 ).
        DATA(found) = scope->lookup( variable_name ).
        IF found IS NOT BOUND.
          fail( |Undefined variable: "${ variable_name }".| ).
        ENDIF.
        result = result && found->to_text( ).
        index = name_end.
      ELSE.
        result = result && character.
        index = index + 1.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

  METHOD has_function.
    result = xsdbool( line_exists( functions[ name = lcl_util=>normalize( name ) ] ) ).
  ENDMETHOD.

  METHOD call_function.
    DATA(definition) = functions[ name = lcl_util=>normalize( name ) ].
    call_depth = call_depth + 1.
    IF call_depth > 100.
      fail( `Maximum call depth exceeded.` ).
    ENDIF.
    DATA(inner_scope) = bind_parameters( params = definition-params definition_scope = definition-scope arguments = arguments ).
    DATA(inner) = VALUE ty_context( scope = inner_scope ).
    returned = abap_false.
    CLEAR returned_value.
    exec_nodes( nodes = definition-body->children context = inner ).
    call_depth = call_depth - 1.
    IF returned = abap_false.
      fail( |Function { name } finished without @return.| ).
    ENDIF.
    result = returned_value.
    returned = abap_false.
  ENDMETHOD.

  METHOD bind_parameters.
    result = NEW lcl_scope( parent = definition_scope ).
    DATA positional TYPE tt_values.
    LOOP AT arguments INTO DATA(argument) WHERE name IS INITIAL.
      APPEND argument-item TO positional.
    ENDLOOP.
    DATA(parameters) = lcl_util=>split_top( text = params separator = `,` ).
    DATA(position) = 0.
    LOOP AT parameters INTO DATA(parameter).
      DATA(declaration) = lcl_util=>trim_text( parameter ).
      IF declaration IS INITIAL.
        CONTINUE.
      ENDIF.
      position = position + 1.
      IF declaration CP `*...`.
        DATA(rest_name) = substring( val = declaration off = 1 len = strlen( declaration ) - 4 ).
        DATA rest_items TYPE tt_values.
        CLEAR rest_items.
        LOOP AT positional INTO DATA(positional_item) FROM position.
          APPEND positional_item TO rest_items.
        ENDLOOP.
        result->declare( name = rest_name item = lcl_value=>make_list( items = rest_items separator = `,` ) ).
        CONTINUE.
      ENDIF.
      DATA(parameter_name) = declaration.
      DATA(default_text) = ``.
      DATA(colon) = find( val = declaration sub = `:` ).
      IF colon >= 0.
        parameter_name = lcl_util=>trim_text( substring( val = declaration len = colon ) ).
        default_text = lcl_util=>trim_text( substring( val = declaration off = colon + 1 ) ).
      ENDIF.
      parameter_name = substring( val = parameter_name off = 1 ).
      DATA bound TYPE REF TO lcl_value.
      CLEAR bound.
      READ TABLE arguments INTO DATA(named) WITH KEY name = lcl_util=>normalize( parameter_name ).
      IF sy-subrc = 0.
        bound = named-item.
      ELSEIF position <= lines( positional ).
        bound = positional[ position ].
      ELSEIF default_text IS NOT INITIAL.
        bound = eval_expression( text = default_text scope = result ).
      ELSE.
        fail( |Missing argument ${ parameter_name }.| ).
      ENDIF.
      result->declare( name = parameter_name item = bound ).
    ENDLOOP.
  ENDMETHOD.

  METHOD exec_nodes.
    DATA(index) = 1.
    WHILE index <= lines( nodes ).
      DATA(node) = nodes[ index ].
      TRY.
          IF node->kind = `at` AND node->name = `if`.
            exec_if( EXPORTING nodes = nodes context = context CHANGING index = index ).
          ELSE.
            exec_node( node = node context = context ).
          ENDIF.
        CATCH ycx_sass_error INTO DATA(error).
          IF error->line = 0 AND node->line > 0.
            RAISE EXCEPTION NEW ycx_sass_error( text = error->text line = node->line ).
          ENDIF.
          RAISE EXCEPTION error.
      ENDTRY.
      IF returned = abap_true.
        RETURN.
      ENDIF.
      index = index + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD exec_flow_block.
    DATA(inner) = context.
    inner-scope = NEW lcl_scope( parent = context-scope flow = abap_true ).
    exec_nodes( nodes = nodes context = inner ).
  ENDMETHOD.

  METHOD exec_if.
    DATA(taken) = abap_false.
    DATA(branch) = nodes[ index ].
    DO.
      DATA(run_branch) = abap_false.
      IF taken = abap_false.
        IF branch->name = `else` AND branch->target <> `if`.
          run_branch = abap_true.
        ELSE.
          run_branch = eval_expression( text = branch->text scope = context-scope )->is_true( ).
        ENDIF.
      ENDIF.
      IF run_branch = abap_true.
        taken = abap_true.
        exec_flow_block( nodes = branch->children context = context ).
      ENDIF.
      IF index < lines( nodes ) AND nodes[ index + 1 ]->kind = `at` AND nodes[ index + 1 ]->name = `else`.
        index = index + 1.
        branch = nodes[ index ].
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD exec_node.
    CASE node->kind.
      WHEN `comment`.
        exec_comment( node = node context = context ).
      WHEN `var`.
        exec_variable( node = node context = context ).
      WHEN `decl`.
        exec_declaration( node = node context = context ).
      WHEN `rule`.
        exec_rule( node = node context = context ).
      WHEN `at`.
        exec_at_rule( node = node context = context ).
    ENDCASE.
  ENDMETHOD.

  METHOD exec_comment.
    IF context-rule IS BOUND.
      APPEND VALUE #( kind = `comment` text = node->text ) TO context-rule->items.
    ELSE.
      DATA(comment) = NEW lcl_out( ).
      comment->kind = `comment`.
      comment->header = node->text.
      APPEND comment TO context-container->children.
    ENDIF.
  ENDMETHOD.

  METHOD exec_variable.
    IF node->flag_default = abap_true.
      DATA(existing) = context-scope->lookup( node->name ).
      IF existing IS BOUND AND existing->kind <> `null`.
        RETURN.
      ENDIF.
    ENDIF.
    DATA(assigned) = eval_expression( text = node->text scope = context-scope ).
    context-scope->assign( name = node->name item = assigned global = node->flag_global ).
  ENDMETHOD.

  METHOD evaluate_declaration_value.
    IF property CP `--*`.
      result = lcl_util=>trim_text( interpolate( text = text scope = scope ) ).
      RETURN.
    ENDIF.
    DATA(expression) = text.
    DATA(suffix) = ``.
    DATA(important_position) = find( val = to_lower( expression ) regex = `!\s*important\s*$` ).
    IF important_position >= 0.
      expression = substring( val = expression len = important_position ).
      suffix = ` !important`.
    ENDIF.
    result = eval_expression( text = expression scope = scope )->to_css( ).
    IF result IS NOT INITIAL.
      result = result && suffix.
    ENDIF.
  ENDMETHOD.

  METHOD exec_declaration.
    DATA(property) = lcl_util=>trim_text( interpolate( text = node->name scope = context-scope ) ).
    IF context-prefix IS NOT INITIAL.
      property = context-prefix && `-` && property.
    ENDIF.
    IF context-rule IS NOT BOUND.
      fail( `Declarations may only be used within style rules.` ).
    ENDIF.
    IF node->text IS NOT INITIAL.
      DATA(css) = evaluate_declaration_value( property = property text = node->text scope = context-scope ).
      IF css IS NOT INITIAL.
        APPEND VALUE #( kind = `decl` property = property text = css ) TO context-rule->items.
      ENDIF.
    ENDIF.
    IF node->has_block = abap_true.
      DATA(inner) = context.
      inner-prefix = property.
      exec_nodes( nodes = node->children context = inner ).
    ENDIF.
  ENDMETHOD.

  METHOD combine_selector.
    IF child CS `&`.
      result = replace( val = child sub = `&` with = parent occ = 0 ).
    ELSE.
      result = parent && ` ` && child.
    ENDIF.
  ENDMETHOD.

  METHOD exec_rule.
    DATA(selector_text) = interpolate( text = node->text scope = context-scope ).
    DATA(parts) = lcl_util=>split_top( text = selector_text separator = `,` ).
    DATA selectors TYPE string_table.
    IF context-selectors IS INITIAL.
      LOOP AT parts INTO DATA(part).
        DATA(child) = lcl_util=>squash( part ).
        IF child IS NOT INITIAL.
          APPEND child TO selectors.
        ENDIF.
      ENDLOOP.
    ELSE.
      LOOP AT context-selectors INTO DATA(parent).
        LOOP AT parts INTO DATA(child_part).
          DATA(nested) = lcl_util=>squash( child_part ).
          IF nested IS NOT INITIAL.
            APPEND combine_selector( parent = parent child = nested ) TO selectors.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDIF.
    DATA(rule) = NEW lcl_out( ).
    rule->kind = `rule`.
    rule->selectors = selectors.
    APPEND rule TO context-container->children.
    DATA(inner) = context.
    inner-rule = rule.
    inner-selectors = selectors.
    CLEAR inner-prefix.
    inner-scope = NEW lcl_scope( parent = context-scope ).
    exec_nodes( nodes = node->children context = inner ).
  ENDMETHOD.

  METHOD exec_at_rule.
    CASE node->name.
      WHEN `mixin`.
        DATA(mixin) = VALUE ty_definition( name = lcl_util=>normalize( node->target ) params = node->text body = node scope = context-scope ).
        INSERT mixin INTO TABLE mixins.
        IF sy-subrc <> 0.
          MODIFY TABLE mixins FROM mixin.
        ENDIF.
      WHEN `function`.
        DATA(function) = VALUE ty_definition( name = lcl_util=>normalize( node->target ) params = node->text body = node scope = context-scope ).
        INSERT function INTO TABLE functions.
        IF sy-subrc <> 0.
          MODIFY TABLE functions FROM function.
        ENDIF.
      WHEN `include`.
        exec_include( node = node context = context ).
      WHEN `content`.
        exec_content( context ).
      WHEN `return`.
        returned_value = eval_expression( text = node->text scope = context-scope ).
        returned = abap_true.
      WHEN `each`.
        exec_each( node = node context = context ).
      WHEN `for`.
        exec_for( node = node context = context ).
      WHEN `while`.
        exec_while( node = node context = context ).
      WHEN `extend`.
        exec_extend( node = node context = context ).
      WHEN `media` OR `supports`.
        exec_bubbling( node = node context = context ).
      WHEN `error`.
        fail( eval_expression( text = node->text scope = context-scope )->to_text( ) ).
      WHEN `warn` OR `debug`.
        RETURN.
      WHEN `import` OR `use` OR `forward`.
        fail( |@{ node->name } is not supported.| ).
      WHEN `else`.
        fail( `@else must follow @if.` ).
      WHEN OTHERS.
        exec_generic_at( node = node context = context ).
    ENDCASE.
  ENDMETHOD.

  METHOD exec_include.
    DATA(key) = lcl_util=>normalize( node->target ).
    IF NOT line_exists( mixins[ name = key ] ).
      fail( |Undefined mixin { node->target }.| ).
    ENDIF.
    DATA(mixin) = mixins[ name = key ].
    DATA(arguments) = NEW lcl_expr( text = node->text scope = context-scope evaluator = me )->parse_call_arguments( ).
    DATA(inner) = context.
    inner-scope = bind_parameters( params = mixin-params definition_scope = mixin-scope arguments = arguments ).
    DATA(content) = VALUE ty_content( scope = context-scope ).
    IF node->has_block = abap_true.
      content-node = node.
    ENDIF.
    APPEND content TO content_stack.
    call_depth = call_depth + 1.
    IF call_depth > 100.
      fail( `Maximum call depth exceeded.` ).
    ENDIF.
    exec_nodes( nodes = mixin-body->children context = inner ).
    call_depth = call_depth - 1.
    DELETE content_stack INDEX lines( content_stack ).
  ENDMETHOD.

  METHOD exec_content.
    IF content_stack IS INITIAL.
      RETURN.
    ENDIF.
    DATA(content) = content_stack[ lines( content_stack ) ].
    IF content-node IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(inner) = context.
    inner-scope = NEW lcl_scope( parent = content-scope ).
    DELETE content_stack INDEX lines( content_stack ).
    exec_nodes( nodes = content-node->children context = inner ).
    APPEND content TO content_stack.
  ENDMETHOD.

  METHOD exec_each.
    DATA(in_position) = find( val = node->text regex = `\s+in\s+` ).
    IF in_position < 0.
      fail( `Expected "in" in @each.` ).
    ENDIF.
    DATA(variables_text) = substring( val = node->text len = in_position ).
    DATA(collection_text) = replace( val = substring( val = node->text off = in_position ) regex = `^\s+in\s+` with = `` ).
    DATA(names) = lcl_util=>split_top( text = variables_text separator = `,` ).
    LOOP AT names ASSIGNING FIELD-SYMBOL(<name>).
      <name> = substring( val = lcl_util=>trim_text( <name> ) off = 1 ).
    ENDLOOP.
    DATA(collection) = eval_expression( text = collection_text scope = context-scope ).
    DATA entries TYPE tt_values.
    IF collection->kind = `map`.
      LOOP AT collection->keys INTO DATA(map_key).
        DATA(map_index) = sy-tabix.
        APPEND lcl_value=>make_list( items = VALUE #( ( map_key ) ( collection->items[ map_index ] ) ) separator = ` ` ) TO entries.
      ENDLOOP.
    ELSEIF collection->kind = `list`.
      entries = collection->items.
    ELSE.
      APPEND collection TO entries.
    ENDIF.
    LOOP AT entries INTO DATA(entry).
      DATA(iteration_scope) = NEW lcl_scope( parent = context-scope flow = abap_true ).
      IF lines( names ) = 1.
        iteration_scope->declare( name = names[ 1 ] item = entry ).
      ELSE.
        DATA(name_position) = 0.
        LOOP AT names INTO DATA(variable_name).
          name_position = name_position + 1.
          DATA entry_item TYPE REF TO lcl_value.
          IF entry->kind = `list` AND name_position <= lines( entry->items ).
            entry_item = entry->items[ name_position ].
          ELSE.
            entry_item = lcl_value=>make_null( ).
          ENDIF.
          iteration_scope->declare( name = variable_name item = entry_item ).
        ENDLOOP.
      ENDIF.
      DATA(inner) = context.
      inner-scope = iteration_scope.
      exec_nodes( nodes = node->children context = inner ).
      IF returned = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD exec_for.
    DATA(statement) = lcl_util=>trim_text( node->text ).
    DATA(from_position) = find( val = statement regex = `\s+from\s+` ).
    IF from_position < 1 OR lcl_util=>char_at( text = statement pos = 0 ) <> `$`.
      fail( `Invalid @for statement.` ).
    ENDIF.
    DATA(variable_name) = substring( val = statement off = 1 len = from_position - 1 ).
    DATA(from_match) = match( val = statement regex = `\s+from\s+` ).
    DATA(remainder) = substring( val = statement off = from_position + strlen( from_match ) ).
    DATA(mode_position) = find( val = remainder regex = `\s+(through|to)\s+` ).
    IF mode_position < 0.
      fail( `Invalid @for statement.` ).
    ENDIF.
    DATA(mode_match) = match( val = remainder regex = `\s+(through|to)\s+` ).
    DATA(from_text) = substring( val = remainder len = mode_position ).
    DATA(to_text) = substring( val = remainder off = mode_position + strlen( mode_match ) ).
    DATA(mode) = lcl_util=>trim_text( mode_match ).
    DATA(from_value) = eval_expression( text = from_text scope = context-scope ).
    DATA(to_value) = eval_expression( text = to_text scope = context-scope ).
    DATA(current) = CONV i( from_value->num ).
    DATA(finish) = CONV i( to_value->num ).
    DATA(step) = COND i( WHEN current <= finish THEN 1 ELSE -1 ).
    IF mode = `to`.
      finish = finish - step.
    ENDIF.
    WHILE ( step = 1 AND current <= finish ) OR ( step = -1 AND current >= finish ).
      DATA(iteration_scope) = NEW lcl_scope( parent = context-scope flow = abap_true ).
      DATA(counter) = CONV decfloat34( current ).
      iteration_scope->declare( name = variable_name item = lcl_value=>make_number( number = counter unit = from_value->unit ) ).
      DATA(inner) = context.
      inner-scope = iteration_scope.
      exec_nodes( nodes = node->children context = inner ).
      IF returned = abap_true.
        RETURN.
      ENDIF.
      current = current + step.
    ENDWHILE.
  ENDMETHOD.

  METHOD exec_while.
    DATA(guard) = 0.
    WHILE eval_expression( text = node->text scope = context-scope )->is_true( ) = abap_true.
      guard = guard + 1.
      IF guard > 10000.
        fail( `@while loop exceeded 10000 iterations.` ).
      ENDIF.
      exec_flow_block( nodes = node->children context = context ).
      IF returned = abap_true.
        RETURN.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

  METHOD exec_extend.
    IF context-selectors IS INITIAL.
      fail( `@extend may only be used within style rules.` ).
    ENDIF.
    DATA(targets) = lcl_util=>split_top( text = interpolate( text = node->text scope = context-scope ) separator = `,` ).
    LOOP AT targets INTO DATA(target).
      DATA(clean_target) = lcl_util=>trim_text( replace( val = target regex = `!optional` with = `` ) ).
      IF clean_target IS INITIAL.
        CONTINUE.
      ENDIF.
      LOOP AT context-selectors INTO DATA(extender).
        APPEND VALUE #( target = clean_target extender = extender ) TO extends.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD exec_bubbling.
    DATA(params) = lcl_util=>squash( substitute_variables( text = interpolate( text = node->text scope = context-scope ) scope = context-scope ) ).
    DATA(out) = NEW lcl_out( ).
    out->kind = `at`.
    out->header = |@{ node->name } { params }|.
    APPEND out TO context-container->children.
    DATA(inner) = context.
    inner-container = out.
    inner-scope = NEW lcl_scope( parent = context-scope ).
    CLEAR: inner-rule, inner-prefix.
    IF context-selectors IS NOT INITIAL.
      DATA(copy) = NEW lcl_out( ).
      copy->kind = `rule`.
      copy->selectors = context-selectors.
      APPEND copy TO out->children.
      inner-rule = copy.
    ENDIF.
    exec_nodes( nodes = node->children context = inner ).
  ENDMETHOD.

  METHOD exec_generic_at.
    DATA(params) = lcl_util=>squash( substitute_variables( text = interpolate( text = node->text scope = context-scope ) scope = context-scope ) ).
    DATA(header) = |@{ node->name }|.
    IF params IS NOT INITIAL.
      header = header && ` ` && params.
    ENDIF.
    DATA(out) = NEW lcl_out( ).
    IF node->has_block = abap_false.
      out->kind = `text`.
      out->header = header && `;`.
      APPEND out TO context-container->children.
      RETURN.
    ENDIF.
    out->kind = `at`.
    out->header = header.
    APPEND out TO context-container->children.
    DATA(inner) = context.
    inner-container = out.
    inner-scope = NEW lcl_scope( parent = context-scope ).
    CLEAR: inner-selectors, inner-prefix, inner-rule.
    IF node->name NP `*keyframes`.
      inner-rule = out.
    ENDIF.
    exec_nodes( nodes = node->children context = inner ).
  ENDMETHOD.

  METHOD finish_extends.
    IF extends IS NOT INITIAL.
      DO 5 TIMES.
        IF apply_extends( root ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    remove_placeholders( root ).
  ENDMETHOD.

  METHOD replace_target.
    DATA(output) = ``.
    DATA(cursor) = 0.
    DATA(found) = abap_false.
    DATA(target_length) = strlen( target ).
    DATA(target_first) = lcl_util=>char_at( text = target pos = 0 ).
    DO.
      DATA(hit) = find( val = selector sub = target off = cursor ).
      IF hit < 0.
        EXIT.
      ENDIF.
      DATA(before) = lcl_util=>char_at( text = selector pos = hit - 1 ).
      DATA(after) = lcl_util=>char_at( text = selector pos = hit + target_length ).
      DATA(boundary_ok) = abap_true.
      IF lcl_util=>is_ident_char( after ) = abap_true.
        boundary_ok = abap_false.
      ENDIF.
      IF lcl_util=>is_ident_char( target_first ) = abap_true
         AND before <> `` AND ( lcl_util=>is_ident_char( before ) = abap_true OR before CA `.#%:` ).
        boundary_ok = abap_false.
      ENDIF.
      IF boundary_ok = abap_true.
        output = output && substring( val = selector off = cursor len = hit - cursor ) && extender.
        found = abap_true.
        cursor = hit + target_length.
      ELSE.
        output = output && substring( val = selector off = cursor len = hit - cursor + 1 ).
        cursor = hit + 1.
      ENDIF.
    ENDDO.
    IF found = abap_true.
      result = output && substring( val = selector off = cursor ).
    ENDIF.
  ENDMETHOD.

  METHOD apply_extends.
    result = abap_false.
    IF node->kind = `rule`.
      LOOP AT extends INTO DATA(extend).
        DATA(snapshot) = node->selectors.
        LOOP AT snapshot INTO DATA(selector).
          DATA(replaced) = replace_target( selector = selector target = extend-target extender = extend-extender ).
          IF replaced IS NOT INITIAL AND NOT line_exists( node->selectors[ table_line = replaced ] ).
            APPEND replaced TO node->selectors.
            result = abap_true.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDIF.
    LOOP AT node->children INTO DATA(child).
      IF apply_extends( child ) = abap_true.
        result = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD remove_placeholders.
    IF node->kind = `rule`.
      LOOP AT node->selectors INTO DATA(selector).
        IF find( val = selector regex = `%[A-Za-z_-]` ) >= 0.
          DELETE node->selectors.
        ENDIF.
      ENDLOOP.
    ENDIF.
    LOOP AT node->children INTO DATA(child).
      remove_placeholders( child ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.



CLASS lcl_renderer IMPLEMENTATION.

  METHOD render.
    render_children( EXPORTING parent = root depth = 0 CHANGING lines = result ).
  ENDMETHOD.

  METHOD has_output.
    CASE node->kind.
      WHEN `rule`.
        result = xsdbool( node->selectors IS NOT INITIAL AND node->items IS NOT INITIAL ).
      WHEN `at`.
        IF node->items IS NOT INITIAL.
          result = abap_true.
          RETURN.
        ENDIF.
        LOOP AT node->children INTO DATA(child).
          IF has_output( child ) = abap_true.
            result = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
      WHEN OTHERS.
        result = abap_true.
    ENDCASE.
  ENDMETHOD.

  METHOD append_text.
    SPLIT text AT cl_abap_char_utilities=>newline INTO TABLE DATA(parts).
    LOOP AT parts INTO DATA(part).
      IF sy-tabix = 1.
        APPEND indent && part TO lines.
      ELSE.
        APPEND part TO lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD render_items.
    DATA(indent) = repeat( val = `  ` occ = depth ).
    LOOP AT node->items INTO DATA(item).
      IF item-kind = `comment`.
        append_text( EXPORTING text = item-text indent = indent CHANGING lines = lines ).
      ELSE.
        APPEND indent && item-property && `: ` && item-text && `;` TO lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD render_children.
    DATA(first) = abap_true.
    DATA(indent) = repeat( val = `  ` occ = depth ).
    LOOP AT parent->children INTO DATA(child).
      IF has_output( child ) = abap_false.
        CONTINUE.
      ENDIF.
      IF first = abap_false.
        APPEND `` TO lines.
      ENDIF.
      first = abap_false.
      CASE child->kind.
        WHEN `comment`.
          append_text( EXPORTING text = child->header indent = indent CHANGING lines = lines ).
        WHEN `text`.
          APPEND indent && child->header TO lines.
        WHEN `rule`.
          APPEND indent && concat_lines_of( table = child->selectors sep = `, ` ) && ` {` TO lines.
          render_items( EXPORTING node = child depth = depth + 1 CHANGING lines = lines ).
          APPEND indent && `}` TO lines.
        WHEN `at`.
          APPEND indent && child->header && ` {` TO lines.
          render_items( EXPORTING node = child depth = depth + 1 CHANGING lines = lines ).
          render_children( EXPORTING parent = child depth = depth + 1 CHANGING lines = lines ).
          APPEND indent && `}` TO lines.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
