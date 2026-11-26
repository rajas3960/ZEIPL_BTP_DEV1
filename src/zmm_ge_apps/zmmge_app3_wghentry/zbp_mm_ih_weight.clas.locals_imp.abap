CLASS lcl_g1 DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_items TYPE TABLE FOR READ RESULT zmm_ih_weight\\WeightItem.

    "! challan qty flag set for series + material group
    CLASS-METHODS flagged
      IMPORTING iv_series      TYPE zmmge_wghflg_t01-gateentryseries
                iv_matgrp      TYPE zmmge_wghflg_t01-materialgroup
      RETURNING VALUE(rv_flag) TYPE abap_bool.

    CLASS-METHODS to_ton
      IMPORTING iv_qty        TYPE numeric
                iv_unit       TYPE clike
      RETURNING VALUE(rv_ton) TYPE decfloat34.

    CLASS-METHODS from_ton
      IMPORTING iv_ton        TYPE numeric
                iv_unit       TYPE clike
      RETURNING VALUE(rv_qty) TYPE decfloat34.

    "! split check of a weighed G1 gate entry; empty = OK
    CLASS-METHODS check
      IMPORTING it_items       TYPE tt_items
                iv_series      TYPE zmmge_wghflg_t01-gateentryseries
                iv_net         TYPE numeric
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS lcl_g1 IMPLEMENTATION.
  METHOD flagged.
    SELECT SINGLE challanqtyflag FROM zmmge_wghflg_t01 WITH PRIVILEGED ACCESS
      WHERE gateentryseries = @iv_series
        AND materialgroup   = @iv_matgrp
      INTO @DATA(lv_flag).
    rv_flag = xsdbool( sy-subrc = 0 AND lv_flag = abap_true ).
  ENDMETHOD.

  METHOD to_ton.
    rv_ton = COND #( WHEN iv_unit = 'KG' THEN iv_qty / 1000 ELSE iv_qty ).
  ENDMETHOD.

  METHOD from_ton.
    rv_qty = COND #( WHEN iv_unit = 'KG' THEN iv_ton * 1000 ELSE iv_ton ).
  ENDMETHOD.

  METHOD check.
    DATA(lv_flagsum) = CONV decfloat34( 0 ).
    DATA(lv_unflsum) = CONV decfloat34( 0 ).
    DATA(lv_n)       = 0.

    LOOP AT it_items INTO DATA(ls_item).
      IF flagged( iv_series = iv_series iv_matgrp = ls_item-Materialgroup ) = abap_true.
        lv_flagsum = lv_flagsum + to_ton( iv_qty = ls_item-Challanqty iv_unit = ls_item-Baseunit ).
      ELSE.
        lv_n       = lv_n + 1.
        lv_unflsum = lv_unflsum + to_ton( iv_qty = ls_item-Grnqty iv_unit = ls_item-Baseunit ).
      ENDIF.
    ENDLOOP.

    DATA(lv_net) = CONV decfloat34( iv_net ).
    DATA(lv_rem) = lv_net - lv_flagsum.
    " net below challan qty is allowed for now (user 2026-11-25) - but lines
    " without challan then get nothing, which S/4 can't post
    IF lv_n > 0 AND lv_rem <= 0.
      rv_text = |No weight left for the { lv_n } PO line(s) without challan - truck net { lv_net } TO, challan { lv_flagsum } TO|.
    ELSEIF lv_n > 0 AND lv_unflsum > lv_rem.
      rv_text = |GR qty of PO lines without challan ({ lv_unflsum } TO) exceeds the remainder { lv_rem } TO|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_weighbridge DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS c_api_key TYPE string VALUE 'enviro-1-15sep-2026-wb1-mm'.

    TYPES ty_weight TYPE zmmge_hdr_t01-grosswt.
    TYPES ty_mcno   TYPE c LENGTH 10.
    TYPES ty_mcndes TYPE c LENGTH 60.

    TYPES: BEGIN OF ty_reading,
             ok      TYPE abap_bool,
             weight  TYPE ty_weight,
             mcno    TYPE ty_mcno,
             mcndes  TYPE ty_mcndes,
             message TYPE string,
           END OF ty_reading.

    "! GET <machine URL>/weight  (no longer used by the Fetch actions since
    "! 2026-10-28: CamView posts the weight to ZMM_WB_WEIGHT instead)
    CLASS-METHODS read_weight
      IMPORTING iv_mcno           TYPE clike
      RETURNING VALUE(rs_reading) TYPE ty_reading.

    TYPES: BEGIN OF ty_launch,
             ok      TYPE abap_bool,
             seqno   TYPE c LENGTH 20,
             message TYPE string,
           END OF ty_launch.

    "! POST <machine URL>/launch - starts the camera. The seqno sent is
    "! the CamView rowid_seq the verification app reads the images with.
    CLASS-METHODS launch_camera
      IMPORTING iv_mcno          TYPE clike
      RETURNING VALUE(rs_launch) TYPE ty_launch.

    CLASS-METHODS machine_text
      IMPORTING iv_mcno        TYPE clike
      RETURNING VALUE(rv_text) TYPE ty_mcndes.

    CLASS-METHODS now
      EXPORTING ev_date TYPE d
                ev_time TYPE t.

  PRIVATE SECTION.
    CLASS-METHODS base_url
      IMPORTING iv_mcno       TYPE clike
      RETURNING VALUE(rv_url) TYPE string.

    "! 2 digits that make the seqno unique across weighbridges
    CLASS-METHODS machine_code
      IMPORTING iv_mcno        TYPE clike
      RETURNING VALUE(rv_code) TYPE string.
ENDCLASS.

