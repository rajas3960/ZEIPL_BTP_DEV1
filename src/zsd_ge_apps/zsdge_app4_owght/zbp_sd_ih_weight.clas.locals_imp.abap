*----------------------------------------------------------------*
* Loaded qty vs assigned qty (local helper) - 05.11.2026
* A line is in excess when its net weight is above the assigned qty
* (Quantity, set by Sales Order Update) plus the S/4 over-delivery
* tolerance % (Overdeltolpct) and it has no delivery yet. Create
* Delivery stays blocked until Sales raises the qty or adds an SO
* line (then Re-split), or the truck is unloaded and weighed again.
*----------------------------------------------------------------*
CLASS lcl_load DEFINITION FINAL.
  PUBLIC SECTION.
    "! assigned qty + tolerance %
    CLASS-METHODS allowed
      IMPORTING iv_qty            TYPE numeric
                iv_pct            TYPE numeric
      RETURNING VALUE(rv_allowed) TYPE decfloat34.

    CLASS-METHODS is_excess
      IMPORTING iv_net           TYPE numeric
                iv_qty           TYPE numeric
                iv_pct           TYPE numeric
                iv_delivery      TYPE clike
      RETURNING VALUE(rv_excess) TYPE abap_bool.

    "! "Excess 1490/10: net 9.120 > 8.000" (kept under 50 characters)
    CLASS-METHODS excess_text
      IMPORTING iv_so          TYPE clike
                iv_item        TYPE clike
                iv_net         TYPE numeric
                iv_qty         TYPE numeric
                iv_pct         TYPE numeric
      RETURNING VALUE(rv_text) TYPE string.

    TYPES tt_items TYPE TABLE FOR READ RESULT zsd_ih_weight\\WeightItem.
    TYPES: BEGIN OF ty_net,
             salesdocument TYPE zsdge_sentry_it1-salesdocument,
             salesitem     TYPE zsdge_sentry_it1-salesitem,
             net           TYPE decfloat34,
           END OF ty_net,
           tt_net TYPE SORTED TABLE OF ty_net WITH UNIQUE KEY salesdocument salesitem.

    "! Net per line of ONE truck, oldest SO line first (09.11.2026):
    "! 1. each line up to its assigned qty, 2. each up to its tolerance,
    "! 3. the rest on the last line (Excess). Per material, as before.
    CLASS-METHODS fill_first
      IMPORTING it_items      TYPE tt_items
                iv_net        TYPE decfloat34
      RETURNING VALUE(rt_net) TYPE tt_net.

    "! the truck's lines in fill order: material, assignment time, SO, item
    CLASS-METHODS fill_order
      CHANGING ct_items TYPE tt_items.
ENDCLASS.

CLASS lcl_load IMPLEMENTATION.

  METHOD allowed.
    rv_allowed = iv_qty + iv_qty * iv_pct / 100.
  ENDMETHOD.

  METHOD is_excess.
    rv_excess = xsdbool( iv_delivery IS INITIAL
                         AND iv_net > allowed( iv_qty = iv_qty iv_pct = iv_pct ) ).
  ENDMETHOD.

  METHOD excess_text.
    DATA(lv_net)     = CONV decfloat34( iv_net ).
    DATA(lv_allowed) = allowed( iv_qty = iv_qty iv_pct = iv_pct ).
    rv_text = |Excess { condense( |{ iv_so ALPHA = OUT }| ) }/{ CONV i( iv_item ) }: | &&
              |net { lv_net DECIMALS = 3 } > { lv_allowed DECIMALS = 3 }|.
  ENDMETHOD.

  METHOD fill_order.
    SORT ct_items BY Material Createdat Salesdocument Salesitem.
  ENDMETHOD.

  METHOD fill_first.
    DATA lt_sorted TYPE tt_items.
    DATA lt_grp    TYPE tt_items.
    DATA lt_part   TYPE STANDARD TABLE OF ty_net WITH EMPTY KEY.
    DATA lv_rest   TYPE decfloat34.
    DATA lv_room   TYPE decfloat34.
    DATA lv_add    TYPE decfloat34.
    DATA lv_idx    TYPE i.

    lt_sorted = it_items.
    fill_order( CHANGING ct_items = lt_sorted ).

    LOOP AT lt_sorted INTO DATA(ls_grp) GROUP BY ls_grp-Material INTO DATA(lv_mat).
      CLEAR: lt_grp, lt_part.
      LOOP AT GROUP lv_mat INTO DATA(ls_member).
        APPEND ls_member TO lt_grp.
        APPEND VALUE #( salesdocument = ls_member-Salesdocument
                        salesitem     = ls_member-Salesitem ) TO lt_part.
      ENDLOOP.
      lv_rest = iv_net.

      " 1. oldest line first, each up to its assigned qty
      LOOP AT lt_grp INTO DATA(ls_1).
        lv_idx = sy-tabix.
        IF lv_rest <= 0.
          EXIT.
        ENDIF.
        lv_room = ls_1-Quantity.
        lv_add  = COND #( WHEN lv_rest < lv_room THEN lv_rest ELSE lv_room ).
        lt_part[ lv_idx ]-net = lv_add.
        lv_rest = lv_rest - lv_add.
      ENDLOOP.

      " 2. more than all assigned qty: each line up to its tolerance
      LOOP AT lt_grp INTO DATA(ls_2).
        lv_idx = sy-tabix.
        IF lv_rest <= 0.
          EXIT.
        ENDIF.
        lv_room = allowed( iv_qty = ls_2-Quantity iv_pct = ls_2-Overdeltolpct ) - ls_2-Quantity.
        lv_add  = COND #( WHEN lv_rest < lv_room THEN lv_rest ELSE lv_room ).
        lt_part[ lv_idx ]-net = lt_part[ lv_idx ]-net + lv_add.
        lv_rest = lv_rest - lv_add.
      ENDLOOP.

      " 3. still more: the last line carries it (shows as Excess)
      IF lv_rest > 0 AND lt_part IS NOT INITIAL.
        lv_idx = lines( lt_part ).
        lt_part[ lv_idx ]-net = lt_part[ lv_idx ]-net + lv_rest.
      ENDIF.

      INSERT LINES OF lt_part INTO TABLE rt_net.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
