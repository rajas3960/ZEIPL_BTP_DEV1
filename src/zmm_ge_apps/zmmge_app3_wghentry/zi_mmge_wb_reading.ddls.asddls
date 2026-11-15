@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CamView weight readings (released)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_MMGE_WB_READING
  as select from zmmge_wb_read
{
  key seqno         as Seqno,
      machine       as Machine,
      @Semantics.quantity.unitOfMeasure: 'Unit'
      weight        as Weight,
      unit          as Unit,
      capturedat    as Capturedat,
      receivedat    as Receivedat,
      gateentryuuid as Gateentryuuid
}
