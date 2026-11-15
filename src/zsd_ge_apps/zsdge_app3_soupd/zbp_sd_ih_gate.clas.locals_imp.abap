*----------------------------------------------------------------*
* SYSTEM: BTP ABAP Environment   Package: ZSDGE_APP3_SOUPD
* ADT object: Class (behavior pool)   ZBP_SD_IH_GATE - Local Types tab
*
* Full Local Types, based on the ADT version pasted on 12.11.2026.
* 12.11.2026 vehicle capacity (client: control the vehicles allocated
* against the SO qty), marked "=== A", "=== B", "=== C":
*   A  SalesOrder: default Loading Advice Qty = MIN( order qty,
*      S/4 open - other trucks, vehicle room = Vehiclecapqty - qty on
*      this truck's other tonne lines ); room <= 0 -> "Vehicle full"
*   B  GateItem features: Quantity editable while the line has no net
*      weight yet (before gross) and, as before, in Excess after gross
*   C  checkQuantity: truck total above Vehiclecapqty -> WARNING on
*      save (not an error)
* No BDEF change needed (Quantity has features : instance, checkQuantity
* runs on create + field Quantity).
*----------------------------------------------------------------*
CLASS lcl_s4_order DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_item     TYPE zsd_s4_soupd_scm=>tys_sales_order_item_type.
    TYPES tt_partner  TYPE STANDARD TABLE OF zsd_s4_soupd_scm=>tys_order_partner_type WITH EMPTY KEY.
    TYPES ty_open_qty TYPE zsd_s4_soupd_scm=>tys_open_qty_type-open_qty.

    "! SD1 = sales order item (open only), SD2 = customer return item
    CLASS-METHODS get_item
      IMPORTING iv_gatetype    TYPE clike
                iv_order       TYPE clike
                iv_item        TYPE clike
      RETURNING VALUE(rs_item) TYPE ty_item
      RAISING   cx_static_check.

    CLASS-METHODS get_partners
      IMPORTING iv_order          TYPE clike
      RETURNING VALUE(rt_partner) TYPE tt_partner
      RAISING   cx_static_check.

    CLASS-METHODS format_address
      IMPORTING iv_street      TYPE clike
                iv_city        TYPE clike
                iv_postal      TYPE clike
                iv_country     TYPE clike
                iv_region      TYPE clike
      RETURNING VALUE(rv_text) TYPE string.

    "! S/4 open qty (order qty - delivered qty, ZSD_OPEN_QTY) of one SO item
    CLASS-METHODS get_open_qty
      IMPORTING iv_order       TYPE clike
                iv_item        TYPE clike
      RETURNING VALUE(rv_open) TYPE ty_open_qty
      RAISING   cx_static_check.

  PRIVATE SECTION.
    CLASS-METHODS get_proxy
      RETURNING VALUE(ro_proxy) TYPE REF TO /iwbep/if_cp_client_proxy
      RAISING   cx_static_check.

    CLASS-METHODS key_filter
      IMPORTING io_read          TYPE REF TO /iwbep/if_cp_request_read_list
                iv_order         TYPE clike
                iv_item          TYPE clike
      RETURNING VALUE(ro_filter) TYPE REF TO /iwbep/if_cp_filter_node
      RAISING   cx_static_check.

ENDCLASS.


CLASS lcl_s4_order IMPLEMENTATION.

  METHOD get_proxy.
    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = 'ZMMGE_S4_PLANT_CS'
                             service_id    = 'ZMMGE_S4_PLANT_REST' ).

    ro_proxy = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
                 is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                     proxy_model_id      = 'ZSD_S4_SOUPD_SCM'
                                                     proxy_model_version = '0001' )
                 io_http_client           = cl_web_http_client_manager=>create_by_http_destination( lo_destination )
                 iv_relative_service_root = '/sap/opu/odata/sap/ZSD_API_SD_SOUPD_O2/' ).
  ENDMETHOD.

  METHOD key_filter.
    DATA lt_order TYPE RANGE OF ty_item-sales_document.
    DATA lt_item  TYPE RANGE OF ty_item-sales_document_item.

    lt_order = VALUE #( ( sign = 'I' option = 'EQ' low = iv_order ) ).
    lt_item  = VALUE #( ( sign = 'I' option = 'EQ' low = iv_item ) ).

    DATA(lo_factory) = io_read->create_filter_factory( ).
    ro_filter = lo_factory->create_by_range( iv_property_path = 'SALES_DOCUMENT'
                                             it_range         = lt_order
              )->and( lo_factory->create_by_range( iv_property_path = 'SALES_DOCUMENT_ITEM'
                                                   it_range         = lt_item ) ).
  ENDMETHOD.

  METHOD get_item.
    DATA lt_so  TYPE STANDARD TABLE OF zsd_s4_soupd_scm=>tys_sales_order_item_type WITH EMPTY KEY.
    DATA lt_ret TYPE STANDARD TABLE OF zsd_s4_soupd_scm=>tys_return_item_type WITH EMPTY KEY.

    DATA(lo_proxy) = get_proxy( ).

    IF iv_gatetype = 'SD2'.
      DATA(lo_read_ret) = lo_proxy->create_resource_for_entity_set( 'RETURN_ITEM' )->create_request_for_read( ).
      lo_read_ret->set_filter( key_filter( io_read = lo_read_ret iv_order = iv_order iv_item = iv_item ) ).
      lo_read_ret->execute( )->get_business_data( IMPORTING et_business_data = lt_ret ).
      IF lt_ret IS NOT INITIAL.
        rs_item = CORRESPONDING #( lt_ret[ 1 ] ).
      ENDIF.
    ELSE.
      DATA(lo_read_so) = lo_proxy->create_resource_for_entity_set( 'SALES_ORDER_ITEM' )->create_request_for_read( ).
      lo_read_so->set_filter( key_filter( io_read = lo_read_so iv_order = iv_order iv_item = iv_item ) ).
      lo_read_so->execute( )->get_business_data( IMPORTING et_business_data = lt_so ).
      DELETE lt_so WHERE sdprocess_status = 'C'.
      rs_item = VALUE #( lt_so[ 1 ] OPTIONAL ).
    ENDIF.
  ENDMETHOD.

  METHOD get_partners.
    DATA lt_order TYPE RANGE OF ty_item-sales_document.

    DATA(lo_read) = get_proxy( )->create_resource_for_entity_set( 'ORDER_PARTNER' )->create_request_for_read( ).
    lt_order = VALUE #( ( sign = 'I' option = 'EQ' low = iv_order ) ).
    lo_read->set_filter( lo_read->create_filter_factory( )->create_by_range( iv_property_path = 'SALES_ORDER'
                                                                             it_range         = lt_order ) ).
    lo_read->execute( )->get_business_data( IMPORTING et_business_data = rt_partner ).
  ENDMETHOD.

  METHOD format_address.
    rv_text = condense( |{ iv_street } { iv_city } { iv_postal } { iv_country } { iv_region }| ).
  ENDMETHOD.

  METHOD get_open_qty.
    DATA lt_open TYPE STANDARD TABLE OF zsd_s4_soupd_scm=>tys_open_qty_type WITH EMPTY KEY.

    DATA(lo_read) = get_proxy( )->create_resource_for_entity_set( 'OPEN_QTY' )->create_request_for_read( ).
    lo_read->set_filter( key_filter( io_read = lo_read iv_order = iv_order iv_item = iv_item ) ).
    lo_read->execute( )->get_business_data( IMPORTING et_business_data = lt_open ).
    rv_open = VALUE #( lt_open[ 1 ]-open_qty OPTIONAL ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_GateHead DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR GateHead RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR GateHead RESULT result.

    METHODS GateCheckIn FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~GateCheckIn RESULT result.

    METHODS Print FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~Print RESULT result.

    METHODS SalesOrder FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~SalesOrder RESULT result.

    METHODS CancelGateEntry FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~CancelGateEntry RESULT result.

