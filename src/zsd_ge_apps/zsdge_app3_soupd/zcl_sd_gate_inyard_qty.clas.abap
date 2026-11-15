*----------------------------------------------------------------*
* SYSTEM: BTP ABAP Environment   Package: ZSDGE_APP3_SOUPD
* ADT object: ABAP Class   ZCL_SD_GATE_INYARD_QTY  (version 2, 05.11.2026)
*
* Quantity of an SO item that is already in the yard on OTHER gate
* entries (not cancelled, no delivery yet):
*   - before gross weighment: the planned item Quantity
*   - after gross weighment:  the loaded item Netweight
* Once the delivery is created, S/4 open qty already includes the
* quantity, so the entry no longer counts.
* Sales Order Update: available qty = S/4 open qty - in-yard qty.
* v2: get_free = S/4 open qty (ZSD_OPEN_QTY via ZSD_S4_SOUPD_OQ_SCM)
*     minus in-yard qty, for Weighment Re-split (claims the extra qty
*     after Sales raised the SO in S/4).
*----------------------------------------------------------------*
CLASS zcl_sd_gate_inyard_qty DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_qty TYPE zsdge_sentry_it1-quantity.

    TYPES: BEGIN OF ty_key,
             salesdocument TYPE zsdge_sentry_it1-salesdocument,
             salesitem     TYPE zsdge_sentry_it1-salesitem,
           END OF ty_key,
           tt_key TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY salesdocument salesitem.

    TYPES: BEGIN OF ty_inyard,
             salesdocument TYPE zsdge_sentry_it1-salesdocument,
             salesitem     TYPE zsdge_sentry_it1-salesitem,
             inyard_qty    TYPE ty_qty,
             entries       TYPE i,
           END OF ty_inyard,
           tt_inyard TYPE SORTED TABLE OF ty_inyard WITH UNIQUE KEY salesdocument salesitem.

    TYPES: BEGIN OF ty_free,
             salesdocument TYPE zsdge_sentry_it1-salesdocument,
             salesitem     TYPE zsdge_sentry_it1-salesitem,
             open_qty      TYPE ty_qty,
             inyard_qty    TYPE ty_qty,
             free_qty      TYPE ty_qty,
           END OF ty_free,
           tt_free TYPE SORTED TABLE OF ty_free WITH UNIQUE KEY salesdocument salesitem.

    "! In-yard qty per SO item; iv_exclude_uuid = the gate entry being edited
    CLASS-METHODS get
      IMPORTING it_keys          TYPE tt_key
                iv_exclude_uuid  TYPE zsdge_sentry_it1-uuid OPTIONAL
      RETURNING VALUE(rt_inyard) TYPE tt_inyard.

    "! S/4 open qty, in-yard qty on other gate entries and the rest (free)
    CLASS-METHODS get_free
      IMPORTING it_keys         TYPE tt_key
                iv_exclude_uuid TYPE zsdge_sentry_it1-uuid OPTIONAL
      RETURNING VALUE(rt_free)  TYPE tt_free
      RAISING   cx_static_check.
ENDCLASS.



CLASS ZCL_SD_GATE_INYARD_QTY IMPLEMENTATION.


  METHOD get.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.

    " cancelgateentry was added later: old rows may hold NULL
    SELECT i~salesdocument, i~salesitem, i~quantity, i~netweight
      FROM zsdge_sentry_it1 AS i
      INNER JOIN zsdge_sentry_ht1 AS h ON h~uuid = i~uuid
      FOR ALL ENTRIES IN @it_keys
      WHERE i~salesdocument = @it_keys-salesdocument
        AND i~salesitem     = @it_keys-salesitem
        AND i~uuid         <> @iv_exclude_uuid
        AND i~deliveryno    = @space
        AND ( h~cancelgateentry IS NULL OR h~cancelgateentry <> 'X' )
      INTO TABLE @DATA(lt_rows).

    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(lv_qty) = COND ty_qty( WHEN ls_row-netweight > 0 THEN ls_row-netweight
                                  ELSE ls_row-quantity ).
      READ TABLE rt_inyard ASSIGNING FIELD-SYMBOL(<ls_inyard>)
           WITH TABLE KEY salesdocument = ls_row-salesdocument
                          salesitem     = ls_row-salesitem.
      IF sy-subrc <> 0.
        INSERT VALUE #( salesdocument = ls_row-salesdocument
                        salesitem     = ls_row-salesitem ) INTO TABLE rt_inyard ASSIGNING <ls_inyard>.
      ENDIF.
      <ls_inyard>-inyard_qty += lv_qty.
      <ls_inyard>-entries    += 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_free.
    DATA lt_range TYPE RANGE OF zsd_s4_soupd_oq_scm=>tys_open_qty_type-sales_document.
    DATA lt_open  TYPE STANDARD TABLE OF zsd_s4_soupd_oq_scm=>tys_open_qty_type WITH EMPTY KEY.

    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.

    lt_range = VALUE #( FOR GROUPS lv_so OF k IN it_keys GROUP BY k-salesdocument
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

    DATA(lt_yard) = get( it_keys = it_keys iv_exclude_uuid = iv_exclude_uuid ).

    LOOP AT it_keys INTO DATA(ls_key).
      DATA(ls_free) = VALUE ty_free( salesdocument = ls_key-salesdocument
                                     salesitem     = ls_key-salesitem
                                     inyard_qty    = VALUE #( lt_yard[ salesdocument = ls_key-salesdocument
                                                                       salesitem     = ls_key-salesitem ]-inyard_qty OPTIONAL ) ).

      " S/4 keys come back in external format ('1526' / '10'): compare
      " both sides without leading zeros (order) and as numbers (item)
      DATA(lv_key_doc)  = condense( |{ ls_key-salesdocument ALPHA = OUT }| ).
      DATA(lv_key_item) = CONV i( ls_key-salesitem ).
      LOOP AT lt_open INTO DATA(ls_open).
        IF condense( |{ ls_open-sales_document ALPHA = OUT }| ) = lv_key_doc
           AND CONV i( ls_open-sales_document_item ) = lv_key_item.
          ls_free-open_qty = ls_open-open_qty.
          EXIT.
        ENDIF.
      ENDLOOP.

      ls_free-free_qty = ls_free-open_qty - ls_free-inyard_qty.
      INSERT ls_free INTO TABLE rt_free.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
