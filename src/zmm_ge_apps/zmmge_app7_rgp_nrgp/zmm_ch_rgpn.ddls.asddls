@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Gate Pass - Issue'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Gpno' ]
define root view entity ZMM_CH_RGPN
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
      Addressid,
      Streetname,
      Bpaddrstreetname,
      Cityname,
      Postalcode,
      Region,
      Gstin,
      Pan,
      Phone,
      Emailaddress,
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
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZGATE_VETYPE_VH', element: 'value_low' } }]
      Vehicletype,
      @ObjectModel.text.element: [ 'Transportername' ]
      @Consumption.valueHelpDefinition: [{entity: { name: 'ZSD_BP_ZTRP_VH', element: 'Transporterid' },
                                        additionalBinding: [{ localElement: 'Transportername', 
                                        element: 'Transportername', usage: #RESULT}]}]
      Transporterid,
      transportername,
      Lrnumber,
      Lrdate,
      Ewabillno,
      ewabilldate,
      Insurno,
      Frghtscope,
      Pcklist,
      Fromplace,
      Toplace,
      Netwgt,
      Grosswgt,
      Tarewgt,
      Wgtuom,
      Gpvalue,
      Curky,
      Attachment,
      Mimetype,
      Filename,
//       @EndUserText.label: 'Upload Supporting Document'
       Zattachment3,
       @Semantics.mimeType: true
       FMinetype,
       FFilename,
      Gvnum,
      Gvdat,
      Gvtim,
      Gvby,
      Gotdat,
      Gottim,
      Gotby,
      Createdby,
      Createdat,
      Lastchangedby,
      Lastchangedat,
      Locallastchangedat,

      /* Associations */
      _Item : redirected to composition child ZMM_CI_RGPN
}