*----------------------------------------------------------------*
* Weighbridge REST client (local helper)
*----------------------------------------------------------------*
CLASS lcl_weighbridge DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS c_api_key TYPE string VALUE 'enviro-1-15sep-2026-wb1-mm'.

    TYPES ty_weight TYPE zsdge_sentry_ht1-tarewt.
    TYPES ty_mcno   TYPE c LENGTH 10.
    TYPES ty_mcndes TYPE c LENGTH 60.

    TYPES: BEGIN OF ty_reading,
             ok      TYPE abap_bool,
             weight  TYPE ty_weight,
             mcno    TYPE ty_mcno,
             mcndes  TYPE ty_mcndes,
             message TYPE string,
           END OF ty_reading.

    "! GET <machine URL>/weight
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

    "! New Code added on 26.10.2026
    "! This code will get the weighment after save image
    TYPES: BEGIN OF ty_record,
             ok         TYPE abap_bool,
             message    TYPE string,
             wb_wt      TYPE string,
             rowid_seq  TYPE string,
             ocr_text   TYPE string,
             timestamp  TYPE string,
             camview_ip TYPE string,
             image1     TYPE string,
             image2     TYPE string,
             image3     TYPE string,
             image4     TYPE string,
           END OF ty_record.

    "! The record of one camera capture, images as base64 JPEG
    CLASS-METHODS get_Weight_record
      IMPORTING iv_rowid_seq     TYPE clike
      RETURNING VALUE(rs_record) TYPE ty_record.


    CLASS-METHODS machine_text
      IMPORTING iv_mcno          TYPE clike
      RETURNING VALUE(rv_text)   TYPE ty_mcndes.

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

    CONSTANTS c_base_url TYPE string VALUE 'https://camview.nrxen.com'.
    CONSTANTS c_auth_key TYPE string VALUE '92n09wv84m03v'.

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
    SELECT SINGLE text FROM zsd_weight_vh
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

    " yymmddhhmmss + machine code, e.g. 26100818300002 (CamView rowid_seq)
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
        " the weight is already saved; the user gets a warning and can recapture
        rs_launch-message = |Camera launch error: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD get_Weight_record.

    DATA lv_seq TYPE string.
    lv_seq = iv_rowid_seq.
    CONDENSE lv_seq NO-GAPS.
    IF lv_seq IS INITIAL.
      rs_record-message = `No image sequence number (camera not launched)`.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                            cl_http_destination_provider=>create_by_url(
                              |{ c_base_url }/record_with_image?rowid_seq={ lv_seq }| ) ).
        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_header_field( i_name = 'auth_key' i_value = c_auth_key ).
        lo_request->set_header_field( i_name = 'Accept'   i_value = 'application/json' ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        DATA(ls_status)   = lo_response->get_status( ).
        DATA(lv_body)     = lo_response->get_text( ).
        lo_client->close( ).

        IF ls_status-code <> 200.
          rs_record-message = |CamView { ls_status-code } { ls_status-reason } for seq { lv_seq }: { substring( val = lv_body len = nmin( val1 = strlen( lv_body ) val2 = 200 ) ) }|.
          RETURN.
        ENDIF.

        /ui2/cl_json=>deserialize( EXPORTING json = lv_body
                                   CHANGING  data = rs_record ).
        CLEAR rs_record-message.
        IF rs_record-rowid_seq IS INITIAL.
          rs_record-message = |No CamView record for seq { lv_seq }: { substring( val = lv_body len = nmin( val1 = strlen( lv_body ) val2 = 200 ) ) }|.
          RETURN.
        ENDIF.
        rs_record-ok = abap_true.

      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_record-message = |CamView error: { lx_error->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Camera launch + image verification status (local helper)
* Launches the camera and, when it started, stores the seqno on the
* header for the stage (T tare / G gross) with status P (pending),
* so the entry shows up in the Image Verification app. A new gross
* capture also clears Imagevalid: the new images are not approved.
* 03.11.2026: manual weighment = no camera, status N (not required);
* a manual gross also sets Imagevalid (Create Delivery released).
*----------------------------------------------------------------*
CLASS lcl_camera DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS: c_tare  TYPE c LENGTH 1 VALUE 'T',
               c_gross TYPE c LENGTH 1 VALUE 'G'.

    "! set by ApplyWeight while it runs ManualFetchTWt: no new camera
    "! launch and no status reset (ApplyWeight sets the status itself)
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

    "! 03.11.2026: manual weighment - no camera, the stage needs no image
    "! verification (status N). Gross also sets Imagevalid, so Create
    "! Delivery is released.
    CLASS-METHODS not_required
      IMPORTING iv_is_draft    TYPE abp_behv_flag
                iv_uuid        TYPE sysuuid_x16
                iv_stage       TYPE c
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS lcl_camera IMPLEMENTATION.

  METHOD launch.
    DATA(lv_stage) = COND string( WHEN iv_stage = c_tare THEN `Tare` ELSE `Gross` ).

    rs_launch = lcl_weighbridge=>launch_camera( iv_mcno ).
    IF rs_launch-ok = abap_false.
      rs_launch-message = |{ rs_launch-message }. Use Recapture { lv_stage }.|.
      RETURN.
    ENDIF.

    IF iv_stage = c_tare.
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Imgseqnotare Imgvrstatustare Imgrejreason Imgstatustaretext Imgcrittare )
          WITH VALUE #( ( %is_draft         = iv_is_draft
                          Uuid              = iv_uuid
                          Imgseqnotare      = rs_launch-seqno
                          Imgvrstatustare   = 'P'
                          Imgrejreason      = ''
                          Imgstatustaretext = 'Pending'      " CDS texts are not recalculated in the draft
                          Imgcrittare       = 2 ) ).
    ELSE.
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Imgseqnogross Imgvrstatusgross Imgrejreason Imagevalid Imgstatusgrosstext Imgcritgross )
          WITH VALUE #( ( %is_draft          = iv_is_draft
                          Uuid               = iv_uuid
                          Imgseqnogross      = rs_launch-seqno
                          Imgvrstatusgross   = 'P'
                          Imgrejreason       = ''
                          Imagevalid         = ''
                          Imgstatusgrosstext = 'Pending'
                          Imgcritgross       = 2 ) ).
    ENDIF.

    rs_launch-message = |{ lv_stage } images captured (seq { rs_launch-seqno }), sent for verification|.
  ENDMETHOD.

  METHOD severity.
    rv_severity = COND #( WHEN is_launch-ok = abap_true
                          THEN if_abap_behv_message=>severity-success
                          ELSE if_abap_behv_message=>severity-warning ).
  ENDMETHOD.

  METHOD not_required.
    IF iv_stage = c_tare.
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Imgseqnotare Imgvrstatustare Imgrejreason Imgstatustaretext Imgcrittare )
          WITH VALUE #( ( %is_draft         = iv_is_draft
                          Uuid              = iv_uuid
                          Imgseqnotare      = ''
                          Imgvrstatustare   = 'N'
                          Imgrejreason      = ''
                          Imgstatustaretext = 'Not required'   " CDS texts are not recalculated in the draft
                          Imgcrittare       = 3 ) ).
      rv_text = `Tare saved (manual weighment, no image verification)`.
    ELSE.
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Imgseqnogross Imgvrstatusgross Imgrejreason Imagevalid Imgstatusgrosstext Imgcritgross )
          WITH VALUE #( ( %is_draft          = iv_is_draft
                          Uuid               = iv_uuid
                          Imgseqnogross      = ''
                          Imgvrstatusgross   = 'N'
                          Imgrejreason       = ''
                          Imagevalid         = 'X'
                          Imgstatusgrosstext = 'Not required'
                          Imgcritgross       = 3 ) ).
      rv_text = `Gross saved (manual weighment, no image verification)`.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Standard S/4 delivery APIs (local helper)
