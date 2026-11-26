CLASS zcl_mm_wmt_flag_filltexts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_mm_wmt_flag_filltexts IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA lv_series_text TYPE zmmge_wghflg_t01-gateentryseriesdes.
    DATA lv_updated     TYPE i.

    SELECT * FROM zmmge_wghflg_t01
      WHERE gateentryseriesdes = '' OR materialgroupdes = ''
      INTO TABLE @DATA(lt_flags).

    LOOP AT lt_flags ASSIGNING FIELD-SYMBOL(<ls_flag>).
      IF <ls_flag>-gateentryseriesdes IS INITIAL.
        CLEAR lv_series_text.
        SELECT SINGLE text FROM zgate_series_vh
          WHERE value_low = @<ls_flag>-gateentryseries
            AND language  = @sy-langu
          INTO @lv_series_text.
        <ls_flag>-gateentryseriesdes = lv_series_text.
      ENDIF.

      IF <ls_flag>-materialgroupdes IS INITIAL.
        <ls_flag>-materialgroupdes = zcl_mmge_matgrpvh_query=>get_name( <ls_flag>-materialgroup ).
      ENDIF.

      UPDATE zmmge_wghflg_t01
        SET gateentryseriesdes = @<ls_flag>-gateentryseriesdes,
            materialgroupdes   = @<ls_flag>-materialgroupdes
        WHERE gateentryseries = @<ls_flag>-gateentryseries
          AND materialgroup   = @<ls_flag>-materialgroup.
      lv_updated += sy-dbcnt.

      out->write( |{ <ls_flag>-gateentryseries } / { <ls_flag>-materialgroup }: | &&
                  |{ <ls_flag>-gateentryseriesdes } / { <ls_flag>-materialgroupdes }| ).
    ENDLOOP.

    COMMIT WORK.
    out->write( |{ lv_updated } row(s) updated| ).
  ENDMETHOD.

ENDCLASS.

