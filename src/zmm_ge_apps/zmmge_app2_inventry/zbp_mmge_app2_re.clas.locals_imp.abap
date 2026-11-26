CLASS lcl_wflag DEFINITION FINAL.
  PUBLIC SECTION.
    "! challan required = row in zmmge_wghflg_t01 with Challanqtyflag = X
    CLASS-METHODS challan_required
      IMPORTING iv_series     TYPE zmmge_wghflg_t01-gateentryseries
                iv_matgrp     TYPE zmmge_wghflg_t01-materialgroup
      RETURNING VALUE(rv_req) TYPE abap_bool.
ENDCLASS.

CLASS lcl_wflag IMPLEMENTATION.
  METHOD challan_required.
    SELECT SINGLE challanqtyflag FROM zmmge_wghflg_t01
      WHERE gateentryseries = @iv_series
        AND materialgroup   = @iv_matgrp
      INTO @DATA(lv_flag).
    rv_req = xsdbool( sy-subrc = 0 AND lv_flag = abap_true ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_subgate DEFINITION FINAL.
  PUBLIC SECTION.
    "! G2: sub gate entry = gate entry no + letter per DISTINCT challan no
    "! (A, B, ... K in order of first use). Same challan on several PO items
    "! = same letter. The item gets the sub gate of its first challan.
    CLASS-METHODS assign
      IMPORTING iv_uuid        TYPE sysuuid_x16
                iv_is_draft    TYPE abp_behv_flag
                iv_series      TYPE zmmge_hdr_t01-gateentryseries
                iv_gateentryno TYPE zmmge_hdr_t01-gateentryno.
ENDCLASS.

CLASS lcl_subgate IMPLEMENTATION.
  METHOD assign.
    DATA lt_upd_ch   TYPE TABLE FOR UPDATE zmmge_app2_re\\GateChallan.
    DATA lt_upd_item TYPE TABLE FOR UPDATE zmmge_app2_re\\GateItem.
    DATA lt_seen     TYPE STANDARD TABLE OF zmmge_chln_t01-challanno WITH EMPTY KEY.

    CHECK iv_series = 'G2' AND iv_gateentryno IS NOT INITIAL.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateHead BY \_Item
        FIELDS ( Purchaseorder Purchaseorderitem Subgateentryno )
        WITH VALUE #( ( %is_draft = iv_is_draft Uuid = iv_uuid ) )
      RESULT DATA(lt_items).
    CHECK lt_items IS NOT INITIAL.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem BY \_Challan
        FIELDS ( Purchaseorder Purchaseorderitem Challanno Subgateentryno Createdat )
        WITH CORRESPONDING #( lt_items )
      RESULT DATA(lt_chall).

    SORT lt_chall BY Createdat Chlnuuid.
    LOOP AT lt_chall INTO DATA(ls_c) WHERE Challanno IS NOT INITIAL.
      IF NOT line_exists( lt_seen[ table_line = ls_c-Challanno ] ).
        APPEND ls_c-Challanno TO lt_seen.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_chall INTO ls_c.
      DATA(lv_idx) = line_index( lt_seen[ table_line = ls_c-Challanno ] ).
      DATA(lv_sub) = VALUE zmmge_chln_t01-subgateentryno( ).
      IF lv_idx BETWEEN 1 AND 11.
        lv_sub = |{ iv_gateentryno }-{ substring( val = `ABCDEFGHIJK` off = lv_idx - 1 len = 1 ) }|.
      ENDIF.
      IF lv_sub <> ls_c-Subgateentryno.
        APPEND VALUE #( %tky = ls_c-%tky Subgateentryno = lv_sub ) TO lt_upd_ch.
      ENDIF.
      " item: sub gate of its first challan (the item field is still read
      " by the other apps)
      READ TABLE lt_items INTO DATA(ls_it)
           WITH KEY Purchaseorder = ls_c-Purchaseorder Purchaseorderitem = ls_c-Purchaseorderitem.
      IF sy-subrc = 0 AND NOT line_exists( lt_upd_item[ Purchaseorder     = ls_c-Purchaseorder
                                                        Purchaseorderitem = ls_c-Purchaseorderitem ] ).
        APPEND VALUE #( %tky = ls_it-%tky Subgateentryno = lv_sub ) TO lt_upd_item.
      ENDIF.
    ENDLOOP.
    DELETE lt_upd_item WHERE Subgateentryno IS INITIAL.

    MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateChallan UPDATE FIELDS ( Subgateentryno ) WITH lt_upd_ch
      ENTITY GateItem    UPDATE FIELDS ( Subgateentryno ) WITH lt_upd_item.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_chtotal DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_item_keys TYPE TABLE FOR READ IMPORT zmmge_app2_re\\GateItem.
    "! item challan fields = totals of the item's challan lines
    "! (qty and weights summed; no/date/transport/LR/document from the
    "! first challan) - read by Weight, slips, Unloading, Gate Exit
    CLASS-METHODS recalc
      IMPORTING it_items TYPE tt_item_keys.
ENDCLASS.

CLASS lcl_chtotal IMPLEMENTATION.
  METHOD recalc.
    DATA lt_upd TYPE TABLE FOR UPDATE zmmge_app2_re\\GateItem.

    CHECK it_items IS NOT INITIAL.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Challanqty Chqtyunit Challantareweight Challangrossweight Challannetweight Chbaseunit
                 Challanno Challandate Trasporterid Lrno Lrdate Chdocumt Weightindicator )
        WITH CORRESPONDING #( it_items )
      RESULT DATA(lt_item)
      ENTITY GateItem BY \_Challan
        FIELDS ( Uuid Purchaseorder Purchaseorderitem Challanqty Chqtyunit Challantareweight
                 Challangrossweight Challannetweight Chbaseunit Challanno Challandate
                 Trasporterid Lrno Lrdate Chdocumt Createdat )
        WITH CORRESPONDING #( it_items )
      RESULT DATA(lt_ch).

    SORT lt_ch BY Createdat Chlnuuid.

    LOOP AT lt_item INTO DATA(ls_item).
      " weighed: Weight Recording owns Challan Qty / GR qty from now on
      IF ls_item-Weightindicator = abap_true.
        CONTINUE.
      ENDIF.
      DATA(ls_new) = ls_item.
      CLEAR: ls_new-Challanqty, ls_new-Challantareweight, ls_new-Challangrossweight,
             ls_new-Challannetweight, ls_new-Challanno, ls_new-Challandate,
             ls_new-Trasporterid, ls_new-Lrno, ls_new-Lrdate, ls_new-Chdocumt.
      DATA(lv_first) = abap_true.

      LOOP AT lt_ch INTO DATA(ls_ch)
           WHERE %is_draft         = ls_item-%is_draft
             AND Uuid              = ls_item-Uuid
             AND Purchaseorder     = ls_item-Purchaseorder
             AND Purchaseorderitem = ls_item-Purchaseorderitem.
        ls_new-Challanqty         = ls_new-Challanqty         + ls_ch-Challanqty.
        ls_new-Challantareweight  = ls_new-Challantareweight  + ls_ch-Challantareweight.
        ls_new-Challangrossweight = ls_new-Challangrossweight + ls_ch-Challangrossweight.
        ls_new-Challannetweight   = ls_new-Challannetweight   + ls_ch-Challannetweight.
        IF lv_first = abap_true.
          ls_new-Chqtyunit    = ls_ch-Chqtyunit.
          ls_new-Chbaseunit   = ls_ch-Chbaseunit.
          ls_new-Challanno    = ls_ch-Challanno.
          ls_new-Challandate  = ls_ch-Challandate.
          ls_new-Trasporterid = ls_ch-Trasporterid.
          ls_new-Lrno         = ls_ch-Lrno.
          ls_new-Lrdate       = ls_ch-Lrdate.
          ls_new-Chdocumt     = ls_ch-Chdocumt.
          lv_first = abap_false.
        ENDIF.
      ENDLOOP.

      IF ls_new <> ls_item.
        APPEND VALUE #( %tky               = ls_item-%tky
                        Challanqty         = ls_new-Challanqty
                        Chqtyunit          = ls_new-Chqtyunit
                        Challantareweight  = ls_new-Challantareweight
                        Challangrossweight = ls_new-Challangrossweight
                        Challannetweight   = ls_new-Challannetweight
                        Chbaseunit         = ls_new-Chbaseunit
                        Challanno          = ls_new-Challanno
                        Challandate        = ls_new-Challandate
                        Trasporterid       = ls_new-Trasporterid
                        Lrno               = ls_new-Lrno
                        Lrdate             = ls_new-Lrdate
                        Chdocumt           = ls_new-Chdocumt ) TO lt_upd.
      ENDIF.
    ENDLOOP.

    CHECK lt_upd IS NOT INITIAL.
    MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
        UPDATE FIELDS ( Challanqty Chqtyunit Challantareweight Challangrossweight Challannetweight
                        Chbaseunit Challanno Challandate Trasporterid Lrno Lrdate Chdocumt )
        WITH lt_upd.
  ENDMETHOD.
