CLASS lsc_zmm_ih_rpnp DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zmm_ih_rpnp IMPLEMENTATION.

  METHOD save_modified.
*  if zbp_mm_ih_rpnp=>gt_gpitm is not INITIAL.
*    MODIFY zmm_app1_itb FROM TABLE @zbp_mm_ih_rpnp=>gt_gpitm.
*  ENDIF.
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

    METHODS checked FOR MODIFY
      keys FOR ACTION _Header~checked RESULT result.

    METHODS MaterialInput FOR MODIFY
      keys FOR ACTION _Header~MaterialInput RESULT result.

    METHODS printout FOR MODIFY
      keys FOR ACTION _Header~printout RESULT result.

    METHODS RGP_NRGP_number FOR MODIFY
      keys FOR ACTION _Header~RGP_NRGP_number RESULT result.
    METHODS head_modify FOR DETERMINE ON SAVE
      keys FOR _Header~head_modify.
    METHODS UpdateAdd FOR DETERMINE ON MODIFY
      keys FOR _Header~UpdateAdd.

    "! Reads PO item data from S/4; connection errors come back in rs_response-message
    METHODS read_product_details
      IMPORTING iv_product          TYPE zmm_app1_itb-matnr
                iv_plant            TYPE zmmge_itm_t01-plant
      RETURNING VALUE(rs_response) TYPE zcl_mm_s4_gate_api=>ty_response.

    "!
    "! @parameter iv_supplier |
    "! @parameter rs_response |
    METHODS read_supaddress_details
      IMPORTING iv_supplier          TYPE ZMM_APP1_TB-vendnum
      RETURNING VALUE(rs_response) TYPE zcl_mm_s4_gate_api=>ty_response.


ENDCLASS.

