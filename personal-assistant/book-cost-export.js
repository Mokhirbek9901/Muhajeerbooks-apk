(function(root){
  'use strict';
  const costs=typeof module==='object' && module.exports?require('./book-costs.js'):root.BookCosts;
  const enc=new TextEncoder();
  const xml=value=>String(value).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g,'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  function crc32(bytes){let crc=0xffffffff;for(const b of bytes){crc^=b;for(let j=0;j<8;j++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}return (crc^0xffffffff)>>>0;}
  function zip(files){
    const chunks=[],central=[];let offset=0;
    for(const [name,text] of files){
      const nameBytes=enc.encode(name),data=enc.encode(text),crc=crc32(data);
      const header=new Uint8Array(30+nameBytes.length),v=new DataView(header.buffer);
      v.setUint32(0,0x04034b50,true);v.setUint16(4,20,true);v.setUint16(10,0,true);v.setUint16(12,33,true);v.setUint32(14,crc,true);v.setUint32(18,data.length,true);v.setUint32(22,data.length,true);v.setUint16(26,nameBytes.length,true);header.set(nameBytes,30);
      chunks.push(header,data);
      const dir=new Uint8Array(46+nameBytes.length),d=new DataView(dir.buffer);
      d.setUint32(0,0x02014b50,true);d.setUint16(4,20,true);d.setUint16(6,20,true);d.setUint16(14,33,true);d.setUint32(16,crc,true);d.setUint32(20,data.length,true);d.setUint32(24,data.length,true);d.setUint16(28,nameBytes.length,true);d.setUint32(42,offset,true);dir.set(nameBytes,46);central.push(dir);offset+=header.length+data.length;
    }
    const size=central.reduce((n,b)=>n+b.length,0),end=new Uint8Array(22),e=new DataView(end.buffer);
    e.setUint32(0,0x06054b50,true);e.setUint16(8,files.length,true);e.setUint16(10,files.length,true);e.setUint32(12,size,true);e.setUint32(16,offset,true);
    const result=new Uint8Array(offset+size+22);let pos=0;for(const b of [...chunks,...central,end]){result.set(b,pos);pos+=b.length;}return result;
  }
  function build(rows,wonPerKg){
    const rate=costs.rate(wonPerKg);
    const table=[['Kitob nomi','Xarid narxi (₩)','Vazni (g)','Yetkazish (₩)','Tan narxi (₩)','Sotuv narxi (₩)','Kutiladigan foyda (₩)','1 kg narxi (₩)'],...rows.map(row=>{const c=costs.calculate(row,rate);return [row.title||'Nomsiz kitob',costs.amount(row.price),costs.amount(row.grams),c.shipping,c.total,costs.amount(row.salePrice),costs.profit(row,rate),rate];})];
    const rowXml=table.map((row,i)=>'<row r="'+(i+1)+'">'+row.map((value,j)=>{const ref=String.fromCharCode(65+j)+(i+1),style=i===0?' s="1"':j===2?' s="3"':j>0?' s="2"':'';return value===null?'<c r="'+ref+'"/>':typeof value==='number'?'<c r="'+ref+'"'+style+'><v>'+value+'</v></c>':'<c r="'+ref+'" t="inlineStr"'+style+'><is><t xml:space="preserve">'+xml(value)+'</t></is></c>';}).join('')+'</row>').join('');
    const ns='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    return zip([
      ['[Content_Types].xml','<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>'],
      ['_rels/.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'],
      ['xl/workbook.xml','<workbook xmlns="'+ns+'" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Kitob tan narxi" sheetId="1" r:id="rId1"/></sheets></workbook>'],
      ['xl/_rels/workbook.xml.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>'],
      ['xl/styles.xml','<styleSheet xmlns="'+ns+'"><numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.###"/></numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF0B4E4B"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0"/><xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>'],
      ['xl/worksheets/sheet1.xml','<worksheet xmlns="'+ns+'"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="1" width="36" customWidth="1"/><col min="2" max="8" width="23" customWidth="1"/></cols><sheetData>'+rowXml+'</sheetData><autoFilter ref="A1:H'+table.length+'"/></worksheet>']
    ]);
  }
  const api={build};if(typeof module==='object' && module.exports)module.exports=api;else root.BookCostExport=api;
})(typeof globalThis==='object'?globalThis:this);
