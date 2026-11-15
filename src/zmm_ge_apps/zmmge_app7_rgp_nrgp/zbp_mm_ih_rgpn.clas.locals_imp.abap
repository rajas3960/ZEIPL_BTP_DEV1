*----------------------------------------------------------------------*
* Helper: constants, India date/time, current user
*----------------------------------------------------------------------*
CLASS lcl_util DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc_status,
        created         TYPE zmmge_rgp_hd-gpstatus VALUE '01',
        gate_verified   TYPE zmmge_rgp_hd-gpstatus VALUE '02',
        gate_out        TYPE zmmge_rgp_hd-gpstatus VALUE '03',
        partly_returned TYPE zmmge_rgp_hd-gpstatus VALUE '04',
        closed          TYPE zmmge_rgp_hd-gpstatus VALUE '05',
      END OF gc_status,
      gc_rgp  TYPE zmmge_rgp_hd-gptype VALUE 'RGP',
      gc_nrgp TYPE zmmge_rgp_hd-gptype VALUE 'NRGP'.

    CLASS-METHODS now_india
      EXPORTING ev_date TYPE d
                ev_time TYPE t.
    CLASS-METHODS user
      RETURNING VALUE(rv_user) TYPE zmmge_rgp_hd-gvby.
ENDCLASS.

CLASS lcl_util IMPLEMENTATION.
  METHOD now_india.
    GET TIME STAMP FIELD DATA(lv_ts).
    CONVERT TIME STAMP lv_ts TIME ZONE 'INDIA' INTO DATE ev_date TIME ev_time.
  ENDMETHOD.

  METHOD user.
    rv_user = cl_abap_context_info=>get_user_technical_name( ).
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Header
*----------------------------------------------------------------------*
CLASS lhc_Header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Header RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Header RESULT result.

    METHODS AddMaterial FOR MODIFY
      IMPORTING keys FOR ACTION Header~AddMaterial RESULT result.
    METHODS PrintPreview FOR MODIFY
      IMPORTING keys FOR ACTION Header~PrintPreview RESULT result.
    METHODS GateVerify FOR MODIFY
      IMPORTING keys FOR ACTION Header~GateVerify RESULT result.
    METHODS GateOut FOR MODIFY
      IMPORTING keys FOR ACTION Header~GateOut RESULT result.

    METHODS SetDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~SetDefaults.
    METHODS GetVendorAddress FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~GetVendorAddress.
    METHODS AssignNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Header~AssignNumber.
    METHODS CalcTotalsAndStatus FOR DETERMINE ON SAVE
      IMPORTING keys FOR Header~CalcTotalsAndStatus.

    METHODS ValidateHeader FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~ValidateHeader.
    METHODS uptransporter FOR DETERMINE ON MODIFY
      keys FOR Header~uptransporter.

    "! Material master data from S/4 (operation PRODUCT)
    METHODS read_product
      IMPORTING iv_product         TYPE zmmge_rgp_it-matnr
                iv_plant           TYPE werks_d
      RETURNING VALUE(rs_response) TYPE zcl_mm_s4_gate_api=>ty_response.
    "! Supplier address from S/4 (operation SUPADD)
    METHODS read_supplier
      IMPORTING iv_supplier        TYPE zmmge_rgp_hd-vendnum
      RETURNING VALUE(rs_response) TYPE zcl_mm_s4_gate_api=>ty_response.

    "! @parameter iv_transp |
    "! @parameter rs_response |
    METHODS read_transporter_details
      IMPORTING iv_transp          TYPE zsdge_sentry_ht1-transportid
      RETURNING VALUE(rs_response) TYPE zcl_sd_s4_owght_api=>ty_response.

ENDCLASS.

CLASS lhc_Header IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Gptype Gpstatus Gpno ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      FAILED failed.

    LOOP AT lt_head INTO DATA(ls_head).
      " open = not yet verified at the gate -> App 1 may still change it
      DATA(lv_open) = xsdbool( ls_head-Gpstatus IS INITIAL
                            OR ls_head-Gpstatus = lcl_util=>gc_status-created

                            OR ls_head-Gpstatus = lcl_util=>gc_status-gate_verified ).  """""""Changed By Prudhvi"""""""

      " RGP out of the gate and not closed -> App 3 may record returns
      DATA(lv_return) = xsdbool( ls_head-Gptype = lcl_util=>gc_rgp
                             AND ( ls_head-Gpstatus = lcl_util=>gc_status-gate_out
                                OR ls_head-Gpstatus = lcl_util=>gc_status-partly_returned ) ).
      DATA(lv_active) = xsdbool( ls_head-%is_draft = if_abap_behv=>mk-off ).

      APPEND VALUE #(
        %tky                 = ls_head-%tky
        %update              = COND #( WHEN lv_open = abap_true OR lv_return = abap_true
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %delete              = COND #( WHEN lv_open = abap_true
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Edit         = COND #( WHEN lv_open = abap_true OR lv_return = abap_true
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %assoc-_Item         = COND #( WHEN lv_open = abap_true
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-AddMaterial  = COND #( WHEN lv_open = abap_true AND lv_active = abap_false
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-PrintPreview = COND #( WHEN lv_active = abap_true AND ls_head-Gpno IS NOT INITIAL
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-GateVerify   = COND #( WHEN lv_active = abap_true AND ls_head-Gpstatus = lcl_util=>gc_status-created
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-GateOut      = COND #( WHEN lv_active = abap_true AND ls_head-Gpstatus = lcl_util=>gc_status-gate_verified
                                       THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %field-Remarks          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-read_only ) "" changed by prudhvi
        %field-Contpr          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-read_only )

        %field-Plant           = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-read_only )
        %field-Vendnum         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-read_only )
        %field-Issuedate       = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-read_only )
        %field-Plnrtndate      = COND #( WHEN lv_open = abap_false                 THEN if_abap_behv=>fc-f-read_only
                                         WHEN ls_head-Gptype = lcl_util=>gc_rgp    THEN if_abap_behv=>fc-f-mandatory
                                         WHEN ls_head-Gptype = lcl_util=>gc_nrgp   THEN if_abap_behv=>fc-f-read_only
                                         ELSE if_abap_behv=>fc-f-unrestricted )
        %field-Rsngp           = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Reqby           = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Reqdpt          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
