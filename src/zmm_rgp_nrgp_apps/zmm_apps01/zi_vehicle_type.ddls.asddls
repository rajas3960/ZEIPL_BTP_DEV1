@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vehicle Type Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_VEHICLE_TYPE 
as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZMM_APP1_VEHICLE_TYPE')
{
    @UI.hidden: true
    key domain_name,

    @UI.hidden: true
    key value_position,

    @Semantics.language: true
    @UI.hidden: true
    key language,

    @EndUserText.label: 'Vehicle Type'
//    @ObjectModel.text.element: [ 'text' ]
    value_low,
    
    @Semantics.text: true
      @EndUserText.label: 'Vehicle Type'
//      @ObjectModel.text.element: [ 'text' ]
//      Vehicletype,
    text
    
}
