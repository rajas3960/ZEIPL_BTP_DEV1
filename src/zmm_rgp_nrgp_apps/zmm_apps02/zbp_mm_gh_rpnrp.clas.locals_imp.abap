CLASS lhc__Header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR _Header RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR _Header RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR _Header RESULT result.

    METHODS Gateout FOR MODIFY
      keys FOR ACTION _Header~Gateout RESULT result.

    METHODS Statusc FOR MODIFY
      keys FOR ACTION _Header~Statusc RESULT result.

ENDCLASS.

CLASS lhc__Header IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD Gateout.

        READ ENTITIES OF zmm_gh_rpnrp IN LOCAL MODE
        ENTITY _Header
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_header).

        DATA(ls_header)  = lt_header[ 1 ].

        GET TIME STAMP FIELD DATA(ts).
          CONVERT TIME STAMP ts TIME ZONE 'INDIA'
              INTO DATE DATA(lv_date) TIME DATA(lv_time).

           MODIFY ENTITIES OF zmm_gh_rpnrp IN LOCAL MODE
           ENTITY _Header
           UPDATE
           FIELDS ( Gotdat Gottim  statustext )
           WITH VALUE #( for key IN keys
                            ( %tky = ls_header-%tky
                         Gotdat = lv_date
                         Gottim = lv_time
                         statustext = 'Gate Out ✅'
                         %control-Gotdat = if_abap_behv=>mk-on
                         %control-Gottim = if_abap_behv=>mk-on
                         %control-statustext = if_abap_behv=>mk-on
                         ) ).

    result = VALUE #( FOR ls_ord IN lt_header
                     ( %tky   = ls_ord-%tky
                       %param = ls_ord ) ).



  ENDMETHOD.

  METHOD Statusc.

  DATA : lt_gphentry TYPE TABLE OF zmm_app1_tb,
         ls_gphentry TYPE zmm_app1_tb.

        READ ENTITIES OF zmm_gh_rpnrp IN LOCAL MODE
        ENTITY _Header
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_header).

        DATA(ls_header)  = lt_header[ 1 ].

        GET TIME STAMP FIELD DATA(ts).
          CONVERT TIME STAMP ts TIME ZONE 'INDIA'
              INTO DATE DATA(lv_date) TIME DATA(lv_time).

        SELECT single max( gpnum ) FROM zmm_app1_tb WHERE uuid IS NOT INITIAL
        AND gptype = @ls_header-gptype
        INTO @DATA(lt_gpentry).

         IF lt_gpentry IS INITIAL.

          IF ls_header-gptype = 'RGP'.
            ls_gphentry-gpnum = '8000000000'.
          ELSE.
            ls_gphentry-gpnum = '9000000000'.
          ENDIF.
          ELSE.
          ls_gphentry-gpnum = lt_gpentry + 1.
        ENDIF.


           MODIFY ENTITIES OF zmm_gh_rpnrp IN LOCAL MODE
           ENTITY _Header
           UPDATE
           FIELDS ( gpnum gitdat gittim statustext )
           WITH VALUE #( for key IN keys
                            ( %tky = ls_header-%tky
                         gpnum = ls_gphentry-gpnum
                         gitdat = lv_date
                         gittim = lv_time
                         statustext = 'Gate Verified ✅'
                         %control-gpnum = if_abap_behv=>mk-on
                         %control-gitdat = if_abap_behv=>mk-on
                         %control-gittim = if_abap_behv=>mk-on
                         %control-statustext = if_abap_behv=>mk-on
                         ) ).

    result = VALUE #( FOR ls_ord IN lt_header
                     ( %tky   = ls_ord-%tky
                       %param = ls_ord ) ).


  ENDMETHOD.

ENDCLASS.
