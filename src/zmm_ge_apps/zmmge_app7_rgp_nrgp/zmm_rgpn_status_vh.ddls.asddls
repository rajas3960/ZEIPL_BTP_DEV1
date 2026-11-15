@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Status Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@ObjectModel.dataCategory: #VALUE_HELP
/*+[hideWarning] { "IDS" : [ "KEY_CHECK" ]  } */
define view entity ZMM_RGPN_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZMMGE_RGP_STATUS' )
{
      @ObjectModel.text.element: [ 'StatusText' ]
      @EndUserText.label: 'Status'
  key value_low as Status,
      @Semantics.text: true
      @EndUserText.label: 'Status Text'
      text      as StatusText,
      @UI.hidden: true
      cast( case value_low
              when '01' then 0
              when '02' then 2
              when '03' then 2
              when '04' then 2
              when '05' then 3
              else 0
            end as abap.int1 ) as Criticality
}
where language = $session.system_language
