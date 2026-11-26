CLASS lhc_UnloadHead DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR UnloadHead RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR UnloadHead RESULT result.

    METHODS Unloadst FOR MODIFY
      IMPORTING keys FOR ACTION UnloadHead~Unloadst RESULT result.

    METHODS UnloadEnd FOR MODIFY
      IMPORTING keys FOR ACTION UnloadHead~UnloadEnd RESULT result.

ENDCLASS.

CLASS lhc_UnloadHead IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmm_ih_unload IN LOCAL MODE
      ENTITY UnloadHead
      FIELDS ( Unloadstindi Unloadendindi ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY UnloadHead BY \_Item
      FIELDS ( Unloadind ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA(ls_head) = VALUE #( lt_head[ 1 ] OPTIONAL ).

    result = VALUE #( FOR ls_key IN lt_item
                      ( %tky              = ls_head-%tky
                        %action-Unloadst  = COND #( WHEN ls_head-Unloadstindi = 'X'
                                                    THEN if_abap_behv=>fc-o-disabled
                                                    ELSE if_abap_behv=>fc-o-enabled )
                        %action-UnloadEnd = COND #( WHEN ls_head-Unloadendindi = 'X'
                                                    THEN if_abap_behv=>fc-o-disabled
                                                    WHEN ls_head-Unloadstindi = 'X'
                                                    AND ls_key-Unloadind = abap_true
                                                    THEN if_abap_behv=>fc-o-enabled
                                                    ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD Unloadst.
    GET TIME STAMP FIELD DATA(ts).
    CONVERT TIME STAMP ts TIME ZONE 'INDIA' INTO DATE DATA(lv_date) TIME DATA(lv_time).

    MODIFY ENTITIES OF zmm_ih_unload IN LOCAL MODE
      ENTITY UnloadHead
      UPDATE FIELDS ( Unloadstdate Unloadsttime Unloadstindi )
      WITH VALUE #( FOR ls_key IN keys
                    ( %tky         = ls_key-%tky
                      Unloadstdate = lv_date
                      Unloadsttime = lv_time
                      Unloadstindi = 'X' ) ).

    READ ENTITIES OF zmm_ih_unload IN LOCAL MODE
      ENTITY UnloadHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_ord IN lt_result
                      ( %tky   = ls_ord-%tky
                        %param = ls_ord ) ).
  ENDMETHOD.

  METHOD UnloadEnd.
    GET TIME STAMP FIELD DATA(ts).
    CONVERT TIME STAMP ts TIME ZONE 'INDIA' INTO DATE DATA(lv_date) TIME DATA(lv_time).

    MODIFY ENTITIES OF zmm_ih_unload IN LOCAL MODE
      ENTITY UnloadHead
      UPDATE FIELDS ( Unloadenddate Unloadendtime Unloadendindi )
      WITH VALUE #( FOR ls_key IN keys
                    ( %tky          = ls_key-%tky
                      Unloadenddate = lv_date
                      Unloadendtime = lv_time
                      Unloadendindi = 'X' ) ).

    READ ENTITIES OF zmm_ih_unload IN LOCAL MODE
      ENTITY UnloadHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_ord IN lt_result
                      ( %tky   = ls_ord-%tky
                        %param = ls_ord ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_UnloadItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR UnloadItem RESULT result.

    METHODS checkG2Unload FOR VALIDATE ON SAVE
      IMPORTING keys FOR UnloadItem~checkG2Unload.

ENDCLASS.

CLASS lhc_UnloadItem IMPLEMENTATION.

  METHOD get_instance_features.
    " G2: a PO line whose unloading is already finished (saved) can't be
    " changed any more. update / delete stay enabled as before.
    READ ENTITIES OF zmm_ih_unload IN LOCAL MODE
      ENTITY UnloadItem
        FIELDS ( Uuid Purchaseorder Purchaseorderitem ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY UnloadItem BY \_Head
        FIELDS ( Gateentryseries ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    CHECK lt_item IS NOT INITIAL.

    SELECT uuid, purchaseorder, purchaseorderitem, unloadind
      FROM zmmge_itm_t01
      FOR ALL ENTRIES IN @lt_item
      WHERE uuid              = @lt_item-Uuid
        AND purchaseorder     = @lt_item-Purchaseorder
        AND purchaseorderitem = @lt_item-Purchaseorderitem
      INTO TABLE @DATA(lt_db).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(ls_hk)   = VALUE #( lt_link[ source-%tky = ls_item-%tky ]-target OPTIONAL ).
      DATA(ls_head) = VALUE #( lt_head[ %tky = ls_hk-%tky ] OPTIONAL ).
      DATA(lv_done) = VALUE #( lt_db[ uuid              = ls_item-Uuid
                                      purchaseorder     = ls_item-Purchaseorder
                                      purchaseorderitem = ls_item-Purchaseorderitem ]-unloadind OPTIONAL ).
      APPEND VALUE #( %tky             = ls_item-%tky
                      %field-Unloadind = COND #( WHEN ls_head-Gateentryseries = 'G2' AND lv_done = abap_true
                                                 THEN if_abap_behv=>fc-f-read_only
                                                 ELSE if_abap_behv=>fc-f-unrestricted ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD checkG2Unload.
    " G2: one PO line per unloading, and not while an unloaded line is
    " still waiting for its weight (else 2 lines end up in one weighing)
    READ ENTITIES OF zmm_ih_unload IN LOCAL MODE
      ENTITY UnloadItem BY \_Head
        FIELDS ( Gateentryseries ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      LINK DATA(lt_link).

    SORT lt_head BY Uuid %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_head COMPARING Uuid %is_draft.

    LOOP AT lt_head INTO DATA(ls_head).
      " clears an old message of this check
      LOOP AT lt_link INTO DATA(ls_lnk) WHERE target-%tky = ls_head-%tky.
        APPEND VALUE #( %tky        = ls_lnk-source-%tky
                        %state_area = 'CHECK_G2UNL'
                        %path       = VALUE #( unloadhead-%tky = ls_head-%tky ) ) TO reported-unloaditem.
      ENDLOOP.

      CHECK ls_head-Gateentryseries = 'G2'.

      READ ENTITIES OF zmm_ih_unload IN LOCAL MODE
        ENTITY UnloadHead BY \_Item
          FIELDS ( Purchaseorder Purchaseorderitem Unloadind )
          WITH VALUE #( ( %tky = ls_head-%tky ) )
        RESULT DATA(lt_new).

      SELECT purchaseorder, purchaseorderitem, unloadind, weightindicator
        FROM zmmge_itm_t01
        WHERE uuid = @ls_head-Uuid
        INTO TABLE @DATA(lt_db).

      DATA(lv_newcount) = 0.
      DATA(lv_text)     = ``.
      LOOP AT lt_new INTO DATA(ls_new) WHERE Unloadind = abap_true.
        IF NOT line_exists( lt_db[ purchaseorder     = ls_new-Purchaseorder
                                   purchaseorderitem = ls_new-Purchaseorderitem
                                   unloadind         = abap_true ] ).
          lv_newcount = lv_newcount + 1.
        ENDIF.
      ENDLOOP.

      IF lv_newcount > 1.
        lv_text = |G2: finish unloading of one PO line at a time|.
      ELSEIF lv_newcount = 1.
        LOOP AT lt_db INTO DATA(ls_wait) WHERE unloadind = abap_true AND weightindicator = ''.
          lv_text = |Weigh PO { ls_wait-purchaseorder }/{ CONV i( ls_wait-purchaseorderitem ) } first|.
          EXIT.
        ENDLOOP.
      ENDIF.

      IF lv_text IS NOT INITIAL.
        LOOP AT lt_link INTO ls_lnk WHERE target-%tky = ls_head-%tky.
          APPEND VALUE #( %tky = ls_lnk-source-%tky ) TO failed-unloaditem.
          APPEND VALUE #( %tky        = ls_lnk-source-%tky
                          %state_area = 'CHECK_G2UNL'
                          %path       = VALUE #( unloadhead-%tky = ls_head-%tky )
                          %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                               text     = lv_text )
                          %element-Unloadind = if_abap_behv=>mk-on ) TO reported-unloaditem.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

