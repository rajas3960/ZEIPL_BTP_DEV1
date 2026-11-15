@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Gate Pass - Item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMM_II_RGPN
  as select from zmmge_rgp_it
  association        to parent ZMM_IH_RGPN as _Header on $projection.Gpuuid = _Header.Gpuuid
  composition [0..*] of ZMM_IR_RGPN        as _Receipt
  association [0..1] to ZMM_RGPN_TAX_VH    as _Tax    on $projection.Taxcode = _Tax.Taxcode
{
  key itemuuid           as Itemuuid,
      gpuuid             as Gpuuid,
      itemno             as Itemno,
      matnr              as Matnr,
      maktx              as Maktx,
      plant              as Plant,
      plantname          as Plantname,
      storagelocation    as Storagelocation,
      hsncode            as Hsncode,
      taxcode            as Taxcode,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      quantity           as Quantity,
      uom                as Uom,
      @Semantics.amount.currencyCode: 'Curky'
      netprice           as Netprice,
      @Semantics.amount.currencyCode: 'Curky'
      totvalue           as Totvalue,
      curky              as Curky,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      totrcvqty          as Totrcvqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      totaccqty          as Totaccqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      totrjtqty          as Totrjtqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      totopnqty          as Totopnqty,
      closed             as Closed,
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

      _Header,
      _Receipt,
      _Tax
}
