"! Loading Yard: Max Loading Qty = Loading Advice Qty + S/4 over-delivery
"! tolerance % of the SO line (05.11.2026, for information only)
CLASS zcl_sd_load_maxqty_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.
ENDCLASS.



CLASS ZCL_SD_LOAD_MAXQTY_CALC IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    IF line_exists( it_requested_calc_elements[ table_line = `MAXLOADQTY` ] ).
      INSERT `QUANTITY`      INTO TABLE et_requested_orig_elements.
      INSERT `OVERDELTOLPCT` INTO TABLE et_requested_orig_elements.
    ENDIF.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_items TYPE STANDARD TABLE OF zsd_ci_load WITH DEFAULT KEY.

    lt_items = CORRESPONDING #( it_original_data ).

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      <ls_item>-MaxLoadQty = <ls_item>-Quantity + <ls_item>-Quantity * <ls_item>-Overdeltolpct / 100.
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_items ).
  ENDMETHOD.
ENDCLASS.
