*----------------------------------------------------------------*
* SYSTEM: BTP ABAP Environment   Package: ZSDGE_APP3_SOUPD
* ADT object: ABAP Class   ZCL_SD_SOUPD_OPENQTY_CALC  (version 2)
* Virtual elements in ZSD_CI_GATE (Sales Order Update) and OpenQtyLive
* in ZSD_CI_WEIGHT (Outgoing Weighment).
*
* Fix 2026-10-06 (Open Order Qty was always blank): the S/4 OData
* service returns the keys in EXTERNAL format (SalesDocument '1200',
* SalesDocumentItem '10'), while the BTP items hold them padded
* ('0000001200' / '000010'). Both sides are normalized before comparing.
* v2 2026-11-05: SO line figures for Sales Order Update
*   OrderQtyLive     = S/4 order qty            (ZSD_OPEN_QTY SalesQty)
*   DeliveredQtyLive = S/4 delivered qty        (DeliveryQTY)
*   OpenQtyLive      = S/4 open qty             (OpenQty)
*   InYardQtyLive    = qty on OTHER gate entries not yet delivered
*                      (ZCL_SD_GATE_INYARD_QTY)
*   FreeQtyLive      = OpenQtyLive - InYardQtyLive (not below 0): the
*                      most this truck may have as loading advice qty
*----------------------------------------------------------------*
CLASS zcl_sd_soupd_openqty_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PRIVATE SECTION.
    CONSTANTS c_chunk_size TYPE i VALUE 40.
    CONSTANTS c_entity_set TYPE /iwbep/if_cp_runtime_types=>ty_entity_set_name VALUE 'OPEN_QTY'.

    TYPES tt_open TYPE STANDARD TABLE OF zsd_s4_soupd_oq_scm=>tys_open_qty_type WITH EMPTY KEY.

    TYPES ty_doc  TYPE c LENGTH 10.
    TYPES ty_item TYPE n LENGTH 6.
    TYPES ty_qty  TYPE zsdge_sentry_it1-quantity.

    "! S/4 figures per order item, keys normalized
    TYPES: BEGIN OF ty_open_norm,
             salesdocument TYPE ty_doc,
             salesitem     TYPE ty_item,
             sales_qty     TYPE ty_qty,
             delivery_qty  TYPE ty_qty,
             open_qty      TYPE ty_qty,
           END OF ty_open_norm,
           tt_open_norm TYPE SORTED TABLE OF ty_open_norm WITH UNIQUE KEY salesdocument salesitem.

    "! qty on other gate entries, per gate entry and order item
    TYPES: BEGIN OF ty_yard_norm,
             uuid          TYPE zsdge_sentry_it1-uuid,
             salesdocument TYPE ty_doc,
             salesitem     TYPE ty_item,
             inyard_qty    TYPE ty_qty,
           END OF ty_yard_norm,
           tt_yard_norm TYPE SORTED TABLE OF ty_yard_norm WITH UNIQUE KEY uuid salesdocument salesitem.

    "! S/4 open qty for the given orders, one OData call per 40 orders
    METHODS read_open_qty
      IMPORTING it_orders      TYPE string_table
      RETURNING VALUE(rt_open) TYPE tt_open
      RAISING   cx_static_check.

    "! '1200' / '0000001200' -> '0000001200'
    METHODS norm_doc
      IMPORTING iv_doc        TYPE clike
      RETURNING VALUE(rv_doc) TYPE ty_doc.

    "! '10' / '000010' -> '000010'
    METHODS norm_item
      IMPORTING iv_item        TYPE clike
      RETURNING VALUE(rv_item) TYPE ty_item.
ENDCLASS.



