@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP/NRGP Gate Pass - Header'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_IH_RGPN
  as select from zmmge_rgp_hd
  composition [0..*] of ZMM_II_RGPN        as _Item
  association [0..1] to ZMM_RGPN_GPTYPE_VH as _GpType on $projection.Gptype = _GpType.Gptype
  association [0..1] to ZMM_RGPN_STATUS_VH as _Status on $projection.Gpstatus = _Status.Status
{
  key gpuuid             as Gpuuid,
      gpno               as Gpno,
      gptype             as Gptype,
      gpstatus           as Gpstatus,
      plant              as Plant,
      plantname          as Plantname,
      vendnum            as Vendnum,
      vendname           as Vendname,
      addressid          as Addressid,
      streetname         as Streetname,
      bpaddrstreetname   as Bpaddrstreetname,
      cityname           as Cityname,
      postalcode         as Postalcode,
      region             as Region,
      gstin              as Gstin,
      pan                as Pan,
      phone              as Phone,
      emailaddress       as Emailaddress,
      issuedate          as Issuedate,
      issuedby           as Issuedby,
      plnrtndate         as Plnrtndate,
      rsngp              as Rsngp,
      reqby              as Reqby,
      reqdpt             as Reqdpt,
      contpr             as Contpr,
      remarks            as Remarks,
      dispby             as Dispby,
      vehicleno          as Vehicleno,
      vehicletype        as Vehicletype,
      transporterid      as Transporterid,
      transportername    as transportername,
      lrnumber           as Lrnumber,
      lrdate             as Lrdate,
      ewabillno          as Ewabillno,
      ewabilldate        as ewabilldate,
      insurno            as Insurno,
      frghtscope         as Frghtscope,
      pcklist            as Pcklist,
      fromplace          as Fromplace,
      toplace            as Toplace,
      @Semantics.quantity.unitOfMeasure: 'Wgtuom'
      netwgt             as Netwgt,
      @Semantics.quantity.unitOfMeasure: 'Wgtuom'
      grosswgt           as Grosswgt,
      @Semantics.quantity.unitOfMeasure: 'Wgtuom'
      tarewgt            as Tarewgt,
      wgtuom             as Wgtuom,
      @Semantics.amount.currencyCode: 'Curky'
      gpvalue            as Gpvalue,
      curky              as Curky,
      @Semantics.largeObject: { mimeType: 'Mimetype',
                                fileName: 'Filename',
                                contentDispositionPreference: #INLINE }
      attachment         as Attachment,
      @Semantics.mimeType: true
      mimetype           as Mimetype,
      filename           as Filename,
      
@EndUserText.label: 'Upload Supporting Document'
@Semantics.largeObject: {
    fileName: 'FFilename',
    mimeType: 'FMinetype',
    contentDispositionPreference: #ATTACHMENT
}
zattachment as Zattachment3,

@Semantics.mimeType: true
fminetype as FMinetype,

ffilename as FFilename,
      
      gvnum              as Gvnum,
      gvdat              as Gvdat,
      gvtim              as Gvtim,
      gvby               as Gvby,
      gotdat             as Gotdat,
      gottim             as Gottim,
      gotby              as Gotby,
      @Semantics.user.createdBy: true
      createdby          as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat          as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangedby      as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangedat      as Lastchangedat,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      locallastchangedat as Locallastchangedat,

      _Item,
      _GpType,
      _Status
}
