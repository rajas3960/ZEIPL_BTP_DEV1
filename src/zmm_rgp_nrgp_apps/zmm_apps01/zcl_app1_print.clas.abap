CLASS zcl_app1_print DEFINITION
 PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_APP1_PRINT IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    IF io_request->is_data_requested( ) = abap_false.
      RETURN.
    ENDIF.

    DATA lt_result TYPE STANDARD TABLE OF zmm_app1_ce1.
    DATA lt_range  TYPE if_rap_query_filter=>tt_name_range_pairs.
    DATA lv_uuid   TYPE ZMM_IH_RPNP-uuid.

    DATA(lo_filter) = io_request->get_filter( ).

    TRY.
        lt_range = lo_filter->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        RETURN.
    ENDTRY.

    IF NOT line_exists( lt_range[ name = 'UUID' ] ).
      io_response->set_data( lt_result ).
      io_response->set_total_number_of_records( 0 ).
      RETURN.
    ENDIF.

    LOOP AT lt_range[ name = 'UUID' ]-range
      ASSIGNING FIELD-SYMBOL(<ls_range>).

      lv_uuid = <ls_range>-low.

      IF lv_uuid IS INITIAL.
        CONTINUE.
      ENDIF.

      SELECT SINGLE *
        FROM ZMM_IH_RPNP WITH PRIVILEGED ACCESS
        WHERE uuid = @lv_uuid
        INTO @DATA(ls_hdr).

      "Add your mapping code here
      DATA ls_result TYPE zmm_app1_ce1.

      CLEAR ls_result.

      ls_result-uuid          = ls_hdr-uuid.
      ls_result-cmpname       = ls_hdr-plant.
      ls_result-typ           = ls_hdr-gptype.
      ls_result-rgpno         = ls_hdr-gpnum.
      ls_result-gatepassdt    = ls_hdr-gitdat.
      ls_result-gatepassno    = ls_hdr-rgpnrpactualno.
*      ls_result-tdname        = ls_hdr-transportername.
      ls_result-vehicleno     = ls_hdr-vehicleno.
      ls_result-fregts        = ls_hdr-frghtscope.
      ls_result-grosswgt      = ls_hdr-grosswgt.
      ls_result-tarewgt       = ls_hdr-tarewgt.
      ls_result-netwgt        = ls_hdr-netwgt.
      ls_result-ewaybill_no   = ls_hdr-ewabillno.
      ls_result-lrno          = ls_hdr-lrnumber.
      ls_result-lrdate        = ls_hdr-lrdate.
      ls_result-formplace     = ls_hdr-fromplace.
      ls_result-placeofsupply = ls_hdr-toplace.
      ls_result-remark        = ls_hdr-remarks.
      ls_result-createdby     = ls_hdr-createdby.
      LS_RESULT-exp_retu_d    = LS_HDR-Plnrtndate.
      LS_RESULT-issuedate     = LS_HDR-Issuedate.
*      ls_result-sp_name       = LS_HDR-transportername.
      ls_result-sp_email      = LS_HDR-EmailAddress.
      ls_result-sp_add1       = LS_HDR-StreetName.
      ls_result-sp_add2       = LS_HDR-BPAddrStreetName.
      ls_result-sp_city       = LS_HDR-CityName.
      ls_result-sp_pcode      = LS_HDR-PostalCode.
      ls_result-Contpr        = ls_hdr-Contpr.
      ls_result-particular    = ls_hdr-Remarks.

  CONCATENATE LS_HDR-BPAddrStreetName LS_HDR-CityName LS_HDR-PostalCode
    INTO ls_result-supaddress .
*    SEPARATED BY ', '.

*        ls_result-sp_cin      = ls_supplier-UK_CompanyRegistrationNumber.
        ls_result-sp_pan        = LS_HDR-pan.
        ls_result-sp_gstin      = LS_HDR-Gstin.
        ls_result-sp_pno        = LS_HDR-Phone.
        ls_result-sp_statename  = LS_HDR-Region.

      APPEND ls_result TO lt_result.

    ENDLOOP.

    io_response->set_data( lt_result ).

    io_response->set_total_number_of_records(
      lines( lt_result )
    ).

  ENDMETHOD.
ENDCLASS.
