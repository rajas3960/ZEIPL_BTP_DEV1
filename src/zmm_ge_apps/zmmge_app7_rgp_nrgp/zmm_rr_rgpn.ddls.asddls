@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Returns - Receipt'
@Metadata.allowExtensions: true
define view entity ZMM_RR_RGPN
  as projection on ZMM_IR_RGPN
{
  key Rcptuuid,
      Itemuuid,
      Gpuuid,
      Rcptno,
      Gateinno,
      Gateindate,
      Gateintime,
      Invoice,
      Challandate,
      Recvqty,
      Accqty,
      Rjtqty,
      Uom,
      Remarks,
      Createdby,
      Createdat,
      Locallastchangedat,

      /* Associations */
      _Item   : redirected to parent ZMM_RI_RGPN,
      _Header : redirected to ZMM_RH_RGPN
}
