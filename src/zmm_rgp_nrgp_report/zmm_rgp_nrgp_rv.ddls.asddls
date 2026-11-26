
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP NRGP Root View'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_RGP_NRGP_RV as select from ZMM_IH_RGPN as A
inner join ZMM_II_RGPN as b on b.Gpuuid = A.Gpuuid

left outer join ZMM_IR_RGPN as C on C.Gpuuid = b.Gpuuid
                            and C.Itemuuid  = b.Itemuuid
                          

{
    key A.Gpuuid, 
    key b.Itemuuid,
    key C.Rcptuuid,
        A.Gpno,
        A.Gptype,
A.Gpstatus,

cast(
    case
        when A.Gpstatus = '01' then 'Created ✅'
        when A.Gpstatus = '02' then 'Gate Verified ✅'
        when A.Gpstatus = '03' then 'Gate Out ✅'
        when A.Gpstatus = '04' then 'Partly Returned ✅'
        when A.Gpstatus = '05' then 'Closed ✅'
        when A.Gpstatus = '06' then 'Gate Not Checked ❌'
        else 'Unknown'
    end
    as abap.char(30)
) as GpStatusText,

cast(
    case
//        when A.Gpstatus = '01' then 5   
        when A.Gpstatus = '02' then 5   
        when A.Gpstatus = '03' then 2   
        when A.Gpstatus = '04' then 2   
        when A.Gpstatus = '05' then 3   
        when A.Gpstatus = '06' then 1   
        else 0                         
    end
    as abap.int1
) as GpStatusCriticality,

        
        b.Itemno,
        A.Vendnum,
        A.Vendname,
        A.Issuedate,
        A.Plnrtndate,
        A.Vehicleno,
        @Semantics.amount.currencyCode: 'Curky'
        A.Gpvalue,            
        A.Curky,
        A.Bpaddrstreetname,
        A.Contpr,
        A.Wgtuom,
        A.Createdby,
        A.Dispby,
        A.Emailaddress,
        A.ewabilldate,
        A.Ewabillno,
        A.Reqby,
        A.Fromplace,
        A.Gotdat,
        A.Gottim,
        A.Gvnum,
        @Semantics.quantity.unitOfMeasure: 'Wgtuom' 
        A.Grosswgt,
        A.Gstin,
        A.Insurno,
        A.Issuedby,
        A.Plant,
        A.Plantname,
        A.Lrdate,
        A.Lrnumber,
        @Semantics.quantity.unitOfMeasure: 'Wgtuom'
        A.Netwgt,
        A.Pan,
        A.Phone,
        A.Postalcode,
        A.Rsngp,
        A.Remarks,
        A.Reqdpt,
        @Semantics.quantity.unitOfMeasure: 'Wgtuom'
        A.Tarewgt,
        A.Toplace,
        A.Transporterid,
        A.transportername,
        A.Gvdat,
        C.Gateinno,
        C.Gateindate,
        C.Invoice,
        C.Challandate,        
        C.Uom,
        @Semantics.quantity.unitOfMeasure: 'Uom'
        b.Quantity,
        @Semantics.quantity.unitOfMeasure: 'Uom'
        C.Recvqty,
        @Semantics.quantity.unitOfMeasure: 'Uom'
        C.Accqty,
        @Semantics.quantity.unitOfMeasure: 'Uom'
        C.Rjtqty,
        @Semantics.quantity.unitOfMeasure: 'Uom'
        b.Totopnqty

}