CLASS ZCL_SD_SOUPD_OPENQTY_CALC IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    LOOP AT it_requested_calc_elements INTO DATA(lv_element)
         WHERE table_line = `OPENQTYLIVE`  OR table_line = `ORDERQTYLIVE` OR table_line = `DELIVEREDQTYLIVE`
            OR table_line = `INYARDQTYLIVE` OR table_line = `FREEQTYLIVE`.
      INSERT `SALESDOCUMENT` INTO TABLE et_requested_orig_elements.
      INSERT `SALESITEM`     INTO TABLE et_requested_orig_elements.
      INSERT `UUID`          INTO TABLE et_requested_orig_elements.
      EXIT.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_items  TYPE STANDARD TABLE OF zsd_ci_gate WITH DEFAULT KEY.
    DATA lt_orders TYPE string_table.
    DATA lt_open   TYPE tt_open.
    DATA lt_norm   TYPE tt_open_norm.
    DATA lt_yard   TYPE tt_yard_norm.
    DATA lt_keys   TYPE zcl_sd_gate_inyard_qty=>tt_key.

    lt_items = CORRESPONDING #( it_original_data ).

    LOOP AT lt_items INTO DATA(ls_item) WHERE Salesdocument IS NOT INITIAL.
      APPEND CONV string( ls_item-Salesdocument ) TO lt_orders.
    ENDLOOP.
    SORT lt_orders.
    DELETE ADJACENT DUPLICATES FROM lt_orders.

    TRY.
        lt_open = read_open_qty( lt_orders ).
      CATCH cx_static_check.
        " S/4 not reachable: the S/4 figures stay blank, the page still loads
        CLEAR lt_open.
    ENDTRY.

    " S/4 keys come back in external format ('1200' / '10')
    LOOP AT lt_open INTO DATA(ls_open).
      INSERT VALUE #( salesdocument = norm_doc( ls_open-sales_document )
                      salesitem     = norm_item( ls_open-sales_document_item )
                      sales_qty     = ls_open-sales_qty
                      delivery_qty  = ls_open-delivery_qty
                      open_qty      = ls_open-open_qty ) INTO TABLE lt_norm.
    ENDLOOP.

    " qty on OTHER gate entries: per gate entry, its own lines excluded
    IF line_exists( it_requested_calc_elements[ table_line = `INYARDQTYLIVE` ] )
       OR line_exists( it_requested_calc_elements[ table_line = `FREEQTYLIVE` ] ).
      LOOP AT lt_items INTO DATA(ls_grp) GROUP BY ls_grp-Uuid INTO DATA(lv_uuid).
        CLEAR lt_keys.
        LOOP AT GROUP lv_uuid INTO DATA(ls_member) WHERE Salesdocument IS NOT INITIAL.
          INSERT VALUE #( salesdocument = ls_member-Salesdocument
                          salesitem     = ls_member-Salesitem ) INTO TABLE lt_keys.
        ENDLOOP.
        LOOP AT zcl_sd_gate_inyard_qty=>get( it_keys = lt_keys iv_exclude_uuid = lv_uuid ) INTO DATA(ls_in).
          INSERT VALUE #( uuid          = lv_uuid
                          salesdocument = norm_doc( ls_in-salesdocument )
                          salesitem     = norm_item( ls_in-salesitem )
                          inyard_qty    = ls_in-inyard_qty ) INTO TABLE lt_yard.
        ENDLOOP.
      ENDLOOP.
    ENDIF.

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      DATA(lv_doc)  = norm_doc( <ls_item>-Salesdocument ).
      DATA(lv_itm)  = norm_item( <ls_item>-Salesitem ).
      DATA(ls_s4)   = VALUE #( lt_norm[ salesdocument = lv_doc salesitem = lv_itm ] OPTIONAL ).
      DATA(lv_yard) = VALUE ty_qty( lt_yard[ uuid = <ls_item>-Uuid salesdocument = lv_doc salesitem = lv_itm ]-inyard_qty OPTIONAL ).

      <ls_item>-OrderQtyLive     = ls_s4-sales_qty.
      <ls_item>-DeliveredQtyLive = ls_s4-delivery_qty.
" over-delivery within tolerance makes the S/4 open qty negative: show 0
      <ls_item>-OpenQtyLive      = COND #( WHEN ls_s4-open_qty > 0 THEN ls_s4-open_qty ELSE 0 ).
      <ls_item>-InYardQtyLive    = lv_yard.
      <ls_item>-FreeQtyLive      = COND #( WHEN ls_s4-open_qty > lv_yard THEN ls_s4-open_qty - lv_yard ELSE 0 ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_items ).
  ENDMETHOD.


  METHOD norm_doc.
    rv_doc = condense( CONV string( iv_doc ) ).
    IF rv_doc CO '0123456789 '.
      rv_doc = |{ rv_doc ALPHA = IN }|.
    ENDIF.
  ENDMETHOD.


  METHOD norm_item.
    DATA(lv_text) = condense( CONV string( iv_item ) ).
    IF lv_text CO '0123456789' AND lv_text IS NOT INITIAL.
      rv_item = lv_text.
    ENDIF.
  ENDMETHOD.


  METHOD read_open_qty.
    DATA lt_range  TYPE RANGE OF zsd_s4_soupd_oq_scm=>tys_open_qty_type-sales_document.
    DATA lt_remote TYPE STANDARD TABLE OF zsd_s4_soupd_oq_scm=>tys_open_qty_type WITH EMPTY KEY.

    IF it_orders IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = 'ZMMGE_S4_PLANT_CS'
                             service_id    = 'ZMMGE_S4_PLANT_REST' ).

    DATA(lo_proxy) = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
                       is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                           proxy_model_id      = 'ZSD_S4_SOUPD_OQ_SCM'
                                                           proxy_model_version = '0001' )
                       io_http_client           = cl_web_http_client_manager=>create_by_http_destination( lo_destination )
                       iv_relative_service_root = '/sap/opu/odata/sap/ZSD_API_SD_SOUPD_O2/' ).

    LOOP AT it_orders INTO DATA(lv_order).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_order ) TO lt_range.

      IF lines( lt_range ) < c_chunk_size AND sy-tabix < lines( it_orders ).
        CONTINUE.
      ENDIF.

      " --- one call per chunk: $filter=SalesDocument eq ... or ... ---
      DATA(lo_read) = lo_proxy->create_resource_for_entity_set( c_entity_set )->create_request_for_read( ).
      lo_read->set_filter( lo_read->create_filter_factory( )->create_by_range(
                             iv_property_path = 'SALES_DOCUMENT'
                             it_range         = lt_range ) ).
      lo_read->set_top( 5000 ).

      CLEAR lt_remote.
      lo_read->execute( )->get_business_data( IMPORTING et_business_data = lt_remote ).
      APPEND LINES OF lt_remote TO rt_open.

      CLEAR lt_range.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