CLASS lhc__Header IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD checked.
  ENDMETHOD.

  METHOD MaterialInput.


            READ ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
            ENTITY _Header
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_header)
            ENTITY _Header BY \_Item1
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_item)
            FAILED DATA(lt_failed).

            DATA(ls_header) = VALUE #( lt_header[ 1 ] optional ).
            DATA(gs_keys)   = VALUE #( keys[ 1 ] OPTIONAL ).
            DATA(gt_keys) = keys.
            DATA: lv_itemno TYPE ZMM_APP1_ITB-itemno.
            DATA ls_response    TYPE zcl_mm_s4_gate_api=>ty_response.
            DATA(lv_product)     = CONV zmm_app1_itb-matnr( gs_keys-%param-Product ).
            DATA(lv_plant) = CONV zmm_app1_itb-plant( gs_keys-%param-Plant ).

            ls_response = read_product_details( iv_product = lv_product iv_plant = lv_plant ).

            SELECT SINGLE max( itemno ) from ZMM_APP1_ITB WITH PRIVILEGED ACCESS
            WHERE uuid = @ls_header-Uuid
            INTO @DATA(ls_itemno).

            if sy-subrc = 0 and ls_itemno is NOT INITIAL.
            lv_itemno = ls_itemno + 10.
            ELSE.
            lv_itemno = 10.
            ENDIF.

            IF ls_response-success = abap_true.

                  MODIFY ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
                  ENTITY _Header
                  CREATE BY \_Item1
                  AUTO FILL CID
                  FIELDS ( itemno matnr maktx uom plant plantname hsncode
                            curky netprice )
                    WITH VALUE #( for gs_head in lt_header
                                ( %is_draft = gs_head-%is_draft
                                  %key = CORRESPONDING #( gs_head )

                                  %target = VALUE #( for ls_product in ls_response-products
                                  ( %cid = |CID{ lv_itemno }|
                                               itemno = lv_itemno
                                               matnr = gs_keys-%param-Product
                                               Plant = gs_keys-%param-Plant
                                               Uom = ls_product-baseunit
                                               maktx = ls_product-prodesc
                                               Plantname = ls_product-plantname
                                               Hsncode = ls_product-hsncode
                                               Netprice = ls_product-netprice
                                               Curky = ls_product-currency
                                               rgpnrpactualno = ls_header-Rgpnrpactualno
                                 )  ) ) )
                    MAPPED mapped
                    FAILED failed
                    REPORTED reported.

              ELSEIF ls_response-message IS NOT INITIAL.
                APPEND VALUE #( %tky = ls_header-%tky ) TO failed-_header.
                APPEND VALUE #( %tky = ls_header-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                    text     = ls_response-message ) )
             TO reported-_header.
    ENDIF.


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    result = VALUE #( FOR ls_output IN lt_header ( %tky = ls_output-%tky
                                                              %param = ls_output ) ).

  ENDMETHOD.

  METHOD printout.


            READ ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
            ENTITY _Header
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_head)
            FAILED DATA(lt_failed).

            DATA(ls_head) = VALUE #( lt_head[ 1 ] OPTIONAL ).

            if ls_head-Rgpnrpactualno is NOT INITIAL.

            DATA: lv_form_name     TYPE string,
                  lv_template_name TYPE string,
                  lv_filename TYPE string.

            CASE ls_head-gptype.
                  WHEN 'RGP'.
                    lv_form_name = 'ZRGP_DELIVERYCHALAN'.
                    lv_template_name = 'ZRGP_DELIVERYCHALAN'.
                    lv_filename = |RGP_Doc-{ ls_head-Rgpnrpactualno }|.
                  WHEN 'NRGP'.
                    lv_form_name = 'ZNRGP_DELIVERYCHALAN'.
                    lv_template_name = 'ZNRGP_DELIVERYCHALAN'.
                    lv_filename = |NRGP_Doc-{ ls_head-Rgpnrpactualno }|.
                  WHEN OTHERS.
                RETURN.
            ENDCASE.


      TRY.
          DATA(lo_fdp)  = cl_fp_fdp_services=>get_instance( iv_service_definition = 'ZMM_APP1_CE1'
                                                             iv_root_node          = 'ZMM_APP1_CE1'
                                                              ).
          DATA(lt_keys) = lo_fdp->get_keys( ).
          lt_keys[ name = 'UUID' ]-value = ls_head-Uuid.
          DATA(lv_xml)  = lo_fdp->read_to_xml( lt_keys ).

          DATA(lv_pdf)  = zcl_ge_adobe_pdf=>render( iv_form_name     = lv_form_name
                                                    iv_template_name = lv_template_name
                                                    iv_xml_data      = lv_xml ).

        CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-_header.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Slip data: { lx_fdp->get_text( ) }| ) )
                 TO reported-_header.
          RETURN.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-_header.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Adobe: HTTP { lx_ads->mv_http_status_code } { lx_ads->mv_http_reason }| ) )
                 TO reported-_header.
          RETURN.
      ENDTRY.

      MODIFY ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
        ENTITY _Header
          UPDATE FIELDS ( Zattachment Minetype Filename )
          WITH VALUE #( ( %tky       = ls_head-%tky
                          Zattachment = lv_pdf
                          Minetype   = 'application/pdf'
                          Filename   = lv_filename ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Gate entry slip created for { ls_head-Rgpnrpactualno }| ) )
             TO reported-_header.


    result = VALUE #( FOR ls_r IN lt_head ( %tky = ls_r-%tky %param = ls_r ) ).


            ENDIF.
  ENDMETHOD.

  METHOD RGP_NRGP_number.
**********************************************************************
            DATA: lv_seq TYPE ZMM_APP1_TB-seqnum,
                  lv_gatenumber TYPE ZMM_APP1_TB-rgpnrpactualno.

            READ ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
            ENTITY _Header
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_header)
            ENTITY _Header BY \_Item1
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_item)
            FAILED DATA(lt_failed).

            DATA(ls_header) = VALUE #( lt_header[ 1 ] OPTIONAL ).

            if ls_header-Gptype is NOT INITIAL.

***********************************************************************
            GET TIME STAMP FIELD Data(ts).
            CONVERT TIME STAMP ts TIME ZONE 'INDIA' INTO DATE DATA(lv_date) TIME DATA(lv_time).
