@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Inward Processing Item - Apps'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZMM_CI_RPINW
 as projection on ZMM_II_RPINW
{
    key Uuid,
    key Itemno,
    key Subuuid,
    Sno,
    Matnr,
    Maktx,
    Uom,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    Quantity,
    Indt,
    Intim,
    @Semantics.quantity.unitOfMeasure: 'Uom'    
    Recvqty,
    @Semantics.quantity.unitOfMeasure: 'Uom'    
    Penqty,
    Invoice,
    Gateindate,
    Gateintime,
    Gateinnumber,
    @Semantics.quantity.unitOfMeasure: 'Uom'    
    Accqty,
    @Semantics.quantity.unitOfMeasure: 'Uom'    
    Rjtqty,
    Createdby,
    Createdat,
    /* Associations */
    _Header : redirected to parent ZMM_CH_RPINW
}