*        %field-Contpr          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
*        %field-Remarks         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Dispby          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Vehicleno       = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Vehicletype     = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Transporterid   = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Transportername = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Lrnumber        = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Lrdate          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Ewabillno       = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Insurno         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Frghtscope      = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Pcklist         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Fromplace       = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Toplace         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Netwgt          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Grosswgt        = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Tarewgt         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Wgtuom          = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_global_authorizations.
    " Access is controlled by the BTP role collections / IAS groups per app
    " (initial value of the action components = allowed)
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD AddMaterial.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY Header BY \_Item FIELDS ( Gpuuid Itemno ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_head INTO DATA(ls_head)
           WITH KEY %is_draft = ls_key-%is_draft Gpuuid = ls_key-Gpuuid.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_plant) = COND werks_d( WHEN ls_key-%param-Plant IS NOT INITIAL
                                     THEN ls_key-%param-Plant ELSE ls_head-Plant ).
      DATA(lv_qty)   = CONV zmmge_rgp_it-quantity( ls_key-%param-Quantity ).

      DATA(lv_error) = COND string(
        WHEN ls_key-%param-Product IS INITIAL OR lv_plant IS INITIAL
          THEN `Enter a material and a plant`
        WHEN lv_qty <= 0
          THEN `Enter a quantity greater than zero`
        WHEN ls_head-Plant IS NOT INITIAL AND lv_plant <> ls_head-Plant
          THEN |All materials must be from plant { ls_head-Plant }| ).

      DATA ls_product TYPE LINE OF zcl_mm_s4_gate_api=>ty_response-products.
      CLEAR ls_product.
      IF lv_error IS INITIAL.
        DATA(ls_response) = read_product( iv_product = CONV #( ls_key-%param-Product )
                                          iv_plant   = lv_plant ).
        ls_product = VALUE #( ls_response-products[ 1 ] OPTIONAL ).
        IF ls_response-success = abap_false OR ls_product IS INITIAL.
          lv_error = COND #( WHEN ls_response-message IS NOT INITIAL THEN ls_response-message
                             ELSE |Material { ls_key-%param-Product } not found in plant { lv_plant }| ).
        ENDIF.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-header.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_error ) ) TO reported-header.
        CONTINUE.
      ENDIF.

      " next item number = highest existing (draft) item + 10
      DATA(lv_itemno) = CONV zmmge_rgp_it-itemno( 0 ).
      LOOP AT lt_item INTO DATA(ls_item)
           WHERE %is_draft = ls_head-%is_draft AND Gpuuid = ls_head-Gpuuid.
        IF ls_item-Itemno > lv_itemno.
          lv_itemno = ls_item-Itemno.
        ENDIF.
      ENDLOOP.
      lv_itemno = lv_itemno + 10.
      " remember it, in case the same header gets two materials in one call
      APPEND VALUE #( %is_draft = ls_head-%is_draft Gpuuid = ls_head-Gpuuid Itemno = lv_itemno ) TO lt_item.

      MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
        ENTITY Header
          CREATE BY \_Item
          FIELDS ( Gpuuid Itemno Matnr Maktx Plant Plantname Hsncode Uom
                   Quantity Netprice Curky Totvalue Totopnqty )
          WITH VALUE #( ( %tky    = ls_head-%tky
                          %target = VALUE #( ( %cid      = |ITEM{ lv_itemno }|
                                               %is_draft = ls_head-%is_draft
                                               Gpuuid    = ls_head-Gpuuid
                                               Itemno    = lv_itemno
                                               Matnr     = ls_key-%param-Product
                                               Maktx     = ls_product-prodesc
                                               Plant     = lv_plant
                                               Plantname = ls_product-plantname
                                               Hsncode   = ls_product-hsncode
                                               Uom       = ls_product-baseunit
                                               Quantity  = lv_qty
                                               Netprice  = ls_product-netprice
                                               Curky     = ls_product-currency
                                               Totvalue  = lv_qty * ls_product-netprice
                                               Totopnqty = lv_qty ) ) ) )
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported).

      " first material fixes the issuing plant of the gate pass
      IF ls_head-Plant IS INITIAL OR ls_head-Plantname IS INITIAL.
        MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
          ENTITY Header
            UPDATE FIELDS ( Plant Plantname )
            WITH VALUE #( ( %tky = ls_head-%tky Plant = lv_plant Plantname = ls_product-plantname ) ).
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD PrintPreview.
    CONSTANTS: lc_print_service TYPE string VALUE 'ZMM_RGPN_PRT',
               lc_print_root    TYPE string VALUE 'ZMM_RGPN_PRT_H'.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA(lv_form) = COND string( WHEN ls_head-Gptype = lcl_util=>gc_rgp  THEN `ZRGP_DELIVERYCHALAN`
                                   WHEN ls_head-Gptype = lcl_util=>gc_nrgp THEN `ZNRGP_DELIVERYCHALAN` ).
      IF ls_head-Gpno IS INITIAL OR lv_form IS INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-header.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `Save the gate pass before printing` ) )
               TO reported-header.
        CONTINUE.
      ENDIF.

      TRY.
          DATA(lo_fdp)  = cl_fp_fdp_services=>get_instance( iv_service_definition = CONV #( lc_print_service )
                                                             iv_root_node          = CONV #( lc_print_root ) ).
          DATA(lt_keys) = lo_fdp->get_keys( ).
*          lt_keys[ name = 'GPUUID' ]-value = ls_head-Gpuuid.
          lt_keys[ name = 'UUID' ]-value = ls_head-Gpuuid.
*          DATA(lv_xml)  = lo_fdp->read_to_xml( lt_keys ).
          " The Adobe forms were designed on the old print service: rename the nodes they are bound to
          DATA(lv_xml_str) = cl_abap_conv_codepage=>create_in( )->convert( lo_fdp->read_to_xml( lt_keys ) ).
          REPLACE ALL OCCURRENCES OF `ZMM_RGPN_PRT_H>` IN lv_xml_str WITH `ZMM_APP1_CE1>`.
          REPLACE ALL OCCURRENCES OF `ZMM_RGPN_PRT_I>` IN lv_xml_str WITH `ZPP_APPS05_CITM>`.
          DATA(lv_xml) = cl_abap_conv_codepage=>create_out( )->convert( lv_xml_str ).
          DATA(lv_pdf)  = zcl_ge_adobe_pdf=>render( iv_form_name     = lv_form
                                                    iv_template_name = lv_form
                                                    iv_xml_data      = lv_xml ).
        CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-header.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Print data: { lx_fdp->get_text( ) }| ) )
                 TO reported-header.
          CONTINUE.
        CATCH zcx_fp_tmpl_store_error INTO DATA(lx_ads).
          APPEND VALUE #( %tky = ls_head-%tky ) TO failed-header.
          APPEND VALUE #( %tky = ls_head-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Adobe: HTTP { lx_ads->mv_http_status_code } { lx_ads->mv_http_reason }| ) )
                 TO reported-header.
          CONTINUE.
      ENDTRY.

      MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
        ENTITY Header
          UPDATE FIELDS ( Attachment Mimetype Filename )
          WITH VALUE #( ( %tky       = ls_head-%tky
                          Attachment = lv_pdf
                          Mimetype   = 'application/pdf'
                          Filename   = |{ ls_head-Gpno }.pdf| ) ).

      APPEND VALUE #( %tky = ls_head-%tky
                      %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                    text     = |Delivery challan created for { ls_head-Gpno }| ) )
             TO reported-header.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD GateVerify.
    DATA: lv_last_rgp  TYPE zmmge_rgp_hd-gvnum,
          lv_last_nrgp TYPE zmmge_rgp_hd-gvnum.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Gptype Gpstatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    lcl_util=>now_india( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).
    DATA(lv_user) = lcl_util=>user( ).

    " Gate verify no.: RGP 8000000001.., NRGP 9000000001..
    SELECT SINGLE MAX( gvnum ) FROM zmmge_rgp_hd WHERE gptype = @lcl_util=>gc_rgp  INTO @lv_last_rgp.
    SELECT SINGLE MAX( gvnum ) FROM zmmge_rgp_hd WHERE gptype = @lcl_util=>gc_nrgp INTO @lv_last_nrgp.
    IF lv_last_rgp IS INITIAL.
      lv_last_rgp = '8000000000'.
    ENDIF.
    IF lv_last_nrgp IS INITIAL.
      lv_last_nrgp = '9000000000'.
    ENDIF.

    LOOP AT lt_head INTO DATA(ls_head).
      IF ls_head-Gpstatus <> lcl_util=>gc_status-created.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-header.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `Gate pass is already verified or not yet saved` ) )
               TO reported-header.
        CONTINUE.
      ENDIF.

      DATA lv_gvnum TYPE zmmge_rgp_hd-gvnum.
      IF ls_head-Gptype = lcl_util=>gc_rgp.
        lv_last_rgp = lv_last_rgp + 1.
        lv_gvnum    = lv_last_rgp.
      ELSE.
        lv_last_nrgp = lv_last_nrgp + 1.
        lv_gvnum     = lv_last_nrgp.
      ENDIF.

      MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
        ENTITY Header
          UPDATE FIELDS ( Gvnum Gvdat Gvtim Gvby Gpstatus )
          WITH VALUE #( ( %tky     = ls_head-%tky
                          Gvnum    = lv_gvnum
                          Gvdat    = lv_date
                          Gvtim    = lv_time
                          Gvby     = lv_user
                          Gpstatus = lcl_util=>gc_status-gate_verified ) ).
    ENDLOOP.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD GateOut.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Gptype Gpstatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY Header BY \_Item FIELDS ( Gpuuid ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    lcl_util=>now_india( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).
    DATA(lv_user) = lcl_util=>user( ).

    LOOP AT lt_head INTO DATA(ls_head).
      IF ls_head-Gpstatus <> lcl_util=>gc_status-gate_verified.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-header.
        APPEND VALUE #( %tky = ls_head-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `Gate Verify must be done before Gate Out` ) )
               TO reported-header.
        CONTINUE.
      ENDIF.

      " NRGP is finished at Gate Out; RGP waits for returns
      DATA(lv_status) = COND zmmge_rgp_hd-gpstatus( WHEN ls_head-Gptype = lcl_util=>gc_nrgp THEN lcl_util=>gc_status-closed
                                ELSE lcl_util=>gc_status-gate_out ).

      MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
        ENTITY Header
          UPDATE FIELDS ( Gotdat Gottim Gotby Gpstatus )
          WITH VALUE #( ( %tky     = ls_head-%tky
                          Gotdat   = lv_date
                          Gottim   = lv_time
                          Gotby    = lv_user
                          Gpstatus = lv_status ) ).

      IF ls_head-Gptype = lcl_util=>gc_nrgp.
        MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
          ENTITY Item
            UPDATE FIELDS ( Closed Totopnqty )
            WITH VALUE #( FOR i IN lt_item WHERE ( Gpuuid = ls_head-Gpuuid )
                          ( %tky = i-%tky Closed = abap_true Totopnqty = 0 ) ).
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD SetDefaults.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Issuedate Issuedby Curky Wgtuom ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    lcl_util=>now_india( IMPORTING ev_date = DATA(lv_date) ).
    DATA(lv_user) = lcl_util=>user( ).

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header
        UPDATE FIELDS ( Issuedate Issuedby Curky Wgtuom )
        WITH VALUE #( FOR h IN lt_head WHERE ( Issuedate IS INITIAL )
                      ( %tky      = h-%tky
                        Issuedate = lv_date
                        Issuedby  = lv_user
                        Curky     = COND #( WHEN h-Curky  IS INITIAL THEN 'INR' ELSE h-Curky )
                        Wgtuom    = COND #( WHEN h-Wgtuom IS INITIAL THEN 'KG'  ELSE h-Wgtuom ) ) ).
  ENDMETHOD.

  METHOD GetVendorAddress.
    DATA lt_update TYPE TABLE FOR UPDATE zmm_ih_rgpn\\Header.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Vendnum ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA ls_addr TYPE LINE OF zcl_mm_s4_gate_api=>ty_response-supaddress.
      CLEAR ls_addr.

      IF ls_head-Vendnum IS NOT INITIAL.
        DATA(ls_response) = read_supplier( ls_head-Vendnum ).
        ls_addr = VALUE #( ls_response-supaddress[ 1 ] OPTIONAL ).
        IF ls_addr IS INITIAL.
          APPEND VALUE #( %tky             = ls_head-%tky
                          %element-Vendnum = if_abap_behv=>mk-on
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-warning
                                   text     = COND #( WHEN ls_response-message IS NOT INITIAL THEN ls_response-message
                                                      ELSE |No address found in S/4 for vendor { ls_head-Vendnum }| ) ) )
                 TO reported-header.
        ENDIF.
      ENDIF.

      " empty vendor or not found -> clear the old address
      APPEND VALUE #( %tky             = ls_head-%tky
                      Vendname         = ls_addr-suppliername
                      Addressid        = ls_addr-addressid
                      Streetname       = ls_addr-streetname
                      Bpaddrstreetname = ls_addr-bpaddrstreetname
                      Cityname         = ls_addr-cityname
                      Postalcode       = ls_addr-postalcode
                      Region           = ls_addr-region
                      Gstin            = ls_addr-gstin
                      Pan              = ls_addr-pan
                      Phone            = ls_addr-phone
                      Emailaddress     = ls_addr-emailaddress ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header
        UPDATE FIELDS ( Vendname Addressid Streetname Bpaddrstreetname Cityname
                        Postalcode Region Gstin Pan Phone Emailaddress )
        WITH lt_update.
  ENDMETHOD.

  METHOD AssignNumber.
    " Format <type><yyyymmdd>-<nnn>, e.g. RGP20261022-001, restarts daily per type
    TYPES: BEGIN OF ty_counter,
             prefix TYPE string,
             seq    TYPE i,
           END OF ty_counter.
    DATA: lt_counter TYPE SORTED TABLE OF ty_counter WITH UNIQUE KEY prefix,
          lt_update  TYPE TABLE FOR UPDATE zmm_ih_rgpn\\Header,
          lv_max     TYPE zmmge_rgp_hd-gpno.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Gptype Gpno ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    lcl_util=>now_india( IMPORTING ev_date = DATA(lv_date) ).

    LOOP AT lt_head INTO DATA(ls_head) WHERE Gpno IS INITIAL.
      DATA(lv_prefix) = |{ ls_head-Gptype }{ lv_date }-|.

      READ TABLE lt_counter ASSIGNING FIELD-SYMBOL(<ls_counter>) WITH TABLE KEY prefix = lv_prefix.
      IF sy-subrc <> 0.
        DATA(lv_pattern) = lv_prefix && `%`.
        CLEAR lv_max.
        SELECT SINGLE MAX( gpno ) FROM zmmge_rgp_hd
          WHERE gpno LIKE @lv_pattern
          INTO @lv_max.
        INSERT VALUE #( prefix = lv_prefix
                        seq    = COND #( WHEN lv_max IS INITIAL THEN 0
                                         ELSE CONV i( substring( val = condense( lv_max )
                                                                 off = strlen( condense( lv_max ) ) - 3
                                                                 len = 3 ) ) ) )
               INTO TABLE lt_counter ASSIGNING <ls_counter>.
      ENDIF.

      <ls_counter>-seq = <ls_counter>-seq + 1.
      APPEND VALUE #( %tky     = ls_head-%tky
                      Gpno     = |{ lv_prefix }{ <ls_counter>-seq WIDTH = 3 ALIGN = RIGHT PAD = '0' }|
                      Gpstatus = lcl_util=>gc_status-created ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header
        UPDATE FIELDS ( Gpno Gpstatus )
        WITH lt_update.
  ENDMETHOD.

  METHOD CalcTotalsAndStatus.
    " Recalculates item values/return totals, header total and RGP return status.
    " Runs on save and always in Prepare (covers deleted items and new receipts).
    DATA: lt_head_upd TYPE TABLE FOR UPDATE zmm_ih_rgpn\\Header,
          lt_item_upd TYPE TABLE FOR UPDATE zmm_ih_rgpn\\Item.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Gptype Gpstatus Gpvalue Curky ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY Header BY \_Item ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item BY \_Receipt FIELDS ( Itemuuid Recvqty Accqty Rjtqty ) WITH CORRESPONDING #( lt_item )
      RESULT DATA(lt_rcpt).

    LOOP AT lt_head INTO DATA(ls_head).
      DATA(lv_returning) = xsdbool( ls_head-Gptype = lcl_util=>gc_rgp
                                AND ( ls_head-Gpstatus = lcl_util=>gc_status-gate_out
                                   OR ls_head-Gpstatus = lcl_util=>gc_status-partly_returned ) ).
      DATA: lv_gpvalue    TYPE zmmge_rgp_hd-gpvalue,
            lv_curky      TYPE zmmge_rgp_hd-curky,
            lv_items      TYPE i,
            lv_closed     TYPE i,
            lv_progressed TYPE abap_boolean.
      CLEAR: lv_gpvalue, lv_curky, lv_items, lv_closed, lv_progressed.

      LOOP AT lt_item INTO DATA(ls_item)
           WHERE %is_draft = ls_head-%is_draft AND Gpuuid = ls_head-Gpuuid.
        DATA: lv_rcv TYPE zmmge_rgp_it-totrcvqty,
              lv_acc TYPE zmmge_rgp_it-totaccqty,
              lv_rjt TYPE zmmge_rgp_it-totrjtqty.
        CLEAR: lv_rcv, lv_acc, lv_rjt.
        LOOP AT lt_rcpt INTO DATA(ls_rcpt)
             WHERE %is_draft = ls_item-%is_draft AND Itemuuid = ls_item-Itemuuid.
          lv_rcv = lv_rcv + ls_rcpt-Recvqty.
          lv_acc = lv_acc + ls_rcpt-Accqty.
          lv_rjt = lv_rjt + ls_rcpt-Rjtqty.
        ENDLOOP.

        DATA(lv_value) = CONV zmmge_rgp_it-totvalue( ls_item-Quantity * ls_item-Netprice ).
        DATA(lv_open)  = COND zmmge_rgp_it-totopnqty( WHEN ls_item-Quantity > lv_acc
                                                       THEN ls_item-Quantity - lv_acc ELSE 0 ).
        DATA(lv_close) = ls_item-Closed.
        IF lv_returning = abap_true AND ls_item-Quantity > 0 AND lv_open = 0.
          lv_close = abap_true.
        ENDIF.

        IF lv_value <> ls_item-Totvalue OR lv_rcv <> ls_item-Totrcvqty OR lv_acc <> ls_item-Totaccqty
        OR lv_rjt <> ls_item-Totrjtqty OR lv_open <> ls_item-Totopnqty OR lv_close <> ls_item-Closed.
          APPEND VALUE #( %tky      = ls_item-%tky
                          Totvalue  = lv_value
                          Totrcvqty = lv_rcv
                          Totaccqty = lv_acc
                          Totrjtqty = lv_rjt
                          Totopnqty = lv_open
                          Closed    = lv_close ) TO lt_item_upd.
        ENDIF.

        lv_gpvalue = lv_gpvalue + lv_value.
        IF lv_curky IS INITIAL.
          lv_curky = ls_item-Curky.
        ENDIF.
        lv_items = lv_items + 1.
        IF lv_close = abap_true.
          lv_closed = lv_closed + 1.
        ENDIF.
        IF lv_acc > 0 OR lv_close = abap_true.
          lv_progressed = abap_true.
        ENDIF.
      ENDLOOP.

      DATA(lv_status) = ls_head-Gpstatus.
      IF lv_returning = abap_true.
        lv_status = COND #( WHEN lv_items > 0 AND lv_closed = lv_items THEN lcl_util=>gc_status-closed
                            WHEN lv_progressed = abap_true             THEN lcl_util=>gc_status-partly_returned
                            ELSE lcl_util=>gc_status-gate_out ).
      ENDIF.
      IF lv_curky IS INITIAL.
        lv_curky = ls_head-Curky.
      ENDIF.

      IF lv_gpvalue <> ls_head-Gpvalue OR lv_curky <> ls_head-Curky OR lv_status <> ls_head-Gpstatus.
        APPEND VALUE #( %tky     = ls_head-%tky
                        Gpvalue  = lv_gpvalue
                        Curky    = lv_curky
                        Gpstatus = lv_status ) TO lt_head_upd.
      ENDIF.
    ENDLOOP.

    IF lt_item_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
        ENTITY Item
          UPDATE FIELDS ( Totvalue Totrcvqty Totaccqty Totrjtqty Totopnqty Closed )
          WITH lt_item_upd.
    ENDIF.
    IF lt_head_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
        ENTITY Header
          UPDATE FIELDS ( Gpvalue Curky Gpstatus )
          WITH lt_head_upd.
    ENDIF.
  ENDMETHOD.

  METHOD ValidateHeader.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header FIELDS ( Gptype Plant Vendnum Issuedate Plnrtndate Contpr Remarks ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      ENTITY Header BY \_Item FIELDS ( Gpuuid ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT lt_head INTO DATA(ls_head).
      " clear old messages of this check
      APPEND VALUE #( %tky = ls_head-%tky %state_area = 'VALIDATE_HEADER' ) TO reported-header.

      DATA(lv_msg) = COND string(
        WHEN ls_head-Gptype <> lcl_util=>gc_rgp AND ls_head-Gptype <> lcl_util=>gc_nrgp
          THEN `Select gate pass type RGP or NRGP`
        WHEN ls_head-Plant IS INITIAL
          THEN `Enter the issuing plant`
        WHEN ls_head-Vendnum IS INITIAL
          THEN `Enter the vendor`
        WHEN ls_head-Contpr IS INITIAL
          THEN `Enter the Authorise Person`
       WHEN ls_head-Remarks IS INITIAL
          THEN `Enter the Remarks`

        WHEN ls_head-Issuedate IS INITIAL
          THEN `Enter the issue date`
        WHEN ls_head-Gptype = lcl_util=>gc_rgp AND ls_head-Plnrtndate IS INITIAL
          THEN `Enter the planned return date for an RGP`
        WHEN ls_head-Gptype = lcl_util=>gc_rgp AND ls_head-Plnrtndate < ls_head-Issuedate
          THEN `Planned return date cannot be before the issue date`
        WHEN NOT line_exists( lt_item[ %is_draft = ls_head-%is_draft Gpuuid = ls_head-Gpuuid ] )
          THEN `Add at least one material` ).

      IF lv_msg IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_head-%tky ) TO failed-header.
        APPEND VALUE #( %tky        = ls_head-%tky
                        %state_area = 'VALIDATE_HEADER'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msg ) ) TO reported-header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_product.
    TRY.
        rs_response = zcl_mm_s4_gate_api=>call( VALUE #( operation = 'PRODUCT'
                                                         product   = iv_product
                                                         plant     = iv_plant ) ).
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD read_supplier.
    TRY.
        rs_response = zcl_mm_s4_gate_api=>call( VALUE #( operation = 'SUPADD'
                                                         supplier  = iv_supplier ) ).
      CATCH cx_http_dest_provider_error cx_web_http_client_error INTO DATA(lx_error).
        rs_response = VALUE #( message = |S/4 not reachable: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD uptransporter.

            READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
            ENTITY Header
            ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(lt_head)
            FAILED DATA(lt_failed).

            DATA(ls_head) = VALUE #( lt_head[ 1 ] OPTIONAL ).
            DATA: lv_transp TYPE n LENGTH 10.
            DATA ls_response    TYPE ZCL_SD_S4_OWGHT_API=>ty_response.
            lv_transp = ls_head-Transporterid.
            DATA(lv_trans) = CONV zsdge_sentry_ht1-transportid( lv_transp ).
            ls_response = read_transporter_details( iv_transp = lv_trans ).


            if ls_response-transportername is NOT INITIAL.

              MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
                ENTITY Header
                UPDATE FIELDS ( transportername )
                WITH VALUE #( ( %tky       = ls_head-%tky
                               transportername = ls_response-transportername ) ).

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

