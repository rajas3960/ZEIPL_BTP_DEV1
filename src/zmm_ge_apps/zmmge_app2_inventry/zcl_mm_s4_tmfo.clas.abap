CLASS zcl_mm_s4_tmfo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_qty TYPE p LENGTH 7 DECIMALS 3.   " = dec(13,3)

    TYPES: BEGIN OF ty_fo,
             purchaseorder     TYPE zmmge_itm_t01-purchaseorder,
             purchaseorderitem TYPE zmmge_itm_t01-purchaseorderitem,
             carrier           TYPE zmmge_carrier_id,
             carriername       TYPE c LENGTH 80,
             allocatedqty      TYPE ty_qty,
             orderunit         TYPE c LENGTH 3,
             freightorder      TYPE zmmge_freight_order_id,
             validfrom         TYPE d,
             validto           TYPE d,
           END OF ty_fo,
           tt_fo TYPE STANDARD TABLE OF ty_fo WITH EMPTY KEY.

    TYPES tt_po_range TYPE RANGE OF zmmge_itm_t01-purchaseorder.

    "! All freight orders of the given POs (empty range = all, max 5000)
    CLASS-METHODS get
      IMPORTING it_po        TYPE tt_po_range
      RETURNING VALUE(rt_fo) TYPE tt_fo
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error
                /iwbep/cx_gateway.

    "! Freight orders of one PO item that are valid on iv_date
    "! (iv_date initial = today)
    CLASS-METHODS get_valid
      IMPORTING iv_po        TYPE zmmge_itm_t01-purchaseorder
                iv_item      TYPE zmmge_itm_t01-purchaseorderitem
                iv_date      TYPE d OPTIONAL
      RETURNING VALUE(rt_fo) TYPE tt_fo
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error
                /iwbep/cx_gateway.

  PRIVATE SECTION.
    CONSTANTS c_entity_set TYPE /iwbep/if_cp_runtime_types=>ty_entity_set_name VALUE 'PO_TM_FO'.

    CLASS-METHODS create_proxy
      RETURNING VALUE(ro_proxy) TYPE REF TO /iwbep/if_cp_client_proxy
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error
                /iwbep/cx_gateway.
ENDCLASS.



CLASS ZCL_MM_S4_TMFO IMPLEMENTATION.


  METHOD get.
    DATA lt_remote TYPE zmm_s4_tmfo_scm=>tyt_po_tm_fo_type.

    DATA(lo_read) = create_proxy( )->create_resource_for_entity_set( c_entity_set )->create_request_for_read( ).
    IF it_po IS NOT INITIAL.
      lo_read->set_filter( lo_read->create_filter_factory( )->create_by_range(
                             iv_property_path = 'PURCHASE_ORDER'
                             it_range         = it_po ) ).
    ENDIF.
    lo_read->set_top( 5000 ).
    lo_read->execute( )->get_business_data( IMPORTING et_business_data = lt_remote ).

    LOOP AT lt_remote INTO DATA(ls_remote) WHERE purchase_order IS NOT INITIAL.
      APPEND VALUE #( purchaseorder     = ls_remote-purchase_order
                      purchaseorderitem = ls_remote-purchase_order_item
                      carrier           = |{ condense( ls_remote-carrier ) ALPHA = IN WIDTH = 10 }|
                      carriername       = ls_remote-carrier_name
                      allocatedqty      = ls_remote-allocated_qty
                      orderunit         = ls_remote-order_unit
                      freightorder      = |{ condense( ls_remote-freight_order ) ALPHA = IN WIDTH = 20 }|
                      validfrom         = ls_remote-valid_from
                      validto           = ls_remote-valid_to ) TO rt_fo.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_valid.
    DATA(lv_date) = COND d( WHEN iv_date IS INITIAL THEN cl_abap_context_info=>get_system_date( )
                            ELSE iv_date ).

    DATA(lt_all) = get( VALUE #( ( sign = 'I' option = 'EQ' low = iv_po ) ) ).

    LOOP AT lt_all INTO DATA(ls_fo)
         WHERE purchaseorderitem = iv_item
           AND validfrom <= lv_date
           AND validto   >= lv_date.
      APPEND ls_fo TO rt_fo.
    ENDLOOP.
  ENDMETHOD.


  METHOD create_proxy.
    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = 'ZMMGE_S4_PLANT_CS'
                             service_id    = 'ZMMGE_S4_PLANT_REST' ).
    DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

    " the S/4 binding is OData V2 - Web API
    ro_proxy = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
                 is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                     proxy_model_id      = 'ZMM_S4_TMFO_SCM'
                                                     proxy_model_version = '0001' )
                 io_http_client           = lo_http_client
                 iv_relative_service_root = '/sap/opu/odata/sap/ZMM_API_PO_TMFO_O2' ).
  ENDMETHOD.
ENDCLASS.
