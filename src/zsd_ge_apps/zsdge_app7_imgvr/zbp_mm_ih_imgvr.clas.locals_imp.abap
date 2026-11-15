CLASS lhc_InImgVerify DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES ty_head   TYPE STRUCTURE FOR READ RESULT zmm_ih_imgvr\\InImgVerify.
    TYPES ty_update TYPE STRUCTURE FOR UPDATE zmm_ih_imgvr\\InImgVerify.
    TYPES tt_update TYPE TABLE FOR UPDATE zmm_ih_imgvr\\InImgVerify.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR InImgVerify RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR InImgVerify RESULT result.

    METHODS Approve FOR MODIFY
      IMPORTING keys FOR ACTION InImgVerify~Approve RESULT result.

    METHODS Reject FOR MODIFY
      IMPORTING keys FOR ACTION InImgVerify~Reject RESULT result.

    "! The update for one decision (A / R) on the pending stage
    METHODS decide
      IMPORTING is_head          TYPE ty_head
                iv_decision      TYPE c
                iv_reason        TYPE clike OPTIONAL
      RETURNING VALUE(rs_update) TYPE ty_update.

    METHODS save_decisions
      IMPORTING it_update TYPE tt_update.

    METHODS status_text
      IMPORTING iv_status      TYPE c
      RETURNING VALUE(rv_text) TYPE string.

    METHODS status_criticality
      IMPORTING iv_status             TYPE c
      RETURNING VALUE(rv_criticality) TYPE int1.
ENDCLASS.

CLASS lhc_InImgVerify IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmm_ih_imgvr IN LOCAL MODE
      ENTITY InImgVerify
        FIELDS ( Pendingstage ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    result = VALUE #( FOR h IN lt_head
                      LET lv_fc = COND #( WHEN h-Pendingstage IS INITIAL
                                          THEN if_abap_behv=>fc-o-disabled
                                          ELSE if_abap_behv=>fc-o-enabled ) IN
                      ( %tky            = h-%tky
                        %action-Approve = lv_fc
                        %action-Reject  = lv_fc ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD Approve.
    DATA lt_update TYPE tt_update.

    READ ENTITIES OF zmm_ih_imgvr IN LOCAL MODE
      ENTITY InImgVerify ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).
      IF ls_head-Pendingstage IS INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-inimgverify.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |{ ls_head-Gateentryno }: no images waiting for verification| ) )
               TO reported-inimgverify.
        CONTINUE.
      ENDIF.

      APPEND decide( is_head = ls_head iv_decision = 'A' ) TO lt_update.
      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = COND #( WHEN ls_head-Pendingstage = 'G'
                                                  THEN |{ ls_head-Gateentryno }: gross images approved, released for unloading|
                                                  ELSE |{ ls_head-Gateentryno }: tare images approved, released for gate exit| ) ) )
             TO reported-inimgverify.
    ENDLOOP.

    save_decisions( lt_update ).

    READ ENTITIES OF zmm_ih_imgvr IN LOCAL MODE
      ENTITY InImgVerify ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD Reject.
    DATA lt_update TYPE tt_update.

    READ ENTITIES OF zmm_ih_imgvr IN LOCAL MODE
      ENTITY InImgVerify ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA(lv_reason) = condense( CONV string( keys[ KEY id %tky = ls_head-%tky ]-%param-Reason ) ).

      IF ls_head-Pendingstage IS INITIAL OR lv_reason IS INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-inimgverify.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = COND #( WHEN ls_head-Pendingstage IS INITIAL
                                                    THEN |{ ls_head-Gateentryno }: no images waiting for verification|
                                                    ELSE `Enter a reject reason` ) ) )
               TO reported-inimgverify.
        CONTINUE.
      ENDIF.

      APPEND decide( is_head = ls_head iv_decision = 'R' iv_reason = lv_reason ) TO lt_update.
      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ ls_head-Gateentryno }: { to_lower( ls_head-Pendingstagetext ) } images rejected, recapture in Inward Weighment| ) )
             TO reported-inimgverify.
    ENDLOOP.

    save_decisions( lt_update ).

    READ ENTITIES OF zmm_ih_imgvr IN LOCAL MODE
      ENTITY InImgVerify ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD decide.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    " inward: gross is decided first
    DATA(lv_gross) = is_head-Imgvrstatusgross.
    DATA(lv_tare)  = is_head-Imgvrstatustare.
    IF lv_gross = 'P'.
      lv_gross = iv_decision.
    ELSE.
      lv_tare = iv_decision.
    ENDIF.

    rs_update = VALUE #(
      %tky               = is_head-%tky
      Imgvrstatusgross   = lv_gross
      Imgvrstatustare    = lv_tare
      " tare approved = images valid, inward Gate Exit lists the entry
      Imagevaldindicator = COND #( WHEN is_head-Pendingstage = 'T' AND iv_decision = 'A' THEN 'X'
                                   WHEN is_head-Pendingstage = 'T'                     THEN ''
                                   ELSE is_head-Imagevaldindicator )
      Imgrejreason       = COND #( WHEN iv_decision = 'R' THEN iv_reason ELSE '' )
      Imgverifiedby      = cl_abap_context_info=>get_user_technical_name( )
      Imgverifiedat      = lv_ts
      " calculated fields, so the result shows the new state at once
      Pendingstage       = COND #( WHEN lv_gross = 'P' THEN 'G' WHEN lv_tare = 'P' THEN 'T' ELSE '' )
      Pendingstagetext   = COND #( WHEN lv_gross = 'P' THEN 'Gross' WHEN lv_tare = 'P' THEN 'Tare' ELSE '' )
      Ispending          = COND #( WHEN lv_gross = 'P' OR lv_tare = 'P' THEN 'X' ELSE '' )
      Imgstatusgrosstext = status_text( lv_gross )
      Imgcritgross       = status_criticality( lv_gross )
      Imgstatustaretext  = status_text( lv_tare )
      Imgcrittare        = status_criticality( lv_tare ) ).
  ENDMETHOD.

  METHOD save_decisions.
    CHECK it_update IS NOT INITIAL.
    DATA(lt_update) = it_update.   " MODIFY ENTITIES needs a changeable table
    MODIFY ENTITIES OF zmm_ih_imgvr IN LOCAL MODE
      ENTITY InImgVerify
        UPDATE FIELDS ( Imgvrstatusgross Imgvrstatustare Imagevaldindicator Imgrejreason
                        Imgverifiedby Imgverifiedat
                        Pendingstage Pendingstagetext Ispending
                        Imgstatusgrosstext Imgcritgross Imgstatustaretext Imgcrittare )
        WITH lt_update.
  ENDMETHOD.

  METHOD status_text.
    rv_text = SWITCH #( iv_status WHEN 'P' THEN `Pending`
                                  WHEN 'A' THEN `Approved`
                                  WHEN 'R' THEN `Rejected`
                                  ELSE `Not captured` ).
  ENDMETHOD.

  METHOD status_criticality.
    rv_criticality = SWITCH #( iv_status WHEN 'P' THEN 2
                                         WHEN 'A' THEN 3
                                         WHEN 'R' THEN 1
                                         ELSE 0 ).
  ENDMETHOD.

ENDCLASS.

