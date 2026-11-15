@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Inward Processing - Apps'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_IH_RPINW
  as select from ZMM_APP1_ITB
  composition [0..*] of ZMM_II_RPINW as _Item
{
  key uuid            as Uuid,
  key itemno          as Itemno,
      matnr           as Matnr,
      maktx           as Maktx,
      uom             as Uom,
      plant           as Plant,
      plantname  as Plantname,
      storagelocation as Storagelocation,
      hsncode         as Hsncode,
      @Semantics.quantity.unitOfMeasure: 'uom'
      quantity        as Quantity,
      curky           as Curky,
      @Semantics.amount.currencyCode: 'Curky'
      netprice        as Netprice,
      @Semantics.amount.currencyCode: 'Curky'      
      totvalue        as Totvalue,
      @Semantics.quantity.unitOfMeasure: 'uom'      
      totrcvqty       as Totrcvqty,
      @Semantics.quantity.unitOfMeasure: 'uom'      
      totopnqty       as Totopnqty,
      remarks         as Remarks,
      mark            as Mark,
      rgpnrpactualno  as Rgpnrpactualno,
      closedocument   as Closedocument,
      createdby       as Createdby,
      createdat       as Createdat,
      lastchangedby   as Lastchangedby,
      lastchangedat   as Lastchangedat,
      _Item
}
