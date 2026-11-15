@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP & NRGP Outward Creation Apps'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZMM_CH_RPNP 
provider contract transactional_query
as projection on ZMM_IH_RPNP
{
    key Uuid,
    Gpnum,
    @ObjectModel.text.element: [ 'Rgptypedesc' ]
    Gptype,
    @ObjectModel.text.element: [ 'Vendname' ]    
    Vendnum,
    Vendname,
    plant,
    plantname,
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
      @Semantics.largeObject: { mimeType: 'Minetype',
                                fileName: 'Filename',
                                contentDispositionPreference: #INLINE }    
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
    Lrnumber,
    Lrdate,
    Fromplace,
    Toplace,
    Uom,
    Gitdat,
    Gittim,
    Gotdat,
    Gottim,
    Statustext,
    Contpr,
    Reqby,
    Reqdpt,
    Seqnum,
    Rgpnrpactualno,
    Rgptypedesc,
    Createdby,
    Createdat,
    Lastchangedby,
    Lastchangedat,
    /* Associations */
    _Item1 : redirected to composition child ZMM_CI_RPNP
}