ENDCLASS.

*----------------------------------------------------------------------*
* Item
*----------------------------------------------------------------------*
CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item RESULT result.
    METHODS DocumentClose FOR MODIFY
      IMPORTING keys FOR ACTION Item~DocumentClose RESULT result.
    METHODS CalcItemValue FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~CalcItemValue.
    METHODS ValidateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~ValidateQuantity.
ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item FIELDS ( Gpuuid Closed ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY Item BY \_Header FIELDS ( Gptype Gpstatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head)
      FAILED failed.

    LOOP AT lt_item INTO DATA(ls_item).
      READ TABLE lt_head INTO DATA(ls_head)
           WITH KEY %is_draft = ls_item-%is_draft Gpuuid = ls_item-Gpuuid.
      DATA(lv_open)   = xsdbool( ls_head-Gpstatus IS INITIAL
                              OR ls_head-Gpstatus = lcl_util=>gc_status-created ).
      DATA(lv_return) = xsdbool( ls_head-Gptype = lcl_util=>gc_rgp
                             AND ( ls_head-Gpstatus = lcl_util=>gc_status-gate_out
                                OR ls_head-Gpstatus = lcl_util=>gc_status-partly_returned )
                             AND ls_item-Closed = abap_false
                             AND ls_item-%is_draft = if_abap_behv=>mk-on ).

      APPEND VALUE #(
        %tky                  = ls_item-%tky
        %update               = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %delete               = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %assoc-_Receipt       = COND #( WHEN lv_return = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-DocumentClose = COND #( WHEN lv_return = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %field-Quantity        = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-mandatory    ELSE if_abap_behv=>fc-f-read_only )
        %field-Uom             = if_abap_behv=>fc-f-read_only
        %field-Netprice        = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Curky           = if_abap_behv=>fc-f-read_only
        %field-Taxcode         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Storagelocation = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Remarks         = COND #( WHEN lv_open = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.
  METHOD DocumentClose.
    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( Closed )
        WITH VALUE #( FOR k IN keys ( %tky = k-%tky Closed = abap_true ) ).

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD CalcItemValue.
    " live value of the changed items + header total
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item FIELDS ( Quantity Netprice Totaccqty ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY Item BY \_Header FIELDS ( Gpuuid ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_head).

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( Totvalue Totopnqty )
        WITH VALUE #( FOR i IN lt_item
                      ( %tky      = i-%tky
                        Totvalue  = i-Quantity * i-Netprice
                        Totopnqty = COND #( WHEN i-Quantity > i-Totaccqty THEN i-Quantity - i-Totaccqty ELSE 0 ) ) ).

    SORT lt_head BY %is_draft Gpuuid.
    DELETE ADJACENT DUPLICATES FROM lt_head COMPARING %is_draft Gpuuid.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header BY \_Item FIELDS ( Gpuuid Totvalue Curky ) WITH CORRESPONDING #( lt_head )
      RESULT DATA(lt_all).

    DATA lt_head_upd TYPE TABLE FOR UPDATE zmm_ih_rgpn\\Header.
    LOOP AT lt_head INTO DATA(ls_head).
      DATA lv_sum TYPE zmmge_rgp_hd-gpvalue.
      DATA lv_cur TYPE zmmge_rgp_hd-curky.
      CLEAR: lv_sum, lv_cur.
      LOOP AT lt_all INTO DATA(ls_all) WHERE %is_draft = ls_head-%is_draft AND Gpuuid = ls_head-Gpuuid.
        lv_sum = lv_sum + ls_all-Totvalue.
        IF lv_cur IS INITIAL.
          lv_cur = ls_all-Curky.
        ENDIF.
      ENDLOOP.
      APPEND VALUE #( %tky = ls_head-%tky Gpvalue = lv_sum Curky = lv_cur ) TO lt_head_upd.
    ENDLOOP.

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Header
        UPDATE FIELDS ( Gpvalue Curky )
        WITH lt_head_upd.
  ENDMETHOD.

  METHOD ValidateQuantity.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item FIELDS ( Itemno Quantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT lt_item INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = 'VALIDATE_QTY' ) TO reported-item.
      IF ls_item-Quantity <= 0.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-item.
        APPEND VALUE #( %tky              = ls_item-%tky
                        %state_area       = 'VALIDATE_QTY'
                        %element-Quantity = if_abap_behv=>mk-on
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |Item { ls_item-Itemno ALPHA = OUT }: quantity must be greater than zero| ) )
               TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* Receipt (RGP returns)
*----------------------------------------------------------------------*
CLASS lhc_Receipt DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Receipt RESULT result.
    METHODS SetReceiptDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Receipt~SetReceiptDefaults.
    METHODS CalcRejected FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Receipt~CalcRejected.
    METHODS AssignGateInNo FOR DETERMINE ON SAVE
      IMPORTING keys FOR Receipt~AssignGateInNo.
    METHODS ValidateReceipt FOR VALIDATE ON SAVE
      IMPORTING keys FOR Receipt~ValidateReceipt.
ENDCLASS.

CLASS lhc_Receipt IMPLEMENTATION.

  METHOD get_instance_features.
    " a receipt can only be changed until it is saved (gate-in no. assigned)
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt FIELDS ( Gateinno ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rcpt)
      FAILED failed.

    result = VALUE #( FOR r IN lt_rcpt
      LET lv_new = xsdbool( r-Gateinno IS INITIAL ) IN
      ( %tky                = r-%tky
        %update             = COND #( WHEN lv_new = abap_true THEN if_abap_behv=>fc-o-enabled    ELSE if_abap_behv=>fc-o-disabled )
        %delete             = COND #( WHEN lv_new = abap_true THEN if_abap_behv=>fc-o-enabled    ELSE if_abap_behv=>fc-o-disabled )
        %field-Recvqty      = COND #( WHEN lv_new = abap_true THEN if_abap_behv=>fc-f-mandatory  ELSE if_abap_behv=>fc-f-read_only )
        %field-Accqty       = COND #( WHEN lv_new = abap_true THEN if_abap_behv=>fc-f-mandatory  ELSE if_abap_behv=>fc-f-read_only )
        %field-Uom          = if_abap_behv=>fc-f-read_only
        %field-Invoice      = COND #( WHEN lv_new = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Challandate  = COND #( WHEN lv_new = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
        %field-Remarks      = COND #( WHEN lv_new = abap_true THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only ) ) ).
  ENDMETHOD.

  METHOD SetReceiptDefaults.
    DATA lt_update TYPE TABLE FOR UPDATE zmm_ih_rgpn\\Receipt.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt FIELDS ( Itemuuid Rcptno ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_new)
      ENTITY Receipt BY \_Item FIELDS ( Gpuuid Uom ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    SORT lt_item BY %is_draft Itemuuid.
    DELETE ADJACENT DUPLICATES FROM lt_item COMPARING %is_draft Itemuuid.

    " all receipts of these items, to continue the running receipt no.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item BY \_Receipt FIELDS ( Itemuuid Rcptno ) WITH CORRESPONDING #( lt_item )
      RESULT DATA(lt_all).

    lcl_util=>now_india( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA lv_no TYPE zmmge_rgp_rc-rcptno.
      CLEAR lv_no.
      LOOP AT lt_all INTO DATA(ls_all) WHERE %is_draft = ls_item-%is_draft AND Itemuuid = ls_item-Itemuuid.
        IF ls_all-Rcptno > lv_no.
          lv_no = ls_all-Rcptno.
        ENDIF.
      ENDLOOP.

      LOOP AT lt_new INTO DATA(ls_new)
           WHERE %is_draft = ls_item-%is_draft AND Itemuuid = ls_item-Itemuuid AND Rcptno IS INITIAL.
        lv_no = lv_no + 1.
        APPEND VALUE #( %tky       = ls_new-%tky
                        Gpuuid     = ls_item-Gpuuid
                        Uom        = ls_item-Uom
                        Rcptno     = lv_no
                        Gateindate = lv_date
                        Gateintime = lv_time ) TO lt_update.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt
        UPDATE FIELDS ( Gpuuid Uom Rcptno Gateindate Gateintime )
        WITH lt_update.
  ENDMETHOD.

  METHOD CalcRejected.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt FIELDS ( Recvqty Accqty ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rcpt).

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt
        UPDATE FIELDS ( Rjtqty )
        WITH VALUE #( FOR r IN lt_rcpt
                      ( %tky   = r-%tky
                        Rjtqty = COND #( WHEN r-Recvqty > r-Accqty THEN r-Recvqty - r-Accqty ELSE 0 ) ) ).
  ENDMETHOD.

  METHOD AssignGateInNo.
    DATA: lv_last   TYPE zmmge_rgp_rc-gateinno,
          lt_update TYPE TABLE FOR UPDATE zmm_ih_rgpn\\Receipt.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt FIELDS ( Gateinno ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rcpt).

    SELECT SINGLE MAX( gateinno ) FROM zmmge_rgp_rc INTO @lv_last.
    IF lv_last IS INITIAL.
      lv_last = '1000000000'.
    ENDIF.
    lcl_util=>now_india( IMPORTING ev_date = DATA(lv_date) ev_time = DATA(lv_time) ).

    LOOP AT lt_rcpt INTO DATA(ls_rcpt) WHERE Gateinno IS INITIAL.
      lv_last = lv_last + 1.
      APPEND VALUE #( %tky       = ls_rcpt-%tky
                      Gateinno   = lv_last
                      Gateindate = lv_date
                      Gateintime = lv_time ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt
        UPDATE FIELDS ( Gateinno Gateindate Gateintime )
        WITH lt_update.
  ENDMETHOD.

  METHOD ValidateReceipt.
    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Receipt FIELDS ( Itemuuid Rcptno Recvqty Accqty ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rcpt)
      ENTITY Receipt BY \_Item FIELDS ( Itemno Quantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    SORT lt_item BY %is_draft Itemuuid.
    DELETE ADJACENT DUPLICATES FROM lt_item COMPARING %is_draft Itemuuid.

    READ ENTITIES OF zmm_ih_rgpn IN LOCAL MODE
      ENTITY Item BY \_Receipt FIELDS ( Itemuuid Accqty ) WITH CORRESPONDING #( lt_item )
      RESULT DATA(lt_all).

    LOOP AT lt_rcpt INTO DATA(ls_rcpt).
      APPEND VALUE #( %tky = ls_rcpt-%tky %state_area = 'VALIDATE_RCPT' ) TO reported-receipt.

      READ TABLE lt_item INTO DATA(ls_item)
           WITH KEY %is_draft = ls_rcpt-%is_draft Itemuuid = ls_rcpt-Itemuuid.
      DATA lv_acc_total TYPE zmmge_rgp_rc-accqty.
      CLEAR lv_acc_total.
      LOOP AT lt_all INTO DATA(ls_all) WHERE %is_draft = ls_rcpt-%is_draft AND Itemuuid = ls_rcpt-Itemuuid.
        lv_acc_total = lv_acc_total + ls_all-Accqty.
      ENDLOOP.

      DATA(lv_msg) = COND string(
        WHEN ls_rcpt-Recvqty <= 0
          THEN `Received quantity must be greater than zero`
        WHEN ls_rcpt-Accqty < 0 OR ls_rcpt-Accqty > ls_rcpt-Recvqty
          THEN `Accepted quantity must be between 0 and the received quantity`
        WHEN lv_acc_total > ls_item-Quantity
          THEN |Item { ls_item-Itemno ALPHA = OUT }: accepted total { lv_acc_total } exceeds issued quantity { ls_item-Quantity }| ).

      IF lv_msg IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_rcpt-%tky ) TO failed-receipt.
        APPEND VALUE #( %tky        = ls_rcpt-%tky
                        %state_area = 'VALIDATE_RCPT'
                        %msg        = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                             text     = lv_msg ) ) TO reported-receipt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

