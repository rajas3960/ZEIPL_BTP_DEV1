*----------------------------------------------------------------*
* SYSTEM: BTP ABAP Environment, package of the Weight app
* Step W3a: ABAP Class ZCL_MM_WB_WEIGHT_HTTP (handler of HTTP service
*           ZMM_WB_WEIGHT, called by CamView)
*
* POST /sap/bc/http/sap/zmm_wb_weight
*   {"seqno":"26102811304507","machine":"WB-7","weight":25.430,
*    "unit":"TO","capturedAt":"2026-10-28T11:30:52"}
* - seqno must be one BTP sent with POST /launch (header field
*   imgseqnogross or imgseqnotare, in the draft zmmge_wght_hd when
*   Auto Fetch ran in edit mode, else in zmmge_hdr_t01)
* - unit TO or KG (KG is converted to TO, the app works in TO)
* - stored in ZMMGE_WB_READ, then applied (action ApplyWeight):
*   directly when the gate entry is not in edit mode, otherwise by
*   the operator's app (polling) into the draft
* Responses (JSON {"status":..,"message":..}):
*   200 applied / stored   400 bad request   404 unknown seqno
*   405 not POST   409 already applied   500 stored, not applied
* A second POST for the same seqno before it is applied replaces the
* first reading (CamView may resend).
*----------------------------------------------------------------*
CLASS zcl_mm_wb_weight_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_in,
             seqno       TYPE string,
             machine     TYPE string,
             weight      TYPE decfloat34,
             unit        TYPE string,
             captured_at TYPE string,
           END OF ty_in.

    TYPES: BEGIN OF ty_reply,
             status  TYPE string,
             message TYPE string,
           END OF ty_reply.

    METHODS reply
      IMPORTING io_response TYPE REF TO if_web_http_response
                iv_code     TYPE i
                iv_status   TYPE string
                iv_message  TYPE string.
ENDCLASS.



