CLASS zcl_mm_s4_gate_api DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_qty TYPE p LENGTH 7 DECIMALS 3.

    TYPES: BEGIN OF ty_req_item,
             purchaseorder     TYPE c LENGTH 10,
             purchaseorderitem TYPE n LENGTH 5,
             plant             TYPE c LENGTH 4,
             material          TYPE c LENGTH 40,
             quantity          TYPE ty_qty,
             unit              TYPE c LENGTH 3,
             storagelocation   TYPE c LENGTH 4,
             InboundDelivery    TYPE c LENGTH 10,       "new One Added By 14.10.2026
             InboundDeliveryItem   TYPE n LENGTH 6,     "new One Added By 14.10.2026
             freightorder      TYPE c LENGTH 20,        "new one added on 30.10.2026 FU -> FO
           END OF ty_req_item,
           tt_req_item TYPE STANDARD TABLE OF ty_req_item WITH EMPTY KEY.

    TYPES: BEGIN OF ty_request,
             operation         TYPE c LENGTH 10,
             purchaseorder     TYPE c LENGTH 10,
             purchaseorderitem TYPE n LENGTH 5,
             gateentryno       TYPE c LENGTH 20,
             supplier          TYPE c LENGTH 10,
             postingdate       TYPE d,
             Product           TYPE c LENGTH 40,        "new One added on 19.2026 RGP & NRGP
             Plant             TYPE c LENGTH 4,         "new One added on 19.2026 RGP & NRGP
             items             TYPE tt_req_item,
           END OF ty_request.

    TYPES: BEGIN OF ty_poitem,
             purchaseorder              TYPE c LENGTH 10,
             purchaseorderitem          TYPE n LENGTH 5,
             material                   TYPE c LENGTH 40,
             plant                      TYPE c LENGTH 4,
             baseunit                   TYPE c LENGTH 3,
             orderquantity              TYPE ty_qty,
             materialgroup              TYPE c LENGTH 9,
             plantname                  TYPE c LENGTH 30,
             productname                TYPE c LENGTH 40,
             supplier                   TYPE c LENGTH 10,
             purchaseorderdate          TYPE d,
             purchaseordertype          TYPE c LENGTH 4,
             suppliername               TYPE c LENGTH 80,
             purchasingdocumenttypename TYPE c LENGTH 20,
           END OF ty_poitem,
           tt_poitem TYPE STANDARD TABLE OF ty_poitem WITH EMPTY KEY.

""New Code Added 14.10.2026 Starting
    TYPES: BEGIN OF ty_resp_item,
             purchaseorder     TYPE c LENGTH 10,
             purchaseorderitem TYPE n LENGTH 5,
             InboundDelivery    TYPE c LENGTH 10,
             InboundDeliveryItem   TYPE n LENGTH 6,
           END OF ty_resp_item,
           tt_resp_item TYPE STANDARD TABLE OF ty_resp_item WITH EMPTY KEY.
""New Code Added 14.10.2026 Ending

""New Code Added on 19.10.2026 for Get the Product details for RGP & NRGP
    TYPES: BEGIN OF ty_product,
             Product                    TYPE c LENGTH 40,
             Plant                      TYPE c LENGTH 4,
             BaseUnit                   TYPE c LENGTH 3,
             Prodesc                    TYPE c LENGTH 40,
             PlantName                  TYPE c LENGTH 30,
             Hsncode                    TYPE c LENGTH 16,
             Netprice                   TYPE p LENGTH 7 DECIMALS 2,
             Currency                   TYPE c LENGTH 5,
           END OF ty_product,
           tt_product TYPE STANDARD TABLE OF ty_product WITH EMPTY KEY.
""New Code Added on 19.10.2026 for Get the Product details for RGP & NRGP Ending

""New Code Added on 20.10.2026 for Get the Supplier address details for RGP & NRGP
    TYPES: BEGIN OF ty_sup_add,
             Supplier           TYPE c LENGTH 10,
             AddressID          TYPE c LENGTH 10,
             SupplierName       TYPE c LENGTH 80,
             StreetName         TYPE c LENGTH 35,
             BPAddrStreetName   TYPE c LENGTH 60,
             gstin              TYPE c LENGTH 18,
             CityName           TYPE c LENGTH 35,
             PostalCode         TYPE c LENGTH 10 ,
             pan                TYPE c LENGTH 40,
             phone              TYPE c LENGTH 16,
             Region             TYPE c LENGTH 3,
             EmailAddress       TYPE c LENGTH 241,
           END OF ty_sup_add,
           tt_supaddress TYPE STANDARD TABLE OF ty_sup_add WITH EMPTY KEY.


    TYPES: BEGIN OF ty_response,
             success              TYPE abap_bool,
             message              TYPE string,
             materialdocument     TYPE c LENGTH 10,
             materialdocumentyear TYPE n LENGTH 4,
             inbounddelivery      TYPE c LENGTH 10,
             fomessage            TYPE string,              "new one added on 30.10.2026 FU -> FO
             poitems              TYPE tt_poitem,
             items                TYPE tt_req_item,
             products             TYPE tt_product,          "new one added on 19.10.2026 RGP & NRGP
             supaddress           TYPE tt_supaddress,       "new one added on 20.10.2026 Supplier Address
           END OF ty_response.

    "! Sends one request to S/4. Business errors come back in rs_response-message
    "! with success = false; only connection problems raise an exception.
    CLASS-METHODS call
      IMPORTING is_request         TYPE ty_request
      RETURNING VALUE(rs_response) TYPE ty_response
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error.
ENDCLASS.



CLASS ZCL_MM_S4_GATE_API IMPLEMENTATION.


  METHOD call.
    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = 'ZMM_S4_GATEPOST_CS'
                             service_id    = 'ZMM_S4_GATEPOST_REST' ).
    DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

    DATA(lo_request) = lo_client->get_http_request( ).
    lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
    lo_request->set_text( /ui2/cl_json=>serialize( data        = is_request
                                                   pretty_name = /ui2/cl_json=>pretty_mode-low_case ) ).

    DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
    DATA(ls_status) = lo_response->get_status( ).

    IF ls_status-code = 200.
      /ui2/cl_json=>deserialize( EXPORTING json        = lo_response->get_text( )
                                           pretty_name = /ui2/cl_json=>pretty_mode-low_case
                                 CHANGING  data        = rs_response ).
    ELSE.
      rs_response-message = |S/4 returned HTTP { ls_status-code } { ls_status-reason }|.
    ENDIF.

    lo_client->close( ).
  ENDMETHOD.
ENDCLASS.
