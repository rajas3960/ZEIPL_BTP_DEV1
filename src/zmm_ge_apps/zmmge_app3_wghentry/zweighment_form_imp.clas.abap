CLASS zweighment_form_imp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

PUBLIC SECTION.

  INTERFACES if_rap_query_provider .
PROTECTED SECTION.
PRIVATE SECTION.
ENDCLASS.



CLASS ZWEIGHMENT_FORM_IMP IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    DATA rt_table TYPE TABLE OF ZMM_WEIGHT_SLIP_CE.
    DATA: lv_uuid TYPE ZMM_WEIGHT_SLIP_CE-uuid.
    DATA: lv_tare TYPE zmmge_itm_t01-grossweight,
          lv_net TYPE zmmge_itm_t01-grossweight,
          lv_total TYPE zmmge_itm_t01-grossweight.

********************************************************************************************************
  if not io_request->is_data_requested(  ).
        RETURN.
    endif.
******************************************************************************************************************
    TRY.
        DATA(lt_range) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        RETURN.
    ENDTRY.

    IF NOT line_exists( lt_range[ name = 'UUID' ] ).
      RETURN.
    ENDIF.
*****************************************************************************************************
     LOOP AT lt_range[ name = 'UUID' ]-range ASSIGNING FIELD-SYMBOL(<ls_Acc>).
        lv_uuid = <ls_acc>-low.

************************************************************************************************************
        select SINGLE * from zmmge_hdr_t01 wiTH PRIVILEGED ACCESS
        whERE uuid = @lv_uuid
        into @data(ls_gate).
************************************************************************************************************
        SELECT * from zmmge_itm_t01 WITH PRIVILEGED ACCESS
        WHERE uuid = @lv_uuid
        INto TABLE @DATA(lt_item).

        lv_total = REDUCE #(
                            INIT total1 = CONV #( 0 )
                            FOR ls_item IN lt_item
                            NEXT total1 = total1 + ls_item-Netweight ).
        lv_net = lv_total.

        lv_tare  = REDUCE #( INIT total = CONV #( 0 )
                                FOR ls_item IN lt_item
                                NEXT total = total + ls_item-tareweight ).
*******************************************************************************************************
        INSERT VALUE ZMM_WEIGHT_SLIP_CE(
                         uuid = ls_gate-uuid
                         vehicleno = ls_gate-vehicleno
                         grosswt = ls_gate-grosswt
                         gateentrydate = ls_gate-gateentrydate
                         netweight = lv_net
                         tareweight = lv_tare

                        )
                        into table rt_table.

    ENDLOOP.
      io_response->set_data( rt_table ).
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( rt_table ) ).
    ENDIF   .


  ENDMETHOD.
ENDCLASS.
