@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP & NRGP Gate Pass Creation Apps'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZMM_HP_RPNRP 
provider contract transactional_query
as projection on ZMM_GH_RPNRP
{
    key Uuid,
    Gpnum,
    Gptype,
    Vendnum,
    Vendname,
    Plnrtndate,
    Vehicleno,
    Vehicletype,
    Dispby,
    Issuedate,
    Issuedby,
    Transporterid,
    Remarks,
    @Semantics.amount.currencyCode: 'Curky'
    Gpvalue,
    Curky,
    Rsngp,
    Frghtscope,
    Pcklist,
    Createdby,
    Createdat,
    Lastchangedby,
    Lastchangedat,
    Zattachment,
    Minetype,
    Filename,
    Insurno,
    Ewabillno,
    @Semantics.quantity.unitOfMeasure : 'Uom'
    Netwgt,
    @Semantics.quantity.unitOfMeasure : 'Uom'
    Grosswgt,
    @Semantics.quantity.unitOfMeasure : 'Uom'
    Tarewgt,
    LRnumber,
    LRdate,
    Fromplace,
    Toplace,
    Uom,
    Gitdat,
    Gittim,
    Gotdat,
    Gottim,
    Contpr,
    Reqby,
    Reqdpt,
    Seqnum,
    Rgpnrpactualno,
    Rgptypedesc,
    Statustext,
    /* Associations */    
    _item
}
