@EndUserText.label: 'Freight Order (S/4 SO carrier allocation)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SD_TMFO_VH_QUERY'
define custom entity ZSD_TMFO_VH
{
      @EndUserText.label: 'Sales Order'
  key Salesorder     : abap.char(10);
      @EndUserText.label: 'SO Item'
  key Salesorderitem : abap.numc(6);
      @EndUserText.label: 'Carrier'
  key Carrier        : zsdge_carrier_id;
      @EndUserText.label: 'Freight Order'
  key Freightorder   : zsdge_freight_order_id;
      @EndUserText.label: 'Carrier Name'
      Carriername    : abap.char(80);
}
