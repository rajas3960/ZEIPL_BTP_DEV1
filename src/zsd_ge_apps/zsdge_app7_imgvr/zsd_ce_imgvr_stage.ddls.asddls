@EndUserText.label: 'Image Verification - Camera Stage'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SD_IMGVR_STAGE_QUERY'
@UI.headerInfo: { typeName: 'Camera Images',
                  typeNamePlural: 'Camera Images',
                  title: { type: #STANDARD, value: 'Stagetext' },
                  description: { type: #STANDARD, value: 'Rowidseq' } }
define root custom entity ZSD_CE_IMGVR_STAGE
{
      @UI.facet: [ { id: 'Capture', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: 'Capture Details', position: 10 } ]
      @UI.hidden: true
  key Uuid       : sysuuid_x16;
      @UI.hidden: true
  key Stage      : abap.char(1);
      @UI.lineItem: [ { position: 10, label: 'Stage' },
                      { type: #FOR_ACTION, dataAction: 'Approve', label: 'Approve', position: 10 },
                      { type: #FOR_ACTION, dataAction: 'Reject', label: 'Reject', position: 20 } ]
      @UI.identification: [ { type: #FOR_ACTION, dataAction: 'Approve', label: 'Approve', position: 10 },
                            { type: #FOR_ACTION, dataAction: 'Reject', label: 'Reject', position: 20 } ]
      Stagetext  : abap.char(10);
      @UI.lineItem: [ { position: 20, label: 'Verification', criticality: 'Statuscrit' } ]
      @UI.identification: [ { position: 10, label: 'Verification', criticality: 'Statuscrit' } ]
      Statustext : abap.char(20);
      @UI.hidden: true
      Statuscrit : abap.int1;
      @UI.lineItem: [ { position: 30, label: 'Image Seq' } ]
      @UI.identification: [ { position: 20, label: 'Image Seq (rowid_seq)' } ]
      Rowidseq   : abap.char(20);
      @UI.identification: [ { position: 30, label: 'Camera Weight' } ]
      Camweight  : abap.char(20);
      @UI.identification: [ { position: 40, label: 'Number Plate (OCR)' } ]
      Ocrtext    : abap.char(60);
      @UI.identification: [ { position: 50, label: 'Captured At' } ]
      Capturedat : abap.char(20);
      @UI.identification: [ { position: 60, label: 'Message' } ]
      Message    : abap.char(255);
      @Semantics.imageUrl: true
      @UI.hidden: true
      Image1     : abap.string(0);
      @Semantics.imageUrl: true
      @UI.hidden: true
      Image2     : abap.string(0);
      @Semantics.imageUrl: true
      @UI.hidden: true
      Image3     : abap.string(0);
      @Semantics.imageUrl: true
      @UI.hidden: true
      Image4     : abap.string(0);
}