* API_OUTBOUND_DELIVERY_SRV / API_CUSTOMER_RETURNS_DELIVERY_SRV, both
* in S/4 scenario SAP_COM_0106. Same calls as the S/4 DeliveryPG and
* UpDlyheadertext, but through the communication arrangement of
* ZMMGE_S4_PLANT_CS (empty path prefix) instead of a hardcoded user.
*----------------------------------------------------------------*
CLASS lcl_s4_delivery DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_result,
             ok      TYPE abap_bool,
             message TYPE string,
           END OF ty_result.

    TYPES: BEGIN OF ty_text,
             id   TYPE c LENGTH 4,
             text TYPE string,
           END OF ty_text,
           tt_text TYPE STANDARD TABLE OF ty_text WITH EMPTY KEY.

    "! PostGoodsIssue (SD1, outbound delivery) or PostGoodsReceipt (SD2, returns delivery)
    CLASS-METHODS post_goods_movement
      IMPORTING iv_gateentrytype TYPE clike
                iv_delivery      TYPE clike
      RETURNING VALUE(rs_result) TYPE ty_result.

    TYPES: BEGIN OF ty_item_sloc,
             item            TYPE n LENGTH 6,
             storagelocation TYPE c LENGTH 4,
           END OF ty_item_sloc,
           tt_item_sloc TYPE STANDARD TABLE OF ty_item_sloc WITH EMPTY KEY.

    "! PATCH StorageLocation on the delivery items (A_OutbDeliveryItem /
    "! A_ReturnsDeliveryItem). I_OutboundDeliveryItemTP can't change it,
    "! and PGI fails without it.
    CLASS-METHODS set_storage_locations
      IMPORTING iv_gateentrytype TYPE clike
                iv_delivery      TYPE clike
                it_items         TYPE tt_item_sloc
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! one A_OutbDeliveryHeaderText per text
    CLASS-METHODS add_header_texts
      IMPORTING iv_delivery      TYPE clike
                it_texts         TYPE tt_text
      RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.
    CONSTANTS c_outbound TYPE string VALUE '/sap/opu/odata/sap/API_OUTBOUND_DELIVERY_SRV;v=0002'.
    CONSTANTS c_returns  TYPE string VALUE '/sap/opu/odata/sap/API_CUSTOMER_RETURNS_DELIVERY_SRV;v=0002'.

    CLASS-METHODS new_client
      RETURNING VALUE(ro_client) TYPE REF TO if_web_http_client
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error.

    "! error.message.value of an OData error, else the HTTP status
    CLASS-METHODS error_text
      IMPORTING io_response    TYPE REF TO if_web_http_response
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS lcl_s4_delivery IMPLEMENTATION.

  METHOD new_client.
    ro_client = cl_web_http_client_manager=>create_by_http_destination(
                  cl_http_destination_provider=>create_by_comm_arrangement(
                    comm_scenario = 'ZMMGE_S4_PLANT_CS'
                    service_id    = 'ZMMGE_S4_PLANT_REST' ) ).
  ENDMETHOD.

  METHOD error_text.
    TYPES: BEGIN OF ty_msg,
             value TYPE string,
           END OF ty_msg,
           BEGIN OF ty_err,
             code    TYPE string,
             message TYPE ty_msg,
           END OF ty_err,
           BEGIN OF ty_body,
             error TYPE ty_err,
           END OF ty_body.
    DATA ls_body TYPE ty_body.

    DATA(ls_status) = io_response->get_status( ).
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json = io_response->get_text( )
                                   CHANGING  data = ls_body ).
      CATCH cx_web_message_error.
        CLEAR ls_body.
    ENDTRY.

    rv_text = COND #( WHEN ls_body-error-message-value IS NOT INITIAL
                      THEN ls_body-error-message-value
                      ELSE |HTTP { ls_status-code } { ls_status-reason }| ).
  ENDMETHOD.

  METHOD post_goods_movement.
    DATA lt_actions TYPE string_table.
    DATA lv_csrf    TYPE string.

    DATA(lv_delivery) = condense( CONV string( iv_delivery ) ).
    DATA(lv_returns)  = xsdbool( condense( CONV string( iv_gateentrytype ) ) = `SD2` ).

    DATA(lv_root)   = COND string( WHEN lv_returns = abap_true THEN c_returns ELSE c_outbound ).
    DATA(lv_entity) = COND string( WHEN lv_returns = abap_true
                                   THEN |A_ReturnsDeliveryHeader(DeliveryDocument='{ lv_delivery }')|
                                   ELSE |A_OutbDeliveryHeader(DeliveryDocument='{ lv_delivery }')| ).

    " SD1: pick all items first. The picking update in S/4 only sets the
    " delivery quantity; PGI then failed with "Delivery has not yet been
    " picked (completely)". PickAllItems picks that quantity.
    IF lv_returns = abap_true.
      lt_actions = VALUE #( ( |PostGoodsReceipt?DeliveryDocument='{ lv_delivery }'| ) ).
    ELSE.
      lt_actions = VALUE #( ( |PickAllItems?DeliveryDocument='{ lv_delivery }'| )
                            ( |PostGoodsIssue?DeliveryDocument='{ lv_delivery }'| ) ).
    ENDIF.

    TRY.
        DATA(lo_client)  = new_client( ).
        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

        LOOP AT lt_actions INTO DATA(lv_action).

          " 1. GET the delivery: current ETag (and the CSRF token the first time)
          lo_request->set_uri_path( |{ lv_root }/{ lv_entity }| ).
          lo_request->delete_header_field( 'If-Match' ).
          lo_request->set_header_field( i_name  = 'X-CSRF-Token'
                                        i_value = COND #( WHEN lv_csrf IS INITIAL THEN `fetch` ELSE lv_csrf ) ).
          DATA(lo_get) = lo_client->execute( if_web_http_client=>get ).
          IF lo_get->get_status( )-code <> 200.
            rs_result-message = |Delivery { lv_delivery }: { error_text( lo_get ) }|.
            lo_client->close( ).
            RETURN.
          ENDIF.
          IF lv_csrf IS INITIAL.
            lv_csrf = lo_get->get_header_field( 'x-csrf-token' ).
          ENDIF.
          DATA(lv_etag) = lo_get->get_header_field( 'etag' ).
          IF lv_csrf IS INITIAL OR lv_etag IS INITIAL.
            rs_result-message = |CSRF token or ETag not received for delivery { lv_delivery }|.
            lo_client->close( ).
            RETURN.
          ENDIF.

          " 2. POST the action
          lo_request->set_uri_path( |{ lv_root }/{ lv_action }| ).
          lo_request->set_header_field( i_name = 'X-CSRF-Token' i_value = lv_csrf ).
          lo_request->set_header_field( i_name = 'If-Match'     i_value = lv_etag ).
          lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
          DATA(lo_post) = lo_client->execute( if_web_http_client=>post ).
          DATA(lv_code) = lo_post->get_status( )-code.
          IF lv_code < 200 OR lv_code >= 300.
            rs_result-message = |{ segment( val = lv_action index = 1 sep = `?` ) }: { error_text( lo_post ) }|.
            lo_client->close( ).
            RETURN.
          ENDIF.
        ENDLOOP.

        rs_result-ok = abap_true.
        lo_client->close( ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error INTO DATA(lx_error).
        rs_result-message = |S/4 not reachable: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD set_storage_locations.
    DATA lt_errors TYPE string_table.
    DATA lv_csrf   TYPE string.

    DATA(lv_delivery) = condense( CONV string( iv_delivery ) ).
    DATA(lv_returns)  = xsdbool( condense( CONV string( iv_gateentrytype ) ) = `SD2` ).
    DATA(lv_root)     = COND string( WHEN lv_returns = abap_true THEN c_returns ELSE c_outbound ).
    DATA(lv_set)      = COND string( WHEN lv_returns = abap_true THEN `A_ReturnsDeliveryItem` ELSE `A_OutbDeliveryItem` ).

    TRY.
        DATA(lo_client)  = new_client( ).
        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

        LOOP AT it_items INTO DATA(ls_item) WHERE storagelocation IS NOT INITIAL.
          lo_request->set_uri_path( |{ lv_root }/{ lv_set }(DeliveryDocument='{ lv_delivery }',| &&
                                    |DeliveryDocumentItem='{ ls_item-item }')| ).

          " GET: ETag of the item (and the CSRF token the first time)
          lo_request->set_text( `` ).
          lo_request->delete_header_field( 'If-Match' ).   " ETag of the previous item
          lo_request->set_header_field( i_name = 'X-CSRF-Token'
                                        i_value = COND #( WHEN lv_csrf IS INITIAL THEN `fetch` ELSE lv_csrf ) ).
          DATA(lo_get) = lo_client->execute( if_web_http_client=>get ).
          IF lo_get->get_status( )-code <> 200.
            APPEND |Item { ls_item-item }: { error_text( lo_get ) }| TO lt_errors.
            CONTINUE.
          ENDIF.
          IF lv_csrf IS INITIAL.
            lv_csrf = lo_get->get_header_field( 'x-csrf-token' ).
          ENDIF.
          DATA(lv_etag) = lo_get->get_header_field( 'etag' ).

          " PATCH StorageLocation
          lo_request->set_header_field( i_name = 'X-CSRF-Token' i_value = lv_csrf ).
          lo_request->set_header_field( i_name = 'If-Match'     i_value = lv_etag ).
          lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
          lo_request->set_text( |\{"StorageLocation":"{ ls_item-storagelocation }"\}| ).
          DATA(lo_patch) = lo_client->execute( if_web_http_client=>patch ).
          IF lo_patch->get_status( )-code <> 204 AND lo_patch->get_status( )-code <> 200.
            APPEND |Item { ls_item-item }: { error_text( lo_patch ) }| TO lt_errors.
          ENDIF.
        ENDLOOP.
        lo_client->close( ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error INTO DATA(lx_error).
        APPEND |S/4 not reachable: { lx_error->get_text( ) }| TO lt_errors.
    ENDTRY.

    rs_result-ok      = xsdbool( lt_errors IS INITIAL ).
    rs_result-message = concat_lines_of( table = lt_errors sep = `; ` ).
  ENDMETHOD.

  METHOD add_header_texts.
    DATA lt_errors TYPE string_table.
    DATA(lv_delivery) = condense( CONV string( iv_delivery ) ).

    TRY.
        DATA(lo_client)  = new_client( ).
        DATA(lo_request) = lo_client->get_http_request( ).

        " CSRF token from the service root
        lo_request->set_uri_path( |{ c_outbound }/| ).
        lo_request->set_header_field( i_name = 'Accept'       i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'X-CSRF-Token' i_value = 'fetch' ).
        DATA(lo_get) = lo_client->execute( if_web_http_client=>get ).
        DATA(lv_csrf) = lo_get->get_header_field( 'x-csrf-token' ).
        IF lv_csrf IS INITIAL.
          rs_result-message = |CSRF token not received ({ error_text( lo_get ) })|.
          lo_client->close( ).
          RETURN.
        ENDIF.

        lo_request->set_uri_path( |{ c_outbound }/A_OutbDeliveryHeaderText| ).
        lo_request->set_header_field( i_name = 'X-CSRF-Token' i_value = lv_csrf ).
        lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).

        LOOP AT it_texts INTO DATA(ls_text).
          lo_request->set_text( |\{"DeliveryDocument":"{ lv_delivery }","TextElement":"{ ls_text-id }",| &&
                                |"Language":"EN","TextElementText":"{ escape( val    = ls_text-text
                                                                               format = cl_abap_format=>e_json_string ) }"\}| ).
          DATA(lo_post) = lo_client->execute( if_web_http_client=>post ).
          IF lo_post->get_status( )-code <> 201.
            APPEND |{ ls_text-id }: { error_text( lo_post ) }| TO lt_errors.
          ENDIF.
        ENDLOOP.
        lo_client->close( ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error INTO DATA(lx_error).
        APPEND |S/4 not reachable: { lx_error->get_text( ) }| TO lt_errors.
    ENDTRY.

    rs_result-ok      = xsdbool( lt_errors IS INITIAL ).
    rs_result-message = concat_lines_of( table = lt_errors sep = `; ` ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Header
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

    METHODS RecaptureTare FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~RecaptureTare RESULT result.

    METHODS RecaptureGross FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~RecaptureGross RESULT result.

    METHODS ApplyWeight FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~ApplyWeight RESULT result.

    METHODS CancelGateEntry FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~CancelGateEntry RESULT result.

    METHODS CrtDelivery FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~CrtDelivery RESULT result.

    METHODS PickingQty FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~PickingQty RESULT result.

    METHODS DeliveryPG FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~DeliveryPG RESULT result.

    METHODS UpDlyheadertext FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~UpDlyheadertext RESULT result.

    METHODS TransExit FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~TransExit RESULT result.

    METHODS Weighmentslip FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~Weighmentslip RESULT result.

    METHODS Resplit FOR MODIFY
      IMPORTING keys FOR ACTION WeightHead~Resplit RESULT result.

ENDCLASS.

CLASS lhc_WeightHead IMPLEMENTATION.

  METHOD get_instance_features.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Cancelgateentry Deliyindicator Imagevalid Pickqtyindicator Giindicator Gateentrytype
                 Tarewt Imgseqnotare Imgseqnogross Imgvrstatustare Imgvrstatusgross Tarewtsts Grosswtsts )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        FIELDS ( Netweight Grossweight Quantity Overdeltolpct Deliveryno )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).

      DATA(lv_cancelled) = xsdbool( ls_head-Cancelgateentry IS NOT INITIAL ).

      " 03.11.2026: the first (tare) weighment fixes the mode for the entry
      "   manual = status N; auto = camera seq stored or CamView weight awaited
      DATA(lv_tare_manual) = xsdbool( ls_head-Imgvrstatustare = 'N' ).
      DATA(lv_tare_auto)   = xsdbool( lv_tare_manual = abap_false
                                      AND ( ls_head-Imgseqnotare IS NOT INITIAL OR ls_head-Tarewtsts = 'P' ) ).

      " all items weighed? any gross yet? any line above assigned qty + tolerance?
      DATA(lv_items)      = 0.
      DATA(lv_unweighed)  = 0.
      DATA(lv_gross_done) = abap_false.
      DATA(lv_excess)     = abap_false.
      LOOP AT lt_item INTO DATA(ls_item) WHERE Uuid = ls_head-Uuid.
        lv_items += 1.
        IF ls_item-Netweight IS INITIAL.
          lv_unweighed += 1.
        ENDIF.
        IF ls_item-Grossweight IS NOT INITIAL.
          lv_gross_done = abap_true.
        ENDIF.
        IF lcl_load=>is_excess( iv_net      = ls_item-Netweight
                                iv_qty      = ls_item-Quantity
                                iv_pct      = ls_item-Overdeltolpct
                                iv_delivery = ls_item-Deliveryno ) = abap_true.
          lv_excess = abap_true.
        ENDIF.
      ENDLOOP.
      DATA(lv_all_weighed) = xsdbool( lv_items > 0 AND lv_unweighed = 0 ).

      DATA(lv_open) = COND #( WHEN lv_cancelled = abap_true
                              THEN if_abap_behv=>fc-o-disabled
                              ELSE if_abap_behv=>fc-o-enabled ).

      " S/4 postings commit in S/4 at once. In edit mode (draft) a later
      " Discard would lose the S/4 document number, so these actions are
      " only offered on the saved entry.
      DATA(lv_post_blocked) = xsdbool( lv_cancelled = abap_true OR ls_head-%is_draft = if_abap_behv=>mk-on ).

      APPEND VALUE #(
        %tky    = ls_head-%tky
        %update = lv_open

        %action-Edit            = lv_open
        %action-AutoFetchWt     = COND #( WHEN lv_cancelled = abap_true OR lv_tare_manual = abap_true
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled )
        %action-ManualFetchWt   = COND #( WHEN lv_cancelled = abap_true OR lv_tare_auto = abap_true
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled )
        %action-CancelGateEntry = lv_open
        %action-TransExit       = COND #( WHEN lv_post_blocked = abap_true
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled )

        " recapture: the stage was rejected, or its camera launch failed
        " 03.11.2026: not for a manual weighment (status N = no images needed)
        %action-RecaptureTare = COND #( WHEN lv_cancelled = abap_true OR ls_head-Imgvrstatustare = 'N'
                                        THEN if_abap_behv=>fc-o-disabled
                                        WHEN ls_head-Imgvrstatustare = 'R'
                                          OR ( ls_head-Tarewt IS NOT INITIAL AND ls_head-Imgseqnotare IS INITIAL )
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )

        %action-RecaptureGross = COND #( WHEN lv_cancelled = abap_true OR ls_head-Imgvrstatusgross = 'N'
                                         THEN if_abap_behv=>fc-o-disabled
                                         WHEN ls_head-Imgvrstatusgross = 'R'
                                           OR ( lv_all_weighed = abap_true AND ls_head-Imgseqnogross IS INITIAL )
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled )

        " 06.11.2026: Create Delivery claims the S/4 qty itself (Resplit), so it
        " stays pressable while a line is in Excess; CrtDelivery refuses if the
        " S/4 open qty is still too small
        %action-CrtDelivery = COND #( WHEN ls_head-Deliyindicator = 'X' OR lv_post_blocked = abap_true
                                      THEN if_abap_behv=>fc-o-disabled
                                      WHEN lv_all_weighed = abap_true AND ls_head-Imagevalid = 'X'
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled )

        " 05.11.2026: split the net again after Sales changed the lines
        %action-Resplit = COND #( WHEN lv_cancelled = abap_true OR ls_head-Deliyindicator = 'X'
                                    OR lv_gross_done = abap_false
                                  THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled )

        %action-PickingQty = COND #( WHEN ls_head-Pickqtyindicator = 'X' OR ls_head-Gateentrytype = 'SD2'
                                          OR lv_post_blocked = abap_true
                                     THEN if_abap_behv=>fc-o-disabled
                                     WHEN ls_head-Deliyindicator = 'X'
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled )

        %action-DeliveryPG = COND #( WHEN ls_head-Giindicator = 'X' OR lv_post_blocked = abap_true
                                     THEN if_abap_behv=>fc-o-disabled
                                     WHEN ls_head-Pickqtyindicator = 'X' OR ls_head-Gateentrytype = 'SD2'
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled )

        %action-Weighmentslip   = if_abap_behv=>fc-o-enabled
        %action-UpDlyheadertext = COND #( WHEN lv_post_blocked = abap_true
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled )

        " CamView: only while a weight is awaited
        %action-ApplyWeight = COND #( WHEN ls_head-Tarewtsts = 'P' OR ls_head-Grosswtsts = 'P'
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled )
      ) TO result.

    ENDLOOP.
  ENDMETHOD.

  METHOD AutoFetchWt.
    " CamView push (2026-10-30): no GET /weight. Launch the tare camera
    " (stores the tare seqno) and set Tarewtsts = 'P'. CamView posts the
    " weight with that seqno to ZMM_WB_WEIGHT (stored in ZMMGE_WB_READ);
    " the app's polling runs ApplyWeight, which writes the tare.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        FIELDS ( Uuid ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA(ls_param) = keys[ KEY id %tky = ls_head-%tky ]-%param.

      DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = ls_head-%is_draft
                                            iv_uuid     = ls_head-Uuid
                                            iv_mcno     = ls_param-Weighmentmcno
                                            iv_stage    = lcl_camera=>c_tare ).
      IF ls_launch-ok = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_launch-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      DATA(lv_itemcount) = REDUCE i( INIT n = 0 FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid ) NEXT n = n + 1 ).

      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Tarewtsts Weighmentmcno Weighmentmcndes Imagecount )
          WITH VALUE #( ( %tky            = ls_head-%tky
                          Tarewtsts       = 'P'
                          Weighmentmcno   = ls_param-Weighmentmcno
                          Weighmentmcndes = lcl_weighbridge=>machine_text( ls_param-Weighmentmcno )
                          Imagecount      = lv_itemcount ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Tare capture started (seq { ls_launch-seqno })| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ManualFetchWt.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Uuid ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        FIELDS ( Uuid ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA(ls_param) = keys[ KEY id %tky = ls_head-%tky ]-%param.

      IF ls_param-Weight IS INITIAL OR ls_param-Unit IS INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = 'Weighment is empty' ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      lcl_weighbridge=>now( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).
      DATA(lv_itemcount) = REDUCE i( INIT n = 0 FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid ) NEXT n = n + 1 ).

      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Tarewt Weighuom Weighmentmcno Weighmentmcndes Weighmentdate Weighmenttime Imagecount Tarewtsts )
          WITH VALUE #( ( %tky            = ls_head-%tky
                          Tarewt          = ls_param-Weight
                          Weighuom        = ls_param-Unit
                          Weighmentmcno   = ls_param-Weighmentmcno
                          Weighmentmcndes = lcl_weighbridge=>machine_text( ls_param-Weighmentmcno )
                          Weighmentdate   = lv_date
                          Weighmenttime   = lv_time
                          Imagecount      = lv_itemcount
                          Tarewtsts       = '' ) )
        ENTITY WeightItem
          UPDATE FIELDS ( Tareweight )
          WITH VALUE #( FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid )
                        ( %tky = itm-%tky  Tareweight = ls_param-Weight ) ).

      " 03.11.2026: manual weighment - no camera, no image verification for the tare
      DATA(lv_text) = lcl_camera=>not_required( iv_is_draft = ls_head-%is_draft
                                                iv_uuid     = ls_head-Uuid
                                                iv_stage    = lcl_camera=>c_tare ).
      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = lv_text ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD RecaptureTare.
    " camera only, the tare weight stays (truck back on the weighbridge, empty)
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

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD RecaptureGross.
    " camera only, the gross / net weights stay (truck back on the weighbridge, loaded)
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

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ApplyWeight.
    " Called by the app (polling) while Tarewtsts / Grosswtsts = 'P'.
    " The reading comes from the released view ZI_MMGE_WB_READING (stored
    " by the CamView API ZMM_WB_WEIGHT). Silent while CamView has not
    " posted yet.
    DATA lt_gross TYPE TABLE FOR ACTION IMPORT zsd_ih_weight\\WeightItem~ManualFetchTWt.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Uuid Tarewtsts Grosswtsts Imgseqnotare Imgseqnogross Weighmentmcno )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        FIELDS ( Uuid Grosspending ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).

      " --- tare (header, empty truck) ---
      IF ls_head-Tarewtsts = 'P' AND ls_head-Imgseqnotare IS NOT INITIAL.
        SELECT SINGLE Weight FROM zi_mmge_wb_reading
          WHERE Seqno = @ls_head-Imgseqnotare
          INTO @DATA(lv_tare).
        IF sy-subrc = 0.
          lcl_weighbridge=>now( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).
          MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
            ENTITY WeightHead
              UPDATE FIELDS ( Tarewt Weighuom Weighmentdate Weighmenttime Tarewtsts )
              WITH VALUE #( ( %tky          = ls_head-%tky
                              Tarewt        = lv_tare
                              Weighuom      = 'TO'
                              Weighmentdate = lv_date
                              Weighmenttime = lv_time
                              Tarewtsts     = 'R' ) )
            ENTITY WeightItem
              UPDATE FIELDS ( Tareweight )
              WITH VALUE #( FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid )
                            ( %tky = itm-%tky  Tareweight = lv_tare ) ).
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                        text     = |Tare { lv_tare NUMBER = USER } TO received from CamView| ) )
                 TO reported-weighthead.
        ENDIF.
      ENDIF.

      " --- gross (items waiting, loaded truck): same net split as a manual
      "     gross weight, without a new camera launch ---
      IF ls_head-Grosswtsts = 'P' AND ls_head-Imgseqnogross IS NOT INITIAL.
        SELECT SINGLE Weight FROM zi_mmge_wb_reading
          WHERE Seqno = @ls_head-Imgseqnogross
          INTO @DATA(lv_gross).
        IF sy-subrc = 0.
          CLEAR lt_gross.
          LOOP AT lt_item INTO DATA(ls_item) WHERE Uuid = ls_head-Uuid AND Grosspending = 'X'.
            APPEND VALUE #( %tky   = ls_item-%tky
                            %param = VALUE #( Weight        = lv_gross
                                              Unit          = 'TO'
                                              Weighmentmcno = ls_head-Weighmentmcno ) ) TO lt_gross.
          ENDLOOP.

          IF lt_gross IS NOT INITIAL.
            lcl_camera=>gv_no_launch = abap_true.
            MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
              ENTITY WeightItem
                EXECUTE ManualFetchTWt FROM lt_gross
              FAILED   DATA(ls_fail_g)
              REPORTED DATA(ls_rep_g).
            lcl_camera=>gv_no_launch = abap_false.
            APPEND LINES OF ls_rep_g-weightitem TO reported-weightitem.

            " done either way: R when the net split worked, else '' so the
            " polling stops and the user sees the net weight error
            MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
              ENTITY WeightHead
                UPDATE FIELDS ( Grosswtsts )
                WITH VALUE #( ( %tky = ls_head-%tky
                                Grosswtsts = COND #( WHEN ls_fail_g IS INITIAL THEN 'R' ELSE '' ) ) )
              ENTITY WeightItem
                UPDATE FIELDS ( Grosspending )
                WITH VALUE #( FOR g IN lt_gross ( %tky = g-%tky  Grosspending = '' ) ).

            IF ls_fail_g IS INITIAL.
              APPEND VALUE #( %tky = ls_head-%tky
                              %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                            text     = |Gross { lv_gross NUMBER = USER } TO received from CamView| ) )
                     TO reported-weighthead.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD CancelGateEntry.
    MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        UPDATE FIELDS ( Cancelgateentry )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky  Cancelgateentry = 'X' ) ).

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD CrtDelivery.
    " 06.11.2026: claim + re-split first - Sales may have raised the SO in
    " S/4 after the gross weighment (Resplit: lines in Excess take up to
    " their net from S/4 open qty - other trucks). The Excess check below
    " then works on the new quantities.
    MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        EXECUTE Resplit FROM VALUE #( FOR k IN keys ( %tky = k-%tky ) )
      REPORTED DATA(ls_rep_split)
      FAILED   DATA(ls_fail_split).

    " pass on "Qty ... raised to ..." (and errors), not the split summary
    LOOP AT ls_rep_split-weighthead INTO DATA(ls_rep_s) WHERE %msg IS BOUND.
            IF ls_rep_s-%msg->m_severity = if_abap_behv_message=>severity-error
             OR ls_rep_s-%msg->if_message~get_text( ) CS 'raised'.
        APPEND ls_rep_s TO reported-weighthead.
      ENDIF.
    ENDLOOP.

    DATA lv_excess_text TYPE string.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).

      " 05.11.2026: no delivery while a line is above assigned qty + tolerance
      " (the button is disabled then; this covers a stale screen)
      CLEAR lv_excess_text.
      LOOP AT lt_item INTO DATA(ls_chk) WHERE Uuid = ls_head-Uuid.
        IF lcl_load=>is_excess( iv_net      = ls_chk-Netweight
                                iv_qty      = ls_chk-Quantity
                                iv_pct      = ls_chk-Overdeltolpct
                                iv_delivery = ls_chk-Deliveryno ) = abap_true.
          lv_excess_text = lcl_load=>excess_text( iv_so   = ls_chk-Salesdocument
                                                  iv_item = ls_chk-Salesitem
                                                  iv_net  = ls_chk-Netweight
                                                  iv_qty  = ls_chk-Quantity
                                                  iv_pct  = ls_chk-Overdeltolpct ).
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_excess_text IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_excess_text ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      " freight order per SO item (maintained in Sales Order Update; the
      " Weighment views don't carry the field) - added on 30.10.2026
      SELECT salesdocument, salesitem, freightorder
        FROM zsdge_sentry_it1
        WHERE uuid = @ls_head-Uuid
        INTO TABLE @DATA(lt_fo).

      DATA(ls_request) = VALUE zcl_sd_s4_owght_api=>ty_request(
        operation     = 'CRTDLV'
        gateentrytype = condense( CONV string( ls_head-Gateentrytype ) )
        items         = VALUE #( FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid )
                                 ( salesdocument              = itm-Salesdocument
                                   salesitem                  = itm-Salesitem
                                   material                   = itm-Material
                                   plant                      = itm-Plant
                                   storagelocation            = itm-Storagelocation
                                   netweight                  = itm-Netweight
                                   unit                       = itm-Baseunit
                                   independentrequirementtype = itm-Independentrequirementtype
                                   shippingpoint              = itm-Shippingpoint
                                   transportdocumentn         = ls_head-Trandocno           "custom field update added on 19.10.2026
                                   modeoftransport            = ls_head-Modeoftransport
                                   transportid                = ls_head-Transportid
                                   vehiclerrno                = ls_head-Vehicleno
                                   sdgateentryno              = ls_head-Gateentryno
                                   transportdocumentd         = ls_head-Trandocdate
                                   vehicletype                = ls_head-Vehicletype
                                   transportername            = ls_head-Transportname
                                   gateentrydate              = ls_head-Gateentrydate
                                   gateentrytime              = ls_head-Gateentrytime
                                   freightorder               = VALUE #( lt_fo[ salesdocument = itm-Salesdocument
                                                                                salesitem     = itm-Salesitem ]-freightorder OPTIONAL )
                                   ) ) ).
      SORT ls_request-items BY salesdocument salesitem.

      TRY.
          DATA(ls_response) = zcl_sd_s4_owght_api=>call( ls_request ).
        CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_conn).
          ls_response = VALUE #( message = |S/4 not reachable: { lx_conn->get_text( ) }| ).
      ENDTRY.

      IF ls_response-success = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_response-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      " delivery number on header and items (the S/4 saver did this)
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Deliveryno Deliyindicator Picqtindicator )
          WITH VALUE #( ( %tky           = ls_head-%tky
                          Deliveryno     = ls_response-deliveryno
                          Deliyindicator = 'X'
                          Picqtindicator = abap_true ) )
        ENTITY WeightItem
          UPDATE FIELDS ( Deliveryno Deliveritem )
          WITH VALUE #( FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid )
                        LET ls_dlv = VALUE zcl_sd_s4_owght_api=>ty_resp_item(
                                       ls_response-items[ salesdocument = itm-Salesdocument
                                                          salesitem     = itm-Salesitem ] OPTIONAL )
                        IN ( %tky        = itm-%tky
                             Deliveryno  = ls_response-deliveryno
                             Deliveritem = ls_dlv-deliveritem ) ).

      " information, not warning: a warning makes Fiori roll the action back
      " and ask to repeat it ("ignore warnings" dialog)
      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = COND #( WHEN ls_response-message IS INITIAL
                                                                           THEN if_abap_behv_message=>severity-success
                                                                           ELSE if_abap_behv_message=>severity-information )
                                                    text     = COND #( WHEN ls_response-message IS INITIAL
                                                                       THEN |Delivery { ls_response-deliveryno ALPHA = OUT } created|
                                                                       ELSE |Delivery { ls_response-deliveryno ALPHA = OUT }: { ls_response-message }| ) ) )
             TO reported-weighthead.

      " freight unit -> freight order (short text: messages are cut after 50 characters)
      IF ls_response-fomessage IS NOT INITIAL.
        DATA(lv_fo_sent) = VALUE #( ls_request-items[ 1 ]-freightorder OPTIONAL ).
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text(
                                 severity = COND #( WHEN ls_response-fomessage CS 'will be assigned'
                                                    THEN if_abap_behv_message=>severity-success
                                                    ELSE if_abap_behv_message=>severity-information )
                                 text     = COND #( WHEN ls_response-fomessage CS 'will be assigned'
                                                    THEN |Freight unit to FO { lv_fo_sent ALPHA = OUT } queued|
                                                    ELSE ls_response-fomessage ) ) )
               TO reported-weighthead.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD PickingQty.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).

      DATA(ls_request) = VALUE zcl_sd_s4_owght_api=>ty_request(
        operation  = 'PICK'
        deliveryno = ls_head-Deliveryno
        items      = VALUE #( FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid )
                              ( salesdocument = itm-Salesdocument
                                salesitem     = itm-Salesitem
                                deliveryno    = itm-Deliveryno
                                deliveritem   = itm-Deliveritem
                                netweight     = itm-Netweight
                                unit          = itm-Baseunit ) ) ).

      " every item needs its delivery item (filled by Create Delivery)
      IF ls_request-items IS INITIAL OR line_exists( ls_request-items[ deliveritem = '000000' ] ).
        DATA(ls_response) = VALUE zcl_sd_s4_owght_api=>ty_response(
                              message = 'The items have no delivery item yet. Create the delivery first.' ).
      ELSE.
        TRY.
            ls_response = zcl_sd_s4_owght_api=>call( ls_request ).
          CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_conn).
            ls_response = VALUE #( message = |S/4 not reachable: { lx_conn->get_text( ) }| ).
        ENDTRY.
      ENDIF.

      IF ls_response-success = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_response-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Pickqtyindicator )
          WITH VALUE #( ( %tky = ls_head-%tky  Pickqtyindicator = 'X' ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Picking quantity updated in delivery { ls_head-Deliveryno }| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD DeliveryPG.
    DATA ls_response TYPE zcl_sd_s4_owght_api=>ty_response.
    DATA ls_matdoc   TYPE zcl_sd_s4_owght_api=>ty_response.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).
      CLEAR: ls_response, ls_matdoc.

      " 1. broker / LC limits in S/4 (SD1 only; S/4 answers OK for SD2)
      IF ls_head-Deliveryno IS INITIAL.
        ls_response-message = 'Create the delivery first'.
      ELSE.
        TRY.
            ls_response = zcl_sd_s4_owght_api=>call( VALUE #(
                            operation     = 'PGICHECK'
                            gateentrytype = condense( CONV string( ls_head-Gateentrytype ) )
                            items         = VALUE #( FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid )
                                                     ( salesdocument = itm-Salesdocument
                                                       salesitem     = itm-Salesitem
                                                       netweight     = itm-Netweight ) ) ) ).
          CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_conn).
            ls_response-message = |S/4 not reachable: { lx_conn->get_text( ) }|.
        ENDTRY.
      ENDIF.

      IF ls_response-success = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_response-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      " 2a. storage location on the delivery items (standard API PATCH)
      DATA(ls_sloc) = lcl_s4_delivery=>set_storage_locations(
                        iv_gateentrytype = ls_head-Gateentrytype
                        iv_delivery      = ls_head-Deliveryno
                        it_items         = VALUE #( FOR itm IN lt_item WHERE ( Uuid = ls_head-Uuid )
                                                    ( item            = itm-Deliveritem
                                                      storagelocation = itm-Storagelocation ) ) ).
      IF ls_sloc-ok = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |Storage location: { ls_sloc-message }| ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      " 2b. PostGoodsIssue (SD1) / PostGoodsReceipt (SD2) - standard API
      DATA(ls_post) = lcl_s4_delivery=>post_goods_movement( iv_gateentrytype = ls_head-Gateentrytype
                                                            iv_delivery      = ls_head-Deliveryno ).
      IF ls_post-ok = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_post-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      " 3. material document of the goods movement
      TRY.
          ls_matdoc = zcl_sd_s4_owght_api=>call( VALUE #( operation  = 'MATDOC'
                                                          deliveryno = ls_head-Deliveryno ) ).
        CATCH cx_http_dest_provider_error cx_web_http_client_error.
          CLEAR ls_matdoc.
      ENDTRY.

      " the goods movement is posted: set the indicator even if the
      " material document can't be read yet, so PGI is not repeated
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Materialdocument Materialdocumentyear Giindicator )
          WITH VALUE #( ( %tky                 = ls_head-%tky
                          Materialdocument     = ls_matdoc-materialdocument
                          Materialdocumentyear = ls_matdoc-materialdocumentyear
                          Giindicator          = 'X' ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Goods movement posted for delivery { ls_head-Deliveryno }| &&
                                                               | (material document { ls_matdoc-materialdocument })| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD UpDlyheadertext.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Deliveryno Vehicleno Transportid ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).

      IF ls_head-Deliveryno IS INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Create the delivery first' ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      lcl_weighbridge=>now( IMPORTING ev_date = DATA(lv_date) ).

      " the same four texts as in S/4 (S/4 built the 4th but never sent it)
      DATA(ls_texts) = lcl_s4_delivery=>add_header_texts(
        iv_delivery = ls_head-Deliveryno
        it_texts    = VALUE #( ( id = 'JGVN' text = ls_head-Vehicleno )                       " vehicle no
                               ( id = 'JGEB' text = 'R' )                                     " vehicle type
                               ( id = 'JGTD' text = |{ lv_date DATE = ENVIRONMENT }| )        " transport date
                               ( id = 'Z018' text = |{ ls_head-Transportid ALPHA = OUT }| ) ) ). " transport ID

      IF ls_texts-ok = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_texts-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Header texts created for delivery { ls_head-Deliveryno }| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD TransExit.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Deliveryno ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).

      IF ls_head-Deliveryno IS INITIAL.
        DATA(ls_response) = VALUE zcl_sd_s4_owght_api=>ty_response(
                              message = 'The billing & E-Way Bill have not been generated.' ).
      ELSE.
        TRY.
            ls_response = zcl_sd_s4_owght_api=>call( VALUE #( operation  = 'BILLING'
                                                              deliveryno = ls_head-Deliveryno ) ).
          CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_conn).
            ls_response = VALUE #( message = |S/4 not reachable: { lx_conn->get_text( ) }| ).
        ENDTRY.
      ENDIF.

      IF ls_response-success = abap_false.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_response-message ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Transferexit Billingdocument Billingdocumentdate Einvoiceno
                          Einvoicedate Ewaybillno Ewaybilldate )
          WITH VALUE #( ( %tky                = ls_head-%tky
                          Transferexit        = 'X'
                          Billingdocument     = ls_response-billingdocument
                          Billingdocumentdate = ls_response-billingdocumentdate
                          Einvoiceno          = ls_response-einvoiceno
                          Einvoicedate        = ls_response-einvoicedate
                          Ewaybillno          = ls_response-ewaybillno
                          Ewaybilldate        = ls_response-ewaybilldate ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Transferred to exit (billing { ls_response-billingdocument })| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD Weighmentslip.
    " Weighment slip (2026-10-08): data XML from the slip service
    " ZSD_WEIGHT_SLIP (custom entity ZSD_CE_WEIGHT, class
    " ZWEIGH_FORM_IMP), rendered with the Adobe REST API through
    " ZCL_GE_ADOBE_PDF (form ZSD_WEIGHT_SLIP / template WEIGHMENT_SLIP),
    " stored in Attachmentwt like in S/4. The slip reads the SAVED data,
    " as in S/4. Print queue: later step.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Uuid Gateentryno ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).

      IF ls_head-Gateentryno IS INITIAL.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(lo_fdp)  = cl_fp_fdp_services=>get_instance( iv_service_definition = 'ZSD_WEIGHT_SLIP'
                                                             iv_root_node          = 'ZSD_CE_WEIGHT' ).
          DATA(lt_keys) = lo_fdp->get_keys( ).
          lt_keys[ name = 'UUID' ]-value = ls_head-Uuid.
          DATA(lv_xml)  = lo_fdp->read_to_xml( lt_keys ).

          DATA(lv_pdf)  = zcl_ge_adobe_pdf=>render( iv_form_name     = `ZSD_WEIGHT_SLIP`
                                                    iv_template_name = `WEIGHMENT_SLIP`
                                                    iv_xml_data      = lv_xml ).

        CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Slip data: { lx_fdp->get_text( ) }| ) )
                 TO reported-weighthead.
          CONTINUE.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Adobe: HTTP { lx_ads->mv_http_status_code } { lx_ads->mv_http_reason }| ) )
                 TO reported-weighthead.
          CONTINUE.
      ENDTRY.

      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Attachmentwt Mimetypewt Filenamewt )
          WITH VALUE #( ( %tky         = ls_head-%tky
                          Attachmentwt = lv_pdf
                          Mimetypewt   = 'application/pdf'
                          Filenamewt   = |Weighment Slip-{ ls_head-Gateentryno }.pdf| ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Weighment slip created for { ls_head-Gateentryno }| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.

  ENDMETHOD.

