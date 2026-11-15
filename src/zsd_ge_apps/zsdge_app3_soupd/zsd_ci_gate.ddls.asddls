@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Gate Entry Item Apps - Dispatch'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZSD_CI_GATE
  as projection on ZSD_II_GATE
{
  key     Uuid,
  key     Salesdocument,
  key     Salesitem,
          Customer,
          Customername,
          Gateentryno,
          @ObjectModel.text.element: [ 'Plantname' ]
          Plant,
          Plantname,
          Material,
          Materialdesc,
          Baseunit,
          Batch,
          @Semantics.quantity.unitOfMeasure: 'Baseunit'
          Quantity,
          Remark,
          @Semantics.quantity.unitOfMeasure: 'Baseunit'
          Tareweight,
          @Semantics.quantity.unitOfMeasure: 'Baseunit'
          Grossweight,
          @Semantics.quantity.unitOfMeasure: 'Baseunit'
          Netweight,
          Ordertype,
          Distributionchannel,
          Shippingpoint,
          @ObjectModel.text.element: [ 'Weighmentmcndes' ]
          Weighmentmcno,
          Weighmentmcndes,
          Independentrequirementtype,
          Incoterms,
          @EndUserText.label: 'Freight Order'
          @ObjectModel.text.element: [ 'Carriername' ]
          @Consumption.valueHelpDefinition: [{ entity: { name: 'ZSD_TMFO_VH', element: 'Freightorder' },
                                               additionalBinding: [{ localElement: 'Salesdocument',
                                                                     element: 'Salesorder',
                                                                     usage: #FILTER },
                                                                   { localElement: 'Salesitem',
                                                                     element: 'Salesorderitem',
                                                                     usage: #FILTER },
                                                                   { localElement: 'Carrier',
                                                                     element: 'Carrier',
                                                                     usage: #RESULT },
                                                                   { localElement: 'Carriername',
                                                                     element: 'Carriername',
                                                                     usage: #RESULT }] }]
          Freightorder,
          @EndUserText.label: 'Carrier'
          Carrier,
          @EndUserText.label: 'Carrier Name'
          Carriername,
          @EndUserText.label: 'Overdelivery Tolerance %'
          Overdeltolpct,
          OpenQty,
          @EndUserText.label: 'SO Order Qty'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SD_SOUPD_OPENQTY_CALC'
  virtual OrderQtyLive     : abap.dec( 15, 3 ),
          @EndUserText.label: 'Already Delivered'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SD_SOUPD_OPENQTY_CALC'
  virtual DeliveredQtyLive : abap.dec( 15, 3 ),
          @EndUserText.label: 'Open Order Qty'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SD_SOUPD_OPENQTY_CALC'
  virtual OpenQtyLive      : abap.dec( 15, 3 ),
          @EndUserText.label: 'In Yard (Other Trucks)'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SD_SOUPD_OPENQTY_CALC'
  virtual InYardQtyLive    : abap.dec( 15, 3 ),
          @EndUserText.label: 'Possible Loading Qty'
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SD_SOUPD_OPENQTY_CALC'
  virtual FreeQtyLive      : abap.dec( 15, 3 ),
          Createdby,
          Createdat,
          Lastchangedby,
          Lastchangedat,
          /* Associations */
          _Header : redirected to parent ZSD_CH_GATE
}
