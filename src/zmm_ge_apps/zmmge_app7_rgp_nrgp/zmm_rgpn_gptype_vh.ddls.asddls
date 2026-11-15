@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Gate Pass Type Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.dataCategory: #VALUE_HELP
/*+[hideWarning] { "IDS" : [ "KEY_CHECK" ]  } */
define view entity ZMM_RGPN_GPTYPE_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZMMGE_RGP_GPTYPE' )
{
      @ObjectModel.text.element: [ 'GptypeText' ]
      @EndUserText.label: 'Gate Pass Type'
  key value_low as Gptype,
      @Semantics.text: true
      @EndUserText.label: 'Gate Pass Type Text'
      text      as GptypeText
}
where language = $session.system_language