CLASS ZCL_MM_WB_WEIGHT_HTTP IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.
    DATA ls_in TYPE ty_in.

    IF to_upper( request->get_method( ) ) <> `POST`.
      reply( io_response = response iv_code = 405 iv_status = `ERROR`
             iv_message = `Use POST with a JSON body` ).
      RETURN.
    ENDIF.

    " --- read the JSON body (camelCase: capturedAt -> captured_at) ---
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = request->get_text( )
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_in ).
      CATCH cx_root INTO DATA(lx_json).
        reply( io_response = response iv_code = 400 iv_status = `ERROR`
               iv_message = |Invalid JSON: { lx_json->get_text( ) }| ).
        RETURN.
    ENDTRY.

    DATA(lv_seqno) = condense( ls_in-seqno ).
    DATA(lv_unit)  = to_upper( condense( ls_in-unit ) ).
    IF lv_unit IS INITIAL.
      lv_unit = `TO`.
    ENDIF.

    IF lv_seqno IS INITIAL OR strlen( lv_seqno ) > 20.
      reply( io_response = response iv_code = 400 iv_status = `ERROR`
             iv_message = `seqno is missing or longer than 20 characters` ).
      RETURN.
    ENDIF.
    IF ls_in-weight <= 0.
      reply( io_response = response iv_code = 400 iv_status = `ERROR`
             iv_message = `weight must be greater than 0` ).
      RETURN.
    ENDIF.
    IF lv_unit <> `TO` AND lv_unit <> `KG`.
      reply( io_response = response iv_code = 400 iv_status = `ERROR`
             iv_message = `unit must be TO or KG` ).
      RETURN.
    ENDIF.

    " the app works in TO
    DATA(lv_weight) = COND decfloat34( WHEN lv_unit = `KG` THEN ls_in-weight / 1000 ELSE ls_in-weight ).

    " --- the seqno must belong to a gate entry (gross or tare capture) ---
    " Auto Fetch in edit mode writes the seqno only into the draft
    " (zmmge_wght_hd) until the operator saves, so look there first
    DATA lv_in_draft TYPE abap_bool.

    SELECT SINGLE uuid, gateentryno
      FROM zmmge_wght_hd
      WHERE imgseqnogross = @lv_seqno
         OR imgseqnotare  = @lv_seqno
      INTO @DATA(ls_head).
    IF sy-subrc = 0.
      lv_in_draft = abap_true.
    ELSE.
      SELECT SINGLE uuid, gateentryno
        FROM zmmge_hdr_t01
        WHERE imgseqnogross = @lv_seqno
           OR imgseqnotare  = @lv_seqno
        INTO @ls_head.

      IF sy-subrc <> 0.
        " not an inward gate entry: park the reading for the outward
        " Weighment app (other software component) - it reads it through
        " the released view ZI_MMGE_WB_READING and applies it itself
        DATA(ls_out) = VALUE zmmge_wb_read( seqno      = lv_seqno
                                            machine    = to_upper( condense( ls_in-machine ) )
                                            weight     = lv_weight
                                            unit       = 'TO'
                                            capturedat = ls_in-captured_at ).
        GET TIME STAMP FIELD ls_out-receivedat.
        MODIFY zmmge_wb_read FROM @ls_out.
        COMMIT WORK.
        reply( io_response = response iv_code = 202 iv_status = `OK`
               iv_message = |Weight { lv_weight } TO stored for seqno { lv_seqno }; the outward Weighment app applies it| ).
        RETURN.
      ENDIF.

      " a draft can also exist with the seqno only on the saved record
      SELECT SINGLE @abap_true FROM zmmge_wght_hd
        WHERE uuid = @ls_head-uuid
        INTO @lv_in_draft.
    ENDIF.

    " already applied = the header stage for this seqno is 'R' (received)
    SELECT SINGLE @abap_true FROM zmmge_hdr_t01
      WHERE ( imgseqnogross = @lv_seqno AND grosswtsts = 'R' )
         OR ( imgseqnotare  = @lv_seqno AND tarewtsts  = 'R' )
      INTO @DATA(lv_applied).
    IF lv_applied = abap_false.
      SELECT SINGLE @abap_true FROM zmmge_wght_hd
        WHERE ( imgseqnogross = @lv_seqno AND grosswtsts = 'R' )
           OR ( imgseqnotare  = @lv_seqno AND tarewtsts  = 'R' )
        INTO @lv_applied.
    ENDIF.
    IF lv_applied = abap_true.
      reply( io_response = response iv_code = 409 iv_status = `ERROR`
             iv_message = |The weight for seqno { lv_seqno } was already applied| ).
      RETURN.
    ENDIF.

    DATA lv_now TYPE p LENGTH 11 DECIMALS 7.
    GET TIME STAMP FIELD lv_now.

    " 1. always park the reading first (nothing is lost if step 2 fails)
    DATA(ls_read) = VALUE zmmge_wb_read( seqno         = lv_seqno
                                         machine       = to_upper( condense( ls_in-machine ) )
                                         weight        = lv_weight
                                         unit          = 'TO'
                                         capturedat    = ls_in-captured_at
                                         receivedat    = lv_now
                                         gateentryuuid = ls_head-uuid ).
    MODIFY zmmge_wb_read FROM @ls_read.
    COMMIT WORK.

    " 2. record open in edit mode (draft)? Then the operator's app applies
    "    it into the draft (ApplyWeight via polling) - a draft belongs to
    "    the user who opened it and can't be changed by CAMVIEW_USER.
    IF lv_in_draft = abap_true.
      reply( io_response = response iv_code = 200 iv_status = `OK`
             iv_message = |Weight { lv_weight } TO stored; gate entry { ls_head-gateentryno } is open in edit mode,|
                       && | the weight is applied there automatically| ).
      RETURN.
    ENDIF.

    " 3. no draft: write into the saved record now (same logic as the app:
    "    gross -> Grosswt, tare -> tare/net/GRN/shortage of the waiting items)
    MODIFY ENTITIES OF zmm_ih_weight
      ENTITY WeightHead
        EXECUTE ApplyWeight
        FROM VALUE #( ( %is_draft = if_abap_behv=>mk-off Uuid = ls_head-uuid ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zmm_ih_weight
        FAILED   DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
    ENDIF.

    IF ls_failed IS NOT INITIAL OR ls_commit_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      DATA(lv_err) = ``.
      LOOP AT ls_reported-weighthead INTO DATA(ls_rep) WHERE %msg IS BOUND.
        lv_err = |{ lv_err } { ls_rep-%msg->if_message~get_text( ) }|.
      ENDLOOP.
      LOOP AT ls_commit_reported-weighthead INTO DATA(ls_crep) WHERE %msg IS BOUND.
        lv_err = |{ lv_err } { ls_crep-%msg->if_message~get_text( ) }|.
      ENDLOOP.
      reply( io_response = response iv_code = 500 iv_status = `ERROR`
             iv_message = |Weight stored but not applied to gate entry { ls_head-gateentryno }:{ lv_err }| ).
      RETURN.
    ENDIF.

    reply( io_response = response iv_code = 200 iv_status = `OK`
           iv_message = |Weight { lv_weight } TO applied to gate entry { ls_head-gateentryno } (seqno { lv_seqno })| ).
  ENDMETHOD.


  METHOD reply.
    io_response->set_status( iv_code ).
    io_response->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
    io_response->set_text( /ui2/cl_json=>serialize( data        = VALUE ty_reply( status = iv_status message = iv_message )
                                                     pretty_name = /ui2/cl_json=>pretty_mode-camel_case ) ).
  ENDMETHOD.
ENDCLASS.