*----------------------------------------------------------------*
* SYSTEM: BTP ABAP Environment   Pool ZBP_SD_IH_WEIGHT (Local Types)
* METHOD Resplit - version 2 (05.11.2026)
* Business rule (user): Sales raises the SO qty in S/4; the gate entry
* takes it over at Re-split, no second edit in Sales Order Update.
* A line that would be in Excess first claims more of its SO item: up
* to the net weight it carries, but never more than S/4 open qty minus
* the qty on other trucks (ZCL_SD_GATE_INYARD_QTY=>get_free). Then the
* net is split by the (new) qty per material, as before.
*----------------------------------------------------------------*
  METHOD Resplit.
    " 09.11.2026: FILL FIRST - the net goes to the oldest SO line on the
    " truck first (lcl_load=>fill_first). If the truck carries more than
    " its lines allow (assigned qty + tolerance), the lines first claim
    " more of their SO item, oldest line first: up to the S/4 open qty
    " minus the qty on other trucks, until the whole net is covered.
    " The truck tare (header) is written to every line, also to lines
    " added after the tare weighment.
    TYPES: BEGIN OF ty_need,
             material TYPE zsdge_sentry_it1-material,
             need     TYPE decfloat34,
           END OF ty_need.
    DATA lt_update TYPE TABLE FOR UPDATE zsd_ih_weight\\WeightItem.
    DATA lt_claim  TYPE zcl_sd_gate_inyard_qty=>tt_key.
    DATA lt_need   TYPE HASHED TABLE OF ty_need WITH UNIQUE KEY material.
    DATA lt_mine   TYPE lcl_load=>tt_items.
    DATA lv_gross  TYPE zsdge_sentry_it1-grossweight.
    DATA lv_over   TYPE abap_bool.
    DATA lv_room   TYPE decfloat34.
    DATA lv_add    TYPE decfloat34.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        FIELDS ( Tarewt Gateentrytype Deliyindicator ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
      ENTITY WeightHead BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).
      CLEAR: lt_update, lv_gross, lt_claim, lt_need, lt_mine, lv_over.

      " the gross weight of the truck (the same on every weighed line)
      LOOP AT lt_item INTO DATA(ls_w) WHERE Uuid = ls_head-Uuid AND Grossweight IS NOT INITIAL.
        lv_gross = ls_w-Grossweight.
        EXIT.
      ENDLOOP.

      DATA(lv_net) = COND decfloat34( WHEN ls_head-Gateentrytype = 'SD2'
                                      THEN ls_head-Tarewt - lv_gross
                                      ELSE lv_gross - ls_head-Tarewt ).
      DATA(lv_error) = COND string( WHEN ls_head-Deliyindicator = 'X' THEN `Delivery already created`
                                    WHEN lv_gross IS INITIAL          THEN `No gross weight yet`
                                    WHEN lv_net <= 0                  THEN |Net Weight { lv_net } is Wrong| ).
      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-weighthead.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_error ) )
               TO reported-weighthead.
        CONTINUE.
      ENDIF.

      " the truck's lines, in fill order
      lt_mine = VALUE #( FOR i IN lt_item WHERE ( Uuid = ls_head-Uuid ) ( i ) ).
      lcl_load=>fill_order( CHANGING ct_items = lt_mine ).

      " 1. overloaded with the current qty? (only the last line can be)
      DATA(lt_first) = lcl_load=>fill_first( it_items = lt_mine iv_net = lv_net ).
      LOOP AT lt_mine INTO DATA(ls_c).
        IF lcl_load=>is_excess( iv_net      = VALUE decfloat34( lt_first[ salesdocument = ls_c-Salesdocument
                                                                          salesitem     = ls_c-Salesitem ]-net OPTIONAL )
                                iv_qty      = ls_c-Quantity
                                iv_pct      = ls_c-Overdeltolpct
                                iv_delivery = ls_c-Deliveryno ) = abap_true.
          lv_over = abap_true.
        ENDIF.
      ENDLOOP.

      " 2. claim: oldest line first, up to S/4 open qty - other trucks,
      "    until the net is covered by assigned qty (per material)
      IF lv_over = abap_true.
        LOOP AT lt_mine INTO DATA(ls_k).
          INSERT VALUE #( salesdocument = ls_k-Salesdocument salesitem = ls_k-Salesitem ) INTO TABLE lt_claim.
          DATA(lv_qty_mat) = REDUCE decfloat34( INIT s = CONV decfloat34( 0 )
                                                FOR m IN lt_mine WHERE ( Material = ls_k-Material )
                                                NEXT s = s + m-Quantity ).
          INSERT VALUE #( material = ls_k-Material need = lv_net - lv_qty_mat ) INTO TABLE lt_need.
        ENDLOOP.

        TRY.
            DATA(lt_free) = zcl_sd_gate_inyard_qty=>get_free( it_keys         = lt_claim
                                                              iv_exclude_uuid = ls_head-Uuid ).
            LOOP AT lt_mine ASSIGNING FIELD-SYMBOL(<ls_m>).
              ASSIGN lt_need[ material = <ls_m>-Material ] TO FIELD-SYMBOL(<ls_need>).
              IF sy-subrc <> 0 OR <ls_need>-need <= 0.
                CONTINUE.
              ENDIF.
              lv_room = VALUE #( lt_free[ salesdocument = <ls_m>-Salesdocument
                                          salesitem     = <ls_m>-Salesitem ]-free_qty OPTIONAL ).
              lv_room = lv_room - <ls_m>-Quantity.
              IF lv_room <= 0.
                CONTINUE.
              ENDIF.
              lv_add = COND #( WHEN <ls_need>-need < lv_room THEN <ls_need>-need ELSE lv_room ).
              <ls_m>-Quantity = <ls_m>-Quantity + lv_add.
              <ls_need>-need  = <ls_need>-need - lv_add.
              APPEND VALUE #( %tky = ls_head-%tky
                              %msg = new_message_with_text( severity = if_abap_behv_message=>severity-information
                                                            text     = |Qty { condense( |{ <ls_m>-Salesdocument ALPHA = OUT }| ) }/| &&
                                                                       |{ CONV i( <ls_m>-Salesitem ) } raised to { <ls_m>-Quantity }| ) )
                     TO reported-weighthead.
            ENDLOOP.
          CATCH cx_static_check INTO DATA(lx_free).
            APPEND VALUE #( %tky = ls_head-%tky
                            %msg = new_message_with_text( severity = if_abap_behv_message=>severity-information
                                                          text     = |S/4 open qty not read: { lx_free->get_text( ) }| ) )
                   TO reported-weighthead.
        ENDTRY.
      ENDIF.

      " 3. fill first with the (new) qty; truck tare on every line
      DATA(lt_split) = lcl_load=>fill_first( it_items = lt_mine iv_net = lv_net ).
      LOOP AT lt_mine INTO DATA(ls_item).
        APPEND VALUE #( %tky        = ls_item-%tky
                        Quantity    = ls_item-Quantity
                        Netweight   = VALUE #( lt_split[ salesdocument = ls_item-Salesdocument
                                                         salesitem     = ls_item-Salesitem ]-net OPTIONAL )
                        Grossweight = lv_gross
                        Tareweight  = ls_head-Tarewt ) TO lt_update.
      ENDLOOP.

      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightItem
          UPDATE FIELDS ( Quantity Netweight Grossweight Tareweight )
          WITH lt_update.

      " 4. lines still above assigned qty + tolerance (S/4 open qty too small)
      LOOP AT lt_update INTO DATA(ls_upd).
        DATA(ls_line) = VALUE #( lt_mine[ %tky = ls_upd-%tky ] OPTIONAL ).
        IF lcl_load=>is_excess( iv_net      = ls_upd-Netweight
                                iv_qty      = ls_upd-Quantity
                                iv_pct      = ls_line-Overdeltolpct
                                iv_delivery = ls_line-Deliveryno ) = abap_true.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-information
                                                        text     = lcl_load=>excess_text( iv_so   = ls_line-Salesdocument
                                                                                          iv_item = ls_line-Salesitem
                                                                                          iv_net  = ls_upd-Netweight
                                                                                          iv_qty  = ls_upd-Quantity
                                                                                          iv_pct  = ls_line-Overdeltolpct ) ) )
                 TO reported-weighthead.
        ENDIF.
      ENDLOOP.

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Net { lv_net DECIMALS = 3 } split over { lines( lt_update ) } lines| ) )
             TO reported-weighthead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Item
