@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Inward Processing - Apps'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZMM_CH_RPINW 
provider contract transactional_query
as projection on ZMM_IH_RPINW
{
    key Uuid,
    key Itemno,
    Matnr,
    Maktx,
    Uom,
    Plant,
    Plantname,
    Storagelocation,
    Hsncode,
    @Semantics.quantity.unitOfMeasure: 'uom'
    Quantity,
    Curky,
    @Semantics.amount.currencyCode: 'Curky'
    Netprice,
    @Semantics.amount.currencyCode: 'Curky'    
    Totvalue,
    @Semantics.quantity.unitOfMeasure: 'uom'    
    Totrcvqty,
    @Semantics.quantity.unitOfMeasure: 'uom'    
    Totopnqty,
    Remarks,
    Mark,
    Rgpnrpactualno,
    Closedocument,
    Createdby,
    Createdat,
    Lastchangedby,
    Lastchangedat,
    /* Associations */
    _Item : redirected to composition child ZMM_CI_RPINW
}
