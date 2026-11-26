@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Weighment Flag Master Projection view'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZMM_CH_WMT_FLAG
  provider contract transactional_query
  as projection on ZMM_IH_WMT_FLAG
{
      @ObjectModel.text.element: [ 'Gateentryseriesdes' ]
      @Search.defaultSearchElement: true
  key Gateentryseries,
      @ObjectModel.text.element: [ 'Materialgroupdes' ]
      @Search.defaultSearchElement: true
  key Materialgroup,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Gateentryseriesdes,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Materialgroupdes,
      Weighmentflag,
      Challanqtyflag,
      Createdby,
      Createdat,
      Lastchangedby,
      Lastchangedat
}
