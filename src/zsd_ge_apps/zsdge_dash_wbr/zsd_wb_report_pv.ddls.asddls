@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Outward Weigh Bridge Dash Board - Report'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@OData.applySupportedForAggregation: #FULL
define root view entity ZSD_WB_REPORT_PV
  provider contract transactional_query
  as projection on ZSD_WB_REPORT_RE
{
  key uuid,
      @EndUserText.label: 'Sales Order'
  key salesdocument,
      @EndUserText.label: 'Order Item'
  key salesitem,
      @EndUserText.label: 'Item Code'
      @ObjectModel.text.element: [ 'materialdesc' ]
      material,
      @EndUserText.label: 'Item Description'
      materialdesc,
      @EndUserText.label: 'Vehicle Number'
      vehicleno,
      @EndUserText.label: 'Party Code'
      @ObjectModel.text.element: [ 'customername' ]
      customer,
      @EndUserText.label: 'Party Name'
      customername,
      @EndUserText.label: 'Transporter Code'
      @ObjectModel.text.element: [ 'transportname' ]
      transportid,
      @EndUserText.label: 'Transporter Name'
      transportname,
      @EndUserText.label: 'Gate Entry Number'
      gateentryno,
      @EndUserText.label: 'Gate Entry Date'
      gateentrydate,
      @EndUserText.label: 'Gate Entry Time'
      gateentrytime,
      @EndUserText.label: 'UOM'
      @Semantics.unitOfMeasure: true
      baseunit,
      @Semantics.quantity.unitOfMeasure: 'baseunit'
      @EndUserText.label: 'Gross Weight'
      grossweight,
      @Semantics.quantity.unitOfMeasure: 'baseunit'
      @EndUserText.label: 'Tare Weight'
      tareweight,
      @Semantics.quantity.unitOfMeasure: 'baseunit'
      @EndUserText.label: 'Net Weight'
      @Aggregation.default: #SUM
      netweight,
      @EndUserText.label: 'Consignee Details'
      consignee,
      @EndUserText.label: 'Bill To Details'
      billto,
      @EndUserText.label: 'Overall Status'
      Gateentrystatus,
      @EndUserText.label: 'Delivery Document'
      deliveryno,
      Criticality
}
