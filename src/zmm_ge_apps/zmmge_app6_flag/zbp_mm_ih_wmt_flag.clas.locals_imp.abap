CLASS lhc_weighFlag DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR weighFlag RESULT result.

    METHODS fillTexts FOR DETERMINE ON MODIFY
      IMPORTING keys FOR weighFlag~fillTexts.

    METHODS validateKeys FOR VALIDATE ON SAVE
      IMPORTING keys FOR weighFlag~validateKeys.

ENDCLASS.

CLASS lhc_weighFlag IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Access is controlled by the app scope (role collection Weighment Flag User)
  ENDMETHOD.


  METHOD fillTexts.
    DATA lt_update TYPE TABLE FOR UPDATE zmm_ih_wmt_flag\\weighFlag.
    DATA lv_series_text TYPE zmmge_wghflg_t01-gateentryseriesdes.

    READ ENTITIES OF zmm_ih_wmt_flag IN LOCAL MODE
      ENTITY weighFlag
        FIELDS ( Gateentryseries Materialgroup )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_flags).

    LOOP AT lt_flags ASSIGNING FIELD-SYMBOL(<ls_flag>).
      CLEAR lv_series_text.
      SELECT SINGLE text FROM zgate_series_vh
        WHERE value_low = @<ls_flag>-Gateentryseries
          AND language  = @sy-langu
        INTO @lv_series_text.

      APPEND VALUE #( %tky                        = <ls_flag>-%tky
                      Gateentryseriesdes          = lv_series_text
                      Materialgroupdes            = zcl_mmge_matgrpvh_query=>get_name( <ls_flag>-Materialgroup )
                      %control-Gateentryseriesdes = if_abap_behv=>mk-on
                      %control-Materialgroupdes   = if_abap_behv=>mk-on ) TO lt_update.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.
    MODIFY ENTITIES OF zmm_ih_wmt_flag IN LOCAL MODE
      ENTITY weighFlag
        UPDATE FROM lt_update.
  ENDMETHOD.


  METHOD validateKeys.
    READ ENTITIES OF zmm_ih_wmt_flag IN LOCAL MODE
      ENTITY weighFlag
        FIELDS ( Gateentryseries )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_flags).

    LOOP AT lt_flags ASSIGNING FIELD-SYMBOL(<ls_flag>).
      APPEND VALUE #( %tky        = <ls_flag>-%tky
                      %state_area = 'VALIDATE_KEYS' ) TO reported-weighflag.

      SELECT SINGLE @abap_true FROM zgate_series_vh
        WHERE value_low = @<ls_flag>-Gateentryseries
        INTO @DATA(lv_exists).

      IF lv_exists = abap_false.
        APPEND VALUE #( %tky = <ls_flag>-%tky ) TO failed-weighflag.
        APPEND VALUE #( %tky                     = <ls_flag>-%tky
                        %state_area              = 'VALIDATE_KEYS'
                        %msg                     = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = |Gate Entry Type { <ls_flag>-Gateentryseries } does not exist| )
                        %element-Gateentryseries = if_abap_behv=>mk-on ) TO reported-weighflag.
      ENDIF.
      CLEAR lv_exists.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

