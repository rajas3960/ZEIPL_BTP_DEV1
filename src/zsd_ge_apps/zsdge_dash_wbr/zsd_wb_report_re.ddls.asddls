@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Outward Weigh Bridge Dash Board - Report'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZSD_WB_REPORT_RE
  as select from zsdge_sentry_ht1 as a
    inner join   zsdge_sentry_it1 as b on b.uuid = a.uuid
{
  key a.uuid,
  key b.salesdocument,
  key b.salesitem,
      b.material,
      b.materialdesc,
      a.vehicleno,
      b.customer,
      b.customername,
      a.transportid,
      a.transportname,
      a.gateentryno,
      a.gateentrydate,
      a.gateentrytime,
      b.baseunit,
      @Semantics.quantity.unitOfMeasure: 'baseunit'
      b.grossweight,
      @Semantics.quantity.unitOfMeasure: 'baseunit'
      b.tareweight,
      @Semantics.quantity.unitOfMeasure: 'baseunit'
      b.netweight,
      a.consignee,
      a.billto,
      b.deliveryno,
      cast( case when a.cancelgateentry = 'X' then 'Gate Entry Cancelled❌'
                 when a.exitindic = 'X' then 'Gate Out Completed✅'
                 else 'Gate Entry Active✅' end as abap.char(25) ) as Gateentrystatus,
      cast( case when a.cancelgateentry = 'X' then 1
                 when a.exitindic       = 'X' then 3
                 else 2 end as abap.int1 )                        as Criticality

      //      cast( case when a.cancelgateentry = 'X' then 1
      //                 else 3 end as abap.int1 )                       as Criticality

}
where
  a.gateentryno is not initial
