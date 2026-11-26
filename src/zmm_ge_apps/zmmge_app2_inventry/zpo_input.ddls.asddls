@EndUserText.label: 'Inventory Ventor & PO Parameter'
define root abstract entity ZPO_INPUT
{
  @EndUserText.label: 'Vendor'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_SUP_VH', element: 'Vendor' } }]
  Vendor            : abap.char(10);
  @EndUserText.label: 'Purchase Order'
  //    @ObjectModel.mandatory: true
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_POHDVH', element: 'PurchaseOrder' },
                                     additionalBinding: [
                                     { localElement: 'Vendor', element: 'Vendor' ,
                                     usage: #FILTER_AND_RESULT }]}]
  PurchaseOrder     : abap.char(10);
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_POITVH', element: 'PurchaseOrderItem' },
                                  additionalBinding: [
                                  { localElement: 'Vendor', element: 'Vendor',usage: #FILTER_AND_RESULT },
                                  { localElement: 'PurchaseOrder', element: 'PurchaseOrder', usage: #FILTER_AND_RESULT }
                                  ] }]
  @EndUserText.label: 'Order Item'
  PurchaseOrderItem : abap.numc(5);
  @EndUserText.label: 'Carrier'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMMGE_TMFO_VH', element: 'Carrier' },
                                  additionalBinding: [
                                  { localElement: 'PurchaseOrder',     element: 'Purchaseorder',     usage: #FILTER },
                                  { localElement: 'PurchaseOrderItem', element: 'Purchaseorderitem', usage: #FILTER }
                                  ] }]
  Carrier           : abap.char(10);
}
