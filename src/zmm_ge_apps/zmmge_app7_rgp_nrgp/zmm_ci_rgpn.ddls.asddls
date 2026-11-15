@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Gate Pass - Issue Item'
@Metadata.allowExtensions: true
define view entity ZMM_CI_RGPN
  as projection on ZMM_II_RGPN
{
  key Itemuuid,
      Gpuuid,
      Itemno,
      @ObjectModel.text.element: [ 'Maktx' ]
      Matnr,
      Maktx,
      @ObjectModel.text.element: [ 'Plantname' ]
      Plant,
      Plantname,
//      @ObjectModel.text.element: [ 'Storagelocation' ]
      Storagelocation,
      Hsncode,
      @ObjectModel.text.element: [ 'TaxcodeText' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_RGPN_TAX_VH', element: 'Taxcode' } }]
      Taxcode,
      _Tax.TaxcodeText as TaxcodeText,
      Quantity,
      Uom,
      Netprice,
      Totvalue,
      Curky,
      Totrcvqty,
      Totaccqty,
      Totrjtqty,
      Totopnqty,
      Closed,
      Remarks,
      Createdby,
      Createdat,
      Lastchangedby,
      Lastchangedat,
      Locallastchangedat,

      /* Associations */
      _Header : redirected to parent ZMM_CH_RGPN
}
