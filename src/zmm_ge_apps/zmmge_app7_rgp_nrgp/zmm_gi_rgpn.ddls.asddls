@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Gate Pass - Security Gate Item'
@Metadata.allowExtensions: true
define view entity ZMM_GI_RGPN
  as projection on ZMM_II_RGPN
{
  key Itemuuid,
      Gpuuid,
      Itemno,
      @ObjectModel.text.element: [ 'Maktx' ]
      Matnr,
      Maktx,
      Plant,
      Hsncode,
      Quantity,
      Uom,
      Netprice,
      Totvalue,
      Curky,
      Remarks,
      Locallastchangedat,

      /* Associations */
      _Header : redirected to parent ZMM_GH_RGPN
}
