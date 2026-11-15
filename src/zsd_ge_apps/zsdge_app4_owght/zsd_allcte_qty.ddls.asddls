@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Allocated Qty'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZSD_ALLCTE_QTY 
as select from zsdge_sentry_it1
{
    key salesdocument as Salesdocument,
    key salesitem as Salesitem,
    cast( sum( netweight ) as abap.dec(15,3)) as Netweight
}
where deliveryno is initial
group by salesdocument,
         salesitem
