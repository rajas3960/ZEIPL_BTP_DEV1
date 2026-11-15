@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inward Image Verification - Gate Entry'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZMM_CH_IMGVR
  provider contract transactional_query
  as projection on ZMM_IH_IMGVR
{
  key Uuid,
      Gateentryno,
      Gateentrydate,
      @ObjectModel.text.element: [ 'Gateentryseriesdes' ]
      Gateentryseries,
      Gateentryseriesdes,
      @ObjectModel.text.element: [ 'Plantname' ]
      Plant,
      Plantname,
      Vehicleno,
      Transportname,
      Drivername,
      Challanno,
      @ObjectModel.text.element: [ 'Weighmentmcndes' ]
      Weighmentmcno,
      Weighmentmcndes,
      Weighmentdate,
      Weighmenttime,
      Weighuom,
      @Semantics.quantity.unitOfMeasure: 'Weighuom'
      Grosswt,
      Unloadendindi,
      Imagevaldindicator,
      Imgseqnogross,
      Imgseqnotare,
      Imgvrstatusgross,
      Imgvrstatustare,
      Imgrejreason,
      Imgverifiedby,
      Imgverifiedat,
      Createdby,
      Createdat,
      Lastchangedby,
      Lastchangedat,
      Pendingstage,
      Pendingstagetext,
      @Consumption.filter: { defaultValue: 'X' }
      Ispending,
      Imgstatusgrosstext,
      Imgcritgross,
      Imgstatustaretext,
      Imgcrittare,
      /* Associations */
      _Images,
      _Stages
}
