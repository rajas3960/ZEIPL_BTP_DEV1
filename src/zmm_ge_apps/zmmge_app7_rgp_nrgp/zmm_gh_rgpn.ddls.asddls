@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Gate Pass - Security Gate'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Gpno' ]
define root view entity ZMM_GH_RGPN
  provider contract transactional_query
  as projection on ZMM_IH_RGPN
{
  key Gpuuid,
      @Search.defaultSearchElement: true
      Gpno,
      @ObjectModel.text.element: [ 'GptypeText' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_RGPN_GPTYPE_VH', element: 'Gptype' } }]
      Gptype,
      _GpType.GptypeText  as GptypeText,
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
      Contpr,
      Remarks,
      Dispby,
      @Search.defaultSearchElement: true
      Vehicleno,
      Vehicletype,
      @ObjectModel.text.element: [ 'Transportername' ]
      Transporterid,
      Transportername,
      Lrnumber,
      Lrdate,
      Ewabillno,
      ewabilldate,
      Netwgt,
      Grosswgt,
      Tarewgt,
      Wgtuom,
      Gpvalue,
      Curky,
      Attachment,
      Mimetype,
      Filename,
      Gvnum,
      Gvdat,
      Gvtim,
      Gvby,
      Gotdat,
      Gottim,
      Gotby,
      Createdat,
      Lastchangedat,
      Locallastchangedat,

      /* Associations */
      _Item : redirected to composition child ZMM_GI_RGPN
}
where
  Gpno <> ''
