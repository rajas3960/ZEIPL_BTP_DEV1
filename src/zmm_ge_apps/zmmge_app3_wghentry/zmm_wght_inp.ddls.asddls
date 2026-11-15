@EndUserText.label: 'Inventory Item Weighment Inp'
define abstract entity ZMM_WGHT_INP
{
  @EndUserText.label: 'Weighment Machine'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_WEIGHMENT_VH', element: 'value_low' } }]
  Weighmentmcno : abap.char(10);

  @EndUserText.label: 'Tare Weight'
  Weight        : menge_d;

  @Semantics.unitOfMeasure: true
  @Consumption.valueHelpDefault.display: true
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' } }]
  Unit          : abap.unit(3);
}
