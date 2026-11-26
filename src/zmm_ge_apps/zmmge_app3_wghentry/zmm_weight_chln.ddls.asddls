@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Weight Recording - Challan lines'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Challan', typeNamePlural: 'Challans',
                  title: { type: #STANDARD, value: 'Challanno' } }
define view entity ZMM_WEIGHT_CHLN
  as select from zmmge_chln_t01
{
      @UI.hidden: true
  key chlnuuid           as Chlnuuid,
      @UI.hidden: true
      uuid               as Uuid,
      @UI.hidden: true
      purchaseorder      as Purchaseorder,
      @UI.hidden: true
      purchaseorderitem  as Purchaseorderitem,

      @UI.lineItem: [ { position: 10, label: 'Challan No' } ]
      challanno          as Challanno,
      @UI.lineItem: [ { position: 20, label: 'Challan Date' } ]
      challandate        as Challandate,
      @UI.lineItem: [ { position: 30, label: 'Challan Qty' } ]
      @Semantics.quantity.unitOfMeasure: 'Chqtyunit'
      challanqty         as Challanqty,
      @UI.hidden: true
      chqtyunit          as Chqtyunit,
      @UI.lineItem: [ { position: 40, label: 'Challan Tare Wt' } ]
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      challantareweight  as Challantareweight,
      @UI.lineItem: [ { position: 50, label: 'Challan Gross Wt' } ]
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      challangrossweight as Challangrossweight,
      @UI.lineItem: [ { position: 60, label: 'Challan Net Wt' } ]
      @Semantics.quantity.unitOfMeasure: 'Chbaseunit'
      challannetweight   as Challannetweight,
      @UI.hidden: true
      chbaseunit         as Chbaseunit,
      @UI.lineItem: [ { position: 70, label: 'Challan Document' } ]
      chdocumt           as Chdocumt,
      @UI.lineItem: [ { position: 80, label: 'Sub-Series Gate No' } ]
      subgateentryno     as Subgateentryno,
      @UI.hidden: true
      createdat          as Createdat
}
