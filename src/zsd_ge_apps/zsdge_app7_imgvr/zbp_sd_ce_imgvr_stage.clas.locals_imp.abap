CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_status TYPE c LENGTH 1.

    TYPES: BEGIN OF ty_decision,
             uuid     TYPE sysuuid_x16,
             stage    TYPE c LENGTH 1,
             decision TYPE c LENGTH 1,
             reason   TYPE c LENGTH 255,
           END OF ty_decision.

    TYPES: BEGIN OF ty_head,
             found         TYPE abap_bool,
             inward        TYPE abap_bool,
             gateentryno   TYPE c LENGTH 20,
             imgseqnotare  TYPE c LENGTH 20,
             imgseqnogross TYPE c LENGTH 20,
             statustare    TYPE c LENGTH 1,
             statusgross   TYPE c LENGTH 1,
           END OF ty_head.

    CLASS-DATA gt_decision TYPE STANDARD TABLE OF ty_decision WITH EMPTY KEY.

    "! the gate entry of a stage row, with decisions of this transaction applied
    CLASS-METHODS read_head
      IMPORTING iv_uuid        TYPE sysuuid_x16
      RETURNING VALUE(rs_head) TYPE ty_head.

    "! status of one stage (P / A / R / blank)
    CLASS-METHODS stage_status
      IMPORTING is_head          TYPE ty_head
                iv_stage         TYPE c
      RETURNING VALUE(rv_status) TYPE ty_status.

    CLASS-METHODS status_text
      IMPORTING iv_status      TYPE c
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS status_crit
      IMPORTING iv_status      TYPE c
      RETURNING VALUE(rv_crit) TYPE int1.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.

  METHOD read_head.
    SELECT SINGLE gateentryno, imgseqnotare, imgseqnogross,
                  imgvrstatustare AS statustare, imgvrstatusgross AS statusgross
      FROM zsdge_sentry_ht1
      WHERE uuid = @iv_uuid
      INTO CORRESPONDING FIELDS OF @rs_head.
    IF sy-subrc = 0.
      rs_head-found = abap_true.
    ELSE.
      SELECT SINGLE gateentryno, imgseqnotare, imgseqnogross,
                    imgvrstatustare AS statustare, imgvrstatusgross AS statusgross
        FROM zmmge_hdr_t01
        WHERE uuid = @iv_uuid
        INTO CORRESPONDING FIELDS OF @rs_head.
      IF sy-subrc = 0.
        rs_head-found  = abap_true.
        rs_head-inward = abap_true.
      ENDIF.
    ENDIF.

    " decisions taken in this transaction, not saved yet
    LOOP AT gt_decision INTO DATA(ls_dec) WHERE uuid = iv_uuid.
      IF ls_dec-stage = 'T'.
        rs_head-statustare = ls_dec-decision.
      ELSE.
        rs_head-statusgross = ls_dec-decision.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD stage_status.
    rv_status = COND #( WHEN iv_stage = 'T' THEN is_head-statustare ELSE is_head-statusgross ).
  ENDMETHOD.

  METHOD status_text.
    rv_text = SWITCH #( iv_status WHEN 'P' THEN `Pending`
                                  WHEN 'A' THEN `Approved`
                                  WHEN 'R' THEN `Rejected`
                                  ELSE `Not captured` ).
  ENDMETHOD.

  METHOD status_crit.
    rv_crit = SWITCH #( iv_status WHEN 'P' THEN 2
                                  WHEN 'A' THEN 3
                                  WHEN 'R' THEN 1
                                  ELSE 0 ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Handler
