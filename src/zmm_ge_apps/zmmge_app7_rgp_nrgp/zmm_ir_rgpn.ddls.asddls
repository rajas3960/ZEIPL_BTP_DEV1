@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Gate Pass - Return Receipt'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMM_IR_RGPN
  as select from zmmge_rgp_rc
  association        to parent ZMM_II_RGPN as _Item   on $projection.Itemuuid = _Item.Itemuuid
  association [1..1] to ZMM_IH_RGPN        as _Header on $projection.Gpuuid = _Header.Gpuuid
{
  key rcptuuid           as Rcptuuid,
      itemuuid           as Itemuuid,
      gpuuid             as Gpuuid,
      rcptno             as Rcptno,
      gateinno           as Gateinno,
      gateindate         as Gateindate,
      gateintime         as Gateintime,
      invoice            as Invoice,
      challandate        as Challandate,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      recvqty            as Recvqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      accqty             as Accqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      rjtqty             as Rjtqty,
      uom                as Uom,
      remarks            as Remarks,
      @Semantics.user.createdBy: true
      createdby          as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat          as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangedby      as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangedat      as Lastchangedat,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      locallastchangedat as Locallastchangedat,

      _Item,
      _Header
}