*----------------------------------------------------------------*
CLASS lhc_WeightItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    TYPES ty_items TYPE TABLE FOR READ RESULT zsd_ih_weight\\WeightItem.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR WeightItem RESULT result.

    " no item get_instance_authorizations: the item actions are checked with
    " the header's update authorization ( authorization : update in the BDEF)

    METHODS AutoFetchTWt FOR MODIFY
      IMPORTING keys FOR ACTION WeightItem~AutoFetchTWt RESULT result.

    METHODS ManualFetchTWt FOR MODIFY
      IMPORTING keys FOR ACTION WeightItem~ManualFetchTWt RESULT result.

    METHODS ImgCapture FOR MODIFY
      IMPORTING keys FOR ACTION WeightItem~ImgCapture RESULT result.

*    "! Share of the net weight for one item: OpenQty / OpenQty of all
*    "! selected items of the same material (S/4 logic). Falls back to
*    "! the order quantity when OpenQty is 0.
*    METHODS split_share
*      IMPORTING it_items        TYPE ty_items
*                is_item         TYPE LINE OF ty_items
*      RETURNING VALUE(rv_share) TYPE decfloat34.

ENDCLASS.

CLASS lhc_WeightItem IMPLEMENTATION.

  METHOD get_instance_features.
    " gross buttons: only after loading end, and only in the mode of the
    " tare weighment (03.11.2026: manual tare -> manual gross, auto -> auto)
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightItem BY \_Head
        FIELDS ( Loadendindi Imgvrstatustare Imgseqnotare Tarewtsts ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    LOOP AT keys INTO DATA(key).
      READ TABLE lt_head INTO DATA(ls_head) WITH KEY Uuid = key-Uuid.
      IF sy-subrc <> 0.
        CLEAR ls_head.
      ENDIF.

      DATA(lv_loaded)      = xsdbool( ls_head-Loadendindi = 'X' ).
      DATA(lv_tare_manual) = xsdbool( ls_head-Imgvrstatustare = 'N' ).
      DATA(lv_tare_auto)   = xsdbool( lv_tare_manual = abap_false
                                      AND ( ls_head-Imgseqnotare IS NOT INITIAL OR ls_head-Tarewtsts = 'P' ) ).

      APPEND VALUE #( %tky                  = key-%tky
                      %action-ImgCapture     = COND #( WHEN lv_loaded = abap_true
                                                       THEN if_abap_behv=>fc-o-enabled
                                                       ELSE if_abap_behv=>fc-o-disabled )
                      %action-AutoFetchTWt   = COND #( WHEN lv_loaded = abap_true AND lv_tare_manual = abap_false
                                                       THEN if_abap_behv=>fc-o-enabled
                                                       ELSE if_abap_behv=>fc-o-disabled )
                      %action-ManualFetchTWt = COND #( WHEN lv_loaded = abap_true AND lv_tare_auto = abap_false
                                                       THEN if_abap_behv=>fc-o-enabled
                                                       ELSE if_abap_behv=>fc-o-disabled ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

