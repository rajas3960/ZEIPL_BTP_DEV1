@EndUserText.label: 'Image Verification - Camera Images'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_SD_IMGVR_IMG_QUERY'
@UI.headerInfo: { typeName: 'Camera Image',
                  typeNamePlural: 'Camera Images',
                  title: { type: #STANDARD, value: 'Stagetext' },
                  description: { type: #STANDARD, value: 'Capturedat' },
                  imageUrl: 'Imageurl' }
define custom entity ZSD_CE_IMGVR_IMG
{
      @UI.facet: [ { id: 'Image', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: 'Camera Data', position: 10 } ]
      @UI.hidden: true
  key Uuid       : sysuuid_x16;
      @UI.hidden: true
  key Stage      : abap.char(1);
      @UI.lineItem: [ { position: 20, label: 'Image No' } ]
      @UI.identification: [ { position: 20, label: 'Image No' } ]
  key Imageno    : abap.int1;
      @UI.lineItem: [ { position: 10, label: 'Stage' } ]
      @UI.identification: [ { position: 10, label: 'Stage' } ]
      Stagetext  : abap.char(10);
      @UI.lineItem: [ { position: 70, label: 'Image Seq' } ]
      @UI.identification: [ { position: 70, label: 'Image Seq (rowid_seq)' } ]
      Rowidseq   : abap.char(20);
      @Semantics.imageUrl: true
      @UI.lineItem: [ { position: 30, label: 'Image' } ]
      Imageurl   : abap.string(0);
      @UI.lineItem: [ { position: 40, label: 'Camera Weight' } ]
      @UI.identification: [ { position: 40, label: 'Camera Weight' } ]
      Camweight  : abap.char(20);
      @UI.lineItem: [ { position: 50, label: 'Number Plate (OCR)' } ]
      @UI.identification: [ { position: 50, label: 'Number Plate (OCR)' } ]
      Ocrtext    : abap.char(60);
      @UI.lineItem: [ { position: 60, label: 'Captured At' } ]
      @UI.identification: [ { position: 60, label: 'Captured At' } ]
      Capturedat : abap.char(20);
      @UI.lineItem: [ { position: 80, label: 'Message' } ]
      @UI.identification: [ { position: 80, label: 'Message' } ]
      Message    : abap.char(255);
}
