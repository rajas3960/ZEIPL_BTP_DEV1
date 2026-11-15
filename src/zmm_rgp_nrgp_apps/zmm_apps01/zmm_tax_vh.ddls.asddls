@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tax Code Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMM_TAX_VH 
 as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZMM_TAX_CODE')
{
      @UI.hidden: true
  key domain_name,
      @UI.hidden: true
  key value_position,
      @Semantics.language: true
      @UI.hidden: true
  key language,
      @EndUserText.label: 'Tax Code'
      @ObjectModel.text.element: [ 'text' ]
      value_low,
      @Semantics.text: true
      text

}
