CLASS zcl_uom_unit_create_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

PUBLIC SECTION.

  INTERFACES if_oo_adt_classrun .
PROTECTED SECTION.
PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_UOM_UNIT_CREATE_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DATA(lo_uom) = cl_uom_maintenance=>get_instance( ).
    DATA(ls_unit) = VALUE cl_uom_maintenance=>ty_uom_cre_ts( commercial  = 'MT'
                                                             technical   = 'MT'
                                                             denominator = '1'
                                                             numerator   = '1000'
                                                             dec_disp    = '0'
*                                                             isocode     = 'MTT'
                                                             long_text   = 'Metric Ton' ).
    TRY.
        lo_uom->create( EXPORTING unit_dimid  = 'MASS'
                                  unit_int    = 'MT'
                                  unit_cre_ts = ls_unit
                        IMPORTING error       = DATA(lv_error) ).
      CATCH cx_uom_error INTO DATA(lo_error).
        out->write( | Exception raised | ).
        out->write( lo_error->get_text( ) ).
    ENDTRY.
    IF lv_error = abap_true.
      out->write( |Error occurred while saving the data in the database| ).
    ENDIF.

*    DATA(lo_uom) = cl_uom_maintenance=>get_instance( ).
*    TRY.
*        lo_uom->delete( EXPORTING unit = 'JK1'
*                        IMPORTING error = DATA(lv_error) ).
*      CATCH cx_uom_error INTO DATA(lo_error).
*        out->write( | Exception raised | ).
*        out->write( lo_error->get_text( ) ).
*    ENDTRY.
*    IF lv_error = abap_true.
*      out->write( |Error occurred while deleting the data from the database| ).
*    ENDIF.
  ENDMETHOD.
ENDCLASS.