*----------------------------------------------------------------*
CLASS lhc_StageRow DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES ty_row TYPE STRUCTURE FOR READ RESULT zsd_ce_imgvr_stage\\StageRow.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR StageRow RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR StageRow RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ StageRow RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK StageRow.

    METHODS Approve FOR MODIFY
      IMPORTING keys FOR ACTION StageRow~Approve RESULT result.

    METHODS Reject FOR MODIFY
      IMPORTING keys FOR ACTION StageRow~Reject RESULT result.

    "! the row as the table shows it (no CamView fields)
    METHODS build_row
      IMPORTING iv_uuid       TYPE sysuuid_x16
                iv_stage      TYPE c
                is_head       TYPE lcl_buffer=>ty_head
      RETURNING VALUE(rs_row) TYPE ty_row.

    "! message for a successful decision
    METHODS decision_text
      IMPORTING is_head        TYPE lcl_buffer=>ty_head
                iv_stage       TYPE c
                iv_decision    TYPE c
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS lhc_StageRow IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
    LOOP AT keys INTO DATA(key).
      DATA(ls_head) = lcl_buffer=>read_head( key-Uuid ).
      DATA(lv_fc) = COND #( WHEN lcl_buffer=>stage_status( is_head = ls_head iv_stage = key-Stage ) = 'P'
                            THEN if_abap_behv=>fc-o-enabled
                            ELSE if_abap_behv=>fc-o-disabled ).
      APPEND VALUE #( %tky            = key-%tky
                      %action-Approve = lv_fc
                      %action-Reject  = lv_fc ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(key).
      DATA(ls_head) = lcl_buffer=>read_head( key-Uuid ).
      DATA(lv_seq)  = COND #( WHEN key-Stage = 'T' THEN ls_head-imgseqnotare ELSE ls_head-imgseqnogross ).
      IF ls_head-found = abap_false OR lv_seq IS INITIAL.
        APPEND VALUE #( %tky = key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-stagerow.
        CONTINUE.
      ENDIF.
      APPEND build_row( iv_uuid = key-Uuid iv_stage = key-Stage is_head = ls_head ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
    " no lock object: a decision is one column update, and a stage can
    " only be decided while it is Pending (checked again in the action)
  ENDMETHOD.

  METHOD Approve.
    LOOP AT keys INTO DATA(key).
      DATA(ls_head) = lcl_buffer=>read_head( key-Uuid ).
      IF lcl_buffer=>stage_status( is_head = ls_head iv_stage = key-Stage ) <> 'P'.
        APPEND VALUE #( %tky = key-%tky ) TO failed-stagerow.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |{ ls_head-gateentryno }: these images are not waiting for verification| ) )
               TO reported-stagerow.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( uuid = key-Uuid stage = key-Stage decision = 'A' ) TO lcl_buffer=>gt_decision.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = decision_text( is_head = ls_head iv_stage = key-Stage iv_decision = 'A' ) ) )
             TO reported-stagerow.

      DATA(ls_after) = lcl_buffer=>read_head( key-Uuid ).
      APPEND VALUE #( %tky   = key-%tky
                      %param = CORRESPONDING #( build_row( iv_uuid = key-Uuid iv_stage = key-Stage is_head = ls_after ) ) )
             TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD Reject.
    LOOP AT keys INTO DATA(key).
      DATA(ls_head)   = lcl_buffer=>read_head( key-Uuid ).
      DATA(lv_reason) = condense( CONV string( key-%param-Reason ) ).

      IF lcl_buffer=>stage_status( is_head = ls_head iv_stage = key-Stage ) <> 'P' OR lv_reason IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-stagerow.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = COND #( WHEN lv_reason IS INITIAL
                                                    THEN `Enter a reject reason`
                                                    ELSE |{ ls_head-gateentryno }: these images are not waiting for verification| ) ) )
               TO reported-stagerow.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( uuid = key-Uuid stage = key-Stage decision = 'R' reason = lv_reason ) TO lcl_buffer=>gt_decision.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = decision_text( is_head = ls_head iv_stage = key-Stage iv_decision = 'R' ) ) )
             TO reported-stagerow.

      DATA(ls_after) = lcl_buffer=>read_head( key-Uuid ).
      APPEND VALUE #( %tky   = key-%tky
                      %param = CORRESPONDING #( build_row( iv_uuid = key-Uuid iv_stage = key-Stage is_head = ls_after ) ) )
             TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_row.
    DATA(lv_status) = lcl_buffer=>stage_status( is_head = is_head iv_stage = iv_stage ).
    rs_row-Uuid       = iv_uuid.
    rs_row-Stage      = iv_stage.
    rs_row-Stagetext  = COND #( WHEN iv_stage = 'T' THEN `Tare` ELSE `Gross` ).
    rs_row-Rowidseq   = COND #( WHEN iv_stage = 'T' THEN is_head-imgseqnotare ELSE is_head-imgseqnogross ).
    rs_row-Statustext = lcl_buffer=>status_text( lv_status ).
    rs_row-Statuscrit = lcl_buffer=>status_crit( lv_status ).
  ENDMETHOD.

  METHOD decision_text.
    DATA(lv_stage) = COND string( WHEN iv_stage = 'T' THEN `tare` ELSE `gross` ).
    IF iv_decision = 'R'.
      rv_text = |{ is_head-gateentryno }: { lv_stage } images rejected, recapture in Weighment|.
      RETURN.
    ENDIF.
    rv_text = COND #(
      WHEN is_head-inward = abap_false AND iv_stage = 'T' THEN |{ is_head-gateentryno }: tare images approved, released for loading|
      WHEN is_head-inward = abap_false                    THEN |{ is_head-gateentryno }: gross images approved, Create Delivery enabled|
      WHEN iv_stage = 'G'                                 THEN |{ is_head-gateentryno }: gross images approved, released for unloading|
      ELSE                                                     |{ is_head-gateentryno }: tare images approved, released for gate exit| ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------*
