CLASS zcl_mmge_matgrpvh_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    "! Name of one material group from S/4; initial if not found or S/4 not reachable
    CLASS-METHODS get_name
      IMPORTING iv_matgroup    TYPE matkl
      RETURNING VALUE(rv_name) TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS create_read_request
      RETURNING VALUE(ro_read) TYPE REF TO /iwbep/if_cp_request_read_list
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error
                /iwbep/cx_gateway.

    METHODS map_element
      IMPORTING iv_element         TYPE string
      RETURNING VALUE(rv_property) TYPE string.
ENDCLASS.


CLASS zcl_mmge_matgrpvh_query IMPLEMENTATION.

  METHOD create_read_request.
    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = 'ZMMGE_S4_PLANT_CS'
                             service_id    = 'ZMMGE_S4_PLANT_REST' ).
    DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

    DATA(lo_proxy) = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
                       is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                           proxy_model_id      = 'ZMM_S4_MATGRP_SCM'
                                                           proxy_model_version = '0001' )
                       io_http_client           = lo_http_client
                       iv_relative_service_root = '/sap/opu/odata/sap/ZMM_API_MATGRP_O2/' ).

    ro_read = lo_proxy->create_resource_for_entity_set( 'MATERIAL_GROUP' )->create_request_for_read( ).
  ENDMETHOD.


  METHOD get_name.
    DATA lt_remote TYPE STANDARD TABLE OF zmm_s4_matgrp_scm=>tys_material_group_type WITH EMPTY KEY.

    CHECK iv_matgroup IS NOT INITIAL.
    TRY.
        DATA(lo_read) = create_read_request( ).
        lo_read->set_filter( lo_read->create_filter_factory( )->create_by_range(
                               iv_property_path = 'MATERIAL_GROUP'
                               it_range         = VALUE if_rap_query_filter=>tt_range_option(
                                                    ( sign = 'I' option = 'EQ' low = iv_matgroup ) ) ) ).
        lo_read->set_top( 1 ).
        lo_read->execute( )->get_business_data( IMPORTING et_business_data = lt_remote ).
        rv_name = VALUE #( lt_remote[ 1 ]-material_group_name OPTIONAL ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error
            /iwbep/cx_gateway.
        CLEAR rv_name.
    ENDTRY.
  ENDMETHOD.


  METHOD if_rap_query_provider~select.
    DATA lt_remote  TYPE STANDARD TABLE OF zmm_s4_matgrp_scm=>tys_material_group_type WITH EMPTY KEY.
    DATA lt_result  TYPE STANDARD TABLE OF zmmge_i_matgrpvh.
    DATA lt_ranges  TYPE if_rap_query_filter=>tt_name_range_pairs.
    DATA lt_orderby TYPE /iwbep/if_cp_runtime_types=>ty_t_sort_order.
    DATA lo_filter  TYPE REF TO /iwbep/if_cp_filter_node.

    TRY.
        DATA(lo_read) = create_read_request( ).
        DATA(lo_filter_factory) = lo_read->create_filter_factory( ).

        " --- $filter (also used by useForValidation on typed input) ---
        TRY.
            lt_ranges = io_request->get_filter( )->get_as_ranges( ).
          CATCH cx_rap_query_filter_no_range.
            CLEAR lt_ranges.
        ENDTRY.

        LOOP AT lt_ranges INTO DATA(ls_range).
          DATA(lo_node) = lo_filter_factory->create_by_range( iv_property_path = map_element( ls_range-name )
                                                              it_range         = ls_range-range ).
          lo_filter = COND #( WHEN lo_filter IS BOUND THEN lo_filter->and( lo_node ) ELSE lo_node ).
        ENDLOOP.

        " --- search field in the value-help dialog ---
        DATA(lv_search) = io_request->get_search_expression( ).
        IF lv_search IS NOT INITIAL.
          lv_search = replace( val = lv_search sub = `"` with = `` occ = 0 ).
          DATA(lt_search) = VALUE if_rap_query_filter=>tt_range_option(
                              ( sign = 'I' option = 'CP' low = |*{ lv_search }*| ) ).
          DATA(lo_search) = lo_filter_factory->create_by_range( iv_property_path = 'MATERIAL_GROUP'
                                                                it_range         = lt_search
                            )->or( lo_filter_factory->create_by_range( iv_property_path = 'MATERIAL_GROUP_NAME'
                                                                       it_range         = lt_search ) ).
          lo_filter = COND #( WHEN lo_filter IS BOUND THEN lo_filter->and( lo_search ) ELSE lo_search ).
        ENDIF.

        IF lo_filter IS BOUND.
          lo_read->set_filter( lo_filter ).
        ENDIF.

        " --- $skip / $top ---
        DATA(lo_paging) = io_request->get_paging( ).
        IF lo_paging->get_offset( ) > 0.
          lo_read->set_skip( lo_paging->get_offset( ) ).
        ENDIF.
        IF lo_paging->get_page_size( ) <> if_rap_query_paging=>page_size_unlimited.
          lo_read->set_top( lo_paging->get_page_size( ) ).
        ENDIF.

        " --- $orderby ---
        LOOP AT io_request->get_sort_elements( ) INTO DATA(ls_sort).
          APPEND VALUE #( property_path = map_element( CONV #( ls_sort-element_name ) )
                          descending    = ls_sort-descending ) TO lt_orderby.
        ENDLOOP.
        IF lt_orderby IS NOT INITIAL.
          lo_read->set_orderby( lt_orderby ).
        ENDIF.

        " --- $count ---
        IF io_request->is_total_numb_of_rec_requested( ).
          lo_read->request_count( ).
        ENDIF.

        DATA(lo_response) = lo_read->execute( ).

        IF io_request->is_data_requested( ).
          lo_response->get_business_data( IMPORTING et_business_data = lt_remote ).
          lt_result = VALUE #( FOR ls_remote IN lt_remote
                               ( materialgroup     = ls_remote-material_group
                                 materialgroupname = ls_remote-material_group_name ) ).
          io_response->set_data( lt_result ).
        ENDIF.

        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lo_response->get_count( ) ).
        ENDIF.

      CATCH cx_http_dest_provider_error
            cx_web_http_client_error
            /iwbep/cx_gateway INTO DATA(lx_error).
        RAISE EXCEPTION NEW lcx_matgrpvh( previous = lx_error ).
    ENDTRY.
  ENDMETHOD.


  METHOD map_element.
    rv_property = SWITCH #( iv_element
                            WHEN 'MATERIALGROUP'     THEN `MATERIAL_GROUP`
                            WHEN 'MATERIALGROUPNAME' THEN `MATERIAL_GROUP_NAME`
                            ELSE iv_element ).
  ENDMETHOD.

ENDCLASS.


