CLASS lhc_GateSecHead DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR GateSecHead RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR GateSecHead RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR GateSecHead RESULT result.

    METHODS GatePrint FOR MODIFY
      IMPORTING keys FOR ACTION GateSecHead~GatePrint RESULT result.

    METHODS headmodify FOR DETERMINE ON SAVE
      IMPORTING keys FOR GateSecHead~headmodify.
    METHODS uptransporter FOR DETERMINE ON MODIFY
      keys FOR GateSecHead~uptransporter.
    METHODS Validation FOR VALIDATE ON SAVE
      keys FOR GateSecHead~Validation.

    "!
    "! @parameter iv_transp |
    "! @parameter rs_response |
    METHODS read_transporter_details
      IMPORTING iv_transp          TYPE zsdge_sentry_ht1-transportid
      RETURNING VALUE(rs_response) TYPE zcl_sd_s4_owght_api=>ty_response.

ENDCLASS.


CLASS lhc_GateSecHead IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD GatePrint.
    READ ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
      ENTITY GateSecHead
        FIELDS ( Uuid Gateentryid ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head) WHERE Gateentryid IS NOT INITIAL.

      TRY.
          DATA(lo_fdp)  = cl_fp_fdp_services=>get_instance( iv_service_definition = 'ZSD_WEIGHT_SLIP_CE'
                                                             iv_root_node          = 'ZSD_HCE_GATESEC' ).
          DATA(lt_keys) = lo_fdp->get_keys( ).
          lt_keys[ name = 'UUID' ]-value = ls_head-Uuid.
          DATA(lv_xml)  = lo_fdp->read_to_xml( lt_keys ).

          DATA(lv_pdf)  = zcl_ge_adobe_pdf=>render( iv_form_name     = `ZSD_ENTRY_SLIP`
                                                    iv_template_name = `ENTRY_SLIP`
                                                    iv_xml_data      = lv_xml ).

        CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-gatesechead.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Slip data: { lx_fdp->get_text( ) }| ) )
                 TO reported-gatesechead.
          CONTINUE.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-gatesechead.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Adobe: HTTP { lx_ads->mv_http_status_code } { lx_ads->mv_http_reason }| ) )
                 TO reported-gatesechead.
          CONTINUE.
      ENDTRY.

      MODIFY ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
        ENTITY GateSecHead
          UPDATE FIELDS ( Attachment Mimetype Filename )
          WITH VALUE #( ( %tky       = ls_head-%tky
                          Attachment = lv_pdf
                          Mimetype   = 'application/pdf'
                          Filename   = |Entry Slip-{ ls_head-Gateentryid }.pdf| ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Gate entry slip created for { ls_head-Gateentryid }| ) )
             TO reported-gatesechead.
    ENDLOOP.

    READ ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
      ENTITY GateSecHead ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD headmodify.
    DATA lv_nextid   TYPE n LENGTH 10.
    DATA lv_typetext TYPE zsdge_sentry_ht1-gateentrytypetext.
    DATA lv_gatetext TYPE zsdge_sentry_ht1-gatenodes.
    DATA lv_modetext TYPE zsdge_sentry_ht1-modeoftransporttext.
    DATA lt_update   TYPE TABLE FOR UPDATE zsd_ih_gatesec\\GateSecHead.

    READ ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
      ENTITY GateSecHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(gt_head).

    DELETE gt_head WHERE Gateentryid IS NOT INITIAL.
    IF gt_head IS INITIAL.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD DATA(ts).
    CONVERT TIME STAMP ts TIME ZONE 'INDIA' INTO DATE DATA(lv_date) TIME DATA(lv_time).

    SELECT SINGLE MAX( gateentryid ) FROM zsdge_sentry_ht1 INTO @DATA(lv_maxid).
    lv_nextid = COND #( WHEN lv_maxid IS INITIAL THEN '1000000000' ELSE lv_maxid ).

    LOOP AT gt_head ASSIGNING FIELD-SYMBOL(<fs_head>).
      lv_nextid += 1.

      CLEAR: lv_typetext, lv_gatetext, lv_modetext.

      IF <fs_head>-Gateentrytype IS NOT INITIAL.
        SELECT SINGLE text FROM zsd_type_vh WITH PRIVILEGED ACCESS
          WHERE value_low = @<fs_head>-Gateentrytype
          INTO @lv_typetext.
      ENDIF.

      IF <fs_head>-Gateno IS NOT INITIAL.
        SELECT SINGLE text FROM zsd_gateno_vh WITH PRIVILEGED ACCESS
          WHERE value_low = @<fs_head>-Gateno
          INTO @lv_gatetext.
      ENDIF.

      IF <fs_head>-Modeoftransport IS NOT INITIAL.
        SELECT SINGLE text FROM zsd_mode_tvh WITH PRIVILEGED ACCESS
          WHERE value_low = @<fs_head>-Modeoftransport
          INTO @lv_modetext.
      ENDIF.

      TRANSLATE <fs_head>-Vehicleno TO UPPER CASE.

      APPEND VALUE #( %tky                = <fs_head>-%tky
                      Gateentryid         = lv_nextid
                      Gateentryiddate     = lv_date
                      Gateentryidtime     = lv_time
                      Gateentrytypetext   = lv_typetext
                      Gatenodes           = lv_gatetext
                      Vehicletype         = 'R'
                      Modeoftransporttext = lv_modetext
                      Vehicleno           = <fs_head>-Vehicleno
                      %control = VALUE #( Gateentryid         = if_abap_behv=>mk-on
                                          Gateentryiddate     = if_abap_behv=>mk-on
                                          Gateentryidtime     = if_abap_behv=>mk-on
                                          Gateentrytypetext   = if_abap_behv=>mk-on
                                          Gatenodes           = if_abap_behv=>mk-on
                                          Vehicletype         = if_abap_behv=>mk-on
                                          Modeoftransporttext = if_abap_behv=>mk-on
                                          Vehicleno = if_abap_behv=>mk-on ) )
             TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
      ENTITY GateSecHead
      UPDATE FROM lt_update.
  ENDMETHOD.

  METHOD uptransporter.


            READ ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
            ENTITY GateSecHead
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_head)
            FAILED DATA(lt_failed).

            DATA(ls_head) = VALUE #( lt_head[ 1 ] OPTIONAL ).
            DATA: lv_transp TYPE n LENGTH 10.
            DATA ls_response    TYPE ZCL_SD_S4_OWGHT_API=>ty_response.
            lv_transp = ls_head-Transportid.
            DATA(lv_trans) = CONV zsdge_sentry_ht1-transportid( lv_transp ).
            ls_response = read_transporter_details( iv_transp = lv_trans ).


            if ls_response-transportername is NOT INITIAL.

              MODIFY ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
                ENTITY GateSecHead
                UPDATE FIELDS ( Transportname )
                WITH VALUE #( ( %tky       = ls_head-%tky
                               Transportname = ls_response-transportername ) ).

            ENDIF.
  ENDMETHOD.

  METHOD read_transporter_details.

    TRY.
        rs_response = ZCL_SD_S4_OWGHT_API=>call( VALUE #( operation         = 'TRANSP'
                                                         transporterid     = iv_transp
                                                          ) ).
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

  METHOD Validation.

            READ ENTITIES OF zsd_ih_gatesec IN LOCAL MODE
            ENTITY GateSecHead
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_head)
            FAILED DATA(lt_failed).

            DATA(ls_head) = VALUE #( lt_head[ 1 ] OPTIONAL ).

       if ls_head-Driverlicensenumber is INITIAL.

        DATA(lv_msgTli) = |License No is Mandatory|.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msgTli ) )
               TO reported-gatesechead.

        APPEND VALUE #( %tky = ls_head-%tky )
               TO failed-gatesechead.
       ENDIF.

       if ls_head-Vehicleno is INITIAL.

        DATA(lv_msgvn) = |Vehicle Number is Mandatory|.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msgvn ) )
               TO reported-gatesechead.

        APPEND VALUE #( %tky = ls_head-%tky )
               TO failed-gatesechead.

       ELSEIF ls_head-Vehicleno is not INITIAL.

                SELECT SINGLE uuid,vehicleno,Exitindic,cancelgateentry FROM zsdge_sentry_ht1 WITH PRIVILEGED ACCESS
                WHERE vehicleno = @ls_head-Vehicleno
                AND Exitindic is INITIAL
                AND cancelgateentry is INITIAL
                INTO @DATA(ls_vehicle).
              if ls_vehicle is not INITIAL.

                DATA(lv_msgvs) = |Vehicle Inside Plant – Exit Pending|.
                APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msgvs ) )
                 TO reported-gatesechead.

                APPEND VALUE #( %tky = ls_head-%tky )
                TO failed-gatesechead.

              ENDIF.

        ENDIF.

       if ls_head-Contactdetails is INITIAL.

        DATA(lv_msgph) = |Mobile Number is Mandatory|.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msgph ) )
               TO reported-gatesechead.

        APPEND VALUE #( %tky = ls_head-%tky )
               TO failed-gatesechead.
       ENDIF.

       if ls_head-Drivername is INITIAL.

        DATA(lv_msgname) = |Driver Name is Mandatory|.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msgname ) )
               TO reported-gatesechead.

        APPEND VALUE #( %tky = ls_head-%tky )
               TO failed-gatesechead.
        ENDIF.

        ""Contact Number Validation
        DATA(lv_contact) = CONV string( ls_head-Contactdetails ).
        if lv_contact is NOT INITIAL .

           if lv_contact CN '0123456789'.

        DATA(lv_msgcon) = |Contact Number should contain only numbers|.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msgcon ) )
               TO reported-gatesechead.

        APPEND VALUE #( %tky = ls_head-%tky )
               TO failed-gatesechead.

            ENDIF.

        if strlen( lv_contact ) <> 10.

        DATA(lv_msgconlg) = |Contact Number must be exactly 10 digits|.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'Validate_Head'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msgconlg ) )
               TO reported-gatesechead.

        APPEND VALUE #( %tky = ls_head-%tky )
               TO failed-gatesechead.
        ENDIF.

            ENDIF.


  ENDMETHOD.

ENDCLASS.


CLASS lhc_GateSecItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR GateSecItem RESULT result.

ENDCLASS.


CLASS lhc_GateSecItem IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

ENDCLASS.