CLASS lcl_weighbridge IMPLEMENTATION.

  METHOD base_url.
    DATA lv_mcno TYPE ty_mcno.
    lv_mcno = iv_mcno.
    CONDENSE lv_mcno.
    CASE lv_mcno.
      WHEN 'WB-2'.   rv_url = 'http://15.207.178.30:6020'.
      WHEN 'WB-7'.   rv_url = 'http://15.207.178.30:6070'.
      WHEN 'WB-8.1'. rv_url = 'http://15.207.178.30:6081'.
      WHEN 'WB-8.2'. rv_url = 'http://15.207.178.30:6082'.
      WHEN 'WB-8.3'. rv_url = 'http://15.207.178.30:6083'.
      WHEN 'WB-10'.  rv_url = 'http://15.207.178.30:6100'.
    ENDCASE.
  ENDMETHOD.

  METHOD machine_code.
    DATA lv_mcno TYPE ty_mcno.
    lv_mcno = iv_mcno.
    CONDENSE lv_mcno.
    CASE lv_mcno.
      WHEN 'WB-2'.   rv_code = '02'.
      WHEN 'WB-7'.   rv_code = '07'.
      WHEN 'WB-8.1'. rv_code = '81'.
      WHEN 'WB-8.2'. rv_code = '82'.
      WHEN 'WB-8.3'. rv_code = '83'.
      WHEN 'WB-10'.  rv_code = '10'.
    ENDCASE.
  ENDMETHOD.

  METHOD machine_text.
    SELECT SINGLE text FROM zmm_weighment_vh
      WHERE value_low = @iv_mcno
        AND language  = 'E'
      INTO @rv_text.
  ENDMETHOD.

  METHOD now.
    GET TIME STAMP FIELD DATA(lv_ts).
    CONVERT TIME STAMP lv_ts TIME ZONE 'INDIA' INTO DATE ev_date TIME ev_time.
  ENDMETHOD.

  METHOD read_weight.
    TYPES: BEGIN OF ty_response,
             raw_value TYPE string,
             wb_no     TYPE string,
           END OF ty_response.
    DATA ls_response TYPE ty_response.

    DATA(lv_url) = base_url( iv_mcno ).
    IF lv_url IS INITIAL.
      rs_reading-message = |No weighbridge address is set up for machine { iv_mcno }|.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                            cl_http_destination_provider=>create_by_url( lv_url ) ).
        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_uri_path( i_uri_path = '/weight' ).
        lo_request->set_header_field( i_name = 'X-API-Key' i_value = c_api_key ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        DATA(ls_status)   = lo_response->get_status( ).
        IF ls_status-code <> 200.
          rs_reading-message = |Weight API error: { ls_status-code } { ls_status-reason }|.
          RETURN.
        ENDIF.

        xco_cp_json=>data->from_string( lo_response->get_text( ) )->write_to( REF #( ls_response ) ).

        " raw_value comes as \"2121210\" -> 2121210
        DATA(lv_weight) = ls_response-raw_value.
        REPLACE ALL OCCURRENCES OF `"` IN lv_weight WITH ``.
        CONDENSE lv_weight NO-GAPS.
        IF lv_weight IS INITIAL.
          rs_reading-message = |Weighbridge { iv_mcno } returned no weight|.
          RETURN.
        ENDIF.
        rs_reading-weight = lv_weight.

        " machine: the one the weighbridge reports, if it is a known value
        CONDENSE ls_response-wb_no.
        IF ls_response-wb_no IS NOT INITIAL.
          rs_reading-mcno   = |WB-{ ls_response-wb_no }|.
          rs_reading-mcndes = machine_text( rs_reading-mcno ).
        ENDIF.
        IF rs_reading-mcndes IS INITIAL.
          rs_reading-mcno   = iv_mcno.
          rs_reading-mcndes = machine_text( rs_reading-mcno ).
        ENDIF.

        rs_reading-ok = abap_true.

      CATCH cx_http_dest_provider_error INTO DATA(lx_dest).
        rs_reading-message = |Destination error: { lx_dest->get_text( ) }|.
      CATCH cx_web_http_client_error INTO DATA(lx_http).
        rs_reading-message = |HTTP error: { lx_http->get_text( ) }|.
      CATCH cx_sy_conversion_error cx_xco_runtime_exception.
        rs_reading-message = |Weighbridge { iv_mcno } returned an invalid weight|.
    ENDTRY.
  ENDMETHOD.

  METHOD launch_camera.
    DATA: BEGIN OF ls_response,
            seqno  TYPE string,
            status TYPE string,
            wb_no  TYPE string,
          END OF ls_response.

    DATA(lv_url)  = base_url( iv_mcno ).
    DATA(lv_code) = machine_code( iv_mcno ).
    IF lv_url IS INITIAL OR lv_code IS INITIAL.
      rs_launch-message = |Camera: unknown weighbridge { iv_mcno }|.
      RETURN.
    ENDIF.

    " yymmddhhmmss + machine code, e.g. 26101009300002 (CamView rowid_seq)
    now( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).
    rs_launch-seqno = |{ lv_date+2(6) }{ lv_time }{ lv_code }|.

    TRY.
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                            cl_http_destination_provider=>create_by_url( |{ lv_url }/launch| ) ).
        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'X-API-Key'    i_value = c_api_key ).
        lo_request->set_text( |\{"seqno":"{ rs_launch-seqno }"\}| ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

        " any 2xx is a start: WB-2 answers 200 "launched", WB-7 answers
        " 202 ACCEPTED (the camera then captures in the background)
        DATA(ls_status) = lo_response->get_status( ).
        IF ls_status-code < 200 OR ls_status-code > 299.
          rs_launch-message = |Camera launch error: { ls_status-code } { ls_status-reason }|.
          RETURN.
        ENDIF.

        /ui2/cl_json=>deserialize( EXPORTING json = lo_response->get_text( )
                                   CHANGING  data = ls_response ).
        DATA(lv_status) = to_lower( ls_response-status ).
        IF lv_status CS 'error' OR lv_status CS 'fail'.
          rs_launch-message = |Camera not launched: { ls_response-status }|.
          RETURN.
        ENDIF.

        rs_launch-ok = abap_true.

      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_launch-message = |Camera launch error: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Camera launch + image verification status (local helper)
* Launches the camera and, when it started, stores the seqno on the
* header for the stage (G gross = arrival / T tare = after unloading)
* with status P (pending), so the entry shows up in the Image
* Verification app. A new tare capture also clears Imagevaldindicator:
* the new images are not approved (Gate Exit waits for it again).
* gv_no_launch: set by ApplyWeight while it runs ManualFetchTWt with
* the CamView weight - that capture already happened, no new launch.
*----------------------------------------------------------------*
CLASS lcl_camera DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS: c_gross TYPE c LENGTH 1 VALUE 'G',
               c_tare  TYPE c LENGTH 1 VALUE 'T'.

    CLASS-DATA gv_no_launch TYPE abap_bool.

    CLASS-METHODS launch
      IMPORTING iv_is_draft      TYPE abp_behv_flag
                iv_uuid          TYPE sysuuid_x16
                iv_mcno          TYPE clike
                iv_stage         TYPE c
      RETURNING VALUE(rs_launch) TYPE lcl_weighbridge=>ty_launch.

    "! success when the camera started, else warning (the weight is saved anyway)
    CLASS-METHODS severity
      IMPORTING is_launch          TYPE lcl_weighbridge=>ty_launch
      RETURNING VALUE(rv_severity) TYPE if_abap_behv_message=>t_severity.
ENDCLASS.

CLASS lcl_camera IMPLEMENTATION.

  METHOD launch.
    DATA(lv_stage) = COND string( WHEN iv_stage = c_tare THEN `Tare` ELSE `Gross` ).

    rs_launch = lcl_weighbridge=>launch_camera( iv_mcno ).
    IF rs_launch-ok = abap_false.
      rs_launch-message = |{ rs_launch-message }. Use Recapture { lv_stage }.|.
      RETURN.
    ENDIF.

    IF iv_stage = c_gross.
      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Imgseqnogross Imgvrstatusgross Imgrejreason Imgstatusgrosstext Imgcritgross )
          WITH VALUE #( ( %is_draft          = iv_is_draft
                          Uuid               = iv_uuid
                          Imgseqnogross      = rs_launch-seqno
                          Imgvrstatusgross   = 'P'
                          Imgrejreason       = ''
                          Imgstatusgrosstext = 'Pending'      " CDS texts are not recalculated in the draft
                          Imgcritgross       = 2 ) ).
    ELSE.
      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Imgseqnotare Imgvrstatustare Imgrejreason Imagevaldindicator ImageValStatus
                          Imgstatustaretext Imgcrittare )
          WITH VALUE #( ( %is_draft          = iv_is_draft
                          Uuid               = iv_uuid
                          Imgseqnotare       = rs_launch-seqno
                          Imgvrstatustare    = 'P'
                          Imgrejreason       = ''
                          Imagevaldindicator = ''
                          ImageValStatus     = 'Image Validation Not Completed'
                          Imgstatustaretext  = 'Pending'
                          Imgcrittare        = 2 ) ).
    ENDIF.

    rs_launch-message = |{ lv_stage } images captured (seq { rs_launch-seqno }), sent for verification|.
  ENDMETHOD.

  METHOD severity.
    rv_severity = COND #( WHEN is_launch-ok = abap_true
                          THEN if_abap_behv_message=>severity-success
                          ELSE if_abap_behv_message=>severity-warning ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Item: tare weight (after unloading)
