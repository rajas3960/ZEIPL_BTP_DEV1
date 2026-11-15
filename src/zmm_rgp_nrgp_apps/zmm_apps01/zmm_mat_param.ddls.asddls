@EndUserText.label: 'Material Input Parameter'
define abstract entity ZMM_MAT_PARAM
//  with parameters parameter_name : parameter_type
{
    @EndUserText.label: 'Material'
        @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_MAT_VH', element: 'Product' } }]
    Product : matnr;
    @EndUserText.label: 'Plant'
        @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_MAT_VH', element: 'Plant' },
                                       additionalBinding: [
                                       { localElement: 'Product', element: 'Product' ,
                                       usage: #FILTER_AND_RESULT }]}]    
    Plant   : werks_d;
    
}