***********************************************************************

            SELECT SINGLE MAX( seqnum ) AS Seqnum,
                  gitdat
            FROM ZMM_APP1_TB
            WHERE gitdat = @lv_date
            AND gptype = @ls_header-Gptype
            GROUP BY gitdat
            INTO @DATA(gs_seqno).

***********************************************************************
            if sy-subrc = 0 and gs_seqno-seqnum is not INITIAL.
                lv_seq = gs_seqno-seqnum + 1.
                lv_gatenumber = |{ ls_header-Gptype }{ lv_date }-{ lv_seq }|.
            else.
                lv_seq = '001'.
                lv_gatenumber = |{ ls_header-Gptype }{ lv_date }-{ lv_seq }|.
            endif.
***********************************************************************

           MODIFY ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
           ENTITY _Header
           UPDATE
           FIELDS ( seqnum rgpnrpactualno )
           WITH VALUE #( for key IN keys
                            ( %tky = ls_header-%tky
                         seqnum = lv_seq
                         rgpnrpactualno = lv_gatenumber
                         %control-seqnum = if_abap_behv=>mk-on
                         %control-rgpnrpactualno = if_abap_behv=>mk-on
                         ) ).

          "item Update

            ENDIF.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    result = VALUE #( FOR ls_output IN lt_header ( %tky = ls_output-%tky
                                                              %param = ls_output ) ).


  ENDMETHOD.

  METHOD head_modify.
            READ ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
            ENTITY _Header
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_header)
            ENTITY _Header BY \_Item1
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_item)
            FAILED DATA(lt_failed).

            DATA(ls_header) = VALUE #( lt_header[ 1 ] OPTIONAL ).

            if ls_header-Gptype is NOT INITIAL.

***********************************************************************
            GET TIME STAMP FIELD Data(ts).
            CONVERT TIME STAMP ts TIME ZONE 'INDIA' INTO DATE DATA(lv_date) TIME DATA(lv_time).
***********************************************************************
           MODIFY ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
           ENTITY _Header
           UPDATE
           FIELDS ( gitdat  )
           WITH VALUE #( for key IN keys
                            ( %tky = ls_header-%tky
                         gitdat = lv_date
                         %control-gitdat = if_abap_behv=>mk-on
                         ) ).

            ENDIF.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

  ENDMETHOD.

  METHOD read_product_details.
    TRY.
        rs_response = zcl_mm_s4_gate_api=>call( VALUE #( operation         = 'PRODUCT'
                                                         product     = iv_product
                                                         plant = iv_plant ) ).
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

  METHOD read_supaddress_details.
    TRY.
        rs_response = zcl_mm_s4_gate_api=>call( VALUE #( operation         = 'SUPADD'
                                                         supplier     = iv_supplier
                                                          ) ).
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

  METHOD UpdateAdd.

            READ ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
            ENTITY _Header
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_head)
            FAILED DATA(lt_failed).

            DATA(ls_head) = VALUE #( lt_head[ 1 ] OPTIONAL ).
            DATA ls_response    TYPE zcl_mm_s4_gate_api=>ty_response.
            data(lv_supplier) = CONV ZMM_APP1_TB-vendnum( ls_head-Vendnum ).
            ls_response = read_supaddress_details( iv_supplier = lv_supplier ).
            DATA(ls_suppaddress) = VALUE #( ls_response-supaddress[ 1 ] OPTIONAL ).

            if ls_suppaddress is NOT INITIAL.

               MODIFY ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
               ENTITY _Header
               UPDATE
               FIELDS ( Addressid Vendname Streetname Bpaddrstreetname
                        Gstin Cityname Postalcode Pan Phone Region EmailAddress  )
               WITH VALUE #( for key IN keys
                            ( %tky = ls_head-%tky
                             Addressid = ls_suppaddress-addressid
                             Vendname = ls_suppaddress-suppliername
                             Streetname = ls_suppaddress-streetname
                             Bpaddrstreetname = ls_suppaddress-bpaddrstreetname
                             Gstin = ls_suppaddress-gstin
                             Cityname = ls_suppaddress-cityname
                             Postalcode = ls_suppaddress-postalcode
                             Pan = ls_suppaddress-pan
                             Phone = ls_suppaddress-phone
                             Region = ls_suppaddress-region
                             EmailAddress = ls_suppaddress-emailaddress

                             %control-Addressid = if_abap_behv=>mk-on
                             %control-Vendname = if_abap_behv=>mk-on
                             %control-Streetname = if_abap_behv=>mk-on
                             %control-Bpaddrstreetname = if_abap_behv=>mk-on
                             %control-Gstin = if_abap_behv=>mk-on
                             %control-Cityname = if_abap_behv=>mk-on
                             %control-Postalcode = if_abap_behv=>mk-on
                             %control-Pan = if_abap_behv=>mk-on
                             %control-Phone = if_abap_behv=>mk-on
                             %control-Region = if_abap_behv=>mk-on
                             %control-EmailAddress = if_abap_behv=>mk-on
                             ) ).

            ENDIF.

  ENDMETHOD.

