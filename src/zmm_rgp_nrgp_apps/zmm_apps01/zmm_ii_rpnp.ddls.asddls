@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP & NRGP Outward Creation Apps'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMM_II_RPNP
  as select from zmm_app1_itb
  association [0..*] to ZMM_TAX_VH     as _Tax on $projection.Taxcode = _Tax.value_low  
  association to parent ZMM_IH_RPNP as _Header on $projection.Uuid = _Header.Uuid  
{
  key uuid            as Uuid,
  key itemno          as Itemno,
      matnr           as Matnr,
      maktx           as Maktx,
      uom             as Uom,
      plant           as Plant,
      plantname       as Plantname,
      storagelocation as Storagelocation,
      hsncode         as Hsncode,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      quantity        as Quantity,
      curky           as Curky,
      @Semantics.amount.currencyCode: 'Curky'
      netprice        as Netprice,
      @Semantics.amount.currencyCode: 'Curky'
      totvalue        as Totvalue,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      totrcvqty       as Totrcvqty,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      totopnqty       as Totopnqty,
      remarks         as Remarks,
      mark            as Mark,
      rgpnrpactualno  as Rgpnrpactualno,
      closedocument   as Closedocument,
      taxcode         as Taxcode,
      _Tax.text       as Taxcodedes,
      createdby       as Createdby,
      createdat       as Createdat,
      lastchangedby   as Lastchangedby,
      lastchangedat   as Lastchangedat,
      _Header
}
