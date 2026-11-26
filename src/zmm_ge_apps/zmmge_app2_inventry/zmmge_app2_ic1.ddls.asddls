@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inventory Gate Entry Item Challan'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMMGE_APP2_IC1
  as select from zmmge_chln_t01
  association        to parent ZMMGE_APP2_IV1 as _Item on  $projection.Uuid              = _Item.Uuid
                                                       and $projection.Purchaseorder     = _Item.Purchaseorder
                                                       and $projection.Purchaseorderitem = _Item.Purchaseorderitem
  association [1..1] to ZMMGE_APP2_RE         as _Head on  $projection.Uuid = _Head.Uuid
{
  key chlnuuid           as Chlnuuid,
      uuid               as Uuid,
      purchaseorder      as Purchaseorder,
      purchaseorderitem  as Purchaseorderitem,
      subgateentryno     as Subgateentryno,
      challanno          as Challanno,
      challandate        as Challandate,
      trasporterid       as Trasporterid,
      trasportername     as Trasportername,
      lrno               as Lrno,
      lrdate             as Lrdate,
      chbaseunit         as Chbaseunit,
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      challantareweight  as Challantareweight,
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      challangrossweight as Challangrossweight,
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      challannetweight   as Challannetweight,
      chqtyunit          as Chqtyunit,
      @Semantics.quantity.unitOfMeasure: 'Chqtyunit'
      challanqty         as Challanqty,
      chdocumt           as Chdocumt,
      @Semantics.user.createdBy: true
      createdby          as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat          as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangedby      as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangedat      as Lastchangedat,

      _Item,
      _Head
}
