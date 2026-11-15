@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inward Image Verification - Gate Entry'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZMM_IH_IMGVR
  as select from zmmge_hdr_t01 as a
  association [0..*] to ZSD_CE_IMGVR_IMG   as _Images on $projection.Uuid = _Images.Uuid
  association [0..*] to ZSD_CE_IMGVR_STAGE as _Stages on $projection.Uuid = _Stages.Uuid
{
  key a.uuid                                                                   as Uuid,
      a.gateentryno                                                            as Gateentryno,
      a.gateentrydate                                                          as Gateentrydate,
      a.gateentryseries                                                        as Gateentryseries,
      a.gateentryseriesdes                                                     as Gateentryseriesdes,
      a.plant                                                                  as Plant,
      a.plantname                                                              as Plantname,
      a.vehicleno                                                              as Vehicleno,
      a.trasportername                                                         as Transportname,
      a.drivername                                                             as Drivername,
      a.challanno                                                              as Challanno,
      a.weighmentmcno                                                          as Weighmentmcno,
      a.weighmentmcndes                                                        as Weighmentmcndes,
      a.weighmentdate                                                          as Weighmentdate,
      a.weighmenttime                                                          as Weighmenttime,
      a.weighuom                                                               as Weighuom,
      @Semantics.quantity.unitOfMeasure: 'Weighuom'
      a.grosswt                                                                as Grosswt,
      a.unloadendindi                                                          as Unloadendindi,
      a.imagevaldindicator                                                     as Imagevaldindicator,
      a.imgseqnogross                                                          as Imgseqnogross,
      a.imgseqnotare                                                           as Imgseqnotare,
      a.imgvrstatusgross                                                       as Imgvrstatusgross,
      a.imgvrstatustare                                                        as Imgvrstatustare,
      a.imgrejreason                                                           as Imgrejreason,
      a.imgverifiedby                                                          as Imgverifiedby,
      a.imgverifiedat                                                          as Imgverifiedat,
      @Semantics.user.createdBy: true
      a.createdby                                                              as Createdby,
      @Semantics.systemDateTime.createdAt: true
      a.createdat                                                              as Createdat,
      @Semantics.user.lastChangedBy: true
      a.lastchangedby                                                          as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      a.lastchangedat                                                          as Lastchangedat,

      // stage waiting for a decision: gross first, then tare
      cast( case when a.imgvrstatusgross = 'P' then 'G'
                 when a.imgvrstatustare  = 'P' then 'T'
                 else ' ' end as abap.char(1) )                                as Pendingstage,
      cast( case when a.imgvrstatusgross = 'P' then 'Gross'
                 when a.imgvrstatustare  = 'P' then 'Tare'
                 else ' ' end as abap.char(10) )                               as Pendingstagetext,
      cast( case when a.imgvrstatusgross = 'P' then 'X'
                 when a.imgvrstatustare  = 'P' then 'X'
                 else ' ' end as abap.char(1) )                                as Ispending,

      // status texts + criticality (same as in Inward Weighment)
      cast( case a.imgvrstatusgross when 'P' then 'Pending'
                                    when 'A' then 'Approved'
                                    when 'R' then 'Rejected'
                                    else 'Not captured' end as abap.char(20) ) as Imgstatusgrosstext,
      cast( case a.imgvrstatusgross when 'P' then 2
                                    when 'A' then 3
                                    when 'R' then 1
                                    else 0 end as abap.int1 )                  as Imgcritgross,
      cast( case a.imgvrstatustare when 'P' then 'Pending'
                                   when 'A' then 'Approved'
                                   when 'R' then 'Rejected'
                                   else 'Not captured' end as abap.char(20) )  as Imgstatustaretext,
      cast( case a.imgvrstatustare when 'P' then 2
                                   when 'A' then 3
                                   when 'R' then 1
                                   else 0 end as abap.int1 )                   as Imgcrittare,

      _Images,
      _Stages
}
where
       a.gateentryno   is not initial
  and(
       a.imgseqnogross <> ''
    or a.imgseqnotare  <> ''
  )
