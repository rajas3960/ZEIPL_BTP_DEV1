@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP & NRGP Outward Creation Apps'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZMM_CI_RPNP 
as projection on ZMM_II_RPNP
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
        @Semantics.quantity.unitOfMeasure : 'Uom'
    Quantity,
    Curky,
        @Semantics.amount.currencyCode: 'Curky'
    Netprice,
        @Semantics.amount.currencyCode: 'Curky'
    Totvalue,
        @Semantics.quantity.unitOfMeasure : 'Uom'
    Totrcvqty,
        @Semantics.quantity.unitOfMeasure : 'Uom'
    Totopnqty,
    Remarks,
    Mark,
    Rgpnrpactualno,
    Closedocument,
    @ObjectModel.text.element: [ 'Taxcodedes' ]
    Taxcode,
    Taxcodedes,
    Createdby,
    Createdat,
    Lastchangedby,
    Lastchangedat,
    /* Associations */
    _Header : redirected to parent ZMM_CH_RPNP
}
