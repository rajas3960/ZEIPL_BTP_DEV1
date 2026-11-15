CLASS zcl_sd_tmfo_vh_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_SD_TMFO_VH_QUERY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_data TYPE STANDARD TABLE OF zsd_tmfo_vh WITH EMPTY KEY.
    DATA lt_so   TYPE zcl_sd_s4_sotmfo=>tt_so_range.
    DATA lt_item TYPE RANGE OF zsd_tmfo_vh-salesorderitem.
    DATA lt_car  TYPE RANGE OF zsd_tmfo_vh-carrier.
    DATA lt_fo   TYPE RANGE OF zsd_tmfo_vh-freightorder.

    " filters of the dialog / the bindings
    TRY.
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_ranges.
    ENDTRY.
    LOOP AT lt_ranges INTO DATA(ls_range).
      CASE ls_range-name.
        WHEN 'SALESORDER'.
          lt_so = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
        WHEN 'SALESORDERITEM'.
          lt_item = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
        WHEN 'CARRIER'.
          lt_car = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
        WHEN 'FREIGHTORDER'.
          lt_fo = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
      ENDCASE.
    ENDLOOP.

    " free-text search
    DATA(lv_search) = to_upper( condense( io_request->get_search_expression( ) ) ).
    REPLACE ALL OCCURRENCES OF `*` IN lv_search WITH ``.

    TRY.
        DATA(lt_fo_s4) = zcl_sd_s4_sotmfo=>get( lt_so ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error
            /iwbep/cx_gateway INTO DATA(lx_error).
        RAISE EXCEPTION NEW lcx_vh( previous = lx_error ).
    ENDTRY.

    LOOP AT lt_fo_s4 INTO DATA(ls_fo)
         WHERE salesorderitem IN lt_item
           AND carrier        IN lt_car
           AND freightorder   IN lt_fo.
      IF lv_search IS NOT INITIAL
         AND to_upper( |{ ls_fo-freightorder ALPHA = OUT } { ls_fo-carrier ALPHA = OUT } { ls_fo-carriername }| ) NS lv_search.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( salesorder     = ls_fo-salesorder
                      salesorderitem = ls_fo-salesorderitem
                      carrier        = ls_fo-carrier
                      freightorder   = ls_fo-freightorder
                      carriername    = ls_fo-carriername ) TO lt_data.
    ENDLOOP.

    " sort as requested by the UI - RAP rejects the query if the
    " requested sort order is not read
    DATA lt_order TYPE abap_sortorder_tab.
    LOOP AT io_request->get_sort_elements( ) INTO DATA(ls_sort).
      APPEND VALUE #( name       = to_upper( ls_sort-element_name )
                      descending = ls_sort-descending ) TO lt_order.
    ENDLOOP.
    IF lt_order IS INITIAL.
      SORT lt_data BY salesorder salesorderitem carrier freightorder.
    ELSE.
      SORT lt_data BY (lt_order).
    ENDIF.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_data ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
      DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
      IF lv_skip > 0.
        DELETE lt_data TO lv_skip.
      ENDIF.
      IF lv_top <> if_rap_query_paging=>page_size_unlimited AND lines( lt_data ) > lv_top.
        DATA(lv_from) = lv_top + 1.
        DELETE lt_data FROM lv_from.
      ENDIF.
      io_response->set_data( lt_data ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
