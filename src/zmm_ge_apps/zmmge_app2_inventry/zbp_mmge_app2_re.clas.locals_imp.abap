CLASS lsc_zmmge_app2_re DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zmmge_app2_re IMPLEMENTATION.

  METHOD save_modified.
    " Challan data is now written to the draft by ChallanInput (EML) and
    " saved by the managed framework on Activate - nothing extra to write.
    " Kept because the BDEF declares 'with additional save'.
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

    METHODS Purchase FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~Purchase RESULT result.

    METHODS WeightScrn FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~WeightScrn RESULT result.

    METHODS MigoPost FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~MigoPost RESULT result.

    METHODS GateSlipForm FOR MODIFY
      IMPORTING keys FOR ACTION GateHead~GateSlipForm RESULT result.

    "! Reads PO item data from S/4; connection errors come back in rs_response-message
    METHODS read_po_items
      IMPORTING iv_po              TYPE zmmge_itm_t01-purchaseorder
                iv_item            TYPE zmmge_itm_t01-purchaseorderitem OPTIONAL
      RETURNING VALUE(rs_response) TYPE zcl_mm_s4_gate_api=>ty_response.

ENDCLASS.

CLASS lhc_GateHead IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      FIELDS ( Materialdocument Gateentryno Entryfilename ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY GateHead BY \_Item
      FIELDS ( Uuid ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      LINK DATA(lt_link).

    " Button flow:
    "   PO               until checked in
    "   Gate CheckIn     at least one PO line, not checked in
    "   Gate Entry Slip  checked in, slip not generated yet
    "   slip generated -> PO, CheckIn and Slip inactive
    " MigoPost: only on a saved gate entry that has no material document yet.
    LOOP AT lt_head INTO DATA(ls_head).
      DATA(lv_checked_in) = xsdbool( ls_head-Gateentryno IS NOT INITIAL ).
      DATA(lv_has_item)   = xsdbool( line_exists( lt_link[ source-%tky = ls_head-%tky ] ) ).
      DATA(lv_has_slip)   = xsdbool( ls_head-Entryfilename IS NOT INITIAL ).

      APPEND VALUE #( %tky                 = ls_head-%tky
                      %action-Purchase     = COND #( WHEN lv_checked_in = abap_false
                                                     THEN if_abap_behv=>fc-o-enabled
                                                     ELSE if_abap_behv=>fc-o-disabled )
                      %action-GateCheckIn  = COND #( WHEN lv_checked_in = abap_false AND lv_has_item = abap_true
                                                     THEN if_abap_behv=>fc-o-enabled
                                                     ELSE if_abap_behv=>fc-o-disabled )
                      %action-GateSlipForm = COND #( WHEN lv_checked_in = abap_true AND lv_has_slip = abap_false
                                                     THEN if_abap_behv=>fc-o-enabled
                                                     ELSE if_abap_behv=>fc-o-enabled  )
                      %action-MigoPost     = COND #( WHEN ls_head-%is_draft = if_abap_behv=>mk-on
                                                       OR ls_head-Materialdocument IS NOT INITIAL
                                                     THEN if_abap_behv=>fc-o-disabled
                                                     ELSE if_abap_behv=>fc-o-enabled ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD GateCheckIn.
    DATA: seqno  TYPE zmmge_hdr_t01-gateentryseqno,
          gateno TYPE zmmge_hdr_t01-gateentryno.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    GET TIME STAMP FIELD DATA(ts).
    CONVERT TIME STAMP ts TIME ZONE 'INDIA' INTO DATE DATA(lv_date) TIME DATA(lv_time).

    LOOP AT lt_head ASSIGNING FIELD-SYMBOL(<fs_head>).
      SELECT SINGLE MAX( gateentryseqno ) AS gateentryseqno,
             gateentrydate
        FROM zmmge_hdr_t01
        WHERE gateentrydate = @lv_date
        GROUP BY gateentrydate
        INTO @DATA(gs_seqno).

      IF sy-subrc = 0 AND gs_seqno-gateentryseqno IS NOT INITIAL.
        seqno = gs_seqno-gateentryseqno + 1.
      ELSE.
        seqno = '001'.
      ENDIF.
      gateno = |{ <fs_head>-Gateentryseries }{ lv_date }-{ seqno }|.

      MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
        ENTITY GateHead
        UPDATE FIELDS ( Gateentryno Gateentryseqno Gateentrydate Gateentrytime )
        WITH VALUE #( ( %tky           = <fs_head>-%tky
                        Gateentryno    = gateno
                        Gateentryseqno = seqno
                        Gateentrydate  = lv_date
                        Gateentrytime  = lv_time ) ).
    ENDLOOP.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.

  METHOD Purchase.
    DATA ls_response TYPE zcl_mm_s4_gate_api=>ty_response.
    DATA lv_subgate  TYPE zmmge_itm_t01-subgateentryno.
    DATA lt_cba      TYPE TABLE FOR CREATE zmmge_app2_re\\GateHead\_Item.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(gt_head)
      ENTITY GateHead BY \_Item
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(gt_item).

    DATA(ls_header) = VALUE #( gt_head[ 1 ] OPTIONAL ).
    DATA(gs_keys)   = VALUE #( keys[ 1 ] OPTIONAL ).
    DATA(lv_po)     = CONV zmmge_itm_t01-purchaseorder( gs_keys-%param-PurchaseOrder ).
    DATA(lv_poitem) = CONV zmmge_itm_t01-purchaseorderitem( gs_keys-%param-PurchaseOrderItem ).

    " FIX: check the items of this instance (draft or active) instead of the
    " active table, so a PO item added earlier in the same draft is found too
    DATA(lv_item_exists) = xsdbool( line_exists( gt_item[ Purchaseorder     = lv_po
                                                          Purchaseorderitem = lv_poitem ] ) ).

    IF lv_po IS NOT INITIAL AND ls_header-Gateentryseries <> 'G2' AND lv_item_exists = abap_false.
      IF lv_poitem IS NOT INITIAL.
        ls_response = read_po_items( iv_po = lv_po iv_item = lv_poitem ).
      ENDIF.
    ELSEIF lv_po IS NOT INITIAL AND ls_header-Gateentryseries = 'G2'.
      ls_response = read_po_items( iv_po = lv_po ).
      " G2 reads all items of the PO - skip the ones already on the gate entry
      LOOP AT ls_response-poitems INTO DATA(ls_existing).
        IF line_exists( gt_item[ Purchaseorder     = ls_existing-purchaseorder
                                 Purchaseorderitem = ls_existing-purchaseorderitem ] ).
          DELETE ls_response-poitems.
        ENDIF.
      ENDLOOP.
    ELSEIF lv_item_exists = abap_true.
      APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
      APPEND VALUE #( %tky = ls_header-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                    text     = |PO { lv_po } item { lv_poitem } is already on this gate entry| ) )
             TO reported-gatehead.
    ENDIF.

    IF ls_response-success = abap_true AND ls_response-poitems IS NOT INITIAL.
      " B5: freight order is mandatory for raw material (series G1) and the
      " PO button saves at once in display mode -> pre-fill it when S/4 has
      " exactly one freight order valid for the PO item on the gate entry
      " date (else the user picks it on the item in edit mode).
      " Other series: no freight order, no S/4 TM call.
      LOOP AT gt_head INTO DATA(gs_head).
        APPEND VALUE #( %tky = gs_head-%tky ) TO lt_cba ASSIGNING FIELD-SYMBOL(<ls_cba>).

        LOOP AT ls_response-poitems INTO DATA(ls_po).
          DATA(ls_fo) = VALUE zcl_mm_s4_tmfo=>ty_fo( ).
          IF gs_head-Gateentryseries = 'G1'.
            TRY.
                DATA(lt_valid) = zcl_mm_s4_tmfo=>get_valid( iv_po   = CONV #( ls_po-purchaseorder )
                                                            iv_item = CONV #( ls_po-purchaseorderitem )
                                                            iv_date = gs_head-Gateentrydate ).
                IF lines( lt_valid ) = 1.
                  ls_fo = lt_valid[ 1 ].
                ENDIF.
              CATCH cx_root ##CATCH_ALL.
                " S/4 not reachable: leave empty, checkFreightOrder reports it
            ENDTRY.
          ENDIF.

          " FIX: the new items must have the same draft indicator as the
          " parent - without it they are 'active' under a draft parent and
          " RAP dumps with 'Invalid operation O' (CX_ABAP_BEHV_RUNTIME_ERROR)
          APPEND VALUE #( %is_draft         = gs_head-%is_draft
                          Uuid              = gs_head-Uuid
                          Purchaseorder     = ls_po-purchaseorder
                          Purchaseorderitem = ls_po-purchaseorderitem
                          Vendor            = ls_po-supplier
                          Suppliername      = ls_po-suppliername
                          Gateentryno       = gs_head-Gateentryno
                          Gateentryseries   = gs_head-Gateentryseries
                          Subgateentryno    = lv_subgate
                          Material          = ls_po-material
                          Materialtext      = ls_po-productname
                          Materialgroup     = ls_po-materialgroup
                          Plant             = ls_po-plant
                          Plantname         = ls_po-plantname
                          Baseunit          = ls_po-baseunit
                          Quantity          = ls_po-orderquantity
                          Poordertype       = ls_po-purchaseordertype
                          Poordertypetext   = ls_po-purchasingdocumenttypename
                          Orderdate         = ls_po-purchaseorderdate
                          Freightorder      = ls_fo-freightorder
                          Carrier           = ls_fo-carrier
                          Carriername       = ls_fo-carriername ) TO <ls_cba>-%target.
        ENDLOOP.
      ENDLOOP.

      MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
        ENTITY GateHead
        CREATE BY \_Item
        AUTO FILL CID
        FIELDS ( Uuid Purchaseorder Purchaseorderitem Vendor Suppliername Gateentryno Gateentryseries Subgateentryno
                 Material Materialtext Materialgroup Plant Plantname Baseunit Quantity
                 Poordertype Poordertypetext Orderdate Freightorder Carrier Carriername )
        WITH lt_cba
        MAPPED mapped
        FAILED failed
        REPORTED reported.
    ELSEIF ls_response-message IS NOT INITIAL.
      APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
      APPEND VALUE #( %tky = ls_header-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                    text     = ls_response-message ) )
             TO reported-gatehead.
    ENDIF.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.
  METHOD read_po_items.
    TRY.
        rs_response = zcl_mm_s4_gate_api=>call( VALUE #( operation         = 'POITEMS'
                                                         purchaseorder     = iv_po
                                                         purchaseorderitem = iv_item ) ).
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD WeightScrn.
    " unchanged: the body was already commented out in the S/4 version
  ENDMETHOD.

  METHOD MigoPost.
    DATA ls_response TYPE zcl_mm_s4_gate_api=>ty_response.

    " NEW: per PO item + carrier
    TYPES: BEGIN OF ty_sum,
             po      TYPE zmmge_itm_t01-purchaseorder,
             item    TYPE zmmge_itm_t01-purchaseorderitem,
             carrier TYPE zmmge_carrier_id,
             qty     TYPE zcl_mm_s4_tmfo=>ty_qty,
           END OF ty_sum.
    DATA lt_sum TYPE SORTED TABLE OF ty_sum WITH UNIQUE KEY po item carrier.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY GateHead BY \_Item
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_poitem).

    LOOP AT lt_head INTO DATA(ls_header).
      DATA(ls_key) = keys[ %tky = ls_header-%tky ].

      "-------------------------------------------------------------
      " NEW: over-receipt check (carrier quantity from S/4)
      "-------------------------------------------------------------
      CLEAR lt_sum.
      LOOP AT lt_poitem INTO DATA(ls_it) WHERE Uuid = ls_header-Uuid AND Carrier IS NOT INITIAL.
        READ TABLE lt_sum ASSIGNING FIELD-SYMBOL(<ls_sum>)
             WITH TABLE KEY po = ls_it-Purchaseorder item = ls_it-Purchaseorderitem carrier = ls_it-Carrier.
        IF sy-subrc <> 0.
          INSERT VALUE #( po = ls_it-Purchaseorder item = ls_it-Purchaseorderitem carrier = ls_it-Carrier )
                 INTO TABLE lt_sum ASSIGNING <ls_sum>.
        ENDIF.
        <ls_sum>-qty = <ls_sum>-qty + ls_it-Netweight.
      ENDLOOP.

      DATA(lv_over) = abap_false.
      IF lt_sum IS NOT INITIAL.
        TRY.
            DATA(lt_alloc) = zcl_mm_s4_tmfo=>get( VALUE #( FOR s IN lt_sum ( sign = 'I' option = 'EQ' low = s-po ) ) ).
          CATCH cx_root INTO DATA(lx_alloc) ##CATCH_ALL.
            APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
            APPEND VALUE #( %tky = ls_header-%tky
                            %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                          text     = |Carrier quantity could not be checked in S/4: { lx_alloc->get_text( ) }| ) )
                   TO reported-gatehead.
            CONTINUE.
        ENDTRY.

        LOOP AT lt_sum INTO DATA(ls_sum).
          READ TABLE lt_alloc INTO DATA(ls_alloc)
               WITH KEY purchaseorder = ls_sum-po purchaseorderitem = ls_sum-item carrier = ls_sum-carrier.
          IF sy-subrc <> 0.
            CONTINUE.          " no allocation: checkFreightOrder already refuses such items
          ENDIF.

          " already posted for this PO item + carrier by other gate entries
          SELECT SUM( i~netweight )
            FROM zmmge_itm_t01 AS i
              INNER JOIN zmmge_hdr_t01 AS h ON i~uuid = h~uuid
            WHERE i~purchaseorder     = @ls_sum-po
              AND i~purchaseorderitem = @ls_sum-item
              AND i~carrier           = @ls_sum-carrier
              AND h~materialdocument <> @space
              AND h~uuid             <> @ls_header-Uuid
            INTO @DATA(lv_posted).

          IF lv_posted + ls_sum-qty > ls_alloc-allocatedqty.
            lv_over = abap_true.
            APPEND VALUE #( %tky = ls_header-%tky
                            %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                          text     = |Carrier { ls_sum-carrier ALPHA = OUT } on PO { ls_sum-po } item { ls_sum-item }:|
                                                                  && | { lv_posted NUMBER = USER } already received + { ls_sum-qty NUMBER = USER } now|
                                                                  && | = { lv_posted + ls_sum-qty NUMBER = USER }, allocation { ls_alloc-allocatedqty NUMBER = USER } { ls_alloc-orderunit }| ) )
                   TO reported-gatehead.
          ENDIF.
          CLEAR lv_posted.
        ENDLOOP.
      ENDIF.

      IF lv_over = abap_true.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
        CONTINUE.            " nothing is posted to S/4
      ENDIF.
      "------------------------------------------------------------- end NEW

      TRY.
          ls_response = zcl_mm_s4_gate_api=>call(
                          VALUE #( operation   = 'MIGO'
                                   gateentryno = ls_header-Gateentryno
                                   postingdate = ls_key-%param-PostingDate
                                   items       = VALUE #( FOR ls_poitem IN lt_poitem WHERE ( Uuid = ls_header-Uuid )
                                                          ( purchaseorder     = ls_poitem-Purchaseorder
                                                            purchaseorderitem = ls_poitem-Purchaseorderitem
                                                            plant             = ls_poitem-Plant
                                                            material          = ls_poitem-Material
                                                            quantity          = ls_poitem-Netweight
                                                            unit              = ls_poitem-Baseunit
                                                            storagelocation   = ls_poitem-Storagelocation ) ) ) ).
        CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
          ls_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
      ENDTRY.

      IF ls_response-success = abap_false.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
        APPEND VALUE #( %tky = ls_header-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |Goods receipt not posted: { ls_response-message }| ) )
               TO reported-gatehead.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
        ENTITY GateHead
        UPDATE FIELDS ( Materialdocument Materialdocumentyear )
        WITH VALUE #( ( %tky                 = ls_header-%tky
                        Materialdocument     = ls_response-materialdocument
                        Materialdocumentyear = ls_response-materialdocumentyear ) ).

      APPEND VALUE #( %tky = ls_header-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Material document { ls_response-materialdocument } posted| ) )
             TO reported-gatehead.
    ENDLOOP.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.

  METHOD GateSlipForm.
    " TEMPORARY until Step 12 (Adobe form setup in BTP) - the real code
    " replaces this method then.
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    LOOP AT lt_result INTO DATA(ls_res) WHERE Gateentryid IS NOT INITIAL.

      TRY.
          DATA(lo_fdp)  = cl_fp_fdp_services=>get_instance( iv_service_definition = 'ZMM_ENTRY_SLIP_SD'
                                                             iv_root_node          = 'ZMM_ENTRY_SLIP_CE' ).
          DATA(lt_keys) = lo_fdp->get_keys( ).
          lt_keys[ name = 'UUID' ]-value = ls_res-Uuid.
          DATA(lv_xml)  = lo_fdp->read_to_xml( lt_keys ).

          DATA(lv_pdf)  = zcl_ge_adobe_pdf=>render( iv_form_name     = `ZMM_ENTRY_SLIP`
                                                    iv_template_name = `ENTRY_SLIP`
                                                    iv_xml_data      = lv_xml ).

        CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
          APPEND VALUE #( %tky = ls_res-%tky ) TO failed-gatehead.
          APPEND VALUE #( %tky = ls_res-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Slip data: { lx_fdp->get_text( ) }| ) )
                 TO reported-gatehead.
          CONTINUE.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_res-%tky ) TO failed-gatehead.
          APPEND VALUE #( %tky = ls_res-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Adobe: HTTP { lx_ads->mv_http_status_code } { lx_ads->mv_http_reason }| ) )
                 TO reported-gatehead.
          CONTINUE.
      ENDTRY.

      MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
        ENTITY GateHead
          UPDATE FIELDS ( Entryslipattcmt Entrymimetype Entryfilename )
          WITH VALUE #( ( %tky            = ls_res-%tky
                          Entryslipattcmt = lv_pdf
                          Entrymimetype   = 'application/pdf'
                          Entryfilename   = |Entry Slip-{ ls_res-Gateentryno }.pdf| ) ).

      APPEND VALUE #( %tky = ls_res-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Gate entry slip created for { ls_res-Gateentryno }| ) )
             TO reported-gatehead.

    ENDLOOP.

    result = VALUE #( FOR ls_r IN lt_result ( %tky = ls_r-%tky %param = ls_r ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_GateItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR GateItem RESULT result.

    METHODS ChallanQtyCal FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GateItem~ChallanQtyCal.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR GateItem RESULT result.

    METHODS InbDelivery FOR MODIFY
      IMPORTING keys FOR ACTION GateItem~InbDelivery RESULT result.

    METHODS ChallanInput FOR MODIFY
      IMPORTING keys FOR ACTION GateItem~ChallanInput RESULT result.

    METHODS fillCarrier FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GateItem~fillCarrier.

    METHODS checkFreightOrder FOR VALIDATE ON SAVE
      IMPORTING keys FOR GateItem~checkFreightOrder.

