@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Returns - Item'
@Metadata.allowExtensions: true
define view entity ZMM_RI_RGPN
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
      Totrcvqty,
      Totaccqty,
      Totrjtqty,
      Totopnqty,
      Closed,
      Remarks,
      Locallastchangedat,

      /* Associations */
      _Header  : redirected to parent ZMM_RH_RGPN,
      _Receipt : redirected to composition child ZMM_RR_RGPN
}
