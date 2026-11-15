@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Weighment Flag Master'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_IH_WMT_FLAG
  as select from zmmge_wghflg_t01
{
  key gateentryseries    as Gateentryseries,
  key materialgroup      as Materialgroup,
      gateentryseriesdes as Gateentryseriesdes,
      materialgroupdes   as Materialgroupdes,
      weighmentflag      as Weighmentflag,
      challanqtyflag     as Challanqtyflag,
      @Semantics.user.createdBy: true
      createdby          as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat          as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangedby      as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangedat      as Lastchangedat
}
