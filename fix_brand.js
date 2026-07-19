const fs = require('fs');

const filePath = String.raw`d:\inventorynew\RetailSale new\RetailSale\lib\screens\dashboard\customer_app_screen.dart`;
let content = fs.readFileSync(filePath, 'utf8');

// Helper: replace specific occurrence
function replaceNth(str, search, replace) {
  const idx = str.indexOf(search);
  if (idx === -1) {
    console.log('NO MATCH for:', search.slice(0, 60));
    return str;
  }
  console.log('REPLACED:', search.slice(0, 60));
  return str.slice(0, idx) + replace + str.slice(idx + search.length);
}

// --- Replace ordered items (ORDERED ITEMS block - line-through style)
const old1 = `'\u2022  \${it['item_name']} x \${q.toStringAsFixed(0)}',\r\n                                                        style: TextStyle(\r\n                                                            fontSize: 13,\r\n                                                            color: Colors.grey.shade600,\r\n                                                            decoration: TextDecoration.lineThrough),`;
const new1 = `(it['brand'] ?? '').toString().isNotEmpty\r\n                                                            ? '\u2022  \${it[\\'item_name\\']} (\${it[\\'brand\\']}) x \${q.toStringAsFixed(0)}'\r\n                                                            : '\u2022  \${it[\\'item_name\\']} x \${q.toStringAsFixed(0)}',\r\n                                                        style: TextStyle(\r\n                                                            fontSize: 13,\r\n                                                            color: Colors.grey.shade600,\r\n                                                            decoration: TextDecoration.lineThrough),`;
content = replaceNth(content, old1, new1);

// --- Replace received items (RECEIVED ITEMS block - w500, grey.shade800)
const old2 = `'\u2022  \${it['item_name']} x \${q.toStringAsFixed(0)}',\r\n                                                        style: TextStyle(\r\n                                                            fontSize: 13,\r\n                                                            fontWeight: FontWeight.w500,\r\n                                                            color: Colors.grey.shade800),`;
const new2 = `(it['brand'] ?? '').toString().isNotEmpty\r\n                                                            ? '\u2022  \${it[\\'item_name\\']} (\${it[\\'brand\\']}) x \${q.toStringAsFixed(0)}'\r\n                                                            : '\u2022  \${it[\\'item_name\\']} x \${q.toStringAsFixed(0)}',\r\n                                                        style: TextStyle(\r\n                                                            fontSize: 13,\r\n                                                            fontWeight: FontWeight.w500,\r\n                                                            color: Colors.grey.shade800),`;
content = replaceNth(content, old2, new2);

// --- Replace regular items (no received_items block - grey.shade800, no fontWeight)
const old3 = `'\u2022  \${it['item_name']} x \${q.toStringAsFixed(0)}',\r\n                                                        style: TextStyle(\r\n                                                            fontSize: 13,\r\n                                                            color: Colors\r\n                                                                .grey.shade800),`;
const new3 = `(it['brand'] ?? '').toString().isNotEmpty\r\n                                                            ? '\u2022  \${it[\\'item_name\\']} (\${it[\\'brand\\']}) x \${q.toStringAsFixed(0)}'\r\n                                                            : '\u2022  \${it[\\'item_name\\']} x \${q.toStringAsFixed(0)}',\r\n                                                        style: TextStyle(\r\n                                                            fontSize: 13,\r\n                                                            color: Colors\r\n                                                                .grey.shade800),`;
content = replaceNth(content, old3, new3);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Done. File written.');
