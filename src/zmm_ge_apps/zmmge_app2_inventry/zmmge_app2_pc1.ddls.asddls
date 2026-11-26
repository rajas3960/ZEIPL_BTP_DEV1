@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inventory Gate Item Challan - Apps'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZMMGE_APP2_PC1
  as projection on ZMMGE_APP2_IC1
{
  key Chlnuuid,
      Uuid,
      Purchaseorder,
      Purchaseorderitem,
      Subgateentryno,
      Challanno,
      Challandate,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZSD_BP_ZTRP_VH', element: 'Transporterid' } } ]
      Trasporterid,
      Trasportername,
      Lrno,
      Lrdate,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' } } ]
      Chbaseunit,
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      Challantareweight,
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      Challangrossweight,
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      Challannetweight,
      Chqtyunit,
      @Semantics.quantity.unitOfMeasure: 'Chqtyunit'
      Challanqty,
      Chdocumt,
      Createdby,
      Createdat,
      Lastchangedby,
      Lastchangedat,

      _Item : redirected to parent ZMMGE_APP2_PV1,
      _Head : redirected to ZMMGE_APP2_PE
}
