*----------------------------------------------------------------*
* SYSTEM: BTP ABAP Environment   Package: ZSDGE_APP3_SOUPD
* ADT object: ABAP Class (console, F9)   ZCL_SD_GATE_FREE_TEST
* Test 09.11.2026: what ZCL_SD_GATE_INYARD_QTY=>get_free returns for
* SO 1549/10 and /20 (SD120261109-004), plus the raw S/4 OPEN_QTY rows
* the same call reads. Read-only. Delete after the test.
*----------------------------------------------------------------*
CLASS zcl_sd_gate_free_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZCL_SD_GATE_FREE_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DATA lt_range TYPE RANGE OF zsd_s4_soupd_oq_scm=>tys_open_qty_type-sales_document.
    DATA lt_open  TYPE STANDARD TABLE OF zsd_s4_soupd_oq_scm=>tys_open_qty_type WITH EMPTY KEY.

    SELECT SINGLE uuid FROM zsdge_sentry_ht1
      WHERE gateentryno = 'SD120261109-004'
      INTO @DATA(lv_uuid).

    SELECT salesdocument, salesitem, quantity, netweight, overdeltolpct, deliveryno FROM zsdge_sentry_it1
      WHERE uuid = @lv_uuid
      INTO TABLE @DATA(lt_lines).
    LOOP AT lt_lines INTO DATA(ls_l).
      out->write( |IT1 line: salesdocument '{ ls_l-salesdocument }' salesitem '{ ls_l-salesitem }' qty { ls_l-quantity } net { ls_l-netweight } tol { ls_l-overdeltolpct } dlv '{ ls_l-deliveryno }'| ).
    ENDLOOP.

    DATA(lt_keys) = VALUE zcl_sd_gate_inyard_qty=>tt_key( FOR l IN lt_lines
                                                          ( salesdocument = l-salesdocument salesitem = l-salesitem ) ).

    " 1. raw S/4 rows (same call as get_free)
    TRY.
        lt_range = VALUE #( FOR GROUPS lv_so OF k IN lt_keys GROUP BY k-salesdocument
                            ( sign = 'I' option = 'EQ' low = lv_so ) ).
        DATA(lo_proxy) = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
                           is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                               proxy_model_id      = 'ZSD_S4_SOUPD_OQ_SCM'
                                                               proxy_model_version = '0001' )
                           io_http_client           = cl_web_http_client_manager=>create_by_http_destination(
                                                        cl_http_destination_provider=>create_by_comm_arrangement(
                                                          comm_scenario = 'ZMMGE_S4_PLANT_CS'
                                                          service_id    = 'ZMMGE_S4_PLANT_REST' ) )
                           iv_relative_service_root = '/sap/opu/odata/sap/ZSD_API_SD_SOUPD_O2/' ).
        DATA(lo_read) = lo_proxy->create_resource_for_entity_set( 'OPEN_QTY' )->create_request_for_read( ).
        lo_read->set_filter( lo_read->create_filter_factory( )->create_by_range( iv_property_path = 'SALES_DOCUMENT'
                                                                                 it_range         = lt_range ) ).
        lo_read->set_top( 5000 ).
        lo_read->execute( )->get_business_data( IMPORTING et_business_data = lt_open ).
        out->write( |S/4 OPEN_QTY rows: { lines( lt_open ) }| ).
        LOOP AT lt_open INTO DATA(ls_o).
          out->write( |  S/4 row: doc '{ ls_o-sales_document }' item '{ ls_o-sales_document_item }' open { ls_o-open_qty }| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_raw).
        out->write( |S/4 read failed: { lx_raw->get_text( ) }| ).
    ENDTRY.

    " 2. get_free result
    TRY.
        DATA(lt_free) = zcl_sd_gate_inyard_qty=>get_free( it_keys = lt_keys iv_exclude_uuid = lv_uuid ).
        LOOP AT lt_free INTO DATA(ls_f).
          out->write( |get_free: '{ ls_f-salesdocument }'/'{ ls_f-salesitem }' open { ls_f-open_qty }| &&
                      | in-yard { ls_f-inyard_qty } free { ls_f-free_qty }| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_free).
        out->write( |get_free failed: { lx_free->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
