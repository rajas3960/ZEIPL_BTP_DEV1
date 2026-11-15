@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Gate entry Status VH'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.dataCategory: #VALUE_HELP
define view entity ZMM_GESTATUS_VH 
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZMM_GPSTATUS' )

{
      @ObjectModel.text.element: [ 'StatusText' ]
      @EndUserText.label: 'Status'
  key value_low as Status,
      @Semantics.text: true
      @EndUserText.label: 'Status Text'
      text      as StatusText
}
where language = $session.system_language
    
