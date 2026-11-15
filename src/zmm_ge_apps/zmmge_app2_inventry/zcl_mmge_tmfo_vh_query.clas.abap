CLASS zcl_mmge_tmfo_vh_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_MMGE_TMFO_VH_QUERY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_data TYPE STANDARD TABLE OF zmmge_tmfo_vh WITH EMPTY KEY.
    DATA lt_po   TYPE zcl_mm_s4_tmfo=>tt_po_range.
    DATA lt_item TYPE RANGE OF zmmge_tmfo_vh-purchaseorderitem.
    DATA lt_car  TYPE RANGE OF zmmge_tmfo_vh-carrier.
    DATA lt_fo   TYPE RANGE OF zmmge_tmfo_vh-freightorder.
    DATA lv_date TYPE d.

    " RAP checks that the query class reads everything the request asks for.
    " Read sort and paging up front so no request ($orderby, $count, $top)
    " can fail with RAP_RUNTIME/004 because one of them was not read.
    DATA(lt_sort)   = io_request->get_sort_elements( ).
    DATA(lo_paging) = io_request->get_paging( ).

    " filters of the dialog / the bindings
    TRY.
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_ranges.
    ENDTRY.
    LOOP AT lt_ranges INTO DATA(ls_range).
      CASE ls_range-name.
        WHEN 'PURCHASEORDER'.
          lt_po = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
        WHEN 'PURCHASEORDERITEM'.
          lt_item = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
        WHEN 'CARRIER'.
          lt_car = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
        WHEN 'FREIGHTORDER'.
          lt_fo = VALUE #( FOR r IN ls_range-range ( sign = r-sign option = r-option low = r-low high = r-high ) ).
        WHEN 'VALIDON'.
          lv_date = COND #( WHEN ls_range-range IS NOT INITIAL THEN ls_range-range[ 1 ]-low ).
      ENDCASE.
    ENDLOOP.
    IF lv_date IS INITIAL.
      lv_date = cl_abap_context_info=>get_system_date( ).
    ENDIF.

    " free-text search
    DATA(lv_search) = to_upper( condense( io_request->get_search_expression( ) ) ).
    REPLACE ALL OCCURRENCES OF `*` IN lv_search WITH ``.

    TRY.
        DATA(lt_fo_s4) = zcl_mm_s4_tmfo=>get( lt_po ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error
            /iwbep/cx_gateway INTO DATA(lx_error).
        RAISE EXCEPTION NEW lcx_vh( previous = lx_error ).
    ENDTRY.

    LOOP AT lt_fo_s4 INTO DATA(ls_fo)
         WHERE purchaseorderitem IN lt_item
           AND carrier           IN lt_car
           AND freightorder      IN lt_fo
           AND validfrom        <= lv_date
           AND validto          >= lv_date.
      IF lv_search IS NOT INITIAL
         AND to_upper( |{ ls_fo-freightorder ALPHA = OUT } { ls_fo-carrier ALPHA = OUT } { ls_fo-carriername }| ) NS lv_search.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( purchaseorder     = ls_fo-purchaseorder
                      purchaseorderitem = ls_fo-purchaseorderitem
                      carrier           = ls_fo-carrier
                      freightorder      = ls_fo-freightorder
                      carriername       = ls_fo-carriername
                      validfrom         = ls_fo-validfrom
                      validto           = ls_fo-validto
                      allocatedqty      = ls_fo-allocatedqty
                      orderunit         = ls_fo-orderunit
                      validon           = lv_date ) TO lt_data.
    ENDLOOP.

    " sort as requested ($orderby), otherwise by PO / item / carrier / valid from
    IF lt_sort IS INITIAL.
      SORT lt_data BY purchaseorder purchaseorderitem carrier validfrom.
    ELSE.
      DATA(lt_order) = VALUE abap_sortorder_tab( FOR s IN lt_sort
                                                 ( name       = s-element_name
                                                   descending = s-descending ) ).
      TRY.
          SORT lt_data BY (lt_order).
        CATCH cx_sy_dyn_table_ill_comp_val.
          SORT lt_data BY purchaseorder purchaseorderitem carrier validfrom.
      ENDTRY.
    ENDIF.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_data ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(lv_skip) = lo_paging->get_offset( ).
      DATA(lv_top)  = lo_paging->get_page_size( ).
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