*  METHOD split_share.
*    DATA(lv_open_total) = REDUCE decfloat34( INIT s = CONV decfloat34( 0 )
*                                             FOR itm IN it_items WHERE ( Material = is_item-Material )
*                                             NEXT s = s + itm-OpenQty ).
*    IF lv_open_total > 0.
*      rv_share = is_item-OpenQty / lv_open_total.
*      RETURN.
*    ENDIF.
*
*    DATA(lv_qty_total) = REDUCE decfloat34( INIT s = CONV decfloat34( 0 )
*                                            FOR itm IN it_items WHERE ( Material = is_item-Material )
*                                            NEXT s = s + itm-Quantity ).
*    rv_share = COND #( WHEN lv_qty_total > 0 THEN is_item-Quantity / lv_qty_total ELSE 1 ).
*  ENDMETHOD.

  METHOD AutoFetchTWt.
    " CamView push (2026-10-30): no GET /weight. Launch the gross camera,
    " mark the selected items Grosspending = 'X' and the header
    " Grosswtsts = 'P'. ApplyWeight writes gross + net when CamView posts.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightItem
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item)
      ENTITY WeightItem BY \_Head
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    DATA(ls_head)  = VALUE #( lt_head[ 1 ] OPTIONAL ).
    DATA(ls_param) = VALUE #( keys[ 1 ]-%param OPTIONAL ).

    IF ls_head-Tarewt IS INITIAL.
      LOOP AT lt_item INTO DATA(ls_err).
        APPEND VALUE #( %tky = ls_err-%tky ) TO failed-weightitem.
        APPEND VALUE #( %tky        = ls_err-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = '1st Weighment (tare) is empty' ) )
               TO reported-weightitem.
      ENDLOOP.
      RETURN.
    ENDIF.

    " the weight now comes with the images, so the camera is always started
    DATA(ls_launch) = lcl_camera=>launch( iv_is_draft = ls_head-%is_draft
                                          iv_uuid     = ls_head-Uuid
                                          iv_mcno     = ls_param-Weighmentmcno
                                          iv_stage    = lcl_camera=>c_gross ).
    IF ls_launch-ok = abap_false.
      LOOP AT lt_item INTO ls_err.
        APPEND VALUE #( %tky = ls_err-%tky ) TO failed-weightitem.
        APPEND VALUE #( %tky = ls_err-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = ls_launch-message ) )
               TO reported-weightitem.
      ENDLOOP.
      RETURN.
    ENDIF.

    DATA(lv_mcndes) = lcl_weighbridge=>machine_text( ls_param-Weighmentmcno ).
    MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightHead
        UPDATE FIELDS ( Grosswtsts )
        WITH VALUE #( ( %tky = ls_head-%tky  Grosswtsts = 'P' ) )
      ENTITY WeightItem
        UPDATE FIELDS ( Grosspending Weighmentmcno Weighmentmcndes )
        WITH VALUE #( FOR itm IN lt_item ( %tky            = itm-%tky
                                           Grosspending    = 'X'
                                           Weighmentmcno   = ls_param-Weighmentmcno
                                           Weighmentmcndes = lv_mcndes ) ).

    APPEND VALUE #( %tky = lt_item[ 1 ]-%tky
                    %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                  text     = |Gross capture started (seq { ls_launch-seqno })| ) )
           TO reported-weightitem.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightItem ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ManualFetchTWt.
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightItem
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item)
      ENTITY WeightItem BY \_Head
        FIELDS ( Gateentrytype Imagecount Tarewt ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    DATA(ls_head)  = VALUE #( lt_head[ 1 ] OPTIONAL ).
    DATA(ls_param) = VALUE #( keys[ 1 ]-%param OPTIONAL ).

    IF ls_param-Weight IS INITIAL OR ls_param-Unit IS INITIAL.
      LOOP AT lt_item INTO DATA(ls_err).
        APPEND VALUE #( %tky = ls_err-%tky ) TO failed-weightitem.
        APPEND VALUE #( %tky        = ls_err-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = 'Weighment is empty' ) )
               TO reported-weightitem.
      ENDLOOP.
      RETURN.
    ENDIF.

    " 09.11.2026: net = gross - TRUCK tare (header), also for SO lines added
    " after the tare weighment; split FILL FIRST (oldest SO line first)
    DATA(lv_net) = COND decfloat34( WHEN ls_head-Gateentrytype = 'SD2'
                                    THEN ls_head-Tarewt - ls_param-Weight
                                    ELSE ls_param-Weight - ls_head-Tarewt ).
    IF lv_net <= 0.
      LOOP AT lt_item INTO ls_err.
        APPEND VALUE #( %tky = ls_err-%tky ) TO failed-weightitem.
        APPEND VALUE #( %tky        = ls_err-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = |Net Weight { lv_net } is Wrong| ) )
               TO reported-weightitem.
      ENDLOOP.
      RETURN.
    ENDIF.

    DATA(lt_split) = lcl_load=>fill_first( it_items = lt_item iv_net = lv_net ).
    DATA lt_update TYPE TABLE FOR UPDATE zsd_ih_weight\\WeightItem.
    LOOP AT lt_item INTO DATA(ls_item).
      APPEND VALUE #( %tky        = ls_item-%tky
                      Netweight   = VALUE #( lt_split[ salesdocument = ls_item-Salesdocument
                                                       salesitem     = ls_item-Salesitem ]-net OPTIONAL )
                      Grossweight = ls_param-Weight
                      Tareweight  = ls_head-Tarewt ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightItem
          UPDATE FIELDS ( Netweight Grossweight Tareweight )
          WITH lt_update.
    ENDIF.

    " a gross weight entered by the user ends a pending CamView gross.
    " When ApplyWeight runs this (gv_no_launch), ApplyWeight sets the status.
    IF lcl_camera=>gv_no_launch = abap_false AND lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zsd_ih_weight IN LOCAL MODE
        ENTITY WeightHead
          UPDATE FIELDS ( Grosswtsts )
          WITH VALUE #( ( %tky = ls_head-%tky  Grosswtsts = '' ) )
        ENTITY WeightItem
          UPDATE FIELDS ( Grosspending )
          WITH VALUE #( FOR u IN lt_update ( %tky = u-%tky  Grosspending = '' ) ).
    ENDIF.

    " 03.11.2026: manual gross entered by the user - no camera, no image
    " verification; Create Delivery is released (Imagevalid). Not when
    " ApplyWeight runs this: CamView took images, they still go to
    " verification.
    IF lcl_camera=>gv_no_launch = abap_false AND lt_update IS NOT INITIAL.
      DATA(lv_text) = lcl_camera=>not_required( iv_is_draft = ls_head-%is_draft
                                                iv_uuid     = ls_head-Uuid
                                                iv_stage    = lcl_camera=>c_gross ).
      APPEND VALUE #( %tky = lt_item[ 1 ]-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = lv_text ) )
             TO reported-weightitem.
    ENDIF.

    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightItem ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD ImgCapture.
    " empty in S/4 as well (the button is commented out in the UI)
    READ ENTITIES OF zsd_ih_weight IN LOCAL MODE
      ENTITY WeightItem ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

ENDCLASS.
