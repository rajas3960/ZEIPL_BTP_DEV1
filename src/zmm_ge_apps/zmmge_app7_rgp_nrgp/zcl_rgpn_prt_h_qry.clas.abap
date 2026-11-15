CLASS zcl_rgpn_prt_h_qry DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_RGPN_PRT_H_QRY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE STANDARD TABLE OF zmm_rgpn_prt_h WITH EMPTY KEY.

    IF io_request->is_data_requested( ) = abap_false.
      RETURN.
    ENDIF.

    TRY.
        DATA(lt_range) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_range.
    ENDTRY.

    READ TABLE lt_range INTO DATA(ls_uuid_filter) WITH KEY name = 'UUID'.
    LOOP AT ls_uuid_filter-range INTO DATA(ls_range).
      DATA(lv_uuid) = CONV sysuuid_x16( ls_range-low ).

      SELECT SINGLE * FROM zmm_ih_rgpn
        WHERE Gpuuid = @lv_uuid
        INTO @DATA(ls_hdr).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " phone digits only (numeric form field); GST state code = first 2 chars of GSTIN
      DATA(lv_phone) = replace( val = ls_hdr-Phone pcre = `[^0-9]` with = `` occ = 0 ).
      DATA(lv_state) = COND string( WHEN strlen( ls_hdr-Gstin ) >= 2 THEN substring( val = ls_hdr-Gstin len = 2 ) ).
      " S/4 often returns the same text in both street fields - print it once
      DATA(lv_add2)  = COND #( WHEN ls_hdr-Bpaddrstreetname <> ls_hdr-Streetname THEN ls_hdr-Bpaddrstreetname ).

      APPEND VALUE #(
        uuid          = ls_hdr-Gpuuid
        typ           = ls_hdr-Gptype
        gatepassno    = ls_hdr-Gpno
        rgpno         = ls_hdr-Gvnum
        gatepassdt    = ls_hdr-Issuedate
        issuedate     = ls_hdr-Issuedate
        exp_retu_d    = ls_hdr-Plnrtndate
        Plnrtndate    = ls_hdr-Plnrtndate
        name          = ls_hdr-Plantname
        vehicleno     = ls_hdr-Vehicleno
        fregts        = ls_hdr-Frghtscope
        grosswgt      = ls_hdr-Grosswgt
        tarewgt       = ls_hdr-Tarewgt
        netwgt        = ls_hdr-Netwgt
        ewaybill_no   = ls_hdr-Ewabillno
        ewaybill_date = ls_hdr-ewabilldate
        lrno          = ls_hdr-Lrnumber
        lrdate        = ls_hdr-Lrdate
        formplace     = ls_hdr-Fromplace
        placeofsupply = ls_hdr-Toplace
        remark        = ls_hdr-Remarks
        particular    = ls_hdr-Rsngp
        Contpr        = ls_hdr-Contpr
        createdby     = ls_hdr-Createdby
        Transportername = ls_hdr-Transportername
        employeeName   = ls_hdr-Reqby
        RequestedDept    = ls_hdr-Reqdpt
        TransporterMode  = ls_hdr-Dispby
        Carrier          = ls_hdr-Transporterid
        " supplier block
        sp_name       = ls_hdr-Vendname
        sp_add1       = ls_hdr-Streetname
        sp_add2       = lv_add2
        sp_city       = ls_hdr-Cityname
        sp_pcode      = ls_hdr-Postalcode
        sp_email      = ls_hdr-Emailaddress
        sp_pan        = ls_hdr-Pan
        sp_gstin      = ls_hdr-Gstin
        sp_pno        = ls_hdr-Phone
        sp_statename  = ls_hdr-Region
        supaddress    = condense( |{ ls_hdr-Streetname }, { ls_hdr-Cityname } - { ls_hdr-Postalcode }| )
        " Details of Recipient (Billed to) = vendor
        bi_add1       = ls_hdr-Streetname
        bi_add2       = lv_add2
        bi_city       = ls_hdr-Cityname
        bi_pstcode    = ls_hdr-Postalcode
        bi_statename  = ls_hdr-Region
        bi_stocde     = lv_state
        bi_gstin      = ls_hdr-Gstin
        bi_gstpan     = ls_hdr-Pan
        bi_phone      = lv_phone
        bi_email      = ls_hdr-Emailaddress
        " Details of Consignee (Shipped to) = same vendor
        sh_add1       = ls_hdr-Streetname
        sh_add2       = lv_add2
        sh_city       = ls_hdr-Cityname
        sh_pstcode    = ls_hdr-Postalcode
        sh_statename  = ls_hdr-Region
        sh_stocde     = lv_state
        sh_gstin      = ls_hdr-Gstin
        sh_gstpan     = ls_hdr-Pan
        sh_phone      = lv_phone
        sh_email      = ls_hdr-Emailaddress
      ) TO lt_result.
    ENDLOOP.

    io_response->set_data( lt_result ).
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