ENDCLASS.


CLASS lhc_GateHead IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
      FIELDS ( Gateentryno Cancelgateentry ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    result = VALUE #( FOR ls_head IN lt_head
      ( %tky                    = ls_head-%tky
        %action-GateCheckIn     = COND #( WHEN ls_head-Gateentryno IS INITIAL AND ls_head-Cancelgateentry IS INITIAL
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-CancelGateEntry = COND #( WHEN ls_head-Cancelgateentry IS INITIAL
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-SalesOrder      = COND #( WHEN ls_head-Cancelgateentry IS INITIAL
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-Edit            = COND #( WHEN ls_head-Cancelgateentry IS INITIAL
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD GateCheckIn.
    DATA lv_seq    TYPE n LENGTH 3.
    DATA lt_update TYPE TABLE FOR UPDATE zsd_ih_gate\\GateHead.

    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      FAILED DATA(lt_failed).

    DELETE lt_head WHERE Gateentryno IS NOT INITIAL OR Cancelgateentry IS NOT INITIAL.

    IF lt_head IS NOT INITIAL.
      GET TIME STAMP FIELD DATA(ts).
      CONVERT TIME STAMP ts TIME ZONE 'INDIA' INTO DATE DATA(lv_date) TIME DATA(lv_time).

      SELECT SINGLE MAX( gateentrysequence ) FROM zsdge_sentry_ht1
        WHERE gateentrydate = @lv_date
        INTO @DATA(lv_maxseq).
      lv_seq = lv_maxseq.

      LOOP AT lt_head ASSIGNING FIELD-SYMBOL(<fs_head>).
        lv_seq += 1.
        APPEND VALUE #( %tky              = <fs_head>-%tky
                        Gateentryno       = |{ <fs_head>-Gateentrytype }{ lv_date }-{ lv_seq }|
                        Gateentrysequence = lv_seq
                        Gateentrydate     = lv_date
                        Gateentrytime     = lv_time
                        %control = VALUE #( Gateentryno       = if_abap_behv=>mk-on
                                            Gateentrysequence = if_abap_behv=>mk-on
                                            Gateentrydate     = if_abap_behv=>mk-on
                                            Gateentrytime     = if_abap_behv=>mk-on ) )
               TO lt_update.
      ENDLOOP.

      MODIFY ENTITIES OF zsd_ih_gate IN LOCAL MODE
        ENTITY GateHead
        UPDATE FROM lt_update.
    ENDIF.

    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result ( %tky = ls_r-%tky %param = ls_r ) ).
  ENDMETHOD.

  METHOD Print.
    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
        FIELDS ( Uuid Gateentryno ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head) WHERE Gateentryno IS NOT INITIAL.

      TRY.
          DATA(lo_fdp)  = cl_fp_fdp_services=>get_instance( iv_service_definition = 'ZSD_LOADING_SLIP'
                                                             iv_root_node          = 'ZSD_CE_GATE' ).
          DATA(lt_keys) = lo_fdp->get_keys( ).
          lt_keys[ name = 'UUID' ]-value = ls_head-Uuid.
          DATA(lv_xml)  = lo_fdp->read_to_xml( lt_keys ).

          DATA(lv_pdf)  = zcl_ge_adobe_pdf=>render( iv_form_name     = `ZSD_LOADING_SLIP`
                                                    iv_template_name = `LOADING_SLIP`
                                                    iv_xml_data      = lv_xml ).

        CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-gatehead.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Slip data: { lx_fdp->get_text( ) }| ) )
                 TO reported-gatehead.
          CONTINUE.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-gatehead.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Adobe: HTTP { lx_ads->mv_http_status_code } { lx_ads->mv_http_reason }| ) )
                 TO reported-gatehead.
          CONTINUE.
      ENDTRY.

      MODIFY ENTITIES OF zsd_ih_gate IN LOCAL MODE
        ENTITY GateHead
          UPDATE FIELDS ( Attachmentload Mimetypeload Filenameload )
          WITH VALUE #( ( %tky           = ls_head-%tky
                          Attachmentload = lv_pdf
                          Mimetypeload   = 'application/pdf'
                          Filenameload   = |Loading Slip-{ ls_head-Gateentryno }.pdf| ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Loading slip created for { ls_head-Gateentryno }| ) )
             TO reported-gatehead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD SalesOrder.
    DATA lv_so      TYPE c LENGTH 10.
    DATA lv_item    TYPE n LENGTH 6.
    DATA lv_error   TYPE string.
    DATA Lv_carrier TYPE n LENGTH 10.
    DATA ls_item    TYPE lcl_s4_order=>ty_item.
    DATA lt_partner TYPE lcl_s4_order=>tt_partner.
    DATA lv_open    TYPE zsdge_sentry_it1-quantity.
    DATA lv_inyard  TYPE zsdge_sentry_it1-quantity.
    DATA lv_qty     TYPE zsdge_sentry_it1-quantity.
    DATA lv_room    TYPE zsdge_sentry_it1-quantity.
    DATA lv_onveh   TYPE zsdge_sentry_it1-quantity.
    DATA lv_capmsg  TYPE string.
    DATA lv_free    TYPE zsdge_sentry_it1-quantity.

    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY GateHead BY \_Item
      FIELDS ( Salesdocument Salesitem Quantity Baseunit ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_head) = VALUE #( lt_head[ %tky = ls_key-%tky ] OPTIONAL ).
      IF ls_head IS INITIAL.
        CONTINUE.
      ENDIF.

      CLEAR: lv_error, ls_item, lt_partner, lv_open, lv_inyard, lv_qty,
             lv_room, lv_onveh, lv_capmsg, lv_free.
      lv_so   = ls_key-%param-Salesdocument.
      lv_so   = |{ lv_so ALPHA = IN }|.
      lv_item = ls_key-%param-SalesDocumentItem.

      IF lv_so IS INITIAL OR lv_item IS INITIAL.
        lv_error = `Enter Sales Order and Sales Order Item`.
      ELSEIF ls_head-Gateentrytype <> 'SD1' AND ls_head-Gateentrytype <> 'SD2'.
        lv_error = |Gate Entry Type { ls_head-Gateentrytype } does not allow sales orders|.
      ELSEIF line_exists( lt_items[ Uuid = ls_head-Uuid Salesdocument = lv_so Salesitem = lv_item ] ).
        lv_error = |Order Already Exists-{ ls_head-Gateentryno }|.
      ELSE.
        TRY.
            ls_item = lcl_s4_order=>get_item( iv_gatetype = ls_head-Gateentrytype
                                              iv_order    = lv_so
                                              iv_item     = lv_item ).
            IF ls_item IS INITIAL.
              lv_error = |This Order { lv_so } is Closed|.
            ELSE.
              IF ls_head-Customer IS INITIAL.
                lt_partner = lcl_s4_order=>get_partners( lv_so ).
              ENDIF.

              " 05.11.2026: SD1 line qty = what is still free on the SO item:
              " S/4 open qty minus the qty on other gate entries in the yard
              " (planned qty until gross weighment, then the net weight)
              lv_qty = ls_item-order_quantity.
              IF ls_head-Gateentrytype = 'SD1'.
                lv_open = lcl_s4_order=>get_open_qty( iv_order = lv_so
                                                      iv_item  = lv_item ).
                DATA(lt_yard) = zcl_sd_gate_inyard_qty=>get(
                                  it_keys         = VALUE #( ( salesdocument = lv_so
                                                               salesitem     = CONV #( lv_item ) ) )
                                  iv_exclude_uuid = ls_head-Uuid ).
                lv_inyard = VALUE #( lt_yard[ 1 ]-inyard_qty OPTIONAL ).

                " 10.11.2026: typed - an inline DATA( ) from a packed calculation has
                " no decimals (3.286 became 3, 19.714 became 20)
                lv_free = lv_open - lv_inyard.
                IF lv_free < lv_qty.
                  lv_qty = lv_free.
                ENDIF.
                IF lv_qty <= 0.
                  " (texts kept under 50 characters - new_message_with_text cuts longer ones)
                  lv_error = |SO { condense( |{ lv_so ALPHA = OUT }| ) }/{ CONV i( lv_item ) } fully assigned: | &&
                             |open { lv_open } yard { lv_inyard }|.
                ENDIF.

                " === A (12.11.2026): default = vehicle capacity. Room on this
                " truck = capacity - qty already on its other lines, whatever SO /
                " material (tonne units only)
                IF lv_error IS INITIAL
                   AND ls_head-Vehiclecapqty > 0
                   AND ( ls_item-order_quantity_unit = 'TO' OR ls_item-order_quantity_unit = 'MT' ).
                  LOOP AT lt_items INTO DATA(ls_onv) WHERE Uuid = ls_head-Uuid
                                                       AND ( Baseunit = 'TO' OR Baseunit = 'MT' ).
                    lv_onveh = lv_onveh + ls_onv-Quantity.
                  ENDLOOP.
                  lv_room = ls_head-Vehiclecapqty - lv_onveh.
                  IF lv_room <= 0.
                    " (under 50 characters - new_message_with_text cuts longer ones)
                    lv_error = |Vehicle full: cap { ls_head-Vehiclecapqty } assigned { lv_onveh }|.
                  ELSEIF lv_room < lv_qty.
                    lv_qty    = lv_room.
                    lv_capmsg = |Advice { lv_qty } = vehicle room (cap { ls_head-Vehiclecapqty })|.
                  ENDIF.
                ENDIF.
                " === end A
              ENDIF.
            ENDIF.
          CATCH cx_static_check INTO DATA(lx_s4).
            lv_error = |S/4 call failed: { lx_s4->get_text( ) }|.
        ENDTRY.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-gatehead.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_error ) )
               TO reported-gatehead.
        CONTINUE.
      ENDIF.

      " --- header: customer and addresses, only for the first order ---
      IF ls_head-Customer IS INITIAL.
        DATA(ls_we) = VALUE #( lt_partner[ partner_function = 'WE' ] OPTIONAL ).
        DATA(ls_re) = VALUE #( lt_partner[ partner_function = 'RE' ] OPTIONAL ).
        DATA(ls_zb) = VALUE #( lt_partner[ partner_function = 'ZB' ] OPTIONAL ).

        MODIFY ENTITIES OF zsd_ih_gate IN LOCAL MODE
          ENTITY GateHead
          UPDATE FIELDS ( Customer Customername Division Fromplace Billingfrom Consignee Billto Broker )
          WITH VALUE #( ( %tky         = ls_head-%tky
                          Customer     = ls_item-sold_to_party
                          Customername = ls_item-customer_name
                          Division     = ls_item-division
                          Fromplace    = ls_item-plant_name
                          Billingfrom  = lcl_s4_order=>format_address( iv_street  = ls_item-plant_street
                                                                       iv_city    = ls_item-plant_city
                                                                       iv_postal  = ls_item-plant_postal_code
                                                                       iv_country = ls_item-plant_country_name
                                                                       iv_region  = ls_item-plant_region_name )
                          Consignee    = lcl_s4_order=>format_address( iv_street  = ls_we-street_name
                                                                       iv_city    = ls_we-city_name
                                                                       iv_postal  = ls_we-postal_code
                                                                       iv_country = ls_we-country_name
                                                                       iv_region  = ls_we-region_name )
                          Billto       = lcl_s4_order=>format_address( iv_street  = ls_re-street_name
                                                                       iv_city    = ls_re-city_name
                                                                       iv_postal  = ls_re-postal_code
                                                                       iv_country = ls_re-country_name
                                                                       iv_region  = ls_re-region_name )
                          Broker       = lcl_s4_order=>format_address( iv_street  = ls_zb-street_name
                                                                       iv_city    = ls_zb-city_name
                                                                       iv_postal  = ls_zb-postal_code
                                                                       iv_country = ls_zb-country_name
                                                                       iv_region  = ls_zb-region_name ) ) )
          REPORTED DATA(ls_rep_head)
          FAILED DATA(ls_fail_head).

        APPEND LINES OF ls_fail_head-gatehead TO failed-gatehead.
        APPEND LINES OF ls_rep_head-gatehead  TO reported-gatehead.
      ENDIF.
      " B4b: pre-fill freight order + carrier when S/4 has exactly one
      " for this SO item - only for Incoterms FOR; other lines carry no
      " freight order, so S/4 does not assign a freight unit at delivery
      DATA(ls_fo) = VALUE zcl_sd_s4_sotmfo=>ty_fo( ).
      Lv_carrier = ls_head-transportid.
      IF to_upper( condense( ls_item-incoterms_classification ) ) = 'FOR'.
        TRY.
            DATA(lt_fo) = zcl_sd_s4_sotmfo=>get_for_item( iv_so   = lv_so
                                                          iv_item = lv_item ).
            IF lines( lt_fo ) = 1.
              ls_fo = lt_fo[ 1 ].
            ELSE.
              ls_fo = VALUE #( lt_fo[ carrier = Lv_carrier ] OPTIONAL ).
            ENDIF.
          CATCH cx_root ##CATCH_ALL.
            " S/4 not reachable: leave empty, checkFreightOrder reports it on save
        ENDTRY.
      ENDIF.
      " --- item row from the order ---
      MODIFY ENTITIES OF zsd_ih_gate IN LOCAL MODE
        ENTITY GateHead
        CREATE BY \_Item
        FIELDS ( Salesdocument Salesitem Gateentryno Plant Plantname Material Materialdesc
                 Batch Baseunit Quantity Customer Customername Ordertype Distributionchannel
                 Shippingpoint Independentrequirementtype Freightorder Carrier Carriername Overdeltolpct Incoterms )
        WITH VALUE #( ( %tky    = ls_head-%tky
                        %target = VALUE #( ( %cid                       = |ITEM{ lv_so }{ lv_item }|
                                             %is_draft                  = ls_head-%is_draft
                                             Salesdocument              = lv_so
                                             Salesitem                  = lv_item
                                             Gateentryno                = ls_head-Gateentryno
                                             Plant                      = ls_item-plant
                                             Plantname                  = ls_item-plant_name
                                             Material                   = ls_item-product
                                             Materialdesc               = ls_item-product_name
                                             Batch                      = ls_item-batch
                                             Baseunit                   = ls_item-order_quantity_unit
                                             Quantity                   = lv_qty
                                             Customer                   = ls_item-sold_to_party
                                             Customername               = ls_item-customer_name
                                             Ordertype                  = ls_item-sales_document_type
                                             Distributionchannel        = ls_item-distribution_channel
                                             Shippingpoint              = ls_item-shipping_point
                                             Independentrequirementtype = ls_item-independent_requirement_ty
                                             Freightorder               = ls_fo-freightorder
                                             Carrier                    = ls_fo-carrier
                                             Carriername                = ls_fo-carriername
                                             Overdeltolpct              = ls_item-overdeliv_tolrtd_lmt_ratio
                                             Incoterms                  = ls_item-incoterms_classification ) ) ) )
        MAPPED DATA(ls_map_item)
        REPORTED DATA(ls_rep_item)
        FAILED DATA(ls_fail_item).

      APPEND LINES OF ls_map_item-gateitem  TO mapped-gateitem.
      APPEND LINES OF ls_fail_item-gateitem TO failed-gateitem.
      APPEND LINES OF ls_rep_item-gateitem  TO reported-gateitem.

      " tell Sales how much of the SO line is left for this truck
      " (information, not warning: a warning makes Fiori repeat the action)
      IF ls_fail_item IS INITIAL AND ( lv_inyard > 0 OR lv_qty < ls_item-order_quantity ).
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-information
                                                      text     = |SO { condense( |{ lv_so ALPHA = OUT }| ) }/{ CONV i( lv_item ) }: | &&
                                                                 |advice { lv_qty } (open { lv_open } yard { lv_inyard })| ) )
               TO reported-gatehead.
      ENDIF.

      " === A (12.11.2026): the advice was cut to the vehicle room
      IF ls_fail_item IS INITIAL AND lv_capmsg IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-information
                                                      text     = lv_capmsg ) )
               TO reported-gatehead.
      ENDIF.
      " === end A
    ENDLOOP.

    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result ( %tky = ls_r-%tky %param = ls_r ) ).
  ENDMETHOD.

  METHOD CancelGateEntry.
    MODIFY ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
      UPDATE FIELDS ( Cancelgateentry )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Cancelgateentry = 'X' ) ).

    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result ( %tky = ls_r-%tky %param = ls_r ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_GateItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR GateItem RESULT result.

    METHODS fillCarrier FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GateItem~fillCarrier.

    METHODS checkFreightOrder FOR VALIDATE ON SAVE
      IMPORTING keys FOR GateItem~checkFreightOrder.

    METHODS checkQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR GateItem~checkQuantity.

ENDCLASS.


CLASS lhc_GateItem IMPLEMENTATION.

  METHOD get_instance_features.
    " 05.11.2026: Quantity can be raised on a line whose net weight is
    " above the assigned qty + tolerance (Excess after gross weighment)
    " === B (12.11.2026): ... and changed while the line has no net weight
    " yet (before gross), so Sales can split the vehicle capacity over the
    " lines of a truck. After gross only in Excess (delivery comes after
    " gross, so a delivered line has a net and is read-only)
    " 10.11.2026: Freight Order only for sales order lines with Incoterms FOR
    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Quantity Netweight Overdeltolpct Incoterms ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    result = VALUE #( FOR ls_item IN lt_item
                      ( %tky                = ls_item-%tky
                        %field-Quantity     = COND #( WHEN ls_item-Netweight IS INITIAL
                                                      THEN if_abap_behv=>fc-f-unrestricted
                                                      WHEN ls_item-Netweight > ls_item-Quantity
                                                                               + ls_item-Quantity * ls_item-Overdeltolpct / 100
                                                      THEN if_abap_behv=>fc-f-unrestricted
                                                      ELSE if_abap_behv=>fc-f-read_only )
                        %field-Freightorder = COND #( WHEN to_upper( condense( ls_item-Incoterms ) ) = 'FOR'
                                                      THEN if_abap_behv=>fc-f-unrestricted
                                                      ELSE if_abap_behv=>fc-f-read_only ) ) ).
  ENDMETHOD.

  METHOD fillCarrier.
    " freight order picked -> carrier + name from the S/4 SO allocation
    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Salesdocument Salesitem Freightorder Carrier Carriername )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA lt_upd TYPE TABLE FOR UPDATE zsd_ih_gate\\GateItem.

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(lv_carrier) = VALUE zsdge_carrier_id( ).
      DATA(lv_name)    = ``.
      IF ls_item-Freightorder IS NOT INITIAL.
        TRY.
            DATA(lt_fo) = zcl_sd_s4_sotmfo=>get_for_item( iv_so   = CONV #( ls_item-Salesdocument )
                                                         iv_item = CONV #( ls_item-Salesitem ) ).
            READ TABLE lt_fo INTO DATA(ls_fo) WITH KEY freightorder = ls_item-Freightorder.
            IF sy-subrc = 0.
              lv_carrier = ls_fo-carrier.
              lv_name    = ls_fo-carriername.
            ENDIF.
          CATCH cx_root ##CATCH_ALL.
            " S/4 not reachable: leave empty, the save check reports it
        ENDTRY.
      ENDIF.
      IF lv_carrier <> ls_item-Carrier OR lv_name <> ls_item-Carriername.
        APPEND VALUE #( %tky        = ls_item-%tky
                        Carrier     = lv_carrier
                        Carriername = lv_name
                        %control    = VALUE #( Carrier     = if_abap_behv=>mk-on
                                               Carriername = if_abap_behv=>mk-on ) ) TO lt_upd.
      ENDIF.
    ENDLOOP.

    CHECK lt_upd IS NOT INITIAL.
    MODIFY ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateItem UPDATE FROM lt_upd.
  ENDMETHOD.


  METHOD checkFreightOrder.
    " 10.11.2026: freight order mandatory only for lines with Incoterms FOR
    " (stored by the Sales Order button); an entered freight order must
    " belong to the SO item in S/4
    " (texts kept under 50 characters - new_message_with_text cuts longer ones)
    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Salesdocument Salesitem Freightorder Incoterms )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY GateItem BY \_Header
        FIELDS ( Uuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(ls_headkey) = VALUE #( lt_link[ source-%tky = ls_item-%tky ]-target OPTIONAL ).

      " clears an old message of this check on the item
      APPEND VALUE #( %tky        = ls_item-%tky
                      %state_area = 'CHECK_FO'
                      %path       = VALUE #( gatehead-%tky = ls_headkey-%tky ) ) TO reported-gateitem.

      DATA(lv_text) = ``.
      IF ls_item-Freightorder IS INITIAL.
        IF to_upper( condense( ls_item-Incoterms ) ) = 'FOR'.
          lv_text = |SO { ls_item-Salesdocument ALPHA = OUT }/{ CONV i( ls_item-Salesitem ) } (FOR): enter freight order|.
        ENDIF.
      ELSE.
        TRY.
            DATA(lt_fo) = zcl_sd_s4_sotmfo=>get_for_item( iv_so   = CONV #( ls_item-Salesdocument )
                                                         iv_item = CONV #( ls_item-Salesitem ) ).
            IF NOT line_exists( lt_fo[ freightorder = ls_item-Freightorder ] ).
              lv_text = |FO { ls_item-Freightorder ALPHA = OUT } not for SO { ls_item-Salesdocument ALPHA = OUT }|.
            ENDIF.
          CATCH cx_root INTO DATA(lx) ##CATCH_ALL.
            lv_text = |FO check failed: { lx->get_text( ) }|.
        ENDTRY.
      ENDIF.

      IF lv_text IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-gateitem.
        APPEND VALUE #( %tky        = ls_item-%tky
                        %state_area = 'CHECK_FO'
                        %path       = VALUE #( gatehead-%tky = ls_headkey-%tky )
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_text )
                        %element-Freightorder = if_abap_behv=>mk-on ) TO reported-gateitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD checkQuantity.
    " 05.11.2026: SD1 line qty may not be above what is still free on the
    " SO item: S/4 open qty minus the qty on OTHER gate entries in the yard
    " === C (12.11.2026): truck total (all tonne lines) above the vehicle
    " capacity -> WARNING only, the save goes through
    " (texts kept under 50 characters - new_message_with_text cuts longer ones)
    READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Salesdocument Salesitem Quantity Baseunit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY GateItem BY \_Header
        FIELDS ( Uuid Gateentrytype Vehiclecapqty )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(ls_headkey) = VALUE #( lt_link[ source-%tky = ls_item-%tky ]-target OPTIONAL ).
      DATA(ls_headrow) = VALUE #( lt_head[ %tky = ls_headkey-%tky ] OPTIONAL ).

      " clears an old message of this check on the item
      APPEND VALUE #( %tky        = ls_item-%tky
                      %state_area = 'CHECK_QTY'
                      %path       = VALUE #( gatehead-%tky = ls_headkey-%tky ) ) TO reported-gateitem.
      " === C: clears an old capacity warning on the item
      APPEND VALUE #( %tky        = ls_item-%tky
                      %state_area = 'CHECK_CAP'
                      %path       = VALUE #( gatehead-%tky = ls_headkey-%tky ) ) TO reported-gateitem.

      IF ls_headrow-Gateentrytype <> 'SD1'.
        CONTINUE.
      ENDIF.

      DATA(lv_so)   = condense( |{ ls_item-Salesdocument ALPHA = OUT }| ).
      DATA(lv_text) = ``.
      IF ls_item-Quantity <= 0.
        lv_text = |SO { lv_so }/{ CONV i( ls_item-Salesitem ) }: enter a quantity|.
      ELSE.
        TRY.
            DATA(lv_open) = lcl_s4_order=>get_open_qty( iv_order = ls_item-Salesdocument
                                                        iv_item  = ls_item-Salesitem ).
            DATA(lt_yard) = zcl_sd_gate_inyard_qty=>get(
                              it_keys         = VALUE #( ( salesdocument = ls_item-Salesdocument
                                                           salesitem     = ls_item-Salesitem ) )
                              iv_exclude_uuid = ls_item-Uuid ).
            DATA(lv_inyard) = VALUE zsdge_sentry_it1-quantity( lt_yard[ 1 ]-inyard_qty OPTIONAL ).
            " 10.11.2026: typed - an inline DATA( ) from a packed calculation has no decimals
            DATA(lv_max)    = CONV zsdge_sentry_it1-quantity( lv_open - lv_inyard ).
            IF ls_item-Quantity > lv_max.
              lv_text = |SO { lv_so }/{ CONV i( ls_item-Salesitem ) }: max qty { lv_max }|.
            ENDIF.
          CATCH cx_static_check INTO DATA(lx).
            lv_text = |Open qty check failed: { lx->get_text( ) }|.
        ENDTRY.
      ENDIF.

      IF lv_text IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-gateitem.
        APPEND VALUE #( %tky        = ls_item-%tky
                        %state_area = 'CHECK_QTY'
                        %path       = VALUE #( gatehead-%tky = ls_headkey-%tky )
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_text )
                        %element-Quantity = if_abap_behv=>mk-on ) TO reported-gateitem.
      ENDIF.

      " === C (12.11.2026): truck above its vehicle capacity -> warning only
      IF lv_text IS INITIAL
         AND ls_headrow-Vehiclecapqty > 0
         AND ( ls_item-Baseunit = 'TO' OR ls_item-Baseunit = 'MT' ).
        READ ENTITIES OF zsd_ih_gate IN LOCAL MODE
          ENTITY GateHead BY \_Item
            FIELDS ( Quantity Baseunit ) WITH VALUE #( ( %tky = ls_headkey-%tky ) )
          RESULT DATA(lt_truck).
        DATA(lv_total) = REDUCE zsdge_sentry_it1-quantity(
                           INIT s = CONV zsdge_sentry_it1-quantity( 0 )
                           FOR t IN lt_truck WHERE ( Baseunit = 'TO' OR Baseunit = 'MT' )
                           NEXT s = s + t-Quantity ).
        IF lv_total > ls_headrow-Vehiclecapqty.
          APPEND VALUE #( %tky        = ls_item-%tky
                          %state_area = 'CHECK_CAP'
                          %path       = VALUE #( gatehead-%tky = ls_headkey-%tky )
                          %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-warning
                                                               text     = |Vehicle over cap: { lv_total } > { ls_headrow-Vehiclecapqty }| )
                          %element-Quantity = if_abap_behv=>mk-on ) TO reported-gateitem.
        ENDIF.
      ENDIF.
      " === end C
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