*----------------------------------------------------------------*
CLASS lhc_weightitem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR WeightItem RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR WeightItem RESULT result.

    METHODS AutoFetchTWt FOR MODIFY
      IMPORTING keys FOR ACTION WeightItem~AutoFetchTWt RESULT result.

    METHODS ManualFetchTWt FOR MODIFY
      IMPORTING keys FOR ACTION WeightItem~ManualFetchTWt RESULT result.

    METHODS checkGrn FOR VALIDATE ON SAVE
      IMPORTING keys FOR WeightItem~checkGrn.

    METHODS long_msg
      IMPORTING iv_text       TYPE string
                iv_severity   TYPE if_abap_behv_message=>t_severity
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.

ENDCLASS.

CLASS lhc_weightitem IMPLEMENTATION.

  METHOD get_instance_features.
    " GR qty editable only: G1, weighed, no inbound delivery yet, line
    " without the challan flag. Everything else stays as before.
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightItem
        FIELDS ( Materialgroup Weightindicator Inbounddelivery ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY WeightItem BY \_Head
        FIELDS ( Gateentryseries ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(ls_hk)   = VALUE #( lt_link[ source-%tky = ls_item-%tky ]-target OPTIONAL ).
      DATA(ls_head) = VALUE #( lt_head[ %tky = ls_hk-%tky ] OPTIONAL ).
      DATA(lv_edit) = xsdbool( ls_head-Gateentryseries = 'G1'
                               AND ls_item-Weightindicator = abap_true
                               AND ls_item-Inbounddelivery IS INITIAL
                               AND lcl_g1=>flagged( iv_series = ls_head-Gateentryseries
                                                    iv_matgrp = ls_item-Materialgroup ) = abap_false ).
      APPEND VALUE #( %tky          = ls_item-%tky
                      %field-Grnqty = COND #( WHEN lv_edit = abap_true
                                              THEN if_abap_behv=>fc-f-unrestricted
                                              ELSE if_abap_behv=>fc-f-read_only ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD AutoFetchTWt.
    " NEW 2026-10-28: no GET /weight. Launch the TARE camera (stores the
    " tare seqno on the header), mark the selected items as waiting and
    " set the header Tarewtsts = 'P'. CamView posts the weight with that
    " seqno to ZMM_WB_WEIGHT; the app's polling runs ApplyWeight, which
    " runs ManualFetchTWt for the marked items with that weight.
    DATA(ls_key) = VALUE #( keys[ 1 ] OPTIONAL ).
    CHECK ls_key IS NOT INITIAL.

    " G1: one tare for the whole truck - only when every PO line is
    " unloaded and no tare was taken yet (else the CamView weight would
    " be refused again and again by the polling)
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Gateentryseries ) WITH VALUE #( ( %is_draft = ls_key-%is_draft Uuid = ls_key-Uuid ) )
      RESULT DATA(lt_g1head)
      ENTITY WeightHead BY \_Item
        FIELDS ( Unloadind Weightindicator ) WITH VALUE #( ( %is_draft = ls_key-%is_draft Uuid = ls_key-Uuid ) )
      RESULT DATA(lt_g1items).

    DATA(lv_series) = VALUE #( lt_g1head[ 1 ]-Gateentryseries OPTIONAL ).

    " the selected line(s) (G2: exactly one)
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightItem
        FIELDS ( Purchaseorder Purchaseorderitem Unloadind Weightindicator )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_g2sel).
    DATA(ls_g2sel) = VALUE #( lt_g2sel[ 1 ] OPTIONAL ).

    DATA(lv_g1err) = COND string(
      " G1: one tare for the whole truck
      WHEN lv_series = 'G1' AND line_exists( lt_g1items[ Unloadind = '' ] )
        THEN `Unloading not completed for all PO lines - tare not started`
      WHEN lv_series = 'G1' AND line_exists( lt_g1items[ Weightindicator = 'X' ] )
        THEN `Tare already weighed for this gate entry`
      " G2: one PO line per weighing, after its own unloading
      WHEN lv_series = 'G2' AND lines( keys ) <> 1
        THEN `G2: select one PO line - each line is weighed after its own unloading`
      WHEN lv_series = 'G2' AND ls_g2sel-Unloadind <> abap_true
        THEN |PO { ls_g2sel-Purchaseorder }/{ CONV i( ls_g2sel-Purchaseorderitem ) }: unloading not finished - weighing not started|
      WHEN lv_series = 'G2' AND ls_g2sel-Weightindicator = abap_true
        THEN |PO { ls_g2sel-Purchaseorder }/{ CONV i( ls_g2sel-Purchaseorderitem ) }: already weighed| ).

    IF lv_g1err IS NOT INITIAL.
      LOOP AT keys INTO DATA(ls_g1key).
        APPEND VALUE #( %tky = ls_g1key-%tky ) TO failed-weightitem.
        APPEND VALUE #( %tky = ls_g1key-%tky
                        %msg = long_msg( iv_text     = lv_g1err
                                         iv_severity = if_abap_behv_message=>severity-error ) )
               TO reported-weightitem.
      ENDLOOP.
      READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightItem ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_g1res).
      result = VALUE #( FOR r IN lt_g1res ( %tky = r-%tky %param = r ) ).
      RETURN.
    ENDIF.

    DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = ls_key-%is_draft
                                          iv_uuid     = ls_key-Uuid
                                          iv_mcno     = ls_key-%param-Weighmentmcno
                                          iv_stage    = lcl_camera=>c_tare ).
    IF ls_launch-ok = abap_false.
      LOOP AT keys INTO DATA(key).
        APPEND VALUE #( %tky = key-%tky ) TO failed-weightitem.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_launch-message ) )
               TO reported-weightitem.
      ENDLOOP.
    ELSE.
      " all items of the gate entry: only the selected ones wait for this reading
      READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead BY \_Item
          FIELDS ( Tarepending )
          WITH VALUE #( ( %is_draft = ls_key-%is_draft Uuid = ls_key-Uuid ) )
        RESULT DATA(lt_all).

      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Tarewtsts Weighmentmcno weighmentmcndes )
          WITH VALUE #( ( %is_draft       = ls_key-%is_draft
                          Uuid            = ls_key-Uuid
                          Tarewtsts       = 'P'
                          Weighmentmcno   = ls_key-%param-Weighmentmcno
                          weighmentmcndes = lcl_weighbridge=>machine_text( ls_key-%param-Weighmentmcno ) ) )
        ENTITY WeightItem
          UPDATE FIELDS ( Tarepending )
          WITH VALUE #( FOR i IN lt_all
                        ( %tky        = i-%tky
                          Tarepending = COND #( WHEN line_exists( keys[ KEY id %tky = i-%tky ] ) THEN 'X' ELSE '' ) ) ).

      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Tare capture started (seq { ls_launch-seqno }), waiting for the weight from CamView| ) )
             TO reported-weightitem.
    ENDIF.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightItem ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ManualFetchTWt.
    TYPES ty_weight TYPE zmmge_itm_t01-netweight.

    DATA: lv_netwt         TYPE zmmge_itm_t01-netweight,
          lv_grswt         TYPE zmmge_itm_t01-netweight,
          lv_tarewt        TYPE zmmge_itm_t01-netweight,
          lv_weiuom        TYPE zmmge_itm_t01-weiuom,
          lv_total_netwt   TYPE zmmge_itm_t01-netweight,
          lv_grnqty        TYPE zmmge_itm_t01-grnqty,
          lv_shortageqty   TYPE zmmge_itm_t01-shortageqty,
          lv_fnshortageqty TYPE zmmge_itm_t01-shortageqty.

    DATA lt_update TYPE TABLE FOR UPDATE zmm_ih_weight\\WeightItem.

    lcl_weighbridge=>now( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT FINAL(lt_head)
      ENTITY WeightItem
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA(ls_header) = VALUE #( lt_head[ 1 ] OPTIONAL ).
    DATA(gs_keys)   = VALUE #( keys[ 1 ] OPTIONAL ).

    IF gs_keys-%param-Weight IS NOT INITIAL AND ls_header-Gateentryseries = 'G1'.
      "================================================================
      " G1 (2026-11-25): one tare for ALL PO lines; flagged lines GR =
      " challan qty, the rest of the truck net weight shared equally
      "================================================================
      READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead BY \_Item
          ALL FIELDS WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_g1).
      SORT lt_g1 BY Purchaseorder Purchaseorderitem.

      DATA(lv_g1err) = ``.
      DATA(lv_tare)  = CONV decfloat34( gs_keys-%param-Weight ).
      DATA(lv_net)   = CONV decfloat34( ls_header-Grosswt ) - lv_tare.
      IF line_exists( lt_g1[ Unloadind = '' ] ).
        lv_g1err = |Unloading not completed for all PO lines - tare not taken|.
      ELSEIF line_exists( lt_g1[ Weightindicator = 'X' ] ).
        lv_g1err = |Tare already weighed for this gate entry|.
      ELSEIF lv_net <= 0.
        lv_g1err = |Tare { lv_tare } must be below the gross weight { ls_header-Grosswt }|.
      ENDIF.

      IF lv_g1err IS NOT INITIAL.
        LOOP AT keys INTO DATA(ls_g1key).
          APPEND VALUE #( %tky = ls_g1key-%tky ) TO failed-weightitem.
        ENDLOOP.
        APPEND VALUE #( %tky = gs_keys-%tky
                        %msg = long_msg( iv_text     = lv_g1err
                                         iv_severity = if_abap_behv_message=>severity-error ) )
               TO reported-weightitem.
      ELSE.
        DATA(lv_flagsum) = CONV decfloat34( 0 ).
        DATA(lv_n)       = 0.
        LOOP AT lt_g1 INTO DATA(ls_g1).
          IF lcl_g1=>flagged( iv_series = 'G1' iv_matgrp = ls_g1-Materialgroup ) = abap_true.
            lv_flagsum = lv_flagsum + lcl_g1=>to_ton( iv_qty = ls_g1-Challanqty iv_unit = ls_g1-Baseunit ).
          ELSE.
            lv_n = lv_n + 1.
          ENDIF.
        ENDLOOP.

        DATA(lv_rem)   = lv_net - lv_flagsum.
        DATA(lv_share) = COND decfloat34( WHEN lv_n > 0 AND lv_rem > 0
                                          THEN round( val = lv_rem / lv_n dec = 3 )
                                          ELSE 0 ).
        DATA(lv_i)     = 0.
        DATA(lv_first) = abap_true.

        LOOP AT lt_g1 INTO ls_g1.
          DATA(lv_netton) = CONV decfloat34( 0 ).
          DATA(lv_grn)    = CONV decfloat34( 0 ).
          DATA(lv_short)  = CONV decfloat34( 0 ).
          IF lcl_g1=>flagged( iv_series = 'G1' iv_matgrp = ls_g1-Materialgroup ) = abap_true.
            lv_grn = ls_g1-Challanqty.
            IF lines( lt_g1 ) = 1.
              " one PO line: the line carries the whole weighed net;
              " shortage = weighed net - challan qty (+ more, - less)
              lv_netton = lv_net.
              lv_short  = lv_net - lcl_g1=>to_ton( iv_qty = ls_g1-Challanqty iv_unit = ls_g1-Baseunit ).
            ELSE.
              lv_netton = lcl_g1=>to_ton( iv_qty = ls_g1-Challanqty iv_unit = ls_g1-Baseunit ).
            ENDIF.
          ELSEIF lv_rem > 0.
            lv_i      = lv_i + 1.
            lv_netton = COND #( WHEN lv_i = lv_n THEN lv_rem - lv_share * ( lv_n - 1 ) ELSE lv_share ).
            lv_grn    = lcl_g1=>from_ton( iv_ton = lv_netton iv_unit = ls_g1-Baseunit ).
          ENDIF.

          APPEND VALUE #( %tky            = ls_g1-%tky
                          Grossweight     = COND #( WHEN lv_first = abap_true THEN ls_header-Grosswt )
                          Tareweight      = COND #( WHEN lv_first = abap_true THEN lv_tare )
                          Weiuom          = gs_keys-%param-Unit
                          Netweight       = lv_netton
                          Weightindicator = 'X'
                          Grnqty          = lv_grn
                          Gateentryno     = ls_header-Gateentryno
                          Weighmentdate   = lv_date
                          Weighmenttime   = lv_time
                          Shortageqty     = lv_short
                          Tarepending     = '' ) TO lt_update.
          lv_first = abap_false.
        ENDLOOP.

        MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
          ENTITY WeightItem
            UPDATE FIELDS ( Grossweight Weiuom Netweight Tareweight Weightindicator
                            Grnqty Gateentryno Weighmentdate Weighmenttime Shortageqty Tarepending )
            WITH lt_update
          ENTITY WeightHead
            UPDATE FIELDS ( Tarewt Netwt )
            WITH VALUE #( ( %tky = ls_header-%tky Tarewt = lv_tare Netwt = lv_net ) ).

        " the tare is kept either way; a bad split blocks the inbound delivery
                IF lv_n > 0 AND lv_rem <= 0.
          APPEND VALUE #( %tky = gs_keys-%tky
                          %msg = long_msg( iv_text     = |Truck net { lv_net } TO vs challan qty { lv_flagsum } TO: | &&
                                                         |no weight left for PO lines without challan - inbound delivery blocked|
                                           iv_severity = if_abap_behv_message=>severity-error ) )
                 TO reported-weightitem.
        ELSE.
          APPEND VALUE #( %tky = gs_keys-%tky
                          %msg = long_msg( iv_text     = |Tare { lv_tare }: truck net { lv_net } TO, challan { lv_flagsum } TO, | &&
                                                         |remainder { lv_rem } TO on { lv_n } line(s) without challan|
                                           iv_severity = if_abap_behv_message=>severity-success ) )
                 TO reported-weightitem.
        ENDIF.
      ENDIF.

    ELSEIF gs_keys-%param-Weight IS NOT INITIAL AND ls_header-Gateentryseries = 'G2'.
      "================================================================
      " G2 (2026-11-25): one PO line per weighing, in sequence.
      " line net = weight before this line was unloaded - weight now;
      " weight before = gross - net of the lines already weighed.
      " GR: flag set -> challan qty, else the line's net weight
      "================================================================
      DATA(lv_g2err) = ``.
      DATA(ls_g2) = VALUE #( lt_item[ 1 ] OPTIONAL ).

      READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead BY \_Item
          FIELDS ( Netweight Weightindicator ) WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_g2all).

      DATA(lv_g2done) = CONV decfloat34( 0 ).
      LOOP AT lt_g2all INTO DATA(ls_g2all) WHERE Weightindicator = abap_true.
        lv_g2done = lv_g2done + ls_g2all-Netweight.
      ENDLOOP.

      DATA(lv_g2tare) = CONV decfloat34( gs_keys-%param-Weight ).
      DATA(lv_g2prev) = CONV decfloat34( ls_header-Grosswt ) - lv_g2done.
      DATA(lv_g2net)  = lv_g2prev - lv_g2tare.

      IF lines( keys ) <> 1.
        lv_g2err = |G2: select one PO line - each line is weighed after its own unloading|.
      ELSEIF ls_g2-Unloadind <> abap_true.
        lv_g2err = |PO { ls_g2-Purchaseorder }/{ CONV i( ls_g2-Purchaseorderitem ) }: unloading not finished - weight not taken|.
      ELSEIF ls_g2-Weightindicator = abap_true.
        lv_g2err = |PO { ls_g2-Purchaseorder }/{ CONV i( ls_g2-Purchaseorderitem ) }: already weighed|.
      ELSEIF lv_g2net <= 0.
        lv_g2err = |Weight { lv_g2tare } must be below the weight before unloading { lv_g2prev }|.
      ENDIF.

      IF lv_g2err IS NOT INITIAL.
        LOOP AT keys INTO DATA(ls_g2key).
          APPEND VALUE #( %tky = ls_g2key-%tky ) TO failed-weightitem.
        ENDLOOP.
        APPEND VALUE #( %tky = gs_keys-%tky
                        %msg = long_msg( iv_text     = lv_g2err
                                         iv_severity = if_abap_behv_message=>severity-error ) )
               TO reported-weightitem.
      ELSE.
        DATA(lv_g2flag) = lcl_g1=>flagged( iv_series = 'G2' iv_matgrp = ls_g2-Materialgroup ).
        DATA(lv_g2grn)  = COND decfloat34( WHEN lv_g2flag = abap_true
                                           THEN ls_g2-Challanqty
                                           ELSE lcl_g1=>from_ton( iv_ton = lv_g2net iv_unit = ls_g2-Baseunit ) ).

        APPEND VALUE #( %tky            = ls_g2-%tky
                        Grossweight     = lv_g2prev
                        Tareweight      = lv_g2tare
                        Weiuom          = gs_keys-%param-Unit
                        Netweight       = lv_g2net
                        Weightindicator = 'X'
                        Grnqty          = lv_g2grn
                        Gateentryno     = ls_header-Gateentryno
                        Weighmentdate   = lv_date
                        Weighmenttime   = lv_time
                        Shortageqty     = 0
                        Tarepending     = '' ) TO lt_update.

        MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
          ENTITY WeightItem
            UPDATE FIELDS ( Grossweight Weiuom Netweight Tareweight Weightindicator
                            Grnqty Gateentryno Weighmentdate Weighmenttime Shortageqty Tarepending )
            WITH lt_update
          ENTITY WeightHead
            UPDATE FIELDS ( Tarewt Netwt )
            WITH VALUE #( ( %tky = ls_header-%tky Tarewt = lv_g2tare Netwt = lv_g2done + lv_g2net ) ).

        APPEND VALUE #( %tky = gs_keys-%tky
                        %msg = long_msg( iv_text     = |PO { ls_g2-Purchaseorder }/{ CONV i( ls_g2-Purchaseorderitem ) }: | &&
                                                       |{ lv_g2prev } - { lv_g2tare } = net { lv_g2net } TO, GR { lv_g2grn } | &&
                                                       |({ COND string( WHEN lv_g2flag = abap_true THEN `challan qty` ELSE `net weight` ) })|
                                         iv_severity = if_abap_behv_message=>severity-success ) )
               TO reported-weightitem.
      ENDIF.

    ELSEIF gs_keys-%param-Weight IS NOT INITIAL.
      "================================================================
      " other series: unchanged logic
      "================================================================
      " net already weighed on this gate entry (all items, same draft/active state)
      READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead BY \_Item
        FIELDS ( Netweight ) WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_all_items).

      lv_total_netwt = REDUCE #( INIT lv_sum = CONV ty_weight( 0 )
                                 FOR ls_all IN lt_all_items
                                 NEXT lv_sum = lv_sum + ls_all-Netweight ).

      SORT lt_item ASCENDING BY Purchaseorder Purchaseorderitem.
      DATA(gs_count) = 1.

      LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item>).

        SELECT SINGLE * FROM zmmge_wghflg_t01 WITH PRIVILEGED ACCESS
          WHERE gateentryseries = @ls_header-Gateentryseries
            AND materialgroup   = @<ls_item>-Materialgroup
          INTO @DATA(ls_master).

        IF gs_count = 1.
          lv_grswt  = ( ls_header-Grosswt - lv_total_netwt ).
          lv_weiuom = gs_keys-%param-Unit.
          lv_tarewt = gs_keys-%param-Weight.
          lv_netwt  = lv_grswt - gs_keys-%param-Weight.
        ENDIF.

        IF ls_master-challanqtyflag = 'X' AND ( <ls_item>-Baseunit = 'KG' OR <ls_item>-Baseunit = 'TO' ).
          lv_grnqty = <ls_item>-Challannetweight.
        ELSEIF ls_master-challanqtyflag = 'X' AND ( <ls_item>-Baseunit NE 'KG' OR <ls_item>-Baseunit NE 'TO' ).
          lv_grnqty = <ls_item>-Challanqty.
        ELSEIF ls_master-challanqtyflag IS INITIAL AND ls_header-Gateentryseries = 'G2'.
          lv_grnqty = <ls_item>-Challanqty.
        ELSE.
          lv_grnqty = COND #( WHEN <ls_item>-Challanqty IS NOT INITIAL
                              THEN <ls_item>-Challanqty
                              ELSE lv_netwt ).
        ENDIF.

        APPEND VALUE #( %tky            = <ls_item>-%tky
                        Grossweight     = lv_grswt
                        Weiuom          = lv_weiuom
                        Netweight       = lv_netwt
                        Tareweight      = lv_tarewt
                        Weightindicator = 'X'
                        Grnqty          = lv_grnqty
                        Gateentryno     = ls_header-Gateentryno
                        Weighmentdate   = lv_date
                        Weighmenttime   = lv_time
                        Shortageqty     = lv_fnshortageqty
                        Tarepending     = '' ) TO lt_update.

        CLEAR: lv_grswt, lv_netwt, lv_tarewt, lv_weiuom, lv_grnqty, lv_shortageqty, ls_master, lv_fnshortageqty.
        gs_count += 1.
      ENDLOOP.

      IF lt_update IS NOT INITIAL.
        MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
          ENTITY WeightItem
          UPDATE FIELDS ( Grossweight Weiuom Netweight Tareweight Weightindicator
                          Grnqty Gateentryno Weighmentdate Weighmenttime Shortageqty Tarepending )
          WITH lt_update.
      ENDIF.

    ELSE.
      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = 'Validate_Head'
                      %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                           text     = |Weightment is Empty| ) )
             TO reported-weighthead.
      APPEND VALUE #( %tky = ls_header-%tky ) TO failed-weighthead.
    ENDIF.

    " camera for the TARE stage when at least one item got the tare.
    " Not when ApplyWeight runs this with the CamView weight.
    IF lt_update IS NOT INITIAL AND lcl_camera=>gv_no_launch = abap_false.
      DATA(ls_key) = keys[ 1 ].

      " a manual tare ends a pending CamView tare
      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Tarewtsts )
          WITH VALUE #( ( %is_draft = ls_key-%is_draft Uuid = ls_key-Uuid Tarewtsts = '' ) ).

      DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = ls_key-%is_draft
                                            iv_uuid     = ls_key-Uuid
                                            iv_mcno     = ls_key-%param-Weighmentmcno
                                            iv_stage    = lcl_camera=>c_tare ).
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text( severity = lcl_camera=>severity( ls_launch )
                                                    text     = ls_launch-message ) )
             TO reported-weightitem.
    ENDIF.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightItem ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD checkGrn.
    " G1: GR of lines without challan must stay within the remainder
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightItem BY \_Head
        FIELDS ( Gateentryseries Netwt ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    SORT lt_head BY %tky.
    DELETE ADJACENT DUPLICATES FROM lt_head COMPARING %tky.

    LOOP AT lt_head INTO DATA(ls_head).
      " clears an old message of this check
      LOOP AT lt_link INTO DATA(ls_lnk) WHERE target-%tky = ls_head-%tky.
        APPEND VALUE #( %tky = ls_lnk-source-%tky %state_area = 'CHECK_GRN' ) TO reported-weightitem.
      ENDLOOP.

      IF ls_head-Gateentryseries <> 'G1' OR ls_head-Netwt IS INITIAL.
        CONTINUE.
      ENDIF.

      READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead BY \_Item
          ALL FIELDS WITH VALUE #( ( %tky = ls_head-%tky ) )
        RESULT DATA(lt_items).

      DATA(lv_text) = lcl_g1=>check( it_items  = CORRESPONDING #( lt_items )
                                     iv_series = ls_head-Gateentryseries
                                     iv_net    = ls_head-Netwt ).
      IF lv_text IS NOT INITIAL.
        LOOP AT lt_link INTO ls_lnk WHERE target-%tky = ls_head-%tky.
          APPEND VALUE #( %tky = ls_lnk-source-%tky ) TO failed-weightitem.
          APPEND VALUE #( %tky        = ls_lnk-source-%tky
                          %state_area = 'CHECK_GRN'
                          %msg        = long_msg( iv_text     = lv_text
                                                  iv_severity = if_abap_behv_message=>severity-error )
                          %element-Grnqty = if_abap_behv=>mk-on ) TO reported-weightitem.
        ENDLOOP.
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

