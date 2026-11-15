@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inward Weigh Bridge Dash Board - Report'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
//@OData.applySupportedForAggregation: #FULL
define root view entity ZMM_WB_REPORT_PV 
provider contract transactional_query
as projection on ZMM_WB_REPORT_RE
{
    key uuid,
    @EndUserText.label: 'Purchase Order'
    key purchaseorder,
    @EndUserText.label: 'Purchase Item'    
    key purchaseorderitem,
    @EndUserText.label: 'Item code'    
    material,
    @EndUserText.label: 'Item Description'    
    materialtext,
    @EndUserText.label: 'UOM'
    @Semantics.unitOfMeasure: true    
    baseunit,
    @EndUserText.label: 'Supplier'    
    vendor,
    @EndUserText.label: 'Supplier Name'    
    suppliername,
    @EndUserText.label: 'Vehicle No'        
    vehicleno,
    @EndUserText.label: 'Transporter ID'    
    trasporterid,
    @EndUserText.label: 'Transporter Name'    
    transportername,
    @EndUserText.label: 'Gate Entry'    
    gateentryno,
    @EndUserText.label: 'Gate Entry Date'    
    gateentrydate,
    @EndUserText.label: 'Gate Entry Time'    
    gateentrytime,
    @EndUserText.label: 'Gross Weight'    
    @Semantics.quantity.unitOfMeasure: 'baseunit'
    @Aggregation.default: #SUM        
    grossweight,
    @EndUserText.label: 'Tare Weight'    
    @Semantics.quantity.unitOfMeasure: 'baseunit'    
    @Aggregation.default: #SUM    
    tareweight,
    @EndUserText.label: 'Net Weight'    
    @Semantics.quantity.unitOfMeasure: 'baseunit'    
    @Aggregation.default: #SUM    
    netweight,
    @EndUserText.label: 'Accpeted/Inbound Qty'    
    @Semantics.quantity.unitOfMeasure: 'baseunit'    
    @Aggregation.default: #SUM    
    grnqty,
    @EndUserText.label: 'Shortage Qty'    
    shortageqty,
    Overallstatus,
    Criticality
}
