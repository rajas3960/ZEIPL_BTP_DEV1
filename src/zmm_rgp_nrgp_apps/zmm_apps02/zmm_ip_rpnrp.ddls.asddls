@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP & NRGP Gate Pass Creation Apps'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZMM_IP_RPNRP
  as select from ZMM_II_RPNP
{
  key Uuid,
  key Itemno,
      Matnr,
      Maktx,
      Uom,
      Hsncode,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      Quantity,
      Curky,
      @Semantics.amount.currencyCode: 'Curky'
      Netprice,
      @Semantics.amount.currencyCode: 'Curky'
      Totvalue,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      Totrcvqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      Totopnqty,
      Mark,
      @Semantics.user.createdBy: true
      Createdby,
      @Semantics.systemDateTime.createdAt: true
      Createdat,
      @Semantics.user.lastChangedBy: true
      Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      Lastchangedat

}
