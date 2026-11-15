@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Returns - Gate Pass'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Gpno' ]
define root view entity ZMM_RH_RGPN
  provider contract transactional_query
  as projection on ZMM_IH_RGPN
{
  key Gpuuid,
      @Search.defaultSearchElement: true
      Gpno,
      Gptype,
      @ObjectModel.text.element: [ 'StatusText' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_RGPN_STATUS_VH', element: 'Status' } }]
      Gpstatus,
      _Status.StatusText  as StatusText,
      _Status.Criticality as StatusCriticality,
      @ObjectModel.text.element: [ 'Plantname' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMMGE_I_PLANTVH', element: 'Plant' } }]
      Plant,
      Plantname,
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: [ 'Vendname' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_SUP_VH', element: 'Vendor' } }]
      Vendnum,
      @Search.defaultSearchElement: true
      Vendname,
      Cityname,
      Issuedate,
      Issuedby,
      Plnrtndate,
      Rsngp,
      Reqby,
      Reqdpt,
      Remarks,
      @Search.defaultSearchElement: true
      Vehicleno,
      Gpvalue,
      Curky,
      Attachment,
      Mimetype,
      Filename,
      Gvnum,
      Gotdat,
      Gottim,
      Createdat,
      Lastchangedat,
      Locallastchangedat,

      /* Associations */
      _Item : redirected to composition child ZMM_RI_RGPN
}
where
       Gptype   = 'RGP'
  and(
       Gpstatus = '03'
    or Gpstatus = '04'
    or Gpstatus = '05'
  )