*----------------------------------------------------------------*
* Header: gross weight (arrival), recapture, weighment slip
*----------------------------------------------------------------*
CLASS lhc_WeightHead DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR WeightHead RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR WeightHead RESULT result.

    METHODS AutoFetchWt FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~AutoFetchWt RESULT result.

    METHODS ManualFetchWt FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~ManualFetchWt RESULT result.

    METHODS ApplyWeight FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~ApplyWeight RESULT result.

    METHODS RecaptureGross FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~RecaptureGross RESULT result.

    METHODS RecaptureTare FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~RecaptureTare RESULT result.

    METHODS Weighmentform FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~Weighmentform RESULT result.
    METHODS InboundDlvy FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~InboundDlvy RESULT result.

    "! Message with up to 200 characters (ZMM_GATE_MSG 001 = &1&2&3&4)
    METHODS long_msg
      IMPORTING iv_text       TYPE string
                iv_severity   TYPE if_abap_behv_message=>t_severity
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.

ENDCLASS.

CLASS lhc_WeightHead IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Grosswt Imgseqnogross Imgseqnotare Imgvrstatusgross Imgvrstatustare Grosswtsts Tarewtsts Inbounddlvy unloadendindi )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        FIELDS ( Weightindicator )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).
      " tare done = at least one item weighed (item Uuid = header Uuid)
      DATA(lv_tare_done) = xsdbool( line_exists( lt_item[ Uuid = ls_head-Uuid Weightindicator = 'X' ] ) ).

      APPEND VALUE #(
        %tky = ls_head-%tky

        " recapture: the stage was rejected, or its camera launch failed
        %action-RecaptureGross = COND #( WHEN ls_head-Imgvrstatusgross = 'R'
                                           OR ( ls_head-Grosswt IS NOT INITIAL AND ls_head-Imgseqnogross IS INITIAL )
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )

        %action-RecaptureTare = COND #( WHEN ls_head-Imgvrstatustare = 'R'
                                          OR ( lv_tare_done = abap_true AND ls_head-Imgseqnotare IS INITIAL )
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )

        " NEW: only while a CamView weight is awaited
        %action-ApplyWeight = COND #( WHEN ls_head-Grosswtsts = 'P' OR ls_head-Tarewtsts = 'P'
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled )

        " inbound delivery only once: inactive as soon as its number is stored
        %action-InboundDlvy = COND #( WHEN ls_head-Inbounddlvy IS INITIAL
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled )

        "
        %action-AutoFetchWt = COND #( WHEN ls_head-unloadendindi IS INITIAL
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled )

        "
        %action-ManualFetchWt = COND #( WHEN ls_head-unloadendindi IS INITIAL
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled )

      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD AutoFetchWt.
    " NEW 2026-10-28: no GET /weight. Launch the GROSS camera (stores the
    " gross seqno) and set Grosswtsts = 'P'. CamView posts the weight with
    " that seqno to ZMM_WB_WEIGHT; the app's polling runs ApplyWeight.
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Uuid ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA(ls_param) = keys[ KEY id %tky = ls_head-%tky ]-%param.

      DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = ls_head-%is_draft
                                            iv_uuid     = ls_head-Uuid
                                            iv_mcno     = ls_param-Weighmentmcno
                                            iv_stage    = lcl_camera=>c_gross ).
      IF ls_launch-ok = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_launch-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Grosswtsts Weighmentmcno weighmentmcndes )
          WITH VALUE #( ( %tky            = ls_head-%tky
                          Grosswtsts      = 'P'
                          Weighmentmcno   = ls_param-Weighmentmcno
                          weighmentmcndes = lcl_weighbridge=>machine_text( ls_param-Weighmentmcno ) ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Gross capture started (seq { ls_launch-seqno }), waiting for the weight from CamView| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ApplyWeight.
    " Called by the app every few seconds while Grosswtsts / Tarewtsts = 'P'.
    " Takes CamView's reading (ZMMGE_WB_READ, filled by ZMM_WB_WEIGHT) for
    " the pending seqno. No reading yet -> nothing happens, no message.
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Uuid Grosswtsts Tarewtsts Imgseqnogross Imgseqnotare Weighmentmcno )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        FIELDS ( Tarepending )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).

      "--- gross ---------------------------------------------------
      IF ls_head-Grosswtsts = 'P' AND ls_head-Imgseqnogross IS NOT INITIAL.
        SELECT SINGLE machine, weight FROM zmmge_wb_read
          WHERE seqno = @ls_head-Imgseqnogross
          INTO @DATA(ls_gross).
        IF sy-subrc = 0.
          DATA(lv_gmcno) = COND lcl_weighbridge=>ty_mcno( WHEN ls_gross-machine IS NOT INITIAL
                                                          THEN ls_gross-machine ELSE ls_head-Weighmentmcno ).
          lcl_weighbridge=>now( IMPORTING ev_date = DATA(lv_gdate) ev_time = DATA(lv_gtime) ).

          MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
            ENTITY WeightHead
              UPDATE FIELDS ( Grosswt Weighuom Weighmentmcno weighmentmcndes Weighmentdate Weighmenttime Grosswtsts )
              WITH VALUE #( ( %tky            = ls_head-%tky
                              Grosswt         = ls_gross-weight
                              Weighuom        = 'TO'
                              Weighmentmcno   = lv_gmcno
                              weighmentmcndes = lcl_weighbridge=>machine_text( lv_gmcno )
                              Weighmentdate   = lv_gdate
                              Weighmenttime   = lv_gtime
                              Grosswtsts      = 'R' ) ).

          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                        text     = |Gross weight { ls_gross-weight } TO received from CamView| ) )
                 TO reported-weighthead.
        ENDIF.
        CLEAR ls_gross.
      ENDIF.

      "--- tare ----------------------------------------------------
      IF ls_head-Tarewtsts = 'P' AND ls_head-Imgseqnotare IS NOT INITIAL.
        SELECT SINGLE machine, weight FROM zmmge_wb_read
          WHERE seqno = @ls_head-Imgseqnotare
          INTO @DATA(ls_tare).
        IF sy-subrc = 0.
          DATA(lv_tmcno) = COND lcl_weighbridge=>ty_mcno( WHEN ls_tare-machine IS NOT INITIAL
                                                          THEN ls_tare-machine ELSE ls_head-Weighmentmcno ).

          " tare logic of ManualFetchTWt, without a new camera launch
          lcl_camera=>gv_no_launch = abap_true.
          MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
            ENTITY WeightItem
              EXECUTE ManualFetchTWt
              FROM VALUE #( FOR i IN lt_item WHERE ( Uuid = ls_head-Uuid AND Tarepending = 'X' )
                            ( %tky                 = i-%tky
                              %param-Weighmentmcno = lv_tmcno
                              %param-Weight        = ls_tare-weight
                              %param-Unit          = 'TO' ) )
            FAILED   DATA(ls_failed)
            REPORTED DATA(ls_reported).
          lcl_camera=>gv_no_launch = abap_false.

          LOOP AT ls_reported-weighthead INTO DATA(lr_head).
            APPEND VALUE #( %tky = ls_head-%tky %msg = lr_head-%msg ) TO reported-weighthead.
          ENDLOOP.
          LOOP AT ls_reported-weightitem INTO DATA(lr_item) WHERE %msg IS BOUND.
            APPEND VALUE #( %tky = ls_head-%tky %msg = lr_item-%msg ) TO reported-weighthead.
          ENDLOOP.

          IF ls_failed-weightitem IS INITIAL AND ls_failed-weighthead IS INITIAL.
            MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
              ENTITY WeightHead
                UPDATE FIELDS ( Tarewtsts )
                WITH VALUE #( ( %tky = ls_head-%tky Tarewtsts = 'R' ) ).

            APPEND VALUE #( %tky = ls_head-%tky
                            %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                          text     = |Tare weight { ls_tare-weight } TO received from CamView| ) )
                   TO reported-weighthead.
          ENDIF.
        ENDIF.
        CLEAR ls_tare.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ManualFetchWt.
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Uuid ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA(ls_param) = keys[ KEY id %tky = ls_head-%tky ]-%param.

      "" -- Value Validation -----
      IF ls_param-Weight IS INITIAL.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = 'Weightment is Empty' ) )
               TO reported-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        CONTINUE.
      ENDIF.

      lcl_weighbridge=>now( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).

      " The G1/G2 gross-vs-tare logic stays commented out, as in S/4;
      " this action records the gross weight only. A manual gross also
      " ends a pending CamView gross (Grosswtsts cleared).
      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Grosswt Weighuom Weighmentmcno weighmentmcndes Weighmentdate Weighmenttime Grosswtsts )
          WITH VALUE #( ( %tky            = ls_head-%tky
                          Grosswt         = ls_param-Weight
                          Weighmentmcno   = ls_param-Weighmentmcno
                          Weighuom        = ls_param-Unit
                          weighmentmcndes = lcl_weighbridge=>machine_text( ls_param-Weighmentmcno )
                          Weighmentdate   = lv_date
                          Weighmenttime   = lv_time
                          Grosswtsts      = '' ) ).

      DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = ls_head-%is_draft
                                            iv_uuid     = ls_head-Uuid
                                            iv_mcno     = ls_param-Weighmentmcno
                                            iv_stage    = lcl_camera=>c_gross ).
      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = lcl_camera=>severity( ls_launch )
                                                    text     = ls_launch-message ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD RecaptureGross.
    " camera only, the gross weight stays (truck back on the weighbridge, loaded)
    LOOP AT keys INTO DATA(key).
      DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = key-%is_draft
                                            iv_uuid     = key-Uuid
                                            iv_mcno     = key-%param-Weighmentmcno
                                            iv_stage    = lcl_camera=>c_gross ).
      IF ls_launch-ok = abap_false.
        APPEND VALUE #( %tky = key-%tky ) TO failed-weighthead.
      ENDIF.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text( severity = COND #( WHEN ls_launch-ok = abap_true
                                                                       THEN if_abap_behv_message=>severity-success
                                                                       ELSE if_abap_behv_message=>severity-error )
                                                    text     = ls_launch-message ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD RecaptureTare.
    " camera only, the tare / net weights stay (truck back on the weighbridge, empty)
    LOOP AT keys INTO DATA(key).
      DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = key-%is_draft
                                            iv_uuid     = key-Uuid
                                            iv_mcno     = key-%param-Weighmentmcno
                                            iv_stage    = lcl_camera=>c_tare ).
      IF ls_launch-ok = abap_false.
        APPEND VALUE #( %tky = key-%tky ) TO failed-weighthead.
      ENDIF.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text( severity = COND #( WHEN ls_launch-ok = abap_true
                                                                       THEN if_abap_behv_message=>severity-success
                                                                       ELSE if_abap_behv_message=>severity-error )
                                                    text     = ls_launch-message ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD Weighmentform.
    " slip = FDP XML of ZWEIGHT_SLIP_CE_SD rendered by ZCL_GE_ADOBE_PDF,
    " stored in Weighslipattcmt (as in the system version, 2026-10-10)
    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    LOOP AT lt_result INTO DATA(ls_res).

      TRY.
          DATA(lo_fdp)  = cl_fp_fdp_services=>get_instance( iv_service_definition = 'ZWEIGHT_SLIP_CE_SD'
                                                             iv_root_node          = 'ZMM_WEIGHT_SLIP_CE' ).
          DATA(lt_keys) = lo_fdp->get_keys( ).
          lt_keys[ name = 'UUID' ]-value = ls_res-Uuid.
          DATA(lv_xml)  = lo_fdp->read_to_xml( lt_keys ).

          DATA(lv_pdf)  = zcl_ge_adobe_pdf=>render( iv_form_name     = `ZMM_WEIGHT_SLIP`
                                                    iv_template_name = `WEIGHT_SLIP`
                                                    iv_xml_data      = lv_xml ).

        CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
          APPEND VALUE #( %tky = ls_res-%tky ) TO failed-weighthead.
          APPEND VALUE #( %tky = ls_res-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Slip data: { lx_fdp->get_text( ) }| ) )
                 TO reported-weighthead.
          CONTINUE.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_res-%tky ) TO failed-weighthead.
          APPEND VALUE #( %tky = ls_res-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Adobe: HTTP { lx_ads->mv_http_status_code } { lx_ads->mv_http_reason }| ) )
                 TO reported-weighthead.
          CONTINUE.
      ENDTRY.

      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Weighslipattcmt Weighmimetype Weighfilename )
          WITH VALUE #( ( %tky            = ls_res-%tky
                          Weighslipattcmt = lv_pdf
                          Weighmimetype   = 'application/pdf'
                          Weighfilename   = |Weighment Slip-{ ls_res-Gateentryno }.pdf| ) ).

      APPEND VALUE #( %tky = ls_res-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Weighment slip created for { ls_res-Gateentryno }| ) )
             TO reported-weighthead.

    ENDLOOP.

    result = VALUE #( FOR ls_ord IN lt_result
                      ( %tky   = ls_ord-%tky
                        %param = ls_ord ) ).
  ENDMETHOD.

  METHOD InboundDlvy.
    DATA ls_response TYPE zcl_mm_s4_gate_api=>ty_response.
    DATA lt_upd_item TYPE TABLE FOR UPDATE zmm_ih_weight\\WeightItem.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
      FIELDS ( Gateentryno Transportername Gateentrydate Gateentrytime Vehicleno
               Gateentryseries Netwt ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_poitem).

    IF lt_poitem IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_poitem ASCENDING BY Purchaseorder Purchaseorderitem.
    DATA(ls_pohead) = VALUE #( lt_head[ 1 ] OPTIONAL ).

    " G1: gross and tare once for the whole truck - no delivery while the
    " tare is missing or the weight split is not OK
    IF ls_pohead-Gateentryseries = 'G1'.
      DATA(lv_g1chk) = COND string(
        WHEN ls_pohead-Netwt IS INITIAL OR line_exists( lt_poitem[ Weightindicator = '' ] )
        THEN `tare not weighed for all PO lines`
        ELSE lcl_g1=>check( it_items  = CORRESPONDING #( lt_poitem )
                            iv_series = ls_pohead-Gateentryseries
                            iv_net    = ls_pohead-Netwt ) ).
      IF lv_g1chk IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_pohead-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_pohead-%tky
                        %msg = long_msg( iv_text     = |Inbound delivery blocked: { lv_g1chk }|
                                         iv_severity = if_abap_behv_message=>severity-error ) )
               TO reported-weighthead.
        RETURN.
      ENDIF.
    ENDIF.
    " G2: every PO line is weighed after its own unloading - no delivery
    " before the last one is done
    IF ls_pohead-Gateentryseries = 'G2' AND line_exists( lt_poitem[ Weightindicator = '' ] ).
      DATA(lv_g2open) = ``.
      LOOP AT lt_poitem INTO DATA(ls_g2open) WHERE Weightindicator = ''.
        lv_g2open = |{ lv_g2open } { ls_g2open-Purchaseorder }/{ CONV i( ls_g2open-Purchaseorderitem ) }|.
      ENDLOOP.
      APPEND VALUE #( %tky = ls_pohead-%tky ) TO failed-weighthead.
      APPEND VALUE #( %tky = ls_pohead-%tky
                      %msg = long_msg( iv_text     = |Inbound delivery blocked: not weighed yet - PO{ lv_g2open }|
                                       iv_severity = if_abap_behv_message=>severity-error ) )
             TO reported-weighthead.
      RETURN.
    ENDIF.

    ""Challan Details Per Po Item
    SELECT SINGLE uuid, purchaseorder, purchaseorderitem, challanno,
            challandate, lrno, lrdate FROM zmmge_chln_t01 WITH PRIVILEGED ACCESS
            WHERE uuid = @ls_pohead-Uuid
            INTO @DATA(ls_challan).

    " freight order per PO item (maintained in the Inventory app; the
    " Weight views don't carry the field)
    SELECT purchaseorder, purchaseorderitem, freightorder
      FROM zmmge_itm_t01
      WHERE uuid = @ls_pohead-Uuid
      INTO TABLE @DATA(lt_fo).

    DATA(lv_first_dlv) = VALUE zcl_mm_s4_gate_api=>ty_response-inbounddelivery( ).
    DATA(lv_all_done)  = abap_true.

    " items that already have their delivery (earlier run)
    LOOP AT lt_poitem INTO DATA(ls_done) WHERE Uuid = ls_pohead-Uuid AND Inbounddelivery IS NOT INITIAL.
      IF lv_first_dlv IS INITIAL.
        lv_first_dlv = ls_done-Inbounddelivery.
      ENDIF.
    ENDLOOP.

    " one delivery per PO (items without a delivery yet)
    LOOP AT lt_poitem INTO DATA(ls_grp)
         WHERE Uuid = ls_pohead-Uuid AND Inbounddelivery IS INITIAL
         GROUP BY ( po = ls_grp-Purchaseorder vendor = ls_grp-Vendor )
         ASSIGNING FIELD-SYMBOL(<grp>).

      DATA(lv_poref) = |PO { <grp>-po ALPHA = OUT }|.
      DATA lt_req_items TYPE zcl_mm_s4_gate_api=>ty_request-items.
      CLEAR lt_req_items.
      LOOP AT GROUP <grp> INTO DATA(ls_item).
        APPEND VALUE #( purchaseorder     = ls_item-Purchaseorder
                        purchaseorderitem = ls_item-Purchaseorderitem
                        unit              = ls_item-Baseunit
                        quantity          = ls_item-Grnqty
                        freightorder      = VALUE #( lt_fo[ purchaseorder     = ls_item-Purchaseorder
                                                            purchaseorderitem = ls_item-Purchaseorderitem ]-freightorder OPTIONAL )
                        ""Custom field update purpose added on 24.11.2026
                        transportername = ls_pohead-Transportername
                        gateentrydate = ls_pohead-Gateentrydate
                        gateentrytime = ls_pohead-Gateentrytime
                        challannumber = ls_challan-challanno
                        challandate   = ls_challan-challandate
                        ewaybillno    = ls_item-Ewaybillno
                        ewaybilldate  = ls_item-Ewaybilldate
                        lrno          = ls_challan-lrno
                        lrdate        = ls_challan-lrdate
                        Vehicleno     = ls_pohead-Vehicleno

                        )

               TO lt_req_items.
      ENDLOOP.

      CLEAR ls_response.
      TRY.
          ls_response = zcl_mm_s4_gate_api=>call(
                          VALUE #( operation   = 'INBDLV'
                                   supplier    = <grp>-vendor
                                   gateentryno = ls_pohead-Gateentryno
                                   items       = lt_req_items ) ).
        CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
          ls_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
      ENDTRY.

      IF ls_response-success = abap_false.
        lv_all_done = abap_false.
        APPEND VALUE #( %tky = ls_pohead-%tky
                        %msg = long_msg( iv_text     = |{ lv_poref }: inbound delivery not created: { ls_response-message }|
                                         iv_severity = if_abap_behv_message=>severity-error ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      IF lv_first_dlv IS INITIAL.
        lv_first_dlv = ls_response-inbounddelivery.
      ENDIF.

      LOOP AT GROUP <grp> INTO ls_item.
        DATA(ls_dlv) = VALUE zcl_mm_s4_gate_api=>ty_resp_item(
                         ls_response-items[ purchaseorder     = ls_item-Purchaseorder
                                            purchaseorderitem = ls_item-Purchaseorderitem ] OPTIONAL ).
        APPEND VALUE #( %tky                = ls_item-%tky
                        Inbounddelivery     = ls_response-inbounddelivery
                        Inbounddeliveryitem = ls_dlv-inbounddeliveryitem ) TO lt_upd_item.
      ENDLOOP.

      APPEND VALUE #( %tky = ls_pohead-%tky
                      %msg = long_msg( iv_severity = COND #( WHEN ls_response-message IS INITIAL
                                                             THEN if_abap_behv_message=>severity-success
                                                             ELSE if_abap_behv_message=>severity-information )
                                       iv_text     = COND #( WHEN ls_response-message IS INITIAL
                                                             THEN |{ lv_poref }: Inbound Delivery { ls_response-inbounddelivery ALPHA = OUT } created|
                                                             ELSE |{ lv_poref }: Inbound Delivery { ls_response-inbounddelivery ALPHA = OUT }: { ls_response-message }| ) ) )
             TO reported-weighthead.

      " freight unit -> freight order of this PO
      IF ls_response-fomessage IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_pohead-%tky
                        %msg = long_msg( iv_severity = COND #( WHEN ls_response-fomessage CS 'assigned to freight order'
                                                                AND ls_response-fomessage NS 'not assigned'
                                                               THEN if_abap_behv_message=>severity-success
                                                               ELSE if_abap_behv_message=>severity-information )
                                         iv_text     = |{ lv_poref }: { ls_response-fomessage }| ) )
               TO reported-weighthead.
      ENDIF.
    ENDLOOP.

    IF lt_upd_item IS NOT INITIAL.
      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightItem
        UPDATE FIELDS ( Inbounddelivery Inbounddeliveryitem )
        WITH lt_upd_item.
    ENDIF.

    " button off only when every item has its delivery. No failed-entry on
    " a partial failure: the deliveries created in this run must still be
    " saved on their items (S/4 finds them again anyway, P5d).
    IF lv_all_done = abap_true AND lv_first_dlv IS NOT INITIAL.
      MODIFY ENTITIES OF zmm_ih_weight IN LOCAL MODE
        ENTITY WeightHead
        UPDATE FIELDS ( Inbounddlvy )
        WITH VALUE #( ( %tky = ls_pohead-%tky Inbounddlvy = lv_first_dlv ) ).
    ENDIF.

    READ ENTITIES OF zmm_ih_weight IN LOCAL MODE
      ENTITY WeightHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
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