* Saver: writes the buffered decisions (column UPDATE only)
*----------------------------------------------------------------*
CLASS lsc_ZSD_CE_IMGVR_STAGE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.
ENDCLASS.

CLASS lsc_ZSD_CE_IMGVR_STAGE IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT lcl_buffer=>gt_decision INTO DATA(ls_dec).
      DATA(lv_reason) = COND #( WHEN ls_dec-decision = 'R' THEN ls_dec-reason ELSE `` ).
      DATA(lv_valid)  = COND #( WHEN ls_dec-decision = 'A' THEN 'X' ELSE '' ).

      " outward entry?
      SELECT SINGLE @abap_true FROM zsdge_sentry_ht1 WHERE uuid = @ls_dec-uuid INTO @DATA(lv_outward).

      IF lv_outward = abap_true.
        IF ls_dec-stage = 'T'.
          UPDATE zsdge_sentry_ht1
            SET imgvrstatustare = @ls_dec-decision, imgrejreason = @lv_reason,
                imgverifiedby = @lv_user, imgverifiedat = @lv_ts, lastchangedat = @lv_ts
            WHERE uuid = @ls_dec-uuid.
        ELSE.
          " gross approved = Create Delivery allowed
          UPDATE zsdge_sentry_ht1
            SET imgvrstatusgross = @ls_dec-decision, imagevalid = @lv_valid, imgrejreason = @lv_reason,
                imgverifiedby = @lv_user, imgverifiedat = @lv_ts, lastchangedat = @lv_ts
            WHERE uuid = @ls_dec-uuid.
        ENDIF.
      ELSE.
        IF ls_dec-stage = 'G'.
          UPDATE zmmge_hdr_t01
            SET imgvrstatusgross = @ls_dec-decision, imgrejreason = @lv_reason,
                imgverifiedby = @lv_user, imgverifiedat = @lv_ts, lastchangedat = @lv_ts
            WHERE uuid = @ls_dec-uuid.
        ELSE.
          " tare approved = Gate Exit allowed
          UPDATE zmmge_hdr_t01
            SET imgvrstatustare = @ls_dec-decision, imagevaldindicator = @lv_valid, imgrejreason = @lv_reason,
                imgverifiedby = @lv_user, imgverifiedat = @lv_ts, lastchangedat = @lv_ts
            WHERE uuid = @ls_dec-uuid.
        ENDIF.
      ENDIF.
      CLEAR lv_outward.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup.
    CLEAR lcl_buffer=>gt_decision.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>gt_decision.
  ENDMETHOD.

ENDCLASS.

