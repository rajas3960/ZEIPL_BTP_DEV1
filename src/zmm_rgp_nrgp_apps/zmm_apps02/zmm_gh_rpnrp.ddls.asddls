@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP & NRGP Gate Pass Creation Apps'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_GH_RPNRP as select from zmm_app1_tb as a

association [0..*] to ZI_GPTYPE     as _gptyp on $projection.Gptype = _gptyp.value_low
 association[0..*] to ZMM_IP_RPNRP as _item on _item.Uuid = $projection.Uuid


{
  key a.uuid          as Uuid,
      a.gpnum         as Gpnum,
      a.gptype        as Gptype,
      a.vendnum       as Vendnum, 
      a.vendname      as Vendname,
      a.plnrtndate    as Plnrtndate,
      a.vehicleno     as Vehicleno,
      a.vehicletype   as Vehicletype,
      a.dispby        as Dispby,
      a.issuedate     as Issuedate,
      a.issuedby      as Issuedby,
      a.transporterid as Transporterid,
      a.remarks       as Remarks,
      @Semantics.amount.currencyCode: 'Curky'
      a.gpvalue       as Gpvalue,
      a.curky         as Curky,
      a.rsngp         as Rsngp,
      a.frghtscope    as Frghtscope,
      a.pcklist       as Pcklist,
      @Semantics.user.createdBy: true
      a.createdby     as Createdby,
      @Semantics.systemDateTime.createdAt: true
      a.createdat     as Createdat,
      @Semantics.user.lastChangedBy: true
      a.lastchangedby as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      a.lastchangedat as Lastchangedat,
      @EndUserText.label: 'Attachments'
      @Semantics.largeObject:{fileName: 'Filename' ,
                                mimeType: 'Minetype',
                                contentDispositionPreference: #INLINE
                                 }
      a.zattachment   as Zattachment,
      @Semantics.mimeType: true
      a.minetype      as Minetype,
      a.filename      as Filename,
      a.insurno       as Insurno,
      a.ewabillno     as Ewabillno,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      a.netwgt        as Netwgt,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      a.grosswgt      as Grosswgt,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      a.tarewgt       as Tarewgt,
      a.lrnumber    as LRnumber,
      a.lrdate      as LRdate,
      a.fromplace   as Fromplace,
      a.toplace     as Toplace,
      a.uom           as Uom,
      a.gitdat        as Gitdat,
      a.gittim        as Gittim,
      a.gotdat        as Gotdat,
      a.gottim        as Gottim,
      a.contpr        as Contpr,
      a.reqby         as Reqby,
      a.reqdpt        as Reqdpt,
      a.seqnum as Seqnum,
      a.rgpnrpactualno as Rgpnrpactualno,
      a.statustext     as Statustext,
       _item,
      _gptyp.text as Rgptypedesc

}
