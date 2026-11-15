@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP & NRGP Outward Creation Apps'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_IH_RPNP
 as select from zmm_app1_tb
  association [0..*] to ZI_GPTYPE     as _gptyp on $projection.Gptype = _gptyp.value_low
  composition [0..*] of ZMM_II_RPNP as _Item1
{
  key uuid           as Uuid,
      gpnum          as Gpnum,
      gptype         as Gptype,
      vendnum        as Vendnum,
      vendname       as Vendname,
      plant          as plant,
      plantname      as plantname,
      plnrtndate     as Plnrtndate,
      vehicleno      as Vehicleno,
      vehicletype    as Vehicletype,
      dispby         as Dispby,
      issuedate      as Issuedate,
      issuedby       as Issuedby,
      transporterid  as Transporterid,
      remarks        as Remarks,
      @Semantics.amount.currencyCode: 'Curky'
      gpvalue        as Gpvalue,
      curky          as Curky,
      rsngp          as Rsngp,
      frghtscope     as Frghtscope,
      pcklist        as Pcklist,
      zattachment    as Zattachment,
      minetype       as Minetype,
      filename       as Filename,
      insurno        as Insurno,
      ewabillno      as Ewabillno,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      netwgt         as Netwgt,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      grosswgt       as Grosswgt,
      @Semantics.quantity.unitOfMeasure : 'Uom'
      tarewgt        as Tarewgt,
      lrnumber       as Lrnumber,
      lrdate         as Lrdate,
      fromplace      as Fromplace,
      toplace        as Toplace,
      uom            as Uom,
      gitdat         as Gitdat,
      gittim         as Gittim,
      gotdat         as Gotdat,
      gottim         as Gottim,
      statustext     as Statustext,
      contpr         as Contpr,
      reqby          as Reqby,
      reqdpt         as Reqdpt,
      seqnum         as Seqnum,
      rgpnrpactualno as Rgpnrpactualno,
      addressid      as Addressid,
      streetname     as Streetname,
      bpaddrstreetname as Bpaddrstreetname,
      gstin           as Gstin,
      cityname        as Cityname,
      postalcode      as Postalcode,
      pan             as Pan,
      phone           as Phone,
      region          as Region,
      emailaddress    as EmailAddress, 
      @Semantics.user.createdBy: true
      createdby      as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat      as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangedby  as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangedat  as Lastchangedat,
      _gptyp.text as Rgptypedesc,
      _Item1      
}
