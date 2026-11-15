@EndUserText.label: 'Inward Auto Weighment Input Parameter'
define abstract entity ZMM_AUTOWT_INP
{
  @EndUserText.label: 'Weighment Machine'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_WEIGHMENT_VH', element: 'value_low' } }]
  Weighmentmcno : abap.char(10);
}
