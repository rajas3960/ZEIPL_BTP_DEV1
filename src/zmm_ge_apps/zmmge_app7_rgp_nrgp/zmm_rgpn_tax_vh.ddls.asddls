@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Tax Code Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.dataCategory: #VALUE_HELP
/*+[hideWarning] { "IDS" : [ "KEY_CHECK" ]  } */
define view entity ZMM_RGPN_TAX_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZMMGE_RGP_TAXCODE' )
{
      @ObjectModel.text.element: [ 'TaxcodeText' ]
      @EndUserText.label: 'Tax Code'
  key value_low as Taxcode,
      @Semantics.text: true
      @EndUserText.label: 'Tax Code Description'
      text      as TaxcodeText
}
where language = $session.system_language
