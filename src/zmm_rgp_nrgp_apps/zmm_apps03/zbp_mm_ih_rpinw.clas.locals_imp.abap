CLASS lhc__item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS createslno FOR DETERMINE ON MODIFY
      keys FOR _Item~createslno.

ENDCLASS.

CLASS lhc__item IMPLEMENTATION.

  METHOD createslno.

            DATA: lv_slno TYPE zmm_app3_tb-sno,
                  lv_gate TYPE zmm_app3_tb-gateinnumber.

  READ ENTITIES OF zmm_ih_rpinw IN LOCAL MODE
  ENTITY _Header
  ALL FIELDS WITH CORRESPONDING #( keys )
  RESULT DATA(lt_header)
  ENTITY _Item
  ALL FIELDS WITH CORRESPONDING #( keys )
  RESULT DATA(lt_item)
  FAILED DATA(lt_failed).

    GET TIME STAMP FIELD DATA(ts).
    CONVERT TIME STAMP ts TIME ZONE 'INDIA'
            INTO DATE DATA(lv_date) TIME DATA(lv_time).


        LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
        if <ls_item> is ASSIGNED.

            select SINGLE max( Sno ) from zmm_app3_tb WITH PRIVILEGED ACCESS
            WHERE uuid = @<ls_item>-Uuid
            and itemno = @<ls_item>-Itemno
            INTO @DATA(ls_slno).
            if sy-subrc = 0 and ls_slno is not INITIAL.
                lv_slno = ls_slno + 1.
            ELSE.
                lv_slno = 1.
            ENDIF.

            SELECT single max( gateinnumber ) FROM zmm_app3_tb WHERE uuid IS NOT INITIAL
            INTO @DATA(lt_gpentry).

            IF lt_gpentry IS INITIAL.
            lv_gate = '1000000000'.
            ELSE.
            lv_gate = lt_gpentry + 1.
            ENDIF.

           MODIFY ENTITIES OF zmm_ih_rpinw IN LOCAL MODE
           ENTITY _Item
           UPDATE
           FIELDS ( Sno Gateinnumber Gateindate Gateintime )
           WITH VALUE #( for key IN keys
                            ( %tky = <ls_item>-%tky
                         Sno = lv_slno
                         Gateinnumber = lv_gate
                         Gateindate = lv_date
                         Gateintime = lv_time
                         %control-Sno = if_abap_behv=>mk-on
                         %control-Gateinnumber = if_abap_behv=>mk-on
                         %control-Gateindate = if_abap_behv=>mk-on
                         %control-Gateintime = if_abap_behv=>mk-on
                         ) ).

        ENDIF.
        ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lhc__Header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR _Header RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR _Header RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR _Header RESULT result.

    METHODS DocumentClose FOR MODIFY
      keys FOR ACTION _Header~DocumentClose RESULT result.

ENDCLASS.

CLASS lhc__Header IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD DocumentClose.
  ENDMETHOD.

ENDCLASS.