ENDCLASS.

CLASS lhc__Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR _Item RESULT result.

    METHODS quant FOR VALIDATE ON SAVE
      keys FOR _Item~quant.
    METHODS Additem FOR DETERMINE ON MODIFY
      keys FOR _Item~Additem.
    METHODS Update FOR DETERMINE ON MODIFY
      keys FOR _Item~Update.

ENDCLASS.

CLASS lhc__Item IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD quant.
  ENDMETHOD.

  METHOD Additem.

*        DATA: ls_gpientry TYPE  ZMM_APP1_ITB-itemno.
*        DATA: lt_upitem TYPE TABLE of zmm_app1_itb,
*              ls_upitem TYPE zmm_app1_itb.
*
*        READ ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
*        ENTITY _Header
*        ALL FIELDS WITH CORRESPONDING #( keys )
*        RESULT DATA(lt_head)
*        ENTITY _Item
*        ALL FIELDS WITH CORRESPONDING #( keys )
*        RESULT DATA(lt_item)
*        FAILED DATA(lt_failed).
*
*        DATA(ls_header) = VALUE #( lt_head[ 1 ] OPTIONAL ).
*
*        loop AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
*        if <ls_item> is ASSIGNED.
*
*        SELECT SINGLE MAX( itemno ) FROM ZMM_APP1_ITB
*          WHERE uuid = @ls_header-uuid
*          INTO @DATA(ls_sno).
*
*        IF sy-subrc = 0 AND NOT ls_sno IS INITIAL.
*        ls_gpientry = ls_sno + 10.
*        ELSE.
*        ls_gpientry = 10.
*        ENDIF.
*
*        if ls_gpientry is NOT INITIAL.
*            MOVE-CORRESPONDING <ls_item> to ls_upitem.
*            ls_upitem-itemno = ls_gpientry.
*
*            APPEND ls_upitem to lt_upitem.
*        ENDIF.
*        ENDIF.
*        ENDLOOP.
*        zbp_mm_ih_rpnp=>gt_gpitm = lt_upitem.
  ENDMETHOD.

  METHOD Update.

        data:lv_totalvalue TYPE zmm_app1_itb-totvalue.

        READ ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
        ENTITY _Header
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_head)
        ENTITY _Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).


        DATA(ls_header) = VALUE #( lt_head[ 1 ] optional ).

        LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
        if <ls_item> is ASSIGNED.
            lv_totalvalue = ( <ls_item>-Quantity * <ls_item>-Netprice ).

           MODIFY ENTITIES OF zmm_ih_rpnp IN LOCAL MODE
           ENTITY _Item
           UPDATE
           FIELDS ( Totvalue Rgpnrpactualno  )
           WITH VALUE #( for key IN keys
                            ( %tky = <ls_item>-%tky
                         Totvalue = lv_totalvalue
                         Rgpnrpactualno = ls_header-Rgpnrpactualno
                         %control-Totvalue = if_abap_behv=>mk-on
                         %control-Rgpnrpactualno = if_abap_behv=>mk-on
                         ) ).

        ENDIF.
        clear: lv_totalvalue.
        ENDLOOP.

  ENDMETHOD.

ENDCLASS.
