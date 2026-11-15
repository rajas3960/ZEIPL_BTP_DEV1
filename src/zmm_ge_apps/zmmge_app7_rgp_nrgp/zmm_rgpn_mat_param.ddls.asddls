@EndUserText.label: 'RGP/NRGP Add Material Parameter'
define abstract entity ZMM_RGPN_MAT_PARAM
{
  @EndUserText.label: 'Material'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_MAT_VH', element: 'Product' } }]
  Product  : matnr;
  @EndUserText.label: 'Plant'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_MAT_VH', element: 'Plant' },
                                       additionalBinding: [{ localElement: 'Product', element: 'Product',
                                                             usage: #FILTER_AND_RESULT }] }]
  Plant    : werks_d;
  @EndUserText.label: 'Quantity'
  Quantity : abap.dec(13,3);
}
