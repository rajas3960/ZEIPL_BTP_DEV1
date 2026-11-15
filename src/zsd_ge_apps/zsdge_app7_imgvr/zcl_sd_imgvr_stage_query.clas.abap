CLASS zcl_sd_imgvr_stage_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    TYPES tt_result TYPE STANDARD TABLE OF zsd_ce_imgvr_stage WITH EMPTY KEY.

    "! one stage row; CamView only when iv_camview = abap_true
    METHODS add_stage
      IMPORTING iv_uuid    TYPE sysuuid_x16
                iv_stage   TYPE c
                iv_seqno   TYPE clike
                iv_status  TYPE c
                iv_camview TYPE abap_bool
      CHANGING  ct_result  TYPE tt_result.
ENDCLASS.



CLASS ZCL_SD_IMGVR_STAGE_QUERY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE tt_result.
    DATA lt_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.
    DATA lv_uuid   TYPE sysuuid_x16.

    TRY.
        lt_ranges = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_ranges.
    ENDTRY.

    " the gate entry: UUID eq <value> (hex, with or without dashes)
    READ TABLE lt_ranges INTO DATA(ls_range) WITH KEY name = 'UUID'.
    IF sy-subrc = 0 AND lines( ls_range-range ) = 1 AND ls_range-range[ 1 ]-option = 'EQ'.
      DATA(lv_hex) = to_upper( replace( val = CONV string( ls_range-range[ 1 ]-low ) sub = `-` with = `` occ = 0 ) ).
      lv_uuid = lv_hex.
    ENDIF.

    " which stages are asked for (stage page = one stage)
    DATA(lv_tare)  = abap_true.
    DATA(lv_gross) = abap_true.
    READ TABLE lt_ranges INTO DATA(ls_stage) WITH KEY name = 'STAGE'.
    IF sy-subrc = 0.
      lv_tare  = xsdbool( 'T' IN ls_stage-range ).
      lv_gross = xsdbool( 'G' IN ls_stage-range ).
    ENDIF.

    " CamView only if a CamView field is requested (the list asks only for
    " stage, status and seq, so it stays fast)
    DATA(lv_camview) = abap_false.
    LOOP AT io_request->get_requested_elements( ) INTO DATA(lv_requested).
      DATA(lv_element) = to_upper( lv_requested ).
      IF lv_element = 'IMAGE1' OR lv_element = 'IMAGE2' OR lv_element = 'IMAGE3' OR lv_element = 'IMAGE4'
         OR lv_element = 'CAMWEIGHT' OR lv_element = 'OCRTEXT' OR lv_element = 'CAPTUREDAT' OR lv_element = 'MESSAGE'.
        lv_camview = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_uuid IS NOT INITIAL.
      " outward (Sales) entry, else inward (MM) entry
      DATA lv_inward TYPE abap_bool.
      SELECT SINGLE imgseqnotare, imgseqnogross, imgvrstatustare, imgvrstatusgross
        FROM zsdge_sentry_ht1
        WHERE uuid = @lv_uuid
        INTO @DATA(ls_head).
      IF sy-subrc <> 0.
        SELECT SINGLE imgseqnotare, imgseqnogross, imgvrstatustare, imgvrstatusgross
          FROM zmmge_hdr_t01
          WHERE uuid = @lv_uuid
          INTO CORRESPONDING FIELDS OF @ls_head.
        lv_inward = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF ls_head-imgseqnotare IS NOT INITIAL AND lv_tare = abap_true.
        add_stage( EXPORTING iv_uuid = lv_uuid iv_stage = 'T' iv_seqno = ls_head-imgseqnotare
                             iv_status = ls_head-imgvrstatustare iv_camview = lv_camview
                   CHANGING  ct_result = lt_result ).
      ENDIF.
      IF ls_head-imgseqnogross IS NOT INITIAL AND lv_gross = abap_true.
        add_stage( EXPORTING iv_uuid = lv_uuid iv_stage = 'G' iv_seqno = ls_head-imgseqnogross
                             iv_status = ls_head-imgvrstatusgross iv_camview = lv_camview
                   CHANGING  ct_result = lt_result ).
      ENDIF.

      " weighing order: outward T before G, inward G before T
      IF lv_inward = abap_true.
        SORT lt_result BY Stage ASCENDING.
      ELSE.
        SORT lt_result BY Stage DESCENDING.
      ENDIF.
    ENDIF.

    " at most 2 rows; the framework expects sort and paging to be read
    io_request->get_sort_elements( ).
    DATA(lv_total)  = CONV int8( lines( lt_result ) ).
    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_offset) = lo_paging->get_offset( ).
    DATA(lv_size)   = lo_paging->get_page_size( ).
    IF lv_offset > 0.
      DELETE lt_result TO lv_offset.
    ENDIF.
    IF lv_size <> if_rap_query_paging=>page_size_unlimited AND lines( lt_result ) > lv_size.
      DATA(lv_from) = lv_size + 1.
      DELETE lt_result FROM lv_from.
    ENDIF.

    IF io_request->is_data_requested( ).
      io_response->set_data( lt_result ).
    ENDIF.
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lv_total ).
    ENDIF.
  ENDMETHOD.


  METHOD add_stage.
    DATA ls_row TYPE zsd_ce_imgvr_stage.

    ls_row-uuid       = iv_uuid.
    ls_row-stage      = iv_stage.
    ls_row-stagetext  = COND #( WHEN iv_stage = 'T' THEN `Tare` ELSE `Gross` ).
    ls_row-rowidseq   = iv_seqno.
    ls_row-statustext = SWITCH #( iv_status WHEN 'P' THEN `Pending`
                                            WHEN 'A' THEN `Approved`
                                            WHEN 'R' THEN `Rejected`
                                            ELSE `Not captured` ).
    ls_row-statuscrit = SWITCH #( iv_status WHEN 'P' THEN 2
                                            WHEN 'A' THEN 3
                                            WHEN 'R' THEN 1
                                            ELSE 0 ).

    IF iv_camview = abap_true.
      DATA(ls_record) = zcl_sd_camview_api=>get_record( iv_seqno ).
      IF ls_record-ok = abap_true.
        ls_row-camweight  = ls_record-wb_wt.
        ls_row-ocrtext    = ls_record-ocr_text.
        ls_row-capturedat = replace( val = ls_record-timestamp sub = `T` with = ` ` ).
        ls_row-image1     = COND #( WHEN ls_record-image1 IS NOT INITIAL THEN |data:image/jpeg;base64,{ ls_record-image1 }| ).
        ls_row-image2     = COND #( WHEN ls_record-image2 IS NOT INITIAL THEN |data:image/jpeg;base64,{ ls_record-image2 }| ).
        ls_row-image3     = COND #( WHEN ls_record-image3 IS NOT INITIAL THEN |data:image/jpeg;base64,{ ls_record-image3 }| ).
        ls_row-image4     = COND #( WHEN ls_record-image4 IS NOT INITIAL THEN |data:image/jpeg;base64,{ ls_record-image4 }| ).
      ELSE.
        ls_row-message = ls_record-message.
      ENDIF.
    ENDIF.

    APPEND ls_row TO ct_result.
  ENDMETHOD.
ENDCLASS.
