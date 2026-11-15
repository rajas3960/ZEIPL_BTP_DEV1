@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Image Verification - Gate Entry'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZSD_CH_IMGVR
  provider contract transactional_query
  as projection on ZSD_IH_IMGVR
{
  key Uuid,
      Gateentryno,
      Gateentrydate,
      Gateentrytype,
      @ObjectModel.text.element: [ 'Plantname' ]
      Plant,
      Plantname,
      Vehicleno,
      Transportname,
      Drivername,
      @ObjectModel.text.element: [ 'Customername' ]
      Customer,
      Customername,
      @ObjectModel.text.element: [ 'Weighmentmcndes' ]
      Weighmentmcno,
      Weighmentmcndes,
      Weighmentdate,
      Weighmenttime,
      Weighuom,
      @Semantics.quantity.unitOfMeasure: 'Weighuom'
      Tarewt,
      Loadendindi,
      Imagevalid,
      Imgseqnotare,
      Imgseqnogross,
      Imgvrstatustare,
      Imgvrstatusgross,
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
      Imgstatustaretext,
      Imgcrittare,
      Imgstatusgrosstext,
      Imgcritgross,
      /* Associations */
      _Images,
      _Stages
}
