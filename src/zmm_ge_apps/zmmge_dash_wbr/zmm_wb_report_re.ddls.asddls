@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inward Weigh Bridge Dash Board - Report'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_WB_REPORT_RE 
as select from zmmge_hdr_t01 as a
inner join zmmge_itm_t01 as b on b.uuid = a.uuid
{
    key a.uuid,
    key b.purchaseorder,
    key b.purchaseorderitem,
        b.material,
        b.materialtext,
        b.baseunit,
        b.vendor,
        b.suppliername,
        a.vehicleno,
        a.trasporterid,
        a.transportername,
        a.gateentryno,
        a.gateentrydate,
        a.gateentrytime,
        @Semantics.quantity.unitOfMeasure: 'baseunit'
        b.grossweight,
        @Semantics.quantity.unitOfMeasure: 'baseunit'        
        b.tareweight,
        @Semantics.quantity.unitOfMeasure: 'baseunit'        
        b.netweight,
        @Semantics.quantity.unitOfMeasure: 'baseunit'        
        b.grnqty,
        b.shortageqty,
      //over all status of gate entry

      cast( case   when a.gateexitindicator = 'X' then 'Gate Out Completed✅'
                   when a.weighmentmcno is not initial then 'Weighment Processing'
                   when a.gateentryid is not initial then 'Gate Entry Created✅'
      //
                 else 'Entry Not Created' end as abap.char(30) )               as Overallstatus,

      cast( case when a.gateexitindicator = 'X' then  3
                 when a.weighmentmcno is not initial then 2
                 when a.gateentryid is not initial then 3
                 else 1 end as abap.int1 )                                     as Criticality
        
}
where
  a.gateentryno is not initial
