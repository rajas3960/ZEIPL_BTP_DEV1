@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RGP Inward Processing Item - Apps'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZMM_II_RPINW
  as select from zmm_app3_tb
  association to parent ZMM_IH_RPINW as _Header on  $projection.Uuid   = _Header.Uuid
                                                and $projection.Itemno = _Header.Itemno
{
  key uuid         as Uuid,
  key itemno       as Itemno,
  key subuuid      as Subuuid,
      sno          as Sno,
      matnr        as Matnr,
      maktx        as Maktx,
      uom          as Uom,
      @Semantics.quantity.unitOfMeasure: 'Uom'
      quantity     as Quantity,
      indt         as Indt,
      intim        as Intim,
      @Semantics.quantity.unitOfMeasure: 'Uom'      
      recvqty      as Recvqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'      
      penqty       as Penqty,
      invoice      as Invoice,
      gateindate   as Gateindate,
      gateintime   as Gateintime,
      gateinnumber as Gateinnumber,
      @Semantics.quantity.unitOfMeasure: 'Uom'      
      accqty       as Accqty,
      @Semantics.quantity.unitOfMeasure: 'Uom'      
      rjtqty       as Rjtqty,
      createdby    as Createdby,
      createdat    as Createdat,
      _Header
}