ENDCLASS.

CLASS lhc_GateItem IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
      FIELDS ( Inbounddelivery ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    " InbDelivery: only on a saved gate entry, and only once per item
    result = VALUE #( FOR ls_item IN lt_item
                      ( %tky                = ls_item-%tky
                        %action-InbDelivery = COND #( WHEN ls_item-%is_draft = if_abap_behv=>mk-on
                                                        OR ls_item-Inbounddelivery IS NOT INITIAL
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD ChallanQtyCal.
    DATA lv_chnetqty TYPE zmmge_app2_iv1-Challannetweight.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
      FIELDS ( Challangrossweight Challantareweight ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE Challangrossweight IS NOT INITIAL.
      lv_chnetqty = ( <ls_item>-Challangrossweight - <ls_item>-Challantareweight ).

      MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
        ENTITY GateItem
        UPDATE FIELDS ( Challannetweight )
        WITH VALUE #( ( %tky             = <ls_item>-%tky
                        Challannetweight = lv_chnetqty ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD InbDelivery.
    DATA ls_response TYPE zcl_mm_s4_gate_api=>ty_response.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_poitem)
      ENTITY GateItem BY \_Head
      FIELDS ( Gateentryno ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    IF lt_poitem IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_poitem ASCENDING BY Purchaseorder Purchaseorderitem.
    DATA(ls_pohead) = VALUE #( lt_head[ 1 ] OPTIONAL ).
    DATA(ls_item)   = lt_poitem[ 1 ].

    " one inbound delivery for all selected items, as in S/4
    TRY.
        ls_response = zcl_mm_s4_gate_api=>call(
                        VALUE #( operation   = 'INBDLV'
                                 supplier    = ls_item-Vendor
                                 gateentryno = ls_pohead-Gateentryno
                                 items       = VALUE #( FOR ls_poitem IN lt_poitem
                                                        ( purchaseorder     = ls_poitem-Purchaseorder
                                                          purchaseorderitem = ls_poitem-Purchaseorderitem ) ) ) ).
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        ls_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
    ENDTRY.

    IF ls_response-success = abap_false.
      LOOP AT lt_poitem INTO DATA(ls_failed_item).
        APPEND VALUE #( %tky = ls_failed_item-%tky ) TO failed-gateitem.
        APPEND VALUE #( %tky = ls_failed_item-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |Inbound delivery not created: { ls_response-message }| ) )
               TO reported-gateitem.
      ENDLOOP.
    ELSE.
      MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
        ENTITY GateItem
        UPDATE FIELDS ( Inbounddelivery )
        WITH VALUE #( FOR ls_poitem IN lt_poitem
                      ( %tky            = ls_poitem-%tky
                        Inbounddelivery = ls_response-inbounddelivery ) ).

      APPEND VALUE #( %tky = ls_item-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Inbound delivery { ls_response-inbounddelivery } created| ) )
             TO reported-gateitem.
    ENDIF.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.

  METHOD ChallanInput.
    " FIX: update the items through EML so the change lands in the draft
    " (or the active instance) the user is working on. The old version
    " wrote straight to zmmge_itm_t01 in save_modified, which bypassed the
    " draft and was overwritten again when the draft was activated.
    DATA lv_subgate TYPE zmmge_itm_t01-subgateentryno.
    DATA lt_challan TYPE SORTED TABLE OF zmmge_itm_t01-challanno WITH UNIQUE KEY table_line.

    DATA(gs_keys) = VALUE #( keys[ 1 ] OPTIONAL ).

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem BY \_Head
      FIELDS ( Uuid Gateentryno Gateentryseries ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    DATA(ls_head) = VALUE #( lt_head[ 1 ] OPTIONAL ).

    " G2: one sub gate entry letter per challan already on the gate entry
    " (no challan yet = A, one = B, ... ten = K)
    IF ls_head-Gateentryseries = 'G2'.
      READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
        ENTITY GateHead BY \_Item
        FIELDS ( Challanno ) WITH VALUE #( ( %tky = ls_head-%tky ) )
        RESULT DATA(lt_all_items).

      LOOP AT lt_all_items INTO DATA(ls_all) WHERE Challanno IS NOT INITIAL.
        INSERT ls_all-Challanno INTO TABLE lt_challan.
      ENDLOOP.

      DATA(lv_subcount) = lines( lt_challan ).
      IF lv_subcount <= 10.
        lv_subgate = |{ ls_head-Gateentryno }-{ substring( val = `ABCDEFGHIJK` off = lv_subcount len = 1 ) }|.
      ENDIF.
    ENDIF.

    MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
      UPDATE FIELDS ( Challanno Challandate Trasporterid Lrno Lrdate Subgateentryno )
      WITH VALUE #( FOR ls_key IN keys
                    ( %tky           = ls_key-%tky
                      Challanno      = gs_keys-%param-Challanno
                      Challandate    = gs_keys-%param-Challandate
                      Trasporterid   = gs_keys-%param-trasporterid
                      Lrno           = gs_keys-%param-lrno
                      Lrdate         = gs_keys-%param-lrdate
                      Subgateentryno = lv_subgate ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.

  METHOD fillCarrier.
    " freight order picked -> carrier + name from the S/4 carrier allocation
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Purchaseorder Purchaseorderitem Freightorder Carrier Carriername )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA lt_upd TYPE TABLE FOR UPDATE zmmge_app2_re\\GateItem.

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(lv_carrier) = VALUE zmmge_carrier_id( ).
      DATA(lv_name)    = ``.
      IF ls_item-Freightorder IS NOT INITIAL.
        TRY.
            DATA(lt_fo) = zcl_mm_s4_tmfo=>get( VALUE #( ( sign = 'I' option = 'EQ' low = ls_item-Purchaseorder ) ) ).
            READ TABLE lt_fo INTO DATA(ls_fo)
                 WITH KEY purchaseorderitem = ls_item-Purchaseorderitem
                          freightorder      = ls_item-Freightorder.
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
    MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem UPDATE FROM lt_upd.
  ENDMETHOD.


  METHOD checkFreightOrder.
    " freight order is mandatory for raw material gate entries (series G1)
    " and must be maintained in S/4 for this PO item and valid on the gate
    " entry date; other series need no freight order
    " (texts kept under 50 characters - new_message_with_text cuts longer ones)
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Purchaseorder Purchaseorderitem Freightorder )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem BY \_Head
        FIELDS ( Gateentrydate Gateentryseries )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(ls_headkey) = VALUE #( lt_link[ source-%tky = ls_item-%tky ]-target OPTIONAL ).
      DATA(ls_headrow) = VALUE #( lt_head[ %tky = ls_headkey-%tky ] OPTIONAL ).
      DATA(lv_date)    = ls_headrow-Gateentrydate.

      " clears an old message of this check on the item
      APPEND VALUE #( %tky        = ls_item-%tky
                      %state_area = 'CHECK_FO'
                      %path       = VALUE #( gatehead-%tky = ls_headkey-%tky ) ) TO reported-gateitem.

      " freight order is only required for raw material (series G1)
      IF ls_headrow-Gateentryseries <> 'G1'.
        CONTINUE.
      ENDIF.

      DATA(lv_text) = ``.
      IF ls_item-Freightorder IS INITIAL.
        lv_text = |PO { ls_item-Purchaseorder }/{ CONV i( ls_item-Purchaseorderitem ) }: enter the freight order|.
      ELSE.
        TRY.
            DATA(lt_valid) = zcl_mm_s4_tmfo=>get_valid( iv_po   = ls_item-Purchaseorder
                                                        iv_item = ls_item-Purchaseorderitem
                                                        iv_date = lv_date ).
            IF NOT line_exists( lt_valid[ freightorder = ls_item-Freightorder ] ).
              lv_text = |FO { ls_item-Freightorder ALPHA = OUT } not valid for PO { ls_item-Purchaseorder }/{ CONV i( ls_item-Purchaseorderitem ) }|.
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

ENDCLASS.
