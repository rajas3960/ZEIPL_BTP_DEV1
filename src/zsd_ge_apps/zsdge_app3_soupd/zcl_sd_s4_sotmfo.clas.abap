CLASS zcl_sd_s4_sotmfo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_fo,
             salesorder     TYPE c LENGTH 10,
             salesorderitem TYPE n LENGTH 6,
             carrier        TYPE zsdge_carrier_id,
             carriername    TYPE c LENGTH 80,
             freightorder   TYPE zsdge_freight_order_id,
           END OF ty_fo,
           tt_fo TYPE STANDARD TABLE OF ty_fo WITH EMPTY KEY.

    TYPES tt_so_range TYPE RANGE OF ty_fo-salesorder.

    "! Freight orders of the given sales orders (empty range = all, max 5000)
    CLASS-METHODS get
      IMPORTING it_so        TYPE tt_so_range
      RETURNING VALUE(rt_fo) TYPE tt_fo
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error
                /iwbep/cx_gateway.

    "! Freight orders of one SO item
    CLASS-METHODS get_for_item
      IMPORTING iv_so        TYPE ty_fo-salesorder
                iv_item      TYPE ty_fo-salesorderitem
      RETURNING VALUE(rt_fo) TYPE tt_fo
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error
                /iwbep/cx_gateway.

  PRIVATE SECTION.
    CONSTANTS c_entity_set TYPE /iwbep/if_cp_runtime_types=>ty_entity_set_name VALUE 'SO_TM_FO'.

    CLASS-METHODS create_proxy
      RETURNING VALUE(ro_proxy) TYPE REF TO /iwbep/if_cp_client_proxy
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error
                /iwbep/cx_gateway.
ENDCLASS.



CLASS ZCL_SD_S4_SOTMFO IMPLEMENTATION.


  METHOD get.
    DATA lt_remote TYPE zsd_s4_sotmfo_scm=>tyt_so_tm_fo_type.

    DATA(lo_read) = create_proxy( )->create_resource_for_entity_set( c_entity_set )->create_request_for_read( ).
    IF it_so IS NOT INITIAL.
      lo_read->set_filter( lo_read->create_filter_factory( )->create_by_range(
                             iv_property_path = 'SALES_ORDER'
                             it_range         = it_so ) ).
    ENDIF.
    lo_read->set_top( 5000 ).
    lo_read->execute( )->get_business_data( IMPORTING et_business_data = lt_remote ).

    LOOP AT lt_remote INTO DATA(ls_remote) WHERE sales_order IS NOT INITIAL.
      APPEND VALUE #( salesorder     = |{ condense( ls_remote-sales_order ) ALPHA = IN WIDTH = 10 }|
                      salesorderitem = |{ condense( ls_remote-sales_order_item ) ALPHA = IN WIDTH = 6 }|
                      carrier        = |{ condense( ls_remote-carrier ) ALPHA = IN WIDTH = 10 }|
                      carriername    = ls_remote-carrier_name
                      freightorder   = |{ condense( ls_remote-freight_order ) ALPHA = IN WIDTH = 20 }| ) TO rt_fo.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_for_item.
    DATA(lv_so) = CONV ty_fo-salesorder( |{ condense( iv_so ) ALPHA = IN WIDTH = 10 }| ).
    DATA(lt_all) = get( VALUE #( ( sign = 'I' option = 'EQ' low = lv_so ) ) ).
    LOOP AT lt_all INTO DATA(ls_fo) WHERE salesorderitem = iv_item.
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
                                                     proxy_model_id      = 'ZSD_S4_SOTMFO_SCM'
                                                     proxy_model_version = '0001' )
                 io_http_client           = lo_http_client
                 iv_relative_service_root = '/sap/opu/odata/sap/ZSD_API_SO_TMFO_O2' ).
  ENDMETHOD.
ENDCLASS.
