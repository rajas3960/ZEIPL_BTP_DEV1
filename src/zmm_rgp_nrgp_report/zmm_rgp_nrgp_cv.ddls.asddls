@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP NRGP Projection View'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZMM_RGP_NRGP_CV provider contract transactional_query
as projection on ZMM_RGP_NRGP_RV
{

    key Gpuuid, 
    key Itemuuid,
    key Rcptuuid,
    Gpno,
    Gptype,
//      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZMM_RGPN_STATUS_VH', element: 'Status' } }]
    Gpstatus,
    GpStatusText,
    GpStatusCriticality,      
    Vendnum,
    Vendname,
    Issuedate,
    Plnrtndate,
    Vehicleno,
    @Semantics.amount.currencyCode: 'Curky'
    Gpvalue,
    Curky,
    Bpaddrstreetname,
    Contpr,
    Wgtuom,
    Createdby,
    Dispby,
    Emailaddress,
    ewabilldate,
    Ewabillno,
    Reqby,
    Fromplace,
    Gotdat,
    Gottim,
    Gvnum,
    @Semantics.quantity.unitOfMeasure: 'Wgtuom'
    Grosswgt,
    Gstin,
    Insurno,
    Issuedby,
    Plant,
    Plantname,
    Lrdate,
    Lrnumber,
    @Semantics.quantity.unitOfMeasure: 'Wgtuom'
    Netwgt,
    Pan,
    Phone,
    Postalcode,
    Rsngp,
    Remarks,
    Reqdpt,
    @Semantics.quantity.unitOfMeasure: 'Wgtuom'
    Tarewgt,
    Toplace,
    Transporterid,
    transportername,
    Gvdat,
    Gateinno,
    Gateindate,
    Invoice,
    Challandate,
    Uom,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    Quantity,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    Recvqty,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    Accqty,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    Rjtqty,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    Totopnqty
    
}
