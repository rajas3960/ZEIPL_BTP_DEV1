"! <p class="shorttext synchronized">Consumption model for client proxy - generated</p>
"! This class has been generated based on the metadata with namespace
"! <em>cds_zsd_sd_so_tmfo</em>
CLASS zsd_s4_sotmfo_scm DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_v4_abs_pm_model_prov
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! <p class="shorttext synchronized">SoTmFoType</p>
      BEGIN OF tys_so_tm_fo_type,
        "! <em>Key property</em> FoUuid
        fo_uuid          TYPE sysuuid_x16,
        "! SalesOrder
        sales_order      TYPE c LENGTH 10,
        "! SalesOrderItem
        sales_order_item TYPE c LENGTH 6,
        "! Carrier
        carrier          TYPE c LENGTH 30,
        "! CarrierName
        carrier_name     TYPE c LENGTH 80,
        "! FreightOrder
        freight_order    TYPE c LENGTH 20,
      END OF tys_so_tm_fo_type,
      "! <p class="shorttext synchronized">List of SoTmFoType</p>
      tyt_so_tm_fo_type TYPE STANDARD TABLE OF tys_so_tm_fo_type WITH DEFAULT KEY.


    CONSTANTS:
      "! <p class="shorttext synchronized">Internal Names of the entity sets</p>
      BEGIN OF gcs_entity_set,
        "! SoTmFo
        "! <br/> Collection of type 'SoTmFoType'
        so_tm_fo TYPE /iwbep/if_cp_runtime_types=>ty_entity_set_name VALUE 'SO_TM_FO',
      END OF gcs_entity_set .

    CONSTANTS:
      "! <p class="shorttext synchronized">Internal names for entity types</p>
      BEGIN OF gcs_entity_type,
        "! <p class="shorttext synchronized">Internal names for SoTmFoType</p>
        "! See also structure type {@link ..tys_so_tm_fo_type}
        BEGIN OF so_tm_fo_type,
          "! <p class="shorttext synchronized">Navigation properties</p>
          BEGIN OF navigation,
            "! Dummy field - Structure must not be empty
            dummy TYPE int1 VALUE 0,
          END OF navigation,
        END OF so_tm_fo_type,
      END OF gcs_entity_type.


    METHODS /iwbep/if_v4_mp_basic_pm~define REDEFINITION.


  PRIVATE SECTION.

    "! <p class="shorttext synchronized">Model</p>
    DATA mo_model TYPE REF TO /iwbep/if_v4_pm_model.


    "! <p class="shorttext synchronized">Define SoTmFoType</p>
    "! @raising /iwbep/cx_gateway | <p class="shorttext synchronized">Gateway Exception</p>
    METHODS def_so_tm_fo_type RAISING /iwbep/cx_gateway.

ENDCLASS.



CLASS ZSD_S4_SOTMFO_SCM IMPLEMENTATION.


  METHOD /iwbep/if_v4_mp_basic_pm~define.

    mo_model = io_model.
    mo_model->set_schema_namespace( 'cds_zsd_sd_so_tmfo' ) ##NO_TEXT.

    def_so_tm_fo_type( ).

  ENDMETHOD.


  METHOD def_so_tm_fo_type.

    DATA:
      lo_complex_property    TYPE REF TO /iwbep/if_v4_pm_cplx_prop,
      lo_entity_type         TYPE REF TO /iwbep/if_v4_pm_entity_type,
      lo_entity_set          TYPE REF TO /iwbep/if_v4_pm_entity_set,
      lo_navigation_property TYPE REF TO /iwbep/if_v4_pm_nav_prop,
      lo_primitive_property  TYPE REF TO /iwbep/if_v4_pm_prim_prop.


    lo_entity_type = mo_model->create_entity_type_by_struct(
                                    iv_entity_type_name       = 'SO_TM_FO_TYPE'
                                    is_structure              = VALUE tys_so_tm_fo_type( )
                                    iv_do_gen_prim_props         = abap_true
                                    iv_do_gen_prim_prop_colls    = abap_true
                                    iv_do_add_conv_to_prim_props = abap_true ).

    lo_entity_type->set_edm_name( 'SoTmFoType' ) ##NO_TEXT.


    lo_entity_set = lo_entity_type->create_entity_set( 'SO_TM_FO' ).
    lo_entity_set->set_edm_name( 'SoTmFo' ) ##NO_TEXT.


    lo_primitive_property = lo_entity_type->get_primitive_property( 'FO_UUID' ).
    lo_primitive_property->set_edm_name( 'FoUuid' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'Guid' ) ##NO_TEXT.
    lo_primitive_property->set_is_key( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'SALES_ORDER' ).
    lo_primitive_property->set_edm_name( 'SalesOrder' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 10 ) ##NUMBER_OK.
    lo_primitive_property->set_is_nullable( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'SALES_ORDER_ITEM' ).
    lo_primitive_property->set_edm_name( 'SalesOrderItem' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 6 ) ##NUMBER_OK.
    lo_primitive_property->set_is_nullable( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'CARRIER' ).
    lo_primitive_property->set_edm_name( 'Carrier' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 30 ) ##NUMBER_OK.
    lo_primitive_property->set_is_nullable( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'CARRIER_NAME' ).
    lo_primitive_property->set_edm_name( 'CarrierName' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 80 ) ##NUMBER_OK.
    lo_primitive_property->set_is_nullable( ).

    lo_primitive_property = lo_entity_type->get_primitive_property( 'FREIGHT_ORDER' ).
    lo_primitive_property->set_edm_name( 'FreightOrder' ) ##NO_TEXT.
    lo_primitive_property->set_edm_type( 'String' ) ##NO_TEXT.
    lo_primitive_property->set_max_length( 20 ) ##NUMBER_OK.
    lo_primitive_property->set_is_nullable( ).

  ENDMETHOD.
ENDCLASS.