ENDCLASS.

CLASS lsc_zmmge_app2_re DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zmmge_app2_re IMPLEMENTATION.

  METHOD save_modified.
    " nothing extra to write - kept because the BDEF declares
    " 'with additional save'
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

    METHODS long_msg
      IMPORTING severity      TYPE if_abap_behv_message=>t_severity
                text          TYPE string
      RETURNING VALUE(result) TYPE REF TO if_abap_behv_message.

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
                      %update              = COND #( WHEN lv_checked_in = abap_true
                                                     THEN if_abap_behv=>fc-o-disabled
                                                     ELSE if_abap_behv=>fc-o-enabled )
                      %delete              = COND #( WHEN lv_checked_in = abap_true
                                                     THEN if_abap_behv=>fc-o-disabled
                                                     ELSE if_abap_behv=>fc-o-enabled )
                      %action-Edit         = COND #( WHEN lv_checked_in = abap_true
                                                     THEN if_abap_behv=>fc-o-disabled
                                                     ELSE if_abap_behv=>fc-o-enabled )
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

      " G1/G2: PO lines whose material group is flagged need a challan
      " before check-in (user 2026-11-25)
      IF <fs_head>-Gateentryseries = 'G1' OR <fs_head>-Gateentryseries = 'G2'.
        READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
          ENTITY GateHead BY \_Item
            FIELDS ( Uuid Purchaseorder Purchaseorderitem Materialgroup )
            WITH VALUE #( ( %tky = <fs_head>-%tky ) )
          RESULT DATA(lt_ciitem).

        READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
          ENTITY GateItem BY \_Challan
            FIELDS ( Uuid Purchaseorder Purchaseorderitem )
            WITH CORRESPONDING #( lt_ciitem )
          RESULT DATA(lt_cich).

        DATA(lv_missing) = ``.
        LOOP AT lt_ciitem INTO DATA(ls_ci).
          IF lcl_wflag=>challan_required( iv_series = <fs_head>-Gateentryseries
                                          iv_matgrp = ls_ci-Materialgroup ) = abap_true
             AND NOT line_exists( lt_cich[ Purchaseorder     = ls_ci-Purchaseorder
                                           Purchaseorderitem = ls_ci-Purchaseorderitem ] ).
            lv_missing = |{ lv_missing } { ls_ci-Purchaseorder }/{ CONV i( ls_ci-Purchaseorderitem ) }|.
          ENDIF.
        ENDLOOP.

        IF lv_missing IS NOT INITIAL.
          APPEND VALUE #( %tky = <fs_head>-%tky ) TO failed-gatehead.
          APPEND VALUE #( %tky = <fs_head>-%tky
                          %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                           text     = |Gate CheckIn not possible - challan required for PO{ lv_missing }| ) )
                 TO reported-gatehead.
          CONTINUE.
        ENDIF.
      ENDIF.

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

      " G2: challans entered before check-in get their sub gate now
      lcl_subgate=>assign( iv_uuid        = <fs_head>-Uuid
                           iv_is_draft    = <fs_head>-%is_draft
                           iv_series      = <fs_head>-Gateentryseries
                           iv_gateentryno = gateno ).
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
    DATA(lv_carrier) = CONV zmmge_carrier_id( |{ condense( CONV string( gs_keys-%param-Carrier ) ) ALPHA = IN WIDTH = 10 }| ).
    GET TIME STAMP FIELD DATA(lv_ts).
    CONVERT TIME STAMP lv_ts TIME ZONE 'INDIA' INTO DATE DATA(lv_today).

    " PO is mandatory; G1: PO item too (carrier is checked per item below)
    IF lv_po IS INITIAL.
      APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
      APPEND VALUE #( %tky = ls_header-%tky
                      %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                       text     = |Enter the purchase order| ) ) TO reported-gatehead.
    ELSEIF ls_header-Gateentryseries = 'G1' AND lv_poitem IS INITIAL.
      APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
      APPEND VALUE #( %tky = ls_header-%tky
                      %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                       text     = |Enter the PO item for PO { lv_po }| ) ) TO reported-gatehead.
    ENDIF.

    " check the items of this instance (draft or active), so a PO item
    " added earlier in the same draft is found too
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
                      %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                       text     = |PO { lv_po } item { lv_poitem } is already on this gate entry| ) )
             TO reported-gatehead.
    ENDIF.

    IF ls_response-success = abap_true AND ls_response-poitems IS NOT INITIAL.
      " G1 (raw material): freight order from the S/4 carrier allocation
      " valid TODAY for PO item + carrier entered in the popup.
      "   incoterms FOR       -> no FO, carrier not needed
      "   carrier empty       -> error
      "   no FO valid today   -> error, item NOT added
      " Other series: no freight order, no S/4 TM call.
      LOOP AT gt_head INTO DATA(gs_head).
        APPEND VALUE #( %tky = gs_head-%tky ) TO lt_cba ASSIGNING FIELD-SYMBOL(<ls_cba>).

        LOOP AT ls_response-poitems INTO DATA(ls_po).
          DATA(ls_fo) = VALUE zcl_mm_s4_tmfo=>ty_fo( ).
          DATA(lv_poref) = |PO { ls_po-purchaseorder }/{ CONV i( ls_po-purchaseorderitem ) }|.

          IF gs_head-Gateentryseries = 'G1' AND ls_po-incotermsclassification <> 'FOR'.
            IF lv_carrier IS INITIAL.
              APPEND VALUE #( %tky = gs_head-%tky ) TO failed-gatehead.
              APPEND VALUE #( %tky = gs_head-%tky
                              %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                               text     = |{ lv_poref }: enter the carrier| ) ) TO reported-gatehead.
              CONTINUE.
            ENDIF.
            TRY.
                DATA(lt_valid) = zcl_mm_s4_tmfo=>get_valid( iv_po   = CONV #( ls_po-purchaseorder )
                                                            iv_item = CONV #( ls_po-purchaseorderitem )
                                                            iv_date = lv_today ).
                ls_fo = VALUE #( lt_valid[ carrier = lv_carrier ] OPTIONAL ).
              CATCH cx_root INTO DATA(lx_fo) ##CATCH_ALL.
                APPEND VALUE #( %tky = gs_head-%tky ) TO failed-gatehead.
                APPEND VALUE #( %tky = gs_head-%tky
                                %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                                 text     = |{ lv_poref }: allocation check in S/4 failed: { lx_fo->get_text( ) }| ) ) TO reported-gatehead.
                CONTINUE.
            ENDTRY.
            IF ls_fo-freightorder IS INITIAL.
              APPEND VALUE #( %tky = gs_head-%tky ) TO failed-gatehead.
              APPEND VALUE #( %tky = gs_head-%tky
                              %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                               text     = |{ lv_poref }: no allocation for carrier { lv_carrier ALPHA = OUT } valid today - item not added| ) ) TO reported-gatehead.
              CONTINUE.
            ENDIF.
          ENDIF.

          " the new items need the parent's draft indicator (else RAP dumps
          " with 'Invalid operation O')
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
                          Incoterms         = ls_po-incotermsclassification
                          Freightorder      = ls_fo-freightorder
                          Carrier           = ls_fo-carrier
                          Carriername       = ls_fo-carriername ) TO <ls_cba>-%target.
        ENDLOOP.
      ENDLOOP.

      DELETE lt_cba WHERE %target IS INITIAL.
      IF lt_cba IS NOT INITIAL.
        MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
          ENTITY GateHead
          CREATE BY \_Item
          AUTO FILL CID
          FIELDS ( Uuid Purchaseorder Purchaseorderitem Vendor Suppliername Gateentryno Gateentryseries Subgateentryno
                   Material Materialtext Materialgroup Plant Plantname Baseunit Quantity
                   Poordertype Poordertypetext Orderdate Incoterms Freightorder Carrier Carriername )
          WITH lt_cba
          MAPPED mapped
          FAILED DATA(lt_failed_cba)
          REPORTED DATA(lt_reported_cba).
        APPEND LINES OF lt_failed_cba-gatehead   TO failed-gatehead.
        APPEND LINES OF lt_failed_cba-gateitem   TO failed-gateitem.
        APPEND LINES OF lt_reported_cba-gatehead TO reported-gatehead.
        APPEND LINES OF lt_reported_cba-gateitem TO reported-gateitem.
      ENDIF.
    ELSEIF ls_response-message IS NOT INITIAL.
      APPEND VALUE #( %tky = ls_header-%tky ) TO failed-gatehead.
      APPEND VALUE #( %tky = ls_header-%tky
                      %msg = long_msg( severity = if_abap_behv_message=>severity-error
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

    " per PO item + carrier
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
      " over-receipt check (carrier quantity from S/4)
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
                            %msg = long_msg( severity = if_abap_behv_message=>severity-error
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
                            %msg = long_msg( severity = if_abap_behv_message=>severity-error
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
                        %msg = long_msg( severity = if_abap_behv_message=>severity-error
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
                      %msg = long_msg( severity = if_abap_behv_message=>severity-success
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
                          %msg = long_msg( severity = if_abap_behv_message=>severity-error
                                           text     = |Slip data: { lx_fdp->get_text( ) }| ) )
                 TO reported-gatehead.
          CONTINUE.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_res-%tky ) TO failed-gatehead.
          APPEND VALUE #( %tky = ls_res-%tky
                          %msg = long_msg( severity = if_abap_behv_message=>severity-error
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
                      %msg = long_msg( severity = if_abap_behv_message=>severity-success
                                       text     = |Gate entry slip created for { ls_res-Gateentryno }| ) )
             TO reported-gatehead.

    ENDLOOP.

    result = VALUE #( FOR ls_r IN lt_result ( %tky = ls_r-%tky %param = ls_r ) ).
  ENDMETHOD.

  METHOD long_msg.
    " new_message_with_text cuts after 50 characters: split the text
    " over the 4 variables of ZMM_GATE_MSG 001 (&1&2&3&4)
    DATA lt_v TYPE STANDARD TABLE OF symsgv WITH EMPTY KEY.
    DATA(lv_rest) = text.
    WHILE lv_rest IS NOT INITIAL AND lines( lt_v ) < 4.
      DATA(lv_len) = nmin( val1 = 50 val2 = strlen( lv_rest ) ).
      WHILE lv_len > 1 AND substring( val = lv_rest off = lv_len - 1 len = 1 ) = ` `.
        lv_len = lv_len - 1.
      ENDWHILE.
      APPEND substring( val = lv_rest len = lv_len ) TO lt_v.
      lv_rest = substring( val = lv_rest off = lv_len ).
    ENDWHILE.
    result = new_message( id       = 'ZMM_GATE_MSG'
                          number   = '001'
                          severity = severity
                          v1       = VALUE #( lt_v[ 1 ] OPTIONAL )
                          v2       = VALUE #( lt_v[ 2 ] OPTIONAL )
                          v3       = VALUE #( lt_v[ 3 ] OPTIONAL )
                          v4       = VALUE #( lt_v[ 4 ] OPTIONAL ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_GateItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR GateItem RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR GateItem RESULT result.

    METHODS InbDelivery FOR MODIFY
      IMPORTING keys FOR ACTION GateItem~InbDelivery RESULT result.

    METHODS fillCarrier FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GateItem~fillCarrier.

    METHODS sumChallans FOR DETERMINE ON SAVE
      IMPORTING keys FOR GateItem~sumChallans.

    METHODS checkFreightOrder FOR VALIDATE ON SAVE
      IMPORTING keys FOR GateItem~checkFreightOrder.

    METHODS checkG1Item FOR VALIDATE ON SAVE
      IMPORTING keys FOR GateItem~checkG1Item.

    METHODS long_msg
      IMPORTING iv_text       TYPE string
                iv_severity   TYPE if_abap_behv_message=>t_severity
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.

ENDCLASS.

CLASS lhc_GateItem IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Inbounddelivery ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item)
      ENTITY GateItem BY \_Head
        FIELDS ( Gateentryno ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
        LINK DATA(lt_link).

    LOOP AT lt_item INTO DATA(ls_item).
      " head checked in (Gate Entry No given) -> no more changes on the line
      DATA(lv_locked) = abap_false.
      READ TABLE lt_link INTO DATA(ls_link) WITH KEY source-%tky = ls_item-%tky.
      IF sy-subrc = 0.
        READ TABLE lt_head INTO DATA(ls_head) WITH KEY %tky = ls_link-target-%tky.
        IF sy-subrc = 0 AND ls_head-Gateentryno IS NOT INITIAL.
          lv_locked = abap_true.
        ENDIF.
      ENDIF.

      DATA(lv_lock) = COND #( WHEN lv_locked = abap_true
                              THEN if_abap_behv=>fc-o-disabled
                              ELSE if_abap_behv=>fc-o-enabled ).

      " InbDelivery: only on a saved gate entry, and only once per item
      APPEND VALUE #( %tky                = ls_item-%tky
                      %update             = lv_lock
                      %delete             = lv_lock
                      %assoc-_Challan     = lv_lock
                      %action-InbDelivery = COND #( WHEN ls_item-%is_draft = if_abap_behv=>mk-on
                                                      OR ls_item-Inbounddelivery IS NOT INITIAL
                                                    THEN if_abap_behv=>fc-o-disabled
                                                    ELSE if_abap_behv=>fc-o-enabled ) ) TO result.
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

  METHOD sumChallans.
    " on Save (Prepare, always): totals of the challan lines on the PO
    " line - catches deleted challans too
    lcl_chtotal=>recalc( CORRESPONDING #( keys ) ).
  ENDMETHOD.

  METHOD checkFreightOrder.
    " freight order is mandatory for raw material gate entries (series G1,
    " not for incoterms FOR) and must be maintained in S/4 for this PO
    " item and valid on the gate entry date
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Purchaseorder Purchaseorderitem Freightorder Incoterms )
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

      IF ls_headrow-Gateentryseries <> 'G1' OR ls_item-Incoterms = 'FOR'.
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

  METHOD checkG1Item.
    " G1: flagged PO line -> at least one challan, qty unit TO/KG
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem BY \_Head
        FIELDS ( Gateentryseries ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem
        FIELDS ( Uuid Purchaseorder Purchaseorderitem Materialgroup Chqtyunit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_all).

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateItem BY \_Challan
        FIELDS ( Uuid Purchaseorder Purchaseorderitem ) WITH CORRESPONDING #( lt_all )
      RESULT DATA(lt_ch).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_hkey) = VALUE #( lt_link[ source-%tky = ls_key-%tky ]-target OPTIONAL ).
      DATA(ls_head) = VALUE #( lt_head[ %tky = ls_hkey-%tky ] OPTIONAL ).
      DATA(ls_item) = VALUE #( lt_all[ %tky = ls_key-%tky ] OPTIONAL ).

      " clears an old message of this check
      APPEND VALUE #( %tky        = ls_key-%tky
                      %state_area = 'CHECK_G1'
                      %path       = VALUE #( gatehead-%tky = ls_hkey-%tky ) ) TO reported-gateitem.

      IF ls_head-Gateentryseries <> 'G1' OR ls_item IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_po)   = |PO { ls_item-Purchaseorder }/{ CONV i( ls_item-Purchaseorderitem ) }|.
      DATA(lv_text) = ``.

      " challan required -> checked at Gate CheckIn (user 2026-11-25);
      " here only: a flagged line's challan qty must be weighable
      IF lcl_wflag=>challan_required( iv_series = ls_head-Gateentryseries
                                      iv_matgrp = ls_item-Materialgroup ) = abap_true
         AND line_exists( lt_ch[ %is_draft         = ls_item-%is_draft
                                 Uuid              = ls_item-Uuid
                                 Purchaseorder     = ls_item-Purchaseorder
                                 Purchaseorderitem = ls_item-Purchaseorderitem ] )
         AND ls_item-Chqtyunit <> 'TO' AND ls_item-Chqtyunit <> 'MT' AND ls_item-Chqtyunit <> 'KG'.
        lv_text = |{ lv_po }: challan qty unit { ls_item-Chqtyunit } can't be weighed - TO, MT or KG needed|.
      ENDIF.

      IF lv_text IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-gateitem.
        APPEND VALUE #( %tky        = ls_key-%tky
                        %state_area = 'CHECK_G1'
                        %path       = VALUE #( gatehead-%tky = ls_hkey-%tky )
                        %msg        = long_msg( iv_text     = lv_text
                                                iv_severity = if_abap_behv_message=>severity-error ) )
               TO reported-gateitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD long_msg.
    DATA lv_text TYPE c LENGTH 200.
    lv_text = iv_text.
    ro_msg = new_message( id       = 'ZMM_GATE_MSG'
                          number   = '001'
                          severity = iv_severity
                          v1       = lv_text(50)
                          v2       = lv_text+50(50)
                          v3       = lv_text+100(50)
                          v4       = lv_text+150(50) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_GateChallan DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS fillChallan FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GateChallan~fillChallan.
    METHODS totalToItem FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GateChallan~totalToItem.
    METHODS setSubGate FOR DETERMINE ON SAVE
      IMPORTING keys FOR GateChallan~setSubGate.
    METHODS checkChallan FOR VALIDATE ON SAVE
      IMPORTING keys FOR GateChallan~checkChallan.
ENDCLASS.

CLASS lhc_GateChallan IMPLEMENTATION.

  METHOD fillChallan.
    " Net Wt = Gross - Tare; Challan Qty unit = PO unit of the item
    DATA lt_upd TYPE TABLE FOR UPDATE zmmge_app2_re\\GateChallan.

    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateChallan
        FIELDS ( Challangrossweight Challantareweight Challannetweight Chqtyunit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ch)
      ENTITY GateChallan BY \_Item
        FIELDS ( Baseunit ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      LINK DATA(lt_link).

    LOOP AT lt_ch INTO DATA(ls_ch).
      DATA(lv_net)  = ls_ch-Challannetweight.
      DATA(lv_unit) = ls_ch-Chqtyunit.
      IF ls_ch-Challangrossweight IS NOT INITIAL.
        lv_net = ls_ch-Challangrossweight - ls_ch-Challantareweight.
      ENDIF.
      DATA(ls_lnk) = VALUE #( lt_link[ source-%tky = ls_ch-%tky ] OPTIONAL ).
      DATA(ls_itm) = VALUE #( lt_item[ %tky = ls_lnk-target-%tky ] OPTIONAL ).
      IF ls_itm-Baseunit IS NOT INITIAL.
        lv_unit = ls_itm-Baseunit.
      ENDIF.
      IF lv_net <> ls_ch-Challannetweight OR lv_unit <> ls_ch-Chqtyunit.
        APPEND VALUE #( %tky             = ls_ch-%tky
                        Challannetweight = lv_net
                        Chqtyunit        = lv_unit
                        %control         = VALUE #( Challannetweight = if_abap_behv=>mk-on
                                                    Chqtyunit        = if_abap_behv=>mk-on ) ) TO lt_upd.
      ENDIF.
    ENDLOOP.

    CHECK lt_upd IS NOT INITIAL.
    MODIFY ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateChallan UPDATE FROM lt_upd.
  ENDMETHOD.

  METHOD totalToItem.
    " live: the changed challans' PO lines get the new totals
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateChallan BY \_Item
        FIELDS ( Uuid ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).
    lcl_chtotal=>recalc( CORRESPONDING #( lt_item ) ).
  ENDMETHOD.

  METHOD setSubGate.
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateChallan BY \_Head
        FIELDS ( Gateentryno Gateentryseries ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).
    SORT lt_head BY Uuid.
    DELETE ADJACENT DUPLICATES FROM lt_head COMPARING Uuid.

    LOOP AT lt_head INTO DATA(ls_head).
      lcl_subgate=>assign( iv_uuid        = ls_head-Uuid
                           iv_is_draft    = ls_head-%is_draft
                           iv_series      = ls_head-Gateentryseries
                           iv_gateentryno = ls_head-Gateentryno ).
    ENDLOOP.
  ENDMETHOD.

  METHOD checkChallan.
    " Challan No/Date/Qty filled, qty > 0, date not after the gate entry
    " date, same supplier + challan no not on another gate entry
    READ ENTITIES OF zmmge_app2_re IN LOCAL MODE
      ENTITY GateChallan
        FIELDS ( Uuid Purchaseorder Purchaseorderitem Challanno Challandate Challanqty )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ch)
      ENTITY GateChallan BY \_Head
        FIELDS ( Gateentrydate ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_hlink)
      ENTITY GateChallan BY \_Item
        FIELDS ( Vendor ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      LINK DATA(lt_ilink).

    LOOP AT lt_ch INTO DATA(ls_ch).
      " path challan -> item -> head, so Fiori shows the message on the line
      DATA(ls_path) = VALUE #( reported-gatechallan[ 1 ]-%path OPTIONAL ).
      ls_path = VALUE #( gatehead-%is_draft         = ls_ch-%is_draft
                         gatehead-Uuid              = ls_ch-Uuid
                         gateitem-%is_draft         = ls_ch-%is_draft
                         gateitem-Uuid              = ls_ch-Uuid
                         gateitem-Purchaseorder     = ls_ch-Purchaseorder
                         gateitem-Purchaseorderitem = ls_ch-Purchaseorderitem ).

      " clears an old message of this check
      APPEND VALUE #( %tky = ls_ch-%tky %state_area = 'CHECK_CHLN' %path = ls_path ) TO reported-gatechallan.

      DATA(ls_hk)   = VALUE #( lt_hlink[ source-%tky = ls_ch-%tky ]-target OPTIONAL ).
      DATA(ls_head) = VALUE #( lt_head[ %tky = ls_hk-%tky ] OPTIONAL ).
      DATA(ls_ik)   = VALUE #( lt_ilink[ source-%tky = ls_ch-%tky ]-target OPTIONAL ).
      DATA(ls_item) = VALUE #( lt_item[ %tky = ls_ik-%tky ] OPTIONAL ).

      DATA(lv_text) = ``.
      IF ls_ch-Challanno IS INITIAL OR ls_ch-Challandate IS INITIAL OR ls_ch-Challanqty <= 0.
        lv_text = |Challan: enter Challan No, Date and Qty|.
      ELSEIF ls_head-Gateentrydate IS NOT INITIAL AND ls_ch-Challandate > ls_head-Gateentrydate.
        lv_text = |Challan { ls_ch-Challanno }: date is after the gate entry date|.
      ELSE.
        " same supplier + challan no on ANOTHER gate entry
        SELECT SINGLE h~gateentryno
          FROM zmmge_chln_t01 AS c
          INNER JOIN zmmge_itm_t01 AS i ON  i~uuid              = c~uuid
                                        AND i~purchaseorder     = c~purchaseorder
                                        AND i~purchaseorderitem = c~purchaseorderitem
          INNER JOIN zmmge_hdr_t01 AS h ON h~uuid = c~uuid
          WHERE c~challanno = @ls_ch-Challanno
            AND i~vendor    = @ls_item-Vendor
            AND c~uuid     <> @ls_ch-Uuid
          INTO @DATA(lv_other).
        IF sy-subrc = 0.
          lv_text = |Challan { ls_ch-Challanno } already used on gate entry { lv_other }|.
        ENDIF.
      ENDIF.

      IF lv_text IS NOT INITIAL.
        DATA lv_t TYPE c LENGTH 100.
        lv_t = lv_text.
        APPEND VALUE #( %tky = ls_ch-%tky ) TO failed-gatechallan.
        APPEND VALUE #( %tky        = ls_ch-%tky
                        %state_area = 'CHECK_CHLN'
                        %path       = ls_path
                        %msg        = new_message( id       = 'ZMM_GATE_MSG'
                                                   number   = '001'
                                                   severity = if_abap_behv_message=>severity-error
                                                   v1       = lv_t(50)
                                                   v2       = lv_t+50(50) )
                        %element-Challanno   = if_abap_behv=>mk-on
                        %element-Challandate = if_abap_behv=>mk-on
                        %element-Challanqty  = if_abap_behv=>mk-on ) TO reported-gatechallan.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
