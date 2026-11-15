CLASS zcl_rgpn_prt_i_qry DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_RGPN_PRT_I_QRY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE STANDARD TABLE OF zmm_rgpn_prt_i WITH EMPTY KEY.

    IF io_request->is_data_requested( ) = abap_false.
      RETURN.
    ENDIF.

    TRY.
        DATA(lt_range) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_range.
    ENDTRY.

    READ TABLE lt_range INTO DATA(ls_uuid_filter) WITH KEY name = 'UUID'.
    LOOP AT ls_uuid_filter-range INTO DATA(ls_range).
      DATA(lv_uuid) = CONV sysuuid_x16( ls_range-low ).

      SELECT * FROM zmm_ii_rgpn
        WHERE Gpuuid = @lv_uuid
        ORDER BY Itemno
        INTO TABLE @DATA(lt_item).

      LOOP AT lt_item INTO DATA(ls_item).
        APPEND VALUE #(
          uuid           = ls_item-Gpuuid
          sno            = ls_item-Itemno
          Mcode          = ls_item-Matnr
          Mdesc          = ls_item-Maktx
          Uom            = ls_item-Uom
          Hsn            = ls_item-Hsncode
          hsncode        = ls_item-Hsncode
          plant          = ls_item-Plant
          plantname      = ls_item-Plantname
          plant_combined = |{ ls_item-Plant } - { ls_item-Plantname }|
          Qty            = ls_item-Quantity
          Curky          = ls_item-Curky
          Taxcode        = ls_item-Taxcode
          Remarks         = ls_item-Remarks
          Rate           = ls_item-Netprice
          Amount         = ls_item-Totvalue
          Talav          = ls_item-Totvalue
        ) TO lt_result.
      ENDLOOP.
    ENDLOOP.

    io_response->set_data( lt_result ).
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
