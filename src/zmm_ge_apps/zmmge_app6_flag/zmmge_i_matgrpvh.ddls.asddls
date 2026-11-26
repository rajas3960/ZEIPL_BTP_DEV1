@EndUserText.label: 'Material Group Value Help (S/4)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MMGE_MATGRPVH_QUERY'
@Search.searchable: true
define custom entity ZMMGE_I_MATGRPVH
{
      @EndUserText.label: 'Material Group'
      @ObjectModel.text.element: [ 'MaterialGroupName' ]
      @Search.defaultSearchElement: true
  key MaterialGroup     : matkl;

      @EndUserText.label: 'Material Group Name'
      @Search.defaultSearchElement: true
      @Semantics.text: true
      MaterialGroupName : abap.char(20);
}
