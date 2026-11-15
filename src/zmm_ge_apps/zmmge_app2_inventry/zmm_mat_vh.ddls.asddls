@EndUserText.label: 'Material Value Help (S/4)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_S4_VH_QUERY'
@Search.searchable: true
define custom entity ZMM_MAT_VH
// with parameters parameter_name : parameter_type
{
      @EndUserText.label: 'Product'
      @ObjectModel.text.element: [ 'Prodesc' ]
      @Search.defaultSearchElement: true
  key Product : abap.char(40);
      @EndUserText.label: 'Plant'
      @ObjectModel.text.element: [ 'Plantname' ]
      @Search.defaultSearchElement: true  
  key Plant : abap.char(4);
      @EndUserText.label: 'Product Description'
      @Search.defaultSearchElement: true        
      Prodesc : abap.char(40);
      @EndUserText.label: 'Plant Name'      
      PlantName : abap.char(30);
  
}
