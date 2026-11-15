@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: ' Item View Entity'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMM_APP1_ITM as select from zmm_app1_tb1
{
    
    key uuid as Uuid,
    key itemno as sno,
    matnr as Mcode,
    maktx as Mdesc,  
    uom as Uom,
    hsncode as Hsn,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    quantity as Qty,
    plant as plant,
//    plantname as plantname,
    plant_combined as plantcombined,
    curky as Curky,
    @Semantics.amount.currencyCode: 'Curky'
    netprice as Rate,
    @Semantics.amount.currencyCode: 'Curky'
    totvalue as Talav

}
    
