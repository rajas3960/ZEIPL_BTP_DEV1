@EndUserText.label: 'Freight Order (S/4 carrier allocation)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MMGE_TMFO_VH_QUERY'
define custom entity ZMMGE_TMFO_VH
{
      @EndUserText.label: 'Purchase Order'
  key Purchaseorder     : abap.char(10);
      @EndUserText.label: 'PO Item'
  key Purchaseorderitem : abap.numc(5);
      @EndUserText.label: 'Carrier'
  key Carrier           : zmmge_carrier_id;
      @EndUserText.label: 'Freight Order'
  key Freightorder      : zmmge_freight_order_id;
      @EndUserText.label: 'Carrier Name'
      Carriername       : abap.char(80);
      @EndUserText.label: 'Valid From'
      Validfrom         : abap.dats;
      @EndUserText.label: 'Valid To'
      Validto           : abap.dats;
      @EndUserText.label: 'Carrier Quantity'
      @Semantics.quantity.unitOfMeasure: 'Orderunit'
      Allocatedqty      : abap.quan(13,3);
      @EndUserText.label: 'Unit'
      Orderunit         : abap.unit(3);
      @EndUserText.label: 'Valid On'
      @UI.hidden        : true
      Validon           : abap.dats;
}
