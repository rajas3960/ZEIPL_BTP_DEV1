CLASS zcl_sd_sotmfo_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZCL_SD_SOTMFO_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    TRY.
        " 1. everything, no filter
        DATA(lt_all) = zcl_sd_s4_sotmfo=>get( VALUE #( ) ).
        out->write( |All rows: { lines( lt_all ) }| ).
        LOOP AT lt_all INTO DATA(ls_fo).
          out->write( |  SO "{ ls_fo-salesorder }" item "{ ls_fo-salesorderitem }" carrier "{ ls_fo-carrier }" FO "{ ls_fo-freightorder }"| ).
        ENDLOOP.

        " 2. with the filter the value help uses
        DATA(lt_so) = zcl_sd_s4_sotmfo=>get( VALUE #( ( sign = 'I' option = 'EQ' low = '0000001469' ) ) ).
        out->write( |Filter 0000001469: { lines( lt_so ) } row(s)| ).

        " 3. filter without leading zeros
        DATA(lt_so2) = zcl_sd_s4_sotmfo=>get( VALUE #( ( sign = 'I' option = 'EQ' low = '1469' ) ) ).
        out->write( |Filter 1469: { lines( lt_so2 ) } row(s)| ).

      CATCH cx_root INTO DATA(lx).
        out->write( |Error: { lx->get_text( ) }| ).
        DATA(lx_prev) = lx->previous.
        WHILE lx_prev IS BOUND.
          out->write( |  caused by: { lx_prev->get_text( ) }| ).
          lx_prev = lx_prev->previous.
        ENDWHILE.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
